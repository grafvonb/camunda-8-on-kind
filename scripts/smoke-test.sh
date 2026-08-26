#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
require_command curl
require_command jq

token="$(curl --fail --silent --show-error \
  --request POST http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode client_id=c8volt \
  --data-urlencode client_secret=c8volt-local-secret | jq -er .access_token)"

probe_post() {
  local name="$1"
  local url="$2"
  curl --fail --silent --show-error \
    --request POST "${url}" \
    --header "Authorization: Bearer ${token}" \
    --header 'Content-Type: application/json' \
    --data '{}' >/dev/null
  echo "OK: ${name}"
}

curl --fail --silent --show-error \
  --header "Authorization: Bearer ${token}" \
  http://localhost:8080/v2/topology >/dev/null
echo "OK: unified v2 API"

if [ "${LEGACY_V1_APIS}" = "true" ]; then
  probe_post "Operate v1 API" http://localhost:8081/v1/process-instances/search
  probe_post "Tasklist v1 API" http://localhost:8082/v1/tasks/search
else
  echo "SKIP: ${CAMUNDA_VERSION} is configured without legacy Operate and Tasklist v1 aliases; use unified v2."
fi

curl --fail --silent --show-error http://localhost:9200/_cluster/health >/dev/null
echo "OK: Elasticsearch"
