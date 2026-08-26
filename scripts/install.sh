#!/usr/bin/env bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

load_version "${1:-}"
require_command kubectl
require_kind_context
HELM="$(helm_command)"
print_helm_compatibility "${HELM}"

if ! kubectl --context "${KIND_CONTEXT}" get namespace "${CAMUNDA_NAMESPACE}" >/dev/null 2>&1; then
  kubectl --context "${KIND_CONTEXT}" create namespace "${CAMUNDA_NAMESPACE}"
fi

if [ -n "${PREINSTALL_MANIFEST}" ]; then
  if [ ! -f "${CAMUNDA_DIR}/${PREINSTALL_MANIFEST}" ]; then
    echo "Declared preinstall manifest does not exist: ${CAMUNDA_DIR}/${PREINSTALL_MANIFEST}" >&2
    exit 1
  fi
  kubectl --context "${KIND_CONTEXT}" --namespace "${CAMUNDA_NAMESPACE}" \
    apply --filename "${CAMUNDA_DIR}/${PREINSTALL_MANIFEST}"
fi

"${HELM}" repo add camunda https://helm.camunda.io --force-update

case "${INFRASTRUCTURE_MODE}" in
  external-chart15-alpha4)
    "${HELM}" repo add elastic https://helm.elastic.co --force-update
    "${HELM}" repo update camunda elastic

    "${HELM}" upgrade --install postgresql "${CAMUNDA_DIR}/charts/postgresql" \
      --kube-context "${KIND_CONTEXT}" \
      --namespace "${CAMUNDA_NAMESPACE}" \
      --values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/postgresql.yaml" \
      --wait --timeout 10m

    "${HELM}" upgrade --install keycloak-postgresql "${CAMUNDA_DIR}/charts/postgresql" \
      --kube-context "${KIND_CONTEXT}" \
      --namespace "${CAMUNDA_NAMESPACE}" \
      --values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/keycloak-postgresql.yaml" \
      --wait --timeout 10m

    "${HELM}" upgrade --install keycloak "${CAMUNDA_DIR}/charts/keycloak" \
      --kube-context "${KIND_CONTEXT}" \
      --namespace "${CAMUNDA_NAMESPACE}" \
      --values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/keycloak.yaml" \
      --wait --timeout 10m

    "${HELM}" upgrade --install elasticsearch elastic/elasticsearch \
      --version 8.5.1 \
      --kube-context "${KIND_CONTEXT}" \
      --namespace "${CAMUNDA_NAMESPACE}" \
      --values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/elasticsearch.yaml" \
      --wait --timeout 10m
    ;;
  bundled)
    "${HELM}" repo update camunda
    ;;
esac

values_args=(--values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/core.yaml")
if [ "${CAMUNDA_EXTRAS:-0}" = "1" ]; then
  values_args+=(--values "${CAMUNDA_DIR}/values/${CAMUNDA_VERSION}/extras.yaml")
fi

"${HELM}" upgrade --install "${CAMUNDA_RELEASE}" camunda/camunda-platform \
  --version "${CHART_VERSION}" \
  --kube-context "${KIND_CONTEXT}" \
  --namespace "${CAMUNDA_NAMESPACE}" \
  "${values_args[@]}" \
  --wait --timeout 15m

echo "Camunda ${CAMUNDA_VERSION} is installed in ${KIND_CONTEXT}/${CAMUNDA_NAMESPACE}."
echo "Run ${SCRIPT_DIR}/port-forward.sh ${CAMUNDA_VERSION}, then ${SCRIPT_DIR}/seed-tenants.sh ${CAMUNDA_VERSION}."
