# zammad-docker-univention

Zammad Docker container for Univention server.

Run:
* docker run -ti -p 3000:3000 -p 6042:6042 -e ES_HOST=elasticsearch-host -e DB_HOST=postgresql-host -e DB_USER=postgresql-user -e DB_PASS=postgresql-pass zammad/zammad-docker-univention

* Optional env vars are:
  - ES_USER
  - ES_PASS
