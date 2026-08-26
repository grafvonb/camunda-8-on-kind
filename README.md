# Local Camunda 8.8, 8.9, and 8.10 on KIND

This directory contains a self-contained local Camunda environment for API
compatibility tests, application development, and occasional manual UI testing. It
supports Camunda 8.8, 8.9, and the current 8.10 alpha line. Camunda 8.7 is
intentionally out of scope and rejected by the scripts.

The setup does not read, source, or reuse files from the parent directory. All
KIND configuration, Helm values, companion charts, scripts, local client profiles,
and runtime documentation required by this setup live below this directory.

## Quick start

Run commands from this directory. Create each version only once:

```bash
./scripts/create-cluster.sh 8.8
./scripts/switch-cluster.sh 8.8
./scripts/seed-tenants.sh 8.8
./scripts/smoke-test.sh 8.8
```

When another chart line is needed, create it once at a convenient time. The
create command stops the active Camunda KIND container before doing the new
installation, so only one full stack consumes memory:

```bash
./scripts/create-cluster.sh 8.9
```

After that, switching is non-destructive and does not run Helm:

```bash
./scripts/switch-cluster.sh 8.8
./scripts/switch-cluster.sh 8.9
```

Inspect all stored versions without starting them:

```bash
./scripts/cluster-status.sh
```

## Supported versions

The chart versions and release capabilities are pinned in
`config/versions.sh`.

| Camunda | Helm chart | Helm tested upstream | Infrastructure |
| --- | --- | --- | --- |
| 8.8 | `13.12.8` | 3.20.2 | Bundled Elasticsearch, Keycloak, and PostgreSQL |
| 8.9 | `14.8.4` | 3.20.2 or 4.2.4 | Bundled Elasticsearch, Keycloak, and PostgreSQL |
| 8.10 | `15.0.0-alpha4` | 4.2.3 | Explicit companion releases |

The 8.10 version is a preview release, not a production baseline. Its pin is
kept explicit so a newly published alpha cannot silently change the local
environment.

## Prerequisites

- Docker Desktop with 8 CPUs and 16 GiB RAM allocated
- `kind`
- `kubectl`
- a compatible `helm` executable
- `curl` and `jq` for tenant seeding and smoke tests

When multiple Helm versions are installed, select one with `HELM_BIN`:

```bash
HELM_BIN=helm3 ./scripts/create-cluster.sh 8.8
HELM_BIN=helm4 ./scripts/create-cluster.sh 8.10
```

The installer reports the detected Helm version. It never installs, upgrades,
or replaces Helm itself.

## Resource model

This environment is designed for a machine with 8 Docker CPUs and a 16 GiB
Docker memory allocation. All three version clusters may remain stored, but
only one KIND node container and Camunda stack run at a time. Stopped KIND
containers retain their etcd database, persistent volumes, container image
cache, tenants, and test data while consuming disk rather than active CPU and
memory.

`switch-cluster.sh` enforces this model: it stops tracked forwards, stops every
other supported KIND node container, starts the requested container, waits for
Kubernetes and Camunda readiness, and starts the requested version's forwards.
It never invokes Helm and never deletes a cluster.

The default stack uses:

| Workload | Replicas | CPU request | Memory request | Memory limit |
| --- | ---: | ---: | ---: | ---: |
| Orchestration | 1 | 750m | 1600 MiB | 2500 MiB |
| Elasticsearch | 1 | 500m | 1 GiB | 2 GiB |
| Identity | 1 | 200m | 512 MiB | 1 GiB |
| Keycloak | 1 | 200m | 512 MiB | 1 GiB |
| Each PostgreSQL instance | 1 | 100m | 128 MiB | 256 MiB |

Orchestration runs one broker, one partition, and replication factor one. The
KIND cluster has one control-plane node that also schedules workloads, avoiding
the memory cost of a separate worker container.

This is a development topology. It provides no high availability and should
not be used for production sizing or resilience tests.

## Default components

The core values enable:

- Orchestration with broker, Admin/Identity, Operate, and Tasklist profiles
- multitenancy and the tenant-management API
- Management Identity
- Keycloak with a local realm managed by Identity
- PostgreSQL for Identity and Keycloak
- single-node Elasticsearch as secondary storage
- one confidential OAuth client for c8volt

The default values disable components that are not required for normal local
API testing:

- Optimize
- Connectors
- standalone Console
- Camunda Hub and Web Modeler

