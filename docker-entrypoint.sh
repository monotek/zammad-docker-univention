#!/bin/bash

set -e

if [ "$1" = 'zammad' ]; then

  if [ -z "${ES_HOST}" ] || [ -z "${DB_HOST}" ] || [ -z "${DB_USER}" ]  || [ -z "${DB_PASS}" ]  || [ -z "${DB_HOST}" ]; then
    echo "ES or DB env vars missing! exiting..."
    exit 1
  fi

  # wait for postgres process coming up on zammad-postgresql
  until (echo > /dev/tcp/${DB_HOST}/5432) &> /dev/null; do
    echo "zammad railsserver waiting for postgresql server to be ready..."
    sleep 5
  done

  echo "railsserver can access postgresql server now..."

  rsync -a --delete --exclude 'storage/fs/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}

  cd ${ZAMMAD_DIR}

  # set postgresql db vars
  sed -e "s#.*adapter: postgresql#  adapter: postgresql#g" -e "s#.*username:.*#  username: ${DB_USER}#g" -e "s#.*password:.*#  password: ${DB_PASS}\n  host: ${DB_HOST}\n#g" < config/database.yml.pkgr > config/database.yml \

  # update zammad
  gem update bundler
  bundle install

  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  # db mirgrate
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rake db:migrate &> /dev/null

  if [ $? != 0 ]; then
    echo "creating db & searchindex..."
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rake db:create
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rake db:migrate
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rake db:seed
  fi

  # es config
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rails r "Setting.set('es_url', 'http://${ES_HOST}:9200')"

  if [ -n "${ES_USER}" ] && [ -n "${ES_PASS}" ]; then
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rails r "Setting.set('es_user', \"${ES_USER}\")"
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rails r "Setting.set('es_password', \"${ES_PASS}\")"
  fi

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec rake searchindex:rebuild

  # start zammad
  echo "starting zammad...."
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run &>> ${ZAMMAD_DIR}/log/zammad.log &
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start &>> ${ZAMMAD_DIR}/log/zammad.log &
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV} &>> ${ZAMMAD_DIR}/log/zammad.log &

  # wait for zammad processe coming up
  until (echo > /dev/tcp/localhost/3000) &> /dev/null; do
    echo "waiting for zammad to be ready..."
    sleep 2
  done

  # show url
  echo -e "\nZammad is ready! Visit http://localhost:3000 in your browser!"

  sleep infinity

fi
