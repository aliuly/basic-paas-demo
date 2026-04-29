# 2-asm — Istio Service Mesh

Installs Istio onto the CCE cluster provisioned by `1-paas` using the
official Helm charts. No OpenTofu — just `helm` and `kubectl`.

## Prerequisites

On the bastion host (or any machine with cluster access):
- `helm` >= 3.x
- `kubectl` configured against the CCE cluster
- Optionally `istioctl` for diagnostics (not required for install/upgrade)

## Files

| File | Purpose |
|---|---|
| `install` | Installs Istio from scratch |
| `upgrade` | Canary upgrade — installs new revision alongside old |
| `upgrade-complete` | Removes old revision after canary validation |
| `istio-base-values.yaml` | Values for the `istio/base` chart (CRDs) |
| `istiod-values.yaml` | Values for the `istiod` chart (control plane) |

## Install

```sh
# Standard (single-master CCE cluster)
./install

# HA (3-master CCE cluster)
./install --ha

# Specific version
./install --version 1.21.2
```

This installs:
1. `istio-base` — CRDs and cluster-wide RBAC
2. `istiod` — control plane (Pilot + Citadel merged)

## Enable sidecar injection

Label namespaces after install:
```sh
kubectl label namespace <your-app-ns> istio-injection=enabled
kubectl rollout restart deployment -n <your-app-ns>
```

## Upgrade

Istio upgrades use a canary revision strategy — the new control plane
runs alongside the old one until all namespaces are validated.

```sh
# Step 1: install new revision
./upgrade --new-version 1.22.0

# Step 2: migrate namespaces one at a time and validate
kubectl label namespace <ns> istio.io/rev=1-22-0 istio-injection- --overwrite
kubectl rollout restart deployment -n <ns>

# Step 3: once all namespaces are migrated and healthy
./upgrade-complete --old-version 1.21.2
```

## Diagnostics (optional — requires istioctl)

```sh
istioctl verify-install
istioctl analyze
istioctl proxy-status
```

## Configuration

Edit `istiod-values.yaml` before installing to customise:
- `pilot.replicaCount` — set to 3 for HA clusters
- `meshConfig.outboundTrafficPolicy.mode` — `ALLOW_ANY` (permissive) or
  `REGISTRY_ONLY` (strict, blocks traffic to unknown services)
- `meshConfig.accessLogFile` — remove `/dev/stdout` in production to
  reduce log volume
