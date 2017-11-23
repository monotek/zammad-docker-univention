# zammad-docker-univention

Zammad Docker container for Univention server.

* Run:
  - docker run -ti -p 80:80 -e ES_HOST=elasticsearch-host -e DB_HOST=postgresql-host -e DB_NAME=database-name -e DB_USER=postgresql-user -e DB_PASS=postgresql-pass monotek/zammad-docker-univention

* Optional env vars are:
  - ES_USER
  - ES_PASS
  - ES_PROTO
