#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
STATE_DIR="${CAMUNDA_DIR}/.state/ports/${CAMUNDA_VERSION}"

if [ ! -d "${STATE_DIR}" ]; then
  exit 0
fi

for pid_file in "${STATE_DIR}"/*.pid; do
  [ -e "${pid_file}" ] || continue
  pid="$(cat "${pid_file}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${pid_file}"
done

echo "Stopped Camunda ${CAMUNDA_VERSION} port forwards."

