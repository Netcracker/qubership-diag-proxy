FROM nginx:1.31.8-alpine@sha256:785835ea65db4bba6f021acc0f3be91b0fef76a53fe41f8588c6698d2aed0606

ENV APP_UID=10001 NGINX_ENTRYPOINT_QUIET_LOGS=1

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/100-render-agent-config.sh /docker-entrypoint.d/100-render-agent-config.sh

RUN chmod a+x /docker-entrypoint.d/100-render-agent-config.sh \
    && mkdir -p \
        /etc/nginx/conf.d/http \
        /etc/nginx/conf.d/stream

USER ${APP_UID}