Operate and Tasklist are profiles inside the unified Orchestration application
for these chart lines; they are not separate pods. Their APIs and UIs are still
available through the Orchestration HTTP service.

## Cluster and release names

| Version | KIND cluster | kubectl context | Namespace | Core release |
| --- | --- | --- | --- | --- |
| 8.8 | `c8.8` | `kind-c8.8` | `camunda` | `camunda` |
| 8.9 | `c8.9` | `kind-c8.9` | `camunda` | `camunda` |
| 8.10 | `c8.10` | `kind-c8.10` | `camunda` | `camunda` |

Scripts always pass the context and namespace explicitly. They do not depend
on whichever kubectl context happens to be current.

## Inexpensive version switching

The persistent lifecycle separates one-time installation from daily switching.

| Command | Purpose | Helm activity | Deletes data |
| --- | --- | --- | --- |
| `create-cluster.sh <version>` | Create and install a version that does not exist | Yes, once | No |
| `switch-cluster.sh <version>` | Activate an installed version and open its ports | No | No |
| `cluster-status.sh` | Show stored/running/absent versions | No | No |
| `install.sh <version>` | Upgrade or repair an existing active version | Yes | No |
| `recreate-cluster.sh <version>` | Reset exactly one version from scratch | Yes | Yes, selected version |
| `delete-cluster.sh <version>` | Remove exactly one stored version | No | Yes, selected version |

Typical daily switching:

```bash
./scripts/switch-cluster.sh 8.8
./scripts/switch-cluster.sh 8.9
./scripts/switch-cluster.sh 8.10
```

Use `--no-port-forward` when only in-cluster access is required:

```bash
./scripts/switch-cluster.sh 8.10 --no-port-forward
```

Stopping a KIND node container is deliberate. Do not remove that Docker
container manually: the container holds the Kubernetes state and local-path
volumes for that version. Use `delete-cluster.sh` only when its data is no
longer needed.

## Installation lifecycle

Create and install a version without touching stored versions:

```bash
./scripts/create-cluster.sh 8.9
```

`create-cluster.sh` refuses to overwrite an existing target. It stops other
supported Camunda clusters, creates the missing single-node KIND cluster, and
calls `install.sh`. Tenant seeding remains an explicit one-time step after the
first switch because Identity must finish provisioning the `c8volt` client.

If a first installation is interrupted after KIND creation, continue the
idempotent Helm sequence without recreating the cluster:

```bash
./scripts/create-cluster.sh 8.10 --resume-install
```

Create a clean replacement only when existing data may be discarded:

```bash
./scripts/recreate-cluster.sh 8.9
```

`recreate-cluster.sh` performs these operations:

1. validates the requested version;
2. stops tracked port forwards for all supported versions;
3. stops other supported KIND node containers without deleting them;
4. deletes only the selected cluster if it already exists;
5. creates a single-node KIND cluster;
6. calls `install.sh` for the selected chart line.

Upgrade or repair an existing installation without recreating the cluster:

```bash
./scripts/install.sh 8.9
```

All installs use `helm upgrade --install`, a pinned chart version, the explicit
KIND context, namespace `camunda`, and `--wait` with bounded timeouts.

## Optional extras

Enable the version-specific extras overlay during installation:

```bash
CAMUNDA_EXTRAS=1 ./scripts/install.sh 8.9
```

For 8.8 and 8.9, this enables Optimize, Connectors, and Console with reduced
local resource requests. For 8.10, it enables Optimize and Connectors. Camunda
Hub/Web Modeler remains disabled in 8.10 because it materially increases memory
usage and is not needed for the core cluster test path.

Running `install.sh` later without `CAMUNDA_EXTRAS=1` returns the release to
the lean core configuration.

## Local ports and API compatibility

Start version-aware port forwards after Helm installation:

```bash
./scripts/port-forward.sh 8.9
```

| Purpose | Local endpoint | Kubernetes target |
| --- | --- | --- |
| Unified Orchestration REST/UI | `http://localhost:8080` | Orchestration HTTP service |
| Operate v1 API alias (8.8/8.9) | `http://localhost:8081` | Same Orchestration HTTP service |
| Tasklist v1 API alias (8.8/8.9) | `http://localhost:8082` | Same Orchestration HTTP service |
| Zeebe gRPC | `localhost:26500` | Orchestration gateway |
| Keycloak | `http://localhost:18080/auth/` | Version-specific Keycloak service |
| Identity | `http://localhost:18081` | Identity service |
| Elasticsearch | `http://localhost:9200` | Version-specific Elasticsearch service |

