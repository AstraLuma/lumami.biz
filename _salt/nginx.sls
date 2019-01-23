nginx-lumami:
  service.running:
    - name: nginx
    - reload: true

/srv/lumami.biz:
  file.recurse:
    - source: salt://_artifacts/site
    - clean: true

lumami.biz:
  acme.cert:
    - email: webmaster@lumami.biz
    - webroot: /srv/certbot
    - watch_in:
        - service: nginx-lumami

www.lumami.biz:
  acme.cert:
    - email: webmaster@lumami.biz
    - webroot: /srv/certbot

/etc/nginx/sites-enabled/lumami.biz:
  file.managed:
    - watch_in:
      - service: nginx
    - require:
      - acme: lumami.biz
      - file: /srv/lumami.biz
    - contents: |
        server {
          listen 443;
          listen [::]:443;

          server_name lumami.biz;

          ssl_certificate /etc/letsencrypt/live/lumami.biz/fullchain.pem;
          ssl_certificate_key /etc/letsencrypt/live/lumami.biz/privkey.pem;
          ssl_trusted_certificate /etc/letsencrypt/live/lumami.biz/chain.pem;

          location / {
            alias /srv/lumami.biz/;
          }
        }

/etc/nginx/sites-enabled/www.lumami.biz:
  file.managed:
    - watch_in:
      - service: nginx
    - require:
      - acme: www.lumami.biz
    - contents: |
        server {
          listen 443;
          listen [::]:443;

          server_name www.lumami.biz;

          ssl_certificate /etc/letsencrypt/live/www.lumami.biz/fullchain.pem;
          ssl_certificate_key /etc/letsencrypt/live/www.lumami.biz/privkey.pem;
          ssl_trusted_certificate /etc/letsencrypt/live/www.lumami.biz/chain.pem;

          return 301 https://lumami.biz$request_uri$is_args$args;
        }
