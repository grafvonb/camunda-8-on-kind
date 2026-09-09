#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
STATE_DIR="${CAMUNDA_DIR}/.state/ports/${CAMUNDA_VERSION}"

is_managed_forward() {
  local pid="$1"
  local command="${2:-}"

  if [ -z "${command}" ]; then
    command="$(ps -p "${pid}" -o command= 2>/dev/null || true)"
  fi
  case "${command}" in
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${ORCHESTRATION_SERVICE} 8080:8080"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${ORCHESTRATION_SERVICE} 8081:8080"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${ORCHESTRATION_SERVICE} 8082:8080"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${ORCHESTRATION_SERVICE} 26500:26500"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${KEYCLOAK_SERVICE} 18080:80"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${IDENTITY_SERVICE} 18081:80"*) return 0 ;;
    *kubectl*"--context ${KIND_CONTEXT}"*"--namespace ${CAMUNDA_NAMESPACE}"*"port-forward service/${ELASTICSEARCH_SERVICE} 9200:9200"*) return 0 ;;
    *) return 1 ;;
  esac
}

if [ -d "${STATE_DIR}" ]; then
  for pid_file in "${STATE_DIR}"/*.pid; do
    [ -e "${pid_file}" ] || continue
    pid="$(cat "${pid_file}")"
    if kill -0 "${pid}" >/dev/null 2>&1; then
      if is_managed_forward "${pid}"; then
        kill "${pid}" >/dev/null 2>&1 || true
      else
        echo "Ignoring stale PID file ${pid_file}; PID ${pid} is not a managed Camunda ${CAMUNDA_VERSION} port forward." >&2
      fi
    fi
    rm -f "${pid_file}"
  done
fi

# Reconcile forwards that survived after their PID files were lost.
while read -r pid command; do
  [ -n "${pid}" ] || continue
  if is_managed_forward "${pid}" "${command}"; then
    kill "${pid}" >/dev/null 2>&1 || true
  fi
done < <(ps -ax -o pid= -o command=)

echo "Stopped Camunda ${CAMUNDA_VERSION} port forwards."
