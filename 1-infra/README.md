This folder contains the Open Tofu Infastructure as Code to deploy
a CCE cluster.

Configuration is done either by environment variables, tfvars files
hcl files.

* Env files: Used to configure authentication for the T Cloud Public
  provider
* tfvars : Used to configure most of things found in `variables.tf`.
* `backend.hcl` : Used to configure the backend, specifically for the
  S3 state backend.

# Network (`modules/network/`)

- VPC "mern-vpc" with 5 isolated subnets:
  - Main (10.200.1.0/24) — CCE worker nodes
  - Bastion (10.200.2.0/24) — SSH entry point
  - VPN (10.200.3.0/24) — VPN gateway
  - Datastore (10.200.4.0/24) — reserved for DDS
  - Ingress (10.200.5.0/24) — dedicated ELB ingress tier
- NAT gateway + shared EIP for outbound internet (SNAT for all subnets)
- 2 VPN EIPs with DNS records (`prevent_destroy` lifecycle)
- VPN advertises CCE (10.200.1.0/24), bastion (10.200.2.0/24), and ingress (10.200.5.0/24) subnets to on-prem — CCE subnet is required so pods can reach on-prem services (e.g. the authentik IdP)

# Bastion (`modules/bastion/`)

- Ubuntu 22.04 VM (s2.medium.1, 32 GB root disk) with public EIP and DNAT via NAT gateway
- Security group: inbound SSH (22) and HTTPS (443) from 0.0.0.0/0
- Cloud-init: user provisioning with SSH keys, nginx, CES monitoring agent, SSH hardening (ports 22 + 443)
- DNS records: public (`www-bastion-mern-1.<zone>`) and internal (`bastion-mern-1.<zone>`)

# CCE Kubernetes cluster (`modules/cce/`)

- Cluster "cce-mern", Kubernetes v1.29, overlay L2 networking, **private API endpoint only** (admin via bastion)
- Single-master by default (`cce.s1.small`); HA mode (`cce_high_availability=true`) uses 3 masters across 3 AZs (`cce.s2.small`)
- Worker node pool: x1.2slarge.3 flavor, EulerOS 2.9, 40 GB system disk + 100 GB data disk, default 2 nodes (min 3 in HA)
- SSH keypair: Terraform-generated RSA 4096, exported to `exports/keypair.pem`; SSH user is `linux`:
  ```sh
  ssh -i exports/keypair.pem -J <your-user>@www-bastion-mern-1.cassiopeia.public.t-cloud.com linux@10.200.1.<node>
  ```
- Security group rules on the auto-created worker node SG:
  - TCP 30000–32767 inbound from ingress subnet (10.200.5.0/24) — ELB → NodePorts
  - TCP 22 inbound from bastion subnet (10.200.2.0/24) — SSH access
- Add-ons:
  - **metrics-server** v0.6.2 — registers `v1beta1.metrics.k8s.io` for `kubectl top` and basic HPA
  - **cie-collector** v3.12.2 — Prometheus + Thanos (HA, 7-day retention, 10 Gi PVC per replica) + Alertmanager + kube-state-metrics + node-exporter, registers `v1beta1.custom.metrics.k8s.io`; access raw metrics via `kubectl port-forward svc/prometheus-query 10902:10902 -n monitoring`
  - **grafana** v1.3.3 — Grafana v7.5.17 dashboard (set `grafana_oss_main_version=v10` in addon custom params to get v10), auto-discovers cie-collector Prometheus; default credentials `admin`/`admin`; access via:
    ```sh
    HTTPS_PROXY=socks5://localhost:1080 KUBECONFIG=exports/kubeconfig \
      kubectl port-forward svc/grafana-oss 3000:3000 -n monitoring
    # open http://localhost:3000
    ```

# VPN (`modules/vpn/`)

- Enterprise VPN gateway "vpngw-uc2" (Basic flavor, dual AZ) with 2 EIPs
- 2 customer gateways resolved via DNS (`www-cust-vpngw-1/2`), with hardcoded IP fallback
- 2 static-route VPN connections (one per tunnel) to the on-prem peer subnets (e.g. 10.183.0.0/16)

# DNS (`modules/dns-tls`)

Register CNAMs in the internal  DNS zone, all pointing to the ELB's DNS name.
In addition, TLS certificates are managed here.


