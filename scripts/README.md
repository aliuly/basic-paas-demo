Utility scripts shared across all deployment phases.

# `krun` — kubectl wrapper with SOCKS proxy

Loads environment from `1-infra/exports/kube.env` and any `*.env` / `*.env.sh`
files in the calling directory, then auto-manages an SSH SOCKS proxy through the
bastion before running the given command with `KUBECONFIG` and `HTTPS_PROXY` set.

```sh
./krun kubectl get pods -A
./krun ./setup/some-script
```

Each phase (`2-shared/`, `3-workloads/`) ships its own `krun` symlink pointing here.

Options:
- `-u <user>` — remote SSH user for the bastion
- `-s <port>` — SOCKS port (default `1080`)
- `-k` — kill the background proxy process

# `tf` — OpenTofu wrapper

Wraps `tofu` to auto-discover and load `*.env`, `*.env.sh`, and `*.tfvars` files
from the current directory. Maps OTC credentials (`OS_ACCESS_KEY` / `OS_SECRET_KEY`)
to the AWS-compatible variables required by the S3 state backend.

```sh
./tf init    # picks up backend.hcl automatically
./tf plan
./tf apply
```

Options:
- `-e <dir>` / `--vars-dir=<dir>` — load vars from a different directory
- `-chdir <dir>` — change directory before running

# `dns2ip` — DNS lookup for Terraform

Resolves a hostname to an IP address and prints `{"value": "<ip>"}`.
Used as a Terraform `external` data source to resolve VPN customer gateway
hostnames at plan time, with a fallback default if DNS is unreachable.

```sh
dns2ip www-cust-vpngw-1.example.com 10.0.0.1
```

# `pys.sh` — Python venv runner

Runs a Python script inside an auto-provisioned virtual environment.
Creates `.venv/` on first use and installs declared requirements automatically.
Used internally by the DDS check scripts (`checks/dds`).

```sh
./pys.sh some_script.py [args...]
```

# `pack` — source archive (without secrets)

Creates a zip of the project tree, excluding all sensitive files
(`*.tfvars`, `backend.hcl`, `*.key`, `*.crt`, `*.pem`, `*.env`, `terraform.tfstate`).
Safe to share or upload.

```sh
./pack /tmp/project.zip
./pack -t          # dry run — list files only
./pack -d 1-infra /tmp/infra.zip
```

# `xvars` — secrets archive

Creates a zip of *only* the sensitive files excluded by `pack`
(`*.tfvars`, `backend.hcl`, `*.pem`, `*.crt`, `*.key`, `*.env`).
Used to hand credentials to a team member or create an offline backup.

```sh
./xvars /tmp/secrets.zip
./xvars -l         # list files only, don't zip
./xvars -d 1-infra /tmp/infra-secrets.zip
```
