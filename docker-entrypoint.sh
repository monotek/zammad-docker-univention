#!/bin/bash

if [ "$1" = 'zammad' ]; then

  if [ -z "${ES_HOST}" ] || [ -z "${DB_HOST}" ] || [ -z "${DB_USER}" ]  || [ -z "${DB_PASS}" ]  || [ -z "${DB_HOST}" ] || [ -z "${DB_NAME}" ]; then
    echo "ES or DB env vars missing! exiting..."
    exit 1
  fi

  # copy zammad
  rsync -a --delete --exclude 'storage/fs/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}

  # set postgresql db vars
  sed -e "s#.*adapter: postgresql#  adapter: postgresql#g" -e "s#.*database:.*#  database: ${DB_NAME}#g" -e "s#.*username:.*#  username: ${DB_USER}#g" -e "s#.*password:.*#  password: ${DB_PASS}\n  host: ${DB_HOST}\n#g" < config/database.yml.pkgr > config/database.yml \

  # update zammad
  gem update bundler
  bundle install

  # db mirgrate
  bundle exec rake db:migrate &> /dev/null

  if [ $? != 0 ]; then
    echo "creating db & searchindex..."
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake db:seed
  fi

  # es config
  bundle exec rails r "Setting.set('es_url', \"http://${ES_HOST}:9200\")"

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

  # show url
  echo -e "\nZammad will be ready in some seconds! Visit http://localhost:3000 in your browser!"

  sleep infinity

fi
