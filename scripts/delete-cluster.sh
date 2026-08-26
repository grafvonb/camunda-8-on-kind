#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
require_command kind
"${SCRIPT_DIR}/stop-port-forward.sh" "${CAMUNDA_VERSION}" || true
kind delete cluster --name "${KIND_CLUSTER}"

