#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
require_command curl
require_command jq

TOKEN_URL="http://localhost:18080/auth/realms/camunda-platform/protocol/openid-connect/token"
API_URL="http://localhost:8080/v2"
CLIENT_ID="${C8VOLT_CLIENT_ID:-c8volt}"
CLIENT_SECRET="${C8VOLT_CLIENT_SECRET:-c8volt-local-secret}"

token="$(curl --fail --silent --show-error \
  --request POST "${TOKEN_URL}" \
  --data-urlencode grant_type=client_credentials \
  --data-urlencode "client_id=${CLIENT_ID}" \
  --data-urlencode "client_secret=${CLIENT_SECRET}" | jq -er .access_token)"

request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local status
  local curl_args=(--silent --show-error --output /dev/null --write-out '%{http_code}'
    --request "${method}" --header "Authorization: Bearer ${token}")
  if [ -n "${body}" ]; then
    curl_args+=(--header 'Content-Type: application/json' --data "${body}")
  fi
  status="$(curl "${curl_args[@]}" "${url}")"
  case "${status}" in
    200|201|204|409) return 0 ;;
    *) echo "Request failed (${status}): ${method} ${url}" >&2; return 1 ;;
  esac
}

for tenant in tenant-a tenant-b; do
  display_name="Tenant ${tenant#tenant-}"
  request POST "${API_URL}/tenants" "{\"tenantId\":\"${tenant}\",\"name\":\"${display_name}\"}"
  request PUT "${API_URL}/tenants/${tenant}/clients/${CLIENT_ID}"
  request PUT "${API_URL}/tenants/${tenant}/users/demo"
  echo "Seeded ${tenant} for client ${CLIENT_ID} and user demo."
done

