#!/bin/ash

set -e

### Constants

# User should just set this variable with any value
# SKIP_HOSTNAME_RESOLVING=true

# Default Kubernetes Service name
JAEGER_DEFAULT_COLLECTOR_SERVICE_NAME="jaeger-collector"
ESC_DEFAULT_COLLECTOR_SERVICE_NAME="esc-collector-service"
ESC_DEFAULT_STATIC_SERVICE_NAME="esc-static-service"

# ESC/CDT ports
ESC_DEFAULT_COLLECTOR_PORT="1715"
ESC_DEFAULT_STATIC_PORT="8080"

# Jaeger ports
JAEGER_DEFAULT_ZIPKIN_PORT="9411"
JAEGER_DEFAULT_GRPC_PORT="14250"
JAEGER_DEFAULT_AGENT_PORT="14267"
JAEGER_DEFAULT_THRIFT_PORT="14268"
JAEGER_DEFAULT_OTEL_GRPC_PORT="4317"
JAEGER_DEFAULT_OTEL_HTTP_PORT="4318"

### Functions to build nginx config and resolve endpoints

function search_endpoint() {
    BASE="${1}"
    if [[ ${BASE} =~ ^[0-9]{1-3}\.[0-9]{1-3}\.[0-9]{1-3}\.[0-9]{1-3}$ ]]; then
        ret_val="${BASE}"
        return 0
    fi
    RESOLVED="$(getent hosts "${BASE}" | sed -E 's/[^\s]+\s+(.+)/\1/' | head -n 1 | awk '{print $1}')"
    if [[ -z "${RESOLVED}" ]]; then
        echo >&2 "can not resolve domain name ${BASE}"
        exit 1
    fi
    ret_val="${RESOLVED}"
}

function forward_server() {
    ENDPOINT="$1"
    ENDPOINT_PORT="$2"
    PORT="$3"
    SSL="$4"

    # ENV variable should be set and has a "true" value
    if [ -n ${SKIP_HOSTNAME_RESOLVING} ] && [ ${SKIP_HOSTNAME_RESOLVING:-"false"} == "true" ]; then
        echo "skip endpoint resolving, proxy :${PORT} -> ${ENDPOINT}:${ENDPOINT_PORT}"
    else
        local ret_val=none
        search_endpoint "$ENDPOINT" || (echo "could not parse ${ENDPOINT}" && exit 1)
        ENDPOINT=$ret_val
        echo "resolved endpoint ${ENDPOINT} into $ret_val, proxy :${PORT} -> ${ENDPOINT}:${ENDPOINT_PORT}"
    fi

    if [ -n ${SSL} ] && [ ${SSL:-"false"} = "true" ]; then
        the_http_forward='
server {
'"${RESOLVERS}"'
    listen 0.0.0.0:'"${PORT}"';
    server_name _;
    location / {
      set $backend_in_var_for_dns_resolv '"${ENDPOINT}"';
      proxy_pass https://$backend_in_var_for_dns_resolv:'"${ENDPOINT_PORT}"';
      proxy_buffer_size 8k;
      proxy_connect_timeout 1s;
      proxy_ssl_trusted_certificate /etc/nginx/certs/ca.crt;
      proxy_ssl_certificate /etc/nginx/certs/tls.crt;
      proxy_ssl_certificate_key /etc/nginx/certs/tls.key;
      proxy_ssl_verify on;
      proxy_ssl_verify_depth 1;
      client_max_body_size 10G;
    }
}'

        the_stream_forward='
server {
    listen 0.0.0.0:'"${PORT}"';
    set $backend_in_var_for_dns_resolv '"${ENDPOINT}"';
    proxy_pass $backend_in_var_for_dns_resolv:'"${ENDPOINT_PORT}"';
    proxy_buffer_size 8k;
    proxy_connect_timeout 1s;
    proxy_ssl_name '"${ENDPOINT}"';
    proxy_ssl_server_name on;
    proxy_ssl_certificate /etc/nginx/certs/tls.crt;
    proxy_ssl_certificate_key /etc/nginx/certs/tls.key;
    proxy_ssl_trusted_certificate /etc/nginx/certs/ca.crt;
    proxy_ssl_protocols TLSv1.2 TLSv1.3;
    proxy_ssl_verify on;
    proxy_ssl on;
    proxy_ssl_verify_depth 1;
}'
    else
        the_http_forward='
server {
'"${RESOLVERS}"'
    listen 0.0.0.0:'"${PORT}"';
    server_name _;
    location / {
      set $backend_in_var_for_dns_resolv '"${ENDPOINT}"';
      proxy_pass http://$backend_in_var_for_dns_resolv:'"${ENDPOINT_PORT}"';
      proxy_buffer_size 8k;
      proxy_connect_timeout 1s;
      client_max_body_size 10G;
    }
}'

        the_stream_forward='
server {
    listen 0.0.0.0:'"${PORT}"';
    set $backend_in_var_for_dns_resolv '"${ENDPOINT}"';
    proxy_pass $backend_in_var_for_dns_resolv:'"${ENDPOINT_PORT}"';
    proxy_buffer_size 8k;
    proxy_connect_timeout 1s;
}'
    fi
}

