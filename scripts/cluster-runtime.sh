#!/usr/bin/env bash

# Shared Docker-backed KIND lifecycle helpers. This file is sourced by the
# non-destructive create, switch, and status commands.

SUPPORTED_CAMUNDA_VERSIONS="8.8 8.9 8.10"

cluster_name_for_version() {
  case "${1:-}" in
    8.8) printf '%s\n' 'c8.8' ;;
    8.9) printf '%s\n' 'c8.9' ;;
    8.10) printf '%s\n' 'c8.10' ;;
    *) return 2 ;;
  esac
}

cluster_context_for_version() {
  printf 'kind-%s\n' "$(cluster_name_for_version "$1")"
}

c8volt_profile_for_version() {
  case "${1:-}" in
    8.8) printf '%s\n' 'c88local' ;;
    8.9) printf '%s\n' 'c89local' ;;
    8.10) printf '%s\n' 'c810local' ;;
    *) return 2 ;;
  esac
}

require_docker_daemon() {
  require_command docker
  docker info >/dev/null 2>&1 || {
    echo "Docker is not available. Start Docker Desktop and retry." >&2
    return 1
  }
}

cluster_containers() {
  local cluster="$1"
  local container

  while IFS= read -r container; do
    [ -n "${container}" ] || continue
    case "${container}" in
      "${cluster}-control-plane"|"${cluster}-worker"|"${cluster}-worker"[0-9]*)
        printf '%s\n' "${container}"
        ;;
      *)
        echo "Refusing unexpected Docker container '${container}' for KIND cluster ${cluster}." >&2
        return 1
        ;;
    esac
  done < <(docker ps --all \
    --filter "label=io.x-k8s.kind.cluster=${cluster}" \
    --format '{{.Names}}')
}

cluster_exists() {
  [ -n "$(cluster_containers "$1")" ]
}

cluster_state() {
  local cluster="$1"
  local containers
  local container
  local running=0
  local stopped=0

  containers="$(cluster_containers "${cluster}")"
  if [ -z "${containers}" ]; then
    printf '%s\n' 'absent'
    return 0
  fi

  while IFS= read -r container; do
    [ -n "${container}" ] || continue
    if [ "$(docker inspect --format '{{.State.Running}}' "${container}")" = "true" ]; then
      running=$((running + 1))
    else
      stopped=$((stopped + 1))
    fi
  done <<<"${containers}"

  if [ "${running}" -gt 0 ] && [ "${stopped}" -gt 0 ]; then
    printf '%s\n' 'partial'
  elif [ "${running}" -gt 0 ]; then
    printf '%s\n' 'running'
  else
    printf '%s\n' 'stopped'
  fi
}

start_cluster_containers() {
  local cluster="$1"
  local containers
  local container

  containers="$(cluster_containers "${cluster}")"
  [ -n "${containers}" ] || {
    echo "KIND cluster ${cluster} does not exist. Create it once with create-cluster.sh." >&2
    return 1
  }

  while IFS= read -r container; do
    [ -n "${container}" ] || continue
    if [ "$(docker inspect --format '{{.State.Running}}' "${container}")" != "true" ]; then
      echo "Starting ${container}."
      docker start "${container}" >/dev/null
    fi
  done <<<"${containers}"
}

stop_cluster_containers() {
  local cluster="$1"
  local containers
  local container

  containers="$(cluster_containers "${cluster}")"
  [ -n "${containers}" ] || return 0

  while IFS= read -r container; do
    [ -n "${container}" ] || continue
    if [ "$(docker inspect --format '{{.State.Running}}' "${container}")" = "true" ]; then
      echo "Stopping ${container}."
      docker stop --time 30 "${container}" >/dev/null
    fi
  done <<<"${containers}"
}

stop_tracked_forwards_for_all_versions() {
  local version

  for version in ${SUPPORTED_CAMUNDA_VERSIONS}; do
    "${SCRIPT_DIR}/stop-port-forward.sh" "${version}" >/dev/null 2>&1 || true
  done
}

stop_other_supported_clusters() {
  local target_cluster="$1"
  local version
  local cluster

  for version in ${SUPPORTED_CAMUNDA_VERSIONS}; do
    cluster="$(cluster_name_for_version "${version}")"
    if [ "${cluster}" != "${target_cluster}" ]; then
      stop_cluster_containers "${cluster}"
    fi
  done
}

wait_for_installed_cluster() {
  local context="$1"
  local attempt=0
  local pods

  echo "Waiting for the Kubernetes API in ${context}."
  until kubectl --context "${context}" get --raw=/readyz >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ "${attempt}" -ge 90 ]; then
      echo "Kubernetes API ${context} did not become ready within 3 minutes." >&2
      return 1
    fi
    sleep 2
  done

  echo "Waiting for Kubernetes node readiness in ${context}."
  kubectl --context "${context}" wait \
    --for=condition=Ready node --all --timeout=180s

  kubectl --context "${context}" get namespace "${CAMUNDA_NAMESPACE}" >/dev/null 2>&1 || {
    echo "Cluster ${context} is running, but Camunda is not installed." >&2
    echo "Run install.sh ${CAMUNDA_VERSION} once, then switch again." >&2
    return 1
  }

  pods="$(kubectl --context "${context}" --namespace "${CAMUNDA_NAMESPACE}" \
    get pod --output=name 2>/dev/null)"
  if [ -z "${pods}" ]; then
    echo "Cluster ${context} has no Camunda pods. Run install.sh ${CAMUNDA_VERSION} once." >&2
    return 1
  fi

  echo "Waiting for Camunda pods in ${context}/${CAMUNDA_NAMESPACE}."
  kubectl --context "${context}" --namespace "${CAMUNDA_NAMESPACE}" wait \
    --for=condition=Ready pod --all --timeout=10m
}