Ports 8080, 8081, and 8082 deliberately target the same pod. Separate local
ports preserve the endpoint contract expected by clients without consuming
resources for duplicate workloads.

- In 8.8 and 8.9, Operate v1 and Tasklist v1 are supported APIs.
- In 8.10, Operate and Tasklist v1 are deprecated. The local 8.10 profile and
  smoke test use the unified v2 API and do not expose v1 aliases.

Port-forward logs and PID files are stored below `.state/ports/<version>/`.
`stop-port-forward.sh` reads those PID files and stops only processes created
by this setup; it does not use a broad `pkill` expression.

## Authentication and local credentials

The setup provisions a demo administrator and a confidential c8volt client:

```text
demo username:  demo
demo password:  demo
client id:      c8volt
client secret:  c8volt-local-secret
```

The client receives `read:*` and `write:*` permissions for
`orchestration-api`. In 8.10 it is also included in Orchestration security
initialization and mapped from the Keycloak `client_id` claim.

Credentials are deliberately predictable for disposable local development.
They must not be copied into a shared, remote, or production environment.

## Tenants

After port forwarding, seed the local tenants:

```bash
./scripts/seed-tenants.sh 8.9
```

The script obtains a client-credentials token from Keycloak and uses the
unified `/v2/tenants` API to create:

- `tenant-a`
- `tenant-b`

It assigns both the `c8volt` client and `demo` user to each tenant. HTTP 409
is treated as an already-existing resource, making repeated runs safe.

Override the client credentials when testing a modified client:

```bash
C8VOLT_CLIENT_ID=my-client \
C8VOLT_CLIENT_SECRET=my-secret \
./scripts/seed-tenants.sh 8.9
```

## Optional c8volt smoke test

