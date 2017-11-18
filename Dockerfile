FROM ruby:2.4.1-slim
MAINTAINER Zammad <info@zammad.org>
ARG BUILD_DATE

ENV ZAMMAD_DIR /home/zammad
ENV ZAMMAD_TMP_DIR /tmp/zammad
ENV ZAMMAD_USER zammad
ENV RAILS_ENV production
ENV GIT_URL https://github.com/zammad/zammad.git
ENV GIT_BRANCH stable
ENV GOSU_VERSION 1.10

VOLUME /home/zammad

# install dependencies, GOSU & zammad
RUN BUILD_DEPENDENCIES="git build-essential libffi-dev libpq5 libpq-dev rsync" \
    GOSU_DEPENDENCIES="ca-certificates wget" \
    set -ex \
	  && apt-get update && apt-get install -y --force-yes --no-install-recommends ${BUILD_DEPENDENCIES} ${GOSU_DEPENDENCIES} && rm -rf /var/lib/apt/lists/* \
	  && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture)" \
	  && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$(dpkg --print-architecture).asc" \
	  && export GNUPGHOME="$(mktemp -d)" \
	  && gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
	  && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
	  && rm -rf "${GNUPGHOME}" /usr/local/bin/gosu.asc \
	  && chmod +x /usr/local/bin/gosu \
	  && gosu nobody true \
    && useradd -M -d ${ZAMMAD_DIR} -s /bin/bash ${ZAMMAD_USER} \
    && cd $(dirname ${ZAMMAD_TMP_DIR}) \
    && git clone --depth 1 -b "${GIT_BRANCH}" "${GIT_URL}" \
    && cd ${ZAMMAD_TMP_DIR} \
    && bundle install --without test development mysql \
    && contrib/packager.io/fetch_locales.rb \
    && sed -e 's#.*adapter: postgresql#  adapter: nulldb#g' -e 's#.*username:.*#  username: postgres#g' -e 's#.*password:.*#  password: \n  host: zammad-postgresql\n#g' < config/database.yml.pkgr > config/database.yml \
    && bundle exec rake assets:precompile \
    && rm -r tmp/cache \
    && chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_TMP_DIR}

# docker init
COPY docker-entrypoint.sh /
RUN chown ${ZAMMAD_USER}:${ZAMMAD_USER} /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD [ "zammad" ]

WORKDIR ${ZAMMAD_DIR}
