#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=cluster-runtime.sh
source "${SCRIPT_DIR}/cluster-runtime.sh"

load_version "${1:-}"
require_command kind
require_command kubectl
require_docker_daemon

case "${2:-}" in
  '') RESUME_INSTALL=0 ;;
  --resume-install) RESUME_INSTALL=1 ;;
  *)
    echo "Usage: ${0##*/} <8.8|8.9|8.10> [--resume-install]" >&2
    exit 2
    ;;
esac

if cluster_exists "${KIND_CLUSTER}"; then
  if [ "${RESUME_INSTALL}" = "0" ]; then
    echo "KIND cluster ${KIND_CLUSTER} already exists; it was not recreated." >&2
    echo "Use ${SCRIPT_DIR}/switch-cluster.sh ${CAMUNDA_VERSION} to activate it." >&2
    echo "Use --resume-install only to continue an interrupted first installation." >&2
    exit 1
  fi

  stop_tracked_forwards_for_all_versions
  stop_other_supported_clusters "${KIND_CLUSTER}"
  start_cluster_containers "${KIND_CLUSTER}"
  "${SCRIPT_DIR}/install.sh" "${CAMUNDA_VERSION}"
  echo "Resumed and completed the Camunda ${CAMUNDA_VERSION} installation in ${KIND_CLUSTER}."
  exit 0
fi

stop_tracked_forwards_for_all_versions
stop_other_supported_clusters "${KIND_CLUSTER}"

kind create cluster \
  --name "${KIND_CLUSTER}" \
  --config "${CAMUNDA_DIR}/kind/kind-config.yaml" \
  --wait 120s

"${SCRIPT_DIR}/install.sh" "${CAMUNDA_VERSION}"

echo "Created persistent Camunda ${CAMUNDA_VERSION} cluster ${KIND_CLUSTER}."
echo "It will be preserved when another version is activated."
echo "Run ${SCRIPT_DIR}/switch-cluster.sh ${CAMUNDA_VERSION} to open local ports."
echo "Then run ${SCRIPT_DIR}/seed-tenants.sh ${CAMUNDA_VERSION} once."
