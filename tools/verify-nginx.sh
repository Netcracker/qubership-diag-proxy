#!/usr/bin/env bash

set -euo pipefail

image="${1:?usage: verify-nginx.sh <image>}"

work_dir=$(mktemp -d)
trap 'rm -rf "${work_dir}"' EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "${work_dir}/tls.key" \
  -out "${work_dir}/tls.crt" \
  -subj "/CN=diag-proxy-ci" >/dev/null 2>&1
cp "${work_dir}/tls.crt" "${work_dir}/ca.crt"

run_nginx_test() {
  local name="$1"
  shift

  local conf_dir="${work_dir}/${name}/conf.d"
  local tmp_dir="${work_dir}/${name}/tmp"
  mkdir -p "${conf_dir}/http" "${conf_dir}/stream" "${tmp_dir}"
  chmod -R a+rwx "${work_dir}/${name}"

  docker run --rm \
    --user 10001:10001 \
    -v "${conf_dir}:/etc/nginx/conf.d" \
    -v "${tmp_dir}:/tmp" \
    -v "${work_dir}/ca.crt:/etc/nginx/certs/ca.crt:ro" \
    -v "${work_dir}/tls.crt:/etc/nginx/certs/tls.crt:ro" \
    -v "${work_dir}/tls.key:/etc/nginx/certs/tls.key:ro" \
    -e SKIP_HOSTNAME_RESOLVING=true \
    -e ESC_COLLECTOR_NS=profiler \
    -e JAEGER_NS=jaeger \
    "$@" \
    "${image}" nginx -t
}

run_nginx_test plain
run_nginx_test tls -e ESC_SSL_ENABLED=true
