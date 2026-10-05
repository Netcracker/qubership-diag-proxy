FROM nginx:1.31.6-alpine@sha256:df221db836e1754089190208cee7eeda94f233197056426eda74a43ab1abeac2

ENV APP_UID=10001

COPY src/nginx/nginx.conf /etc/nginx/nginx.conf
COPY src/nginx/100-render-agent-config.sh /docker-entrypoint.d/100-render-agent-config.sh

RUN chmod a+x /docker-entrypoint.d/100-render-agent-config.sh \
    && mkdir -p \
        /etc/nginx/conf.d/http \
        /etc/nginx/conf.d/stream

USER ${APP_UID}
