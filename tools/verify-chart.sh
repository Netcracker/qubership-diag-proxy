#!/usr/bin/env bash

set -euo pipefail

repository_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
chart_dir="${repository_root}/charts/diag-proxy"
render_dir=$(mktemp -d)
trap 'rm -rf "${render_dir}"' EXIT

helm lint "${chart_dir}"

helm template diag-proxy "${chart_dir}" \
  --namespace diag-proxy \
  >"${render_dir}/default.yaml"

helm template diag-proxy "${chart_dir}" \
  --namespace diag-proxy \
  --set tlsConfig.enabled=true \
  --set-string tlsConfig.caCert=ci-ca \
  --set-string tlsConfig.tlsCert=ci-cert \
  --set-string tlsConfig.tlsKey=ci-key \
  >"${render_dir}/tls.yaml"

require_ports() {
  local rendered="$1"
  local port
  for port in 1715 8080 9411 4317 4318 14250 14267 14268 8888; do
    grep -q "containerPort: ${port}" "${rendered}"
  done
}

grep -q 'mountPath: /etc/nginx/conf.d' "${render_dir}/default.yaml"
grep -q 'mountPath: /tmp' "${render_dir}/default.yaml"
if grep -q 'mountPath: /etc/nginx/certs' "${render_dir}/default.yaml"; then
  echo "default values must not mount TLS assets" >&2
  exit 1
fi
if grep -q '^kind: Secret$' "${render_dir}/default.yaml"; then
  echo "default values must not render the TLS secret" >&2
  exit 1
fi
require_ports "${render_dir}/default.yaml"

grep -q 'mountPath: /etc/nginx/certs' "${render_dir}/tls.yaml"
grep -q 'name: ESC_SSL_ENABLED' "${render_dir}/tls.yaml"
grep -q 'name: tls-assets-nc-diag-agent' "${render_dir}/tls.yaml"
grep -q '^kind: Secret$' "${render_dir}/tls.yaml"
require_ports "${render_dir}/tls.yaml"
