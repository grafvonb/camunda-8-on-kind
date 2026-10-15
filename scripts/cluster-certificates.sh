#!/usr/bin/env bash

prepare_kind_config() {
  KIND_CA_SOURCE="${HOME}/.certs/Zscaler Root CA.pem"
  if [ ! -f "${KIND_CA_SOURCE}" ] || [ ! -r "${KIND_CA_SOURCE}" ]; then
    echo "Missing CA certificate: ${KIND_CA_SOURCE}" >&2
    return 1
  fi

  local config
  local certificate="${KIND_CA_SOURCE//\'/\'\'}" # Escape YAML apostrophes.
  config="$(cat "${CAMUNDA_DIR}/kind/kind-config.yaml")"
  mkdir -p "${CAMUNDA_DIR}/.state/kind"
  KIND_CONFIG_FILE="${CAMUNDA_DIR}/.state/kind/${KIND_CLUSTER}.yaml"
  printf '%s\n' "${config//__LOCAL_CA_CERT__/${certificate}}" > "${KIND_CONFIG_FILE}"
}

configure_kind_certificates() {
  local node="${KIND_CLUSTER}-control-plane"
  echo "Trusting Zscaler CA in ${node}."
  # Resume older clusters that were created without the mount.
  if ! docker exec "${node}" test -f /usr/local/share/ca-certificates/camunda-local-ca.crt; then
    docker cp "${KIND_CA_SOURCE}" "${node}:/usr/local/share/ca-certificates/camunda-local-ca.crt"
  fi
  docker exec "${node}" update-ca-certificates
  docker exec "${node}" systemctl restart containerd
}
