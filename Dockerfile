FROM nginx:1.31.3-alpine@sha256:4a73073bd557c65b759505da037898b61f1be6cbcc3c2c3aeac22d2a470c1752

ENV APP_UID=10001

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/100-render-agent-config.sh /docker-entrypoint.d/100-render-agent-config.sh

RUN chmod a+x /docker-entrypoint.d/100-render-agent-config.sh \
    && mkdir -p \
        /etc/nginx/conf.d/http \
        /etc/nginx/conf.d/stream

USER ${APP_UID}
