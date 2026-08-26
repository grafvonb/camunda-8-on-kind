#!/usr/bin/env bash

# Published chart pins validated against the Camunda Helm version matrix on
# 2026-08-25. Override HELM_BIN when a version-specific Helm executable is
# needed (8.8 officially requires Helm 3; 8.10 alpha4 requires Helm 4).

configure_version() {
  case "${1:-}" in
    8.8)
      CAMUNDA_VERSION="8.8"
      KIND_CLUSTER="c8.8"
      CHART_VERSION="13.12.8"
      HELM_COMPATIBILITY="3.20.2"
      INFRASTRUCTURE_MODE="bundled"
      PREINSTALL_MANIFEST=""
      LEGACY_V1_APIS="true"
      KEYCLOAK_SERVICE="camunda-keycloak"
      ELASTICSEARCH_SERVICE="camunda-elasticsearch"
      ;;
    8.9)
      CAMUNDA_VERSION="8.9"
      KIND_CLUSTER="c8.9"
      CHART_VERSION="14.8.4"
      HELM_COMPATIBILITY="3.20.2 or 4.2.4"
      INFRASTRUCTURE_MODE="bundled"
      PREINSTALL_MANIFEST="manifests/8.9/local-credentials.yaml"
      LEGACY_V1_APIS="true"
      KEYCLOAK_SERVICE="camunda-keycloak"
      ELASTICSEARCH_SERVICE="camunda-elasticsearch"
      ;;
    8.10)
      CAMUNDA_VERSION="8.10"
      KIND_CLUSTER="c8.10"
      CHART_VERSION="15.0.0-alpha4"
      HELM_COMPATIBILITY="4.2.3"
      INFRASTRUCTURE_MODE="external-chart15-alpha4"
      PREINSTALL_MANIFEST=""
      LEGACY_V1_APIS="false"
      KEYCLOAK_SERVICE="keycloak"
      ELASTICSEARCH_SERVICE="elasticsearch-master"
      ;;
    *)
      echo "Unsupported Camunda version '${1:-}'. Supported: 8.8, 8.9, 8.10." >&2
      return 2
      ;;
  esac

  CAMUNDA_NAMESPACE="camunda"
  CAMUNDA_RELEASE="camunda"
  ORCHESTRATION_SERVICE="camunda-zeebe-gateway"
  IDENTITY_SERVICE="camunda-identity"
  KIND_CONTEXT="kind-${KIND_CLUSTER}"

  case "${INFRASTRUCTURE_MODE}" in
    bundled|external-chart15-alpha4) ;;
    *)
      echo "Invalid infrastructure capability for Camunda ${CAMUNDA_VERSION}: ${INFRASTRUCTURE_MODE}" >&2
      return 2
      ;;
  esac

  case "${LEGACY_V1_APIS}" in
    true|false) ;;
    *)
      echo "Invalid legacy-v1 capability for Camunda ${CAMUNDA_VERSION}: ${LEGACY_V1_APIS}" >&2
      return 2
      ;;
  esac
}
