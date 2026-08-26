#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
require_command kubectl
require_kind_context

STATE_DIR="${CAMUNDA_DIR}/.state/ports/${CAMUNDA_VERSION}"
mkdir -p "${STATE_DIR}"
"${SCRIPT_DIR}/stop-port-forward.sh" "${CAMUNDA_VERSION}" >/dev/null 2>&1 || true

cleanup_failed_forwards() {
  "${SCRIPT_DIR}/stop-port-forward.sh" "${CAMUNDA_VERSION}" >/dev/null 2>&1 || true
}
trap cleanup_failed_forwards ERR

start_forward() {
  local service="$1"
  local local_port="$2"
  local remote_port="$3"
  local label="$4"
  local pid

  kubectl --context "${KIND_CONTEXT}" --namespace "${CAMUNDA_NAMESPACE}" get service "${service}" >/dev/null
  nohup kubectl --context "${KIND_CONTEXT}" --namespace "${CAMUNDA_NAMESPACE}" \
    port-forward "service/${service}" "${local_port}:${remote_port}" \
    >"${STATE_DIR}/${label}.log" 2>&1 &
  pid="$!"
  echo "${pid}" >"${STATE_DIR}/${label}.pid"
  sleep 0.25
  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    echo "Failed to start ${label} port forward on localhost:${local_port}." >&2
    sed -n '1,80p' "${STATE_DIR}/${label}.log" >&2
    return 1
  fi
  echo "${label}: http://localhost:${local_port} -> ${service}:${remote_port}"
}

start_forward "${ORCHESTRATION_SERVICE}" 8080 8080 orchestration
if [ "${LEGACY_V1_APIS}" = "true" ]; then
  start_forward "${ORCHESTRATION_SERVICE}" 8081 8080 operate-v1
  start_forward "${ORCHESTRATION_SERVICE}" 8082 8080 tasklist-v1
fi
start_forward "${ORCHESTRATION_SERVICE}" 26500 26500 zeebe-grpc
start_forward "${KEYCLOAK_SERVICE}" 18080 80 keycloak
start_forward "${IDENTITY_SERVICE}" 18081 80 identity
start_forward "${ELASTICSEARCH_SERVICE}" 9200 9200 elasticsearch

trap - ERR
echo "Logs and PID files: ${STATE_DIR}"
