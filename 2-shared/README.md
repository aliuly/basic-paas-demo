This folder contains shared resources or in general things that
can not be fully configured using Open Telekom Cloud terraform
provider.

Installs shared cluster-side infrastructure via Helm and shell scripts.
All scripts are run via `./krun`, which sets `KUBECONFIG`,
`HTTPS_PROXY`, and exports `kube.env` variables and other local
configuration variables before executing the script.

# HTTP → HTTPS redirect (`charts/http-redir/`)

Helm chart (release `http-redir`, namespace `local-tools`).
Deploys `ghcr.io/tortugalabs/http-to-https-redir:latest` as a catch-all HTTP redirect on ELB port 80.

- Deployment + NodePort Service (port 80 → container port 80)
- Ingress: no host filter, ELB port 80 — catches all HTTP traffic and redirects to HTTPS

```sh
./krun ./setup/http-redir
```

# Grafana HTTPS ingress (`charts/grafana/`)

Helm chart (release `grafana`, namespace `monitoring`).
Wires the CCE-addon Grafana service to the ELB over HTTPS.

- Ingress: `Host: $GRAFANA_HOST` → `grafana-oss:3000`, ELB port 443, TLS termination
- Setup script creates/refreshes the TLS secret in the `monitoring` namespace

```sh
./krun ./setup/grafana-ingress
```

Values: `grafana.elbId`, `grafana.host`, `grafana.certId`, `grafana.certName`.

# ASM / Istio (`charts/asm/`)

Helm chart (release `asm-config`, namespace `istio-system`).
Installs the Istio service mesh control plane and applies mesh-wide configuration.

- Upstream `istio/base` (CRDs) and `istio/istiod` (control plane) installed via Helm
- Mesh-wide STRICT mTLS enforced via `PeerAuthentication`
- **`outboundTrafficPolicy: REGISTRY_ONLY`** — pods cannot reach external hosts unless a `ServiceEntry` is created
- Prometheus metrics + Envoy access logging via `Telemetry`
- Workload namespaces labelled for sidecar injection; pods pick up the sidecar on rollout restart

```sh
./krun ./setup/asm
```

Values: `mtls.mode` (default `STRICT`), `telemetry.accessLogging` (default `true`).
Override Istio version: `ISTIO_VERSION=1.23.0 ../1-infra/krun ./setup/asm` (default `1.22.3`).

# ASM console / Kiali (`charts/asm-console/`)

Helm charts (releases `asm-console` + `asm-console-ingress`, namespace `istio-system`).
Deploys Kiali as the ASM web console and wires it to the ELB over HTTPS.

- `asm-console` — upstream `kiali/kiali-server` chart; anonymous auth, NodePort service, Prometheus at `prometheus-query.monitoring:10902`, Grafana at `grafana-oss.monitoring:3000`
- `asm-console-ingress` — local Ingress chart: `Host: $ASM_HOST` → `asm-console:20001`, ELB port 443, TLS termination
- Setup script creates/refreshes the TLS secret in `istio-system`
- Kiali UI served at `/kiali/` (default `web_root`)

```sh
./krun ./setup/asm-console
```

Values: `asmConsole.elbId`, `asmConsole.host`, `asmConsole.certId`, `asmConsole.certName`.
Override Kiali version: `KIALI_VERSION=1.84.0 ../1-infra/krun ./setup/asm-console` (default `1.83.0`).

# Checks (`checks/`)

- `checks/grafana` — verifies the Grafana Ingress end-to-end:
  1. Ingress object exists with correct ELB annotation
  2. ELB address present in Ingress status
  3. HTTP → HTTPS redirect on ELB VIP port 80
  4. TLS certificate valid for `GRAFANA_HOST`
  5. HTTPS host-based routing returns 200/302
  6. `/api/health` reports `database: ok`
  ```sh
  ../1-infra/krun ./checks/grafana
  ```
- `checks/asm` — verifies the ASM control plane:
  1. Helm releases `istio-base`, `istiod`, `asm-config` are deployed
  2. `istiod` deployment is fully ready
  3. Core Istio CRDs are registered
  4. Mesh-wide `PeerAuthentication` is `STRICT`
  5. Sidecar injection webhook is active
  ```sh
  ../1-infra/krun ./checks/asm
  ```
- `checks/asm-console` — verifies the ASM console end-to-end:
  1. Helm releases `asm-console` and `asm-console-ingress` are deployed
  2. `asm-console` deployment is fully ready
  3. Ingress exists with correct ELB annotation
  4. ELB address present in Ingress status
  5. HTTPS host-based routing returns 200/302
  6. `/kiali/healthz` returns 200
  ```sh
  ../1-infra/krun ./checks/asm-console
  ```

# Management URLS

* https://idp1.cassiopeia.public.t-cloud.com/ - Identity Provider
  on customer network
* https://mern-grafana.cassiopeia.public.t-cloud.com/ - Cloud Native
  Reports
* https://mern-asm-console.cassiopeia.public.t-cloud.com/ - ASM
  console
