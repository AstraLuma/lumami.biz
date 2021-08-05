caddy-lumami:
  service.running:
    - name: caddy
    - reload: true

/srv/lumami.biz:
  file.recurse:
    - source: salt://_artifacts/site
    - clean: true

/etc/caddy/sites/derez.zone:
  file.managed:
    - watch_in:
      - service: caddy-lumami
    - require:
      - file: /srv/lumami.biz
    - contents: |
        lumami.biz {
          root * /srv/lumami.biz
          file_server
        }

        www.lumami.biz {
          redir https://lumami.biz{uri} 301
        }
