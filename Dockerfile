FROM nginx:1.31.8-alpine@sha256:713fc2ebfd92e8217db451477182ee91944b123d2b1ee9fd5a8c6e91ca6c3a11

ENV APP_UID=10001 NGINX_ENTRYPOINT_QUIET_LOGS=1

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/100-render-agent-config.sh /docker-entrypoint.d/100-render-agent-config.sh

RUN chmod a+x /docker-entrypoint.d/100-render-agent-config.sh \
    && mkdir -p \
        /etc/nginx/conf.d/http \
        /etc/nginx/conf.d/stream

USER ${APP_UID}
