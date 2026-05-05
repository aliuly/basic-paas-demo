This folder contains the workloads/usable payloads.

Deploys workloads via Helm. Uses the local `krun` wrapper (same pattern as `1-infra/krun`).

`krun` sources `1-infra/exports/kube.env` and then any `*.env` / `*.env.sh` files in the
`3-workloads/` directory. Workload-specific credentials go into a  `*.env` (gitignored).

# Helloworld (`charts/helloworld/`)

Helm chart (release `helloworld`, namespace `helloworld`).
Static "Authorized Users Only" landing page served over HTTPS — used to verify the full ELB → NodePort → pod path.

- Deployment: `lipanski/docker-static-website:latest`, serves from `/home/static/` on port 3000
- HTML content injected via ConfigMap mounted at `/home/static/index.html`
- NodePort Service (port 3000)
- Ingress: `Host: $HELLO_HOST`, ELB port 443, TLS termination

```sh
./krun ./setup/helloworld
./krun ./checks/helloworld
```

Values: `elbId`, `host`, `certId`, `certName`.

# MERN demo (`charts/mern-demo/`)



Helm chart (release `mern-demo`, namespace `mern-demo`).
MERN tutorial app (bezkoder fork) with DDS as the database and oauth2-proxy in front
authenticating against the on-prem authentik IdP.

## Architecture

```
ELB (443) → oauth2-proxy (NodePort :4180)
               ↓ upstream (authenticated requests)
            bezkoder-ui nginx (ClusterIP :80)
               /api  → bezkoder-api (ClusterIP :8080)
               /     → React SPA static files
            bezkoder-api → DDS :8635 (SSL, app user)
```

## Components

- **bezkoder-api** — Express/Node.js REST API; reads DDS credentials from `mern-dds` secret
- **bezkoder-ui** — React SPA served by nginx; proxies `/api` to `bezkoder-api`; uses `imagePullSecrets: default-secret` for SWR
- **oauth2-proxy** — OIDC proxy against authentik; namespace STRICT mTLS with a PERMISSIVE override for this pod (receives plain HTTP from ELB)
- **Istio ServiceEntries**: `idp1-authentik` (HTTPS to on-prem IdP) and `dds-mern` (TCP to DDS IP) — required because istiod runs `outboundTrafficPolicy: REGISTRY_ONLY`

## Credentials

Stored in `3-workloads/*.env` (gitignored):
- `MERN_DEMO_OAUTH2_IDP_URL` — authentik OIDC issuer URL
- `MERN_DEMO_OAUTH2_CLIENT_ID` / `MERN_DEMO_OAUTH2_CLIENT_SECRET` — authentik app credentials

Kubernetes secrets created by the setup script:
- `mern-dds` — app DB credentials (`DB_HOST/PORT/USER/PASSWORD/NAME/SSL`); password auto-generated on first run, preserved on re-runs
- `mern-oauth2-proxy` — `client_id`, `client_secret`, `cookie_secret`; cookie secret auto-generated on first run

## Building images

```sh
# Requires: docker login swr.eu-de.otc.t-systems.com (temporary AK/SK credentials)
./src/mern-demo/build
```

Images pushed to `swr.eu-de.otc.t-systems.com/golden/`:
- `mern-api:latest` — bezkoder-api
- `mern-ui:latest` — bezkoder-ui (nginx with `/api` proxy + React build)

## DDS app database

The setup script connects to DDS as `rwuser` via pymongo + SOCKS proxy and idempotently creates:
- Database: `bezkoder_db`
- User: `bezkoder` in `admin` DB with `readWrite` on `bezkoder_db`

## Deploy and verify

```sh
./krun ./setup/mern-demo
./krun ./checks/mern-demo
```

Values set at deploy time: `elbId`, `host`, `certId`, `certName`, `api.clientOrigin`,
`api.ddsHost`, `api.ddsPort`, `proxy.oidcIssuerUrl`, `proxy.idpHost`.

# Configuring oauth2-proxy with Authentik as Identity Provider

**App URL:** `https://mern-demo2.<dns_zone>/`
**IdP URL:** `https://<authentik_dns_name>/`

## 1. Create the OIDC Provider in Authentik

In the Authentik admin UI at `https://<authentik_dns_name>/`:

1. **Providers → Create → OAuth2/OpenID Provider**
   - Name: `mern-demo` (or anything)
   - Client type: **Confidential**
   - Client ID: auto-generated (copy it)
   - Client Secret: auto-generated (copy it)
   - Redirect URIs: `https://mern-demo2.<dns_zone>/oauth2/callback`
   - Signing Key: pick your default RSA key
   - Scopes: `openid`, `email`, `profile`

2. **Applications → Create**
   - Link it to the provider you just created
   - Note the **slug** you give the application (e.g. `mern-demo`)

3. The OIDC issuer URL will be:
   ```
   https://<authentik_dns_name>/application/o/<your-app-slug>/
   ```
   You can verify it by fetching:
   ```
   https://<authentik_dns_name>/application/o/<slug>/.well-known/openid-configuration
   ```

## 2. Fix: email_verified in the ID token

oauth2-proxy rejects logins where the ID token contains `email_verified: false`. Authentik's
default admin account (`root@example.com`) and some user sources return unverified emails.

`proxy-deployment.yaml` includes `--insecure-oidc-allow-unverified-email=true`.
This is acceptable for a demo but means the proxy will pass through any user regardless
of whether the IdP has verified their email.

## 3. Set credentials in `3-workloads/dev.env`

Add (or update) these three variables in the gitignored `3-workloads/dev.env`:

```sh
MERN_DEMO_OAUTH2_IDP_URL=https://<authentik_dns_name>/application/o/<your-app-slug>/
MERN_DEMO_OAUTH2_CLIENT_ID=<client-id-from-authentik>
MERN_DEMO_OAUTH2_CLIENT_SECRET=<client-secret-from-authentik>
```

# Traffic flow and mTLS

oauth2-proxy listens on plain HTTP (`--http-address=0.0.0.0:4180`). This is correct — the
Istio sidecar handles mTLS transparently between pods. The application never sees TLS.

```
Browser
  → HTTPS → ELB (TLS termination)
  → HTTP  → Ingress controller
  → mTLS  → oauth2-proxy sidecar   (Istio)
  → HTTP  → oauth2-proxy app       (localhost inside pod)
  → mTLS  → bezkoder-ui sidecar    (Istio)
  → HTTP  → bezkoder-ui app
```

The `PeerAuthentication` in the chart sets the namespace to `STRICT` mTLS, with oauth2-proxy
itself as `PERMISSIVE` so the ingress controller (which has no sidecar) can reach it.
Using `--https-address` instead would double-encrypt and conflict with Istio.