function assemble_stream_forwards() {
    local the_stream_forward
    local the_http_forward

    if [ -n "${ESC_COLLECTOR_HOST}" ]; then
        forward_server "${ESC_COLLECTOR_HOST}" "${ESC_COLLECTOR_PORT}" "${ESC_DEFAULT_COLLECTOR_PORT}" "${ESC_SSL_ENABLED}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
    fi

    if [ -n "${ESC_STATIC_HOST}" ]; then
        forward_server "${ESC_STATIC_HOST}" "${ESC_STATIC_PORT}" "${ESC_DEFAULT_STATIC_PORT}" "${ESC_SSL_ENABLED}" || exit 1
        HTTP_FORWARDS="${HTTP_FORWARDS}${the_http_forward}"
    fi

    if [ -n "${ZIPKIN_COLLECTOR_HOST}" ]; then
        forward_server "${ZIPKIN_COLLECTOR_HOST}" "${ZIPKIN_COLLECTOR_PORT}" "${JAEGER_DEFAULT_ZIPKIN_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
    fi

    if [ -n "${JAEGER_COLLECTOR_HOST}" ]; then
        # Proxy ports to send data in Jaeger protocol (OpenTracing)
        forward_server "${JAEGER_COLLECTOR_HOST}" "${JAEGER_GRPC_PORT}" "${JAEGER_DEFAULT_GRPC_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
        forward_server "${JAEGER_COLLECTOR_HOST}" "${JAEGER_AGENT_PORT}" "${JAEGER_DEFAULT_AGENT_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
        forward_server "${JAEGER_COLLECTOR_HOST}" "${JAEGER_THRIFT_PORT}" "${JAEGER_DEFAULT_THRIFT_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"

        # Proxy ports to send data in OpenTelemetry protocol
        forward_server "${JAEGER_COLLECTOR_HOST}" "${JAEGER_OTEL_GRPC_PORT}" "${JAEGER_DEFAULT_OTEL_GRPC_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
        forward_server "${JAEGER_COLLECTOR_HOST}" "${JAEGER_OTEL_HTTP_PORT}" "${JAEGER_DEFAULT_OTEL_HTTP_PORT}" || exit 1
        STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"

        # Proxy port to send data in Jaeger with using Zipkin protocol
        if [ -z "${ZIPKIN_COLLECTOR_HOST}" ]; then
            forward_server "${JAEGER_COLLECTOR_HOST}" "${ZIPKIN_COLLECTOR_PORT}" "${JAEGER_DEFAULT_ZIPKIN_PORT}" || exit 1
            STREAM_FORWARDS="${STREAM_FORWARDS}${the_stream_forward}"
        fi
    fi
}

### Set defaults if ENV is not specified
if [ -z "${ESC_COLLECTOR_PORT}" ]; then
    if [ -n ${ESC_SSL_ENABLED} ] && [ ${ESC_SSL_ENABLED:-"false"} == "true" ]; then
        ESC_COLLECTOR_PORT="1717"
    else
        ESC_COLLECTOR_PORT="1715"
    fi