As an optional client-level verification after switching and tenant seeding,
run the [c8volt](https://c8volt.info) operational smoke test with the matching
prepared local profile:

```bash
c8volt --profile c88local ops execute smoke-test --no-cleanup
c8volt --profile c89local ops execute smoke-test
c8volt --profile c810local ops execute smoke-test
```

The 8.8 workflow uses `--no-cleanup` because full process-definition history
deletion is supported by c8volt from Camunda 8.9 onward.

## Smoke test

Run after port forwarding and tenant seeding:

```bash
./scripts/smoke-test.sh 8.9
```

The test obtains a confidential-client token and verifies:

1. unified v2 topology access;
2. Operate v1 process-instance search;
3. Tasklist v1 task search;
4. Elasticsearch cluster health.

A successful open port is not considered sufficient; each enabled API probe
must complete an authenticated request. Steps 2 and 3 run only for releases
that explicitly declare legacy v1 support; 8.10 runs steps 1 and 4.

## Camunda 8.8 and 8.9 architecture

Charts 13 and 14 still contain dependency charts for Elasticsearch, Keycloak,
Keycloak PostgreSQL, and Identity PostgreSQL. They are installed as part of the
single `camunda` Helm release.

Chart 14 removed the old automatic-secret generator. The 8.9 installer applies
`manifests/8.9/local-credentials.yaml` before Helm so the bundled dependencies
receive stable local database and Keycloak credentials. Chart 13 retains its
supported one-time generated-secret mechanism.

Both versions explicitly enable the Operate and Tasklist Orchestration
profiles. The 8.8 values also preserve the legacy Tasklist v1 mode setting.

## Camunda 8.10 architecture

Chart 15 no longer bundles the former Bitnami Elasticsearch, Keycloak, or
PostgreSQL dependencies. The 8.10 installer deploys four companion releases
before the core chart:

1. `postgresql` using the local minimal PostgreSQL chart for Identity;
2. `keycloak-postgresql` using the same chart with a separate database;
3. `keycloak` using the local minimal Keycloak 26 chart;
4. `elasticsearch` using `elastic/elasticsearch` chart 8.5.1 and
   Elasticsearch image 8.18.0.

The core release then connects to these stable service names:

```text
postgresql
keycloak-postgresql
keycloak
elasticsearch-master
```

The local PostgreSQL charts use persistent volume claims so pod restarts do
not discard Identity or Keycloak state. Elasticsearch uses a 4 GiB claim and a
512 MiB JVM heap. An index template enables automatic replica expansion so a
single-node cluster does not remain yellow because application-created indices
request one replica.

The 8.10 core values intentionally contain none of the chart-15 removed keys:

```text
identityKeycloak
identityPostgresql
webModelerPostgresql
top-level elasticsearch
```

## Directory structure

```text
camunda/
├── README.md
├── c8volt/                  standalone examples and short local profiles
├── charts/                  local 8.10 Keycloak and PostgreSQL charts
├── config/versions.sh       version, chart, service, and context mapping
├── kind/kind-config.yaml    single-node KIND definition
├── manifests/8.9/           stable local credentials required by chart 14
├── scripts/                 lifecycle, forwarding, seeding, and smoke tests
└── values/
    ├── 8.8/                 chart-13 core and extras values
    ├── 8.9/                 chart-14 core and extras values
    └── 8.10/                chart-15 core and companion values
```

## Troubleshooting

Check cluster and workload state without changing the current kubectl context:

```bash
./scripts/cluster-status.sh
kubectl --context kind-c8.9 -n camunda get pods
kubectl --context kind-c8.9 -n camunda get services
helm --kube-context kind-c8.9 -n camunda list
```

Inspect a failing workload:

```bash
kubectl --context kind-c8.9 -n camunda describe pod <pod-name>
kubectl --context kind-c8.9 -n camunda logs <pod-name> --all-containers
```

Common problems:

- **Create reports that the target exists:** use `switch-cluster.sh`; creation
  is intentionally one-time and never overwrites a stored cluster.
- **Switch reports that the target is absent:** run `create-cluster.sh` once
  for that version.
- **Switch reports that Camunda is not installed:** activate the target with
  `--no-port-forward`, run its version-compatible `install.sh`, then switch
  normally.
- **Pods stay Pending or restart:** confirm Docker Desktop has approximately
  16 GiB RAM and use `cluster-status.sh` to confirm only one cluster is running.
- **Helm rejects the chart:** use the chart-line-compatible Helm executable via
  `HELM_BIN`.
- **Port-forward exits immediately:** inspect `.state/ports/<version>/*.log`
  and confirm the Helm install completed successfully.
- **Tenant seeding cannot obtain a token:** verify the Keycloak forward on port
  18080 and wait until Identity has finished provisioning the realm/client.
- **A local port is already in use:** stop the previous version's forwards or
  the process occupying that port before starting new forwards.

## Preparing a future release

There is deliberately no catch-all `8.10+` behavior. Every supported release
case in `config/versions.sh` must explicitly declare:

- `HELM_COMPATIBILITY`: the upstream-tested Helm version;
- `INFRASTRUCTURE_MODE`: either the known bundled layout or a specifically
  implemented external-stack profile;
- `PREINSTALL_MANIFEST`: a required manifest path, or an explicit empty value;
- `LEGACY_V1_APIS`: whether local Operate and Tasklist v1 aliases and probes
  are enabled.

The scripts reject unknown versions and invalid capability values. Therefore,
adding 8.11 cannot silently inherit 8.10 alpha4 assumptions. For every new
8.10 alpha, release candidate, stable chart, or later minor release:

1. add or update the candidate case and declare all capabilities;
2. compare the new `values.yaml`, `values.schema.json`, constraints, and
   release notes against the current chart-15 values;
3. inspect changes to Identity, multitenancy, Orchestration initialization,
   secondary storage, and companion versions;
4. render both `core.yaml` and `core.yaml` plus `extras.yaml`;
5. verify the rendered service names used by `port-forward.sh`;
6. run a clean install, seed tenants, and execute `smoke-test.sh`;
7. only then replace the committed pin.

Do not assume all chart 15+ releases use the alpha4 external stack. Keep
Elasticsearch, Keycloak, and PostgreSQL explicit where the inspected chart
requires them. Removed Bitnami dependency keys must not be reintroduced.

## Data deletion and security warning

`delete-cluster.sh` deletes the selected KIND cluster. That removes all
Kubernetes resources, persistent volumes, tenants, deployed processes, and test
data stored inside that cluster. The operation is intentionally scoped to the
selected version's exact KIND cluster name.

`switch-cluster.sh` does not delete any of those resources. A stopped version
remains recoverable by switching back to it.

This environment disables Elasticsearch security and uses fixed local
credentials. Keep all exposed services bound through local `kubectl
port-forward`; do not expose this setup to an untrusted network.
