# The Lumami Way of Setting Up Salt

SaltStack is fairly vague about good practices in setting up a Salt Master, and naturally has very few opinions about good usage of third-party software. Given the number of pieces needed for a good setup, we thought we would share our opinions about how to accomplish this.

This guide will outline how we think you should set up a Salt Master. The resulting setup will encourage security best practices (such as not using `sudo` regularly on the most important server in your company) while trying to make best practices easy.

A reminder that your Salt Master is the keys to your kingdom: it has complete access to everything managed by Salt. We use nicknames like "godbox" to describe its power. In general, the people with direct access (either physical or shell) should be as limited as possible, the things running on it should be the bare minimum needed, and Salt operations should be performed through salt-api and other systems.

## Things you will need

* A server: This will be your Salt Master. It doesn't need to be remarkably powerful, but we have have found that terribly weak computers (such as a Raspberry Pi 3) do not run Salt well, and it is strongly encouraged that this is a dedicated physical server preferably at a location you completely control.
* A git host with CI: This is where you will host your Base Repo as well as SpiroFS-deployed repos
* Networking: The chosen server needs to be able to receive connections from:
    - The git CI system via SpiroFS
    - All of the minions
    - Admins via salt-api
    - Let's Encrypt

Some proxying and network juggling can be done (SpiroFS and salt-api via HTTP-based tools, salt via the use of syndics), but careful thought should be employed when desinging such a system.


## Setup

The Salt Master itself will be managed by a masterless minion. This allows you to use some configuration management on the master without intrinsically exposing the master to general salt

1. Do a fresh install of your preferred Linux onto the server. An LTS version is recommended.
2. Install the Salt Minion. This can be done with either the [SaltStack Package Repo](https://repo.saltstack.com/) or [salt bootstrap](https://repo.saltstack.com/). We have found that using the repo (pinned to a major version) is the best way to keep current.
3. Configure the minion for masterless. [SaltStack has instructions](https://docs.saltstack.com/en/latest/topics/tutorials/standalone_minion.html), but the summary is:
    1. Set `/etc/salt/minion` as per below
    2. Restart the minion
4. Copy (or clone) the state into `/srv/salt-master`
5. Run `salt-call state.highstate`

The minion config is extremely simple, just:

```yaml
file_client: local
file_roots:
  base:
    - /srv/salt-master
```

This should apply any state you created to the master. That should include:

* Setting up salt-master itself
* Setting up salt-api
* Configuring ACLs

## The State Configuration

There is a lot of room for site-specific customization here. We will discuss the highlights and critical pieces.

It is suggested you keep the master's salt states in git.

One of the things we do is to have salt "take over" much of the configuration we set out above.

When copying the code below to SLS files, be sure to watch dependencies.

### Basic installation
This is where we manage core packages and such.

```yaml
# This is specific for debian, customize for your own uses
salt-repo:
  pkgrepo.managed:
    - name: 'deb https://repo.saltstack.com/py3/debian/{{release}}/{{grains['osarch']}}/3000 stretch main'
    - key_url: https://repo.saltstack.com/py3/debian/{{release}}/{{grains['osarch']}}/2019.2/SALTSTACK-GPG-KEY.pub
    - file: /etc/apt/sources.list.d/saltstack.list

salt-minion:
  pkg.installed: []
  service.running:
    - enable: true

salt-master:
  pkg.installed: []
  service.running:
    - enable: true
```

### Services

Setting up and configuring SpiroFS and salt-api are significantly more complex. This uses Let's Encrypt to manage the TLS certificates used.

```yaml
certbot:
  pkg.installed

/etc/letsencrypt/cli.ini:
  file.managed:
    - contents: |
        email = webmaster@your.domain.example
        agree-tos = True
        noninteractive = True

spirofs:
  pip.installed:
    - bin_env: /usr/bin/pip3

CherryPy:
  pip.installed:
    - bin_env: /usr/bin/pip3

salt.your.domain.example:
  acme.cert:
    - listen_in:
      service: salt-master

salt-api:
  pkg.installed: []
  service.running:
    - enable: true
    - requires:
      - pkg: salt-api
      - pip: CherryPy
    - watch:
      - acme: salt.your.domain.example

/etc/salt/master.d/services.conf:
  file.serialize:
    - requires:
      - pip: spirofs
    - listen_in:
      - service: salt-master
      - service: salt-api
    - dataset:
        # Enable salt-api
        rest_cherrypy:
          port: 8000
          ssl_crt: /etc/letsencrypt/live/salt.your.domain.example/fullchain.pem
          ssl_key: /etc/letsencrypt/live/salt.your.domain.example/privkey.pem
        engines:
          # Enable spirofs
          - spiro:
              port: 4510
              ssl_crt: /etc/letsencrypt/live/salt.your.domain.example/fullchain.pem
              ssl_key: /etc/letsencrypt/live/salt.your.domain.example/privkey.pem
```

This will change considerably if you decide to make use of reverse proxies or other HTTP middleware. The important thing is that these are configured to stream requests and responses, not to buffer them.

And remember, this is transporting configuration for your entire infrastructure. Please use TLS.

### Permissions

In order to use salt-api, some authentication needs to be set up. The example below uses pam (system logins) and the system group `salt` to authenticate and authorize users, but you are endouraged to use what works well for you.

```yaml
/etc/salt/master.d/services.conf:
  file.serialize:
    - listen_in:
      - service: salt-master
    - dataset:
        external_auth:
          pam:
            'salt%':
              - .*
              - '@wheel'
              - '@runner'
```

Please see the [Salt Documentation](https://docs.saltstack.com/en/latest/topics/eauth/index.html) for more information on how to configure this as well as the [list of eauth modules](https://docs.saltstack.com/en/latest/ref/auth/all/).

### Fileserver

The parts below are required for SpiroFS, but additions may be made to taste.

```yaml
/etc/salt/master.d/fileserver.conf:
  file.serialize:
    - listen_in:
      - service: salt-master
    - dataset:
        fileserver_backend:
          - spiro
```

### Updating

One last thing: In order for Let's Encrypt to function, a bunch of the above states must be re-evaluated on a schedule. This can be handled with a few different strategies.

A very common practice is to just run `state.highstate` on everything on a regular basis. We have heard rumor that this is done as often as every 15 minutes, but we generally set it to a few times a day:

```yaml
highstate:
  schedule.present:
    - function: state.highstate
    - hours: 12
    - splay: 7200
```

If you prefer something more specific, something like this might be more to your liking:

```yaml
cert-renew:
  schedule.present:
    - function: state.apply
    - job_args:
      - master
    - hours: 12
    - splay: 300
```

The splay above is something that helps when lot of systems are doing this. It allows the specific time to drift, preventing lockstep, aliasing-like, or load spike problems from occurring. It is not required, but it can prevent odd operational issues.

## What Next

With all of the configuration above applied and functioning, your master should be all configured and ready for use.

See the [SpiroFS docs](https://spirostack.com/spirofs/#spiro-deploy-configuration) and [spiro-deploy docs](https://spirostack.com/spirofs/deploy/) for how to deploy to this set up.
