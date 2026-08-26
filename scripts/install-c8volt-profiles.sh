#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAMUNDA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROFILE_SOURCE="${CAMUNDA_DIR}/c8volt/profiles-local.yaml"
CONFIG_FILE="${1:-${C8VOLT_CONFIG_FILE:-${HOME}/.config/c8volt/config.yaml}}"

command -v yq >/dev/null 2>&1 || {
  echo "Required command not found: yq" >&2
  exit 1
}

[ -f "${CONFIG_FILE}" ] || {
  echo "c8volt configuration does not exist: ${CONFIG_FILE}" >&2
  exit 1
}

export CAMUNDA_LOCAL_PROFILE_SOURCE="${PROFILE_SOURCE}"
yq --inplace '
  .profiles.c88local = load(strenv(CAMUNDA_LOCAL_PROFILE_SOURCE)).profiles.c88local |
  .profiles.c89local = load(strenv(CAMUNDA_LOCAL_PROFILE_SOURCE)).profiles.c89local |
  .profiles.c810local = load(strenv(CAMUNDA_LOCAL_PROFILE_SOURCE)).profiles.c810local
' "${CONFIG_FILE}"

echo "Installed c8volt profiles c88local, c89local, and c810local in ${CONFIG_FILE}."
echo "The active_profile value was not changed."
