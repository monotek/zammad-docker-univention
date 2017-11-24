#!/bin/bash

set -ex

if [ "$1" = 'zammad' ]; then

  if [ -z "${ES_HOST}" ] || [ -z "${DB_HOST}" ] || [ -z "${DB_USER}" ]  || [ -z "${DB_PASS}" ]  || [ -z "${DB_HOST}" ] || [ -z "${DB_NAME}" ]; then
    echo "ES or DB env vars missing! exiting..."
    exit 1
  fi

  echo ${ZAMMAD_DIR}

  ls -al

  cd ${ZAMMAD_DIR}

  ls -al
  ls -al config

  # change db config to DB env vars
  sed -e "s#.*adapter:.*#  adapter: postgresql#g" -e "s#.*database:.*#  database: ${DB_NAME}#g" -e "s#.*username:.*#  username: ${DB_USER}#g" -e "s#.*password:.*#  password: ${DB_PASS}\n  host: ${DB_HOST}\n#g" < config/database.yml.pkgr > config/database.yml

  # db mirgrate
  bundle exec rake db:migrate &> /dev/null

  if [ $? != 0 ]; then
    echo "creating db & searchindex..."
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake db:seed
  fi

  # es config
  bundle exec rails r "Setting.set('es_url', \"${ES_PROTO:-http}://${ES_HOST}:9200\")"

  if [ -n "${ES_USER}" ] && [ -n "${ES_PASS}" ]; then
    bundle exec rails r "Setting.set('es_user', \"${ES_USER}\")"
    bundle exec rails r "Setting.set('es_password', \"${ES_PASS}\")"
  fi

  bundle exec rake searchindex:rebuild

  # start zammad
  echo "starting zammad...."
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  su -c "bundle exec script/websocket-server.rb -b 0.0.0.0 start &" ${ZAMMAD_USER}
  su -c "bundle exec script/scheduler.rb start &" ${ZAMMAD_USER}
  su -c "bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV} &" ${ZAMMAD_USER}

  /usr/sbin/nginx -g 'daemon off;'

fi
