#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=cluster-runtime.sh
source "${SCRIPT_DIR}/cluster-runtime.sh"
# shellcheck source=cluster-certificates.sh
source "${SCRIPT_DIR}/cluster-certificates.sh"

load_version "${1:-}"
require_command kind
require_command kubectl
require_docker_daemon

prepare_kind_config
stop_tracked_forwards_for_all_versions
stop_other_supported_clusters "${KIND_CLUSTER}"

if cluster_exists "${KIND_CLUSTER}"; then
  kind delete cluster --name "${KIND_CLUSTER}"
fi

kind create cluster \
  --name "${KIND_CLUSTER}" \
  --config "${KIND_CONFIG_FILE}" \
  --wait 120s

configure_kind_certificates
"${SCRIPT_DIR}/install.sh" "${CAMUNDA_VERSION}"
