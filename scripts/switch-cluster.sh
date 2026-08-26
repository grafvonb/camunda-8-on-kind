#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=cluster-runtime.sh
source "${SCRIPT_DIR}/cluster-runtime.sh"

load_version "${1:-}"
require_command kubectl
require_docker_daemon

case "${2:-}" in
  '') START_PORT_FORWARDS=1 ;;
  --no-port-forward) START_PORT_FORWARDS=0 ;;
  *)
    echo "Usage: ${0##*/} <8.8|8.9|8.10> [--no-port-forward]" >&2
    exit 2
    ;;
esac

if ! cluster_exists "${KIND_CLUSTER}"; then
  echo "KIND cluster ${KIND_CLUSTER} has not been created yet." >&2
  echo "Run ${SCRIPT_DIR}/create-cluster.sh ${CAMUNDA_VERSION} once." >&2
  exit 1
fi

stop_tracked_forwards_for_all_versions
stop_other_supported_clusters "${KIND_CLUSTER}"
start_cluster_containers "${KIND_CLUSTER}"
wait_for_installed_cluster "${KIND_CONTEXT}"

if [ "${START_PORT_FORWARDS}" = "1" ]; then
  "${SCRIPT_DIR}/port-forward.sh" "${CAMUNDA_VERSION}"
fi

profile="$(c8volt_profile_for_version "${CAMUNDA_VERSION}")"
echo "Camunda ${CAMUNDA_VERSION} is active in ${KIND_CONTEXT}."
if [ "${START_PORT_FORWARDS}" = "1" ]; then
  echo "c8volt profile: ${profile}"
  echo "Example: c8volt --profile ${profile} config test-connection"
else
  echo "Local port forwards were not started."
fi
