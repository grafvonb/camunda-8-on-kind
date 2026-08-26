#!/usr/bin/env bash

set -euo pipefail

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMUNDA_DIR="$(cd "${COMMON_DIR}/.." && pwd)"
# shellcheck source=../config/versions.sh
source "${CAMUNDA_DIR}/config/versions.sh"

usage_version() {
  echo "Usage: $1 <8.8|8.9|8.10>" >&2
  exit 2
}

load_version() {
  local requested_version="${1:-}"
  [ -n "${requested_version}" ] || usage_version "${0##*/}"
  configure_version "${requested_version}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}

helm_command() {
  local candidate="${HELM_BIN:-helm}"
  command -v "${candidate}" >/dev/null 2>&1 || {
    echo "Helm executable not found: ${candidate}" >&2
    exit 1
  }
  printf '%s\n' "${candidate}"
}

require_kind_context() {
  kubectl config get-contexts "${KIND_CONTEXT}" >/dev/null 2>&1 || {
    echo "KIND context ${KIND_CONTEXT} does not exist. Run create-cluster.sh ${CAMUNDA_VERSION} once." >&2
    exit 1
  }
}

print_helm_compatibility() {
  local helm_bin="$1"
  local helm_version
  helm_version="$("${helm_bin}" version --short 2>/dev/null || true)"
  echo "Camunda ${CAMUNDA_VERSION} chart ${CHART_VERSION}; upstream-tested Helm: ${HELM_COMPATIBILITY} (detected ${helm_version})."
}