fi
if [ -z "${ESC_STATIC_PORT}" ]; then
    if [ -n ${ESC_SSL_ENABLED} ] && [ ${ESC_SSL_ENABLED:-"false"} == "true" ]; then
        ESC_STATIC_PORT="8443"
    else
        ESC_STATIC_PORT="8080"
    fi
fi
if [ -z "${ZIPKIN_COLLECTOR_PORT}" ]; then
    ZIPKIN_COLLECTOR_PORT="9411"
fi
if [ -z "${JAEGER_GRPC_PORT}" ]; then
    JAEGER_GRPC_PORT="14250"
fi
if [ -z "${JAEGER_AGENT_PORT}" ]; then
    JAEGER_AGENT_PORT="14267"
fi
if [ -z "${JAEGER_THRIFT_PORT}" ]; then
    JAEGER_THRIFT_PORT="14268"
fi
if [ -z "${JAEGER_OTEL_GRPC_PORT}" ]; then
    JAEGER_OTEL_GRPC_PORT="4317"
fi
if [ -z "${JAEGER_OTEL_HTTP_PORT}" ]; then
    JAEGER_OTEL_HTTP_PORT="4318"
fi

### Generate hosts parameters if they are not se, but set "*_NS" ENVs

# Generate "esc-collector-service.${ESC_COLLECTOR_NS}" if ESC_COLLECTOR_HOST is not set
# otherwise continue use ESC_COLLECTOR_HOST
if [ -z "${ESC_COLLECTOR_HOST}" ]; then
    if [ -n "${ESC_COLLECTOR_NS}" ]; then
        ESC_COLLECTOR_HOST="${ESC_DEFAULT_COLLECTOR_SERVICE_NAME}.${ESC_COLLECTOR_NS}.svc"
    fi
fi

# Generate "esc-static-service.${ESC_COLLECTOR_NS}" if ESC_STATIC_HOST is not set
# otherwise continue use ESC_STATIC_HOST
if [ -z "${ESC_STATIC_HOST}" ]; then
    if [ -n "${ESC_COLLECTOR_NS}" ]; then
        ESC_STATIC_HOST="${ESC_DEFAULT_STATIC_SERVICE_NAME}.${ESC_COLLECTOR_NS}.svc"
    fi
fi

# Generate "jaeger-collector.${JAEGER_NS}" if JAEGER_COLLECTOR_HOST is not set
# otherwise continue use JAEGER_COLLECTOR_HOST
if [ -z "${JAEGER_COLLECTOR_HOST}" ]; then
    if [ -n "${JAEGER_NS}" ]; then
        JAEGER_COLLECTOR_HOST="${JAEGER_DEFAULT_COLLECTOR_SERVICE_NAME}.${JAEGER_NS}.svc"
    fi
fi

### Build nginx config
PROBE_CONFIG="
server {
  listen 8888;
  listen [::]:8888;
  server_name  _;
  location /health {
      access_log off;
      # default_type application/json;
      return 200 '{\"status\":\"UP\"}';
  }

  location /probes/live {
      access_log off;
      # default_type application/json;
      return 200 '{\"status\":\"UP\"}';
  }

  location /probes/ready {
      access_log off;
      # default_type application/json;
      return 200 '{\"status\":\"UP\"}';
  }
}"

HTTP_FORWARDS=""
STREAM_FORWARDS=""
RESOLVERS=$(grep nameserver /etc/resolv.conf | sed -E 's/^nameserver\s+([^\s]+\s*$)$/resolver \1 valid=10s;/')

assemble_stream_forwards

mkdir -p /etc/nginx/conf.d/http /etc/nginx/conf.d/stream

# Render probe server config
echo "${PROBE_CONFIG}" >/etc/nginx/conf.d/http/01-probe.conf

# Render HTTP proxy config
echo "${HTTP_FORWARDS}" >/etc/nginx/conf.d/http/02-http-proxy.conf

# Render TCP proxy server config
{
    echo "${RESOLVERS}"
    echo "${STREAM_FORWARDS}"
} >/etc/nginx/conf.d/stream/01-tcp-proxy.conf