- `mern-grafana.<zone>` — Grafana dashboard
- `mern-asm-console.<zone>` — ASM console (Kiali)
- `mern-demo2.<zone>` — MERN demo app
- `mern-helloworld.<zone>` — Hello world!

# Ingress (`modules/ingress/`)

- Dedicated internal ELB "elb-ingress", L7 `s1.small` flavor, no EIP (VPC-internal only)
- Reachable from on-prem via VPN through the ingress subnet (10.200.5.0/24)
- HA mode (`cce_high_availability=true`): spans eu-de-01 + eu-de-02; non-HA: eu-de-01 only
- Security group `sg-ingress-elb`: inbound TCP 80 and 443 from `0.0.0.0/0`
- ELB ID and VIP exported as root outputs (`elb_id`, `elb_vip`) for use in CCE Ingress annotations

# DDS (`modules/dds/`)

T Cloud Public Document Database Service (MongoDB-compatible) in the datastore subnet (10.200.4.0/24).

- **Topology** (controlled by `dds_high_availability`):
  - `false` (default) → Single node — dev/test, no redundancy
  - `true` → 3-node ReplicaSet — automatic primary election and failover
- **Port**: 8635 (DDS default; not MongoDB's 27017)
- **SSL**: always enabled; connection strings use `ssl=true&authSource=admin`
- **Storage engine**: wiredTiger (versions 3.2–4.0) or rocksDB (4.2–4.4)
- **Security group** `sg-dds-<name>`: inbound tcp/8635 from:
  - CCE worker node SG (`module.cce.node_sg_id`) — application pods
  - Bastion SG (`module.bastion.bastion_sg_id`) — admin / mongo shell access
- **Backups**: automated, configurable via `dds_backup_*` variables (`backup_enabled`, `backup_start_time`, `backup_keep_days`, `backup_period`)
- **Disk encryption**: optional KMS key via `disk_encryption_id`
- **`kube.env` exports**: `DDS_HOST` (primary node private IP), `DDS_PORT`, `DDS_PASSWORD`

Connect from bastion (requires mongo shell):
```sh
mongosh "mongodb://rwuser:${DDS_PASSWORD}@${DDS_HOST}:${DDS_PORT}/admin?ssl=true&authSource=admin"

```

# Exports

Certain files are generated into `exports` to be used in the
later phases.

- `kubeconfig` — kubectl auth config (cluster endpoint, CA, client cert/key)
- `keypair.pem` — RSA private key for SSH to worker nodes
- `kube.env` — environment variables for `krun` and downstream scripts:
  - `EXT_BASTION_HOST`, `BASTION_HOST` — bastion DNS hostnames
  - `ELB_ID`, `ELB_VIP` — ingress ELB identity and VIP address
  - `GRAFANA_HOST` — Grafana CNAME hostname
  - `HELLO_HOST` — helloworld CNAME hostname
  - `ASM_HOST` — ASM console (Kiali) CNAME hostname
  - `DEMO_HOST` — MERN demo app CNAME hostname
  - `CERT_ID`, `CERT_NAME` — ELB certificate ID and Kubernetes TLS secret name
  - `DDS_HOST` (primary node private IP), `DDS_PORT`, `DDS_PASSWORD`
- `tls.crt` and `tls.key` — TLS certificate and key

# Checks

This folder contains scripts to check that the infrastructure was
deployed correctly:

- cluster
  - All worker nodes are Ready
  - metrics-server APIService is Available and `kubectl top` responds
  - cie-collector (Prometheus/Thanos) APIService and pods are healthy
  - Grafana pod running and `/api/health` responding
  - Cluster has ≥ 2 vCPU + 2 Gi RAM headroom for use
- dds
  - Launches a temporary `busybox` pod in a throwaway namespace
  - TCP connectivity to `DDS_HOST:DDS_PORT` via `nc`
  - TLS handshake via `openssl s_client` (skipped gracefully if openssl absent)
  - MongoDB authentication and ping via pymongo (uses `scripts/pys.sh` venv helper)
  - Cleans up the namespace on exit


# Helper scripts

- `tidy` — destroys CCE, bastion, VPN, and ingress ELB while preserving the network (VPC, subnets, EIPs)
- `krun` — runs kubectl (and any command) with SOCKS proxy and kubeconfig pre-configured


