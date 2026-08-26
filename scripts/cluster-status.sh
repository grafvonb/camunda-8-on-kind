#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=cluster-runtime.sh
source "${SCRIPT_DIR}/cluster-runtime.sh"

require_docker_daemon

printf '%-8s %-8s %-14s %-12s %s\n' VERSION CLUSTER STATE CONTEXT C8VOLT_PROFILE
for version in ${SUPPORTED_CAMUNDA_VERSIONS}; do
  cluster="$(cluster_name_for_version "${version}")"
  context="$(cluster_context_for_version "${version}")"
  profile="$(c8volt_profile_for_version "${version}")"
  state="$(cluster_state "${cluster}")"
  printf '%-8s %-8s %-14s %-12s %s\n' \
    "${version}" "${cluster}" "${state}" "${context}" "${profile}"
done
