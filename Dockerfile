FROM nginx:1.31.5-alpine@sha256:72ba65eb42c10344912a84ff42408db7d34f2feb642204570ab8fc5ffd29f1d3

ENV APP_UID=10001

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/100-render-agent-config.sh /docker-entrypoint.d/100-render-agent-config.sh

RUN chmod a+x /docker-entrypoint.d/100-render-agent-config.sh \
    && mkdir -p \
        /etc/nginx/conf.d/http \
        /etc/nginx/conf.d/stream

USER ${APP_UID}
