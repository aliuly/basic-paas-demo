
locals {
  tags = {
    environment = var.environment
    project     = "mern"
    managed_by  = "OpenTofu"
    CASIO       = "Use2"
  }
}

# ---------------------------------------------------------------------------
# Network — VPC, Subnet, NAT GW, VPN EIPs, SSH key
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  region            = var.region
  vpc_name          = var.vpc_name
  vpc_cidr          = "${var.vpc_cidr_prefix}.0.0/16"
  subnet_name       = "mern-dev-subnet"
  subnet_cidr       = "${var.vpc_cidr_prefix}.1.0/24"
  subnet_gateway_ip = "${var.vpc_cidr_prefix}.1.1"

  bastion_subnet_name       = "mern-dev-bastion-subnet"
  bastion_subnet_cidr       = "${var.vpc_cidr_prefix}.2.0/24"
  bastion_subnet_gateway_ip = "${var.vpc_cidr_prefix}.2.1"

  vpn_subnet_name       = "mern-dev-vpn-subnet"
  vpn_subnet_cidr       = "${var.vpc_cidr_prefix}.3.0/24"
  vpn_subnet_gateway_ip = "${var.vpc_cidr_prefix}.3.1"

  datastore_subnet_name       = "mern-dev-datastore-subnet"
  datastore_subnet_cidr       = "${var.vpc_cidr_prefix}.4.0/24"
  datastore_subnet_gateway_ip = "${var.vpc_cidr_prefix}.4.1"

  tags              = local.tags

  environment       = var.environment
  node_keypair      = var.node_keypair
  my_ssh_key        = var.my_ssh_key
  vpn_name          = var.vpn_name
  dns_zone          = var.dns_zone
}

# ---------------------------------------------------------------------------
# Bastion — admin entry point via SSH; all cluster admin goes through here
# ---------------------------------------------------------------------------
module "bastion" {
  source = "./modules/bastion"

  region       = var.region
  subnet_id    = module.network.bastion_subnet_id
  natgw_id     = module.network.natgw_id
  local_users  = var.local_users

  node_keypair = var.node_keypair
  dns_zone     = var.dns_zone
  environment  = var.environment
  tags         = local.tags
}

# ---------------------------------------------------------------------------
# VPN — site-to-site tunnel to customer network
# ---------------------------------------------------------------------------
module "vpn" {
  source = "./modules/vpn"

  region       = var.region
  vpc_id       = module.network.vpc_id
  dmz_id       = module.network.vpn_subnet_id
  subnets      = ["${var.vpc_cidr_prefix}.1.0/24", "${var.vpc_cidr_prefix}.2.0/24", "${var.vpc_cidr_prefix}.3.0/24"]
  peer_subnets = var.peer_subnets

  vpn_psk      = var.vpn_psk
  vpn_name     = var.vpn_name

  eip_1        = module.network.vpngw_ip_1_id
  eip_2        = module.network.vpngw_ip_2_id
  dns_zone     = var.dns_zone

  tags         = local.tags
}

# ---------------------------------------------------------------------------
# LTS — Log Tank Service
#
# Creates the log group and streams consumed by the CCE log-agent add-on.
# Must be applied before (or in the same apply as) the CCE module so the
# stream IDs are available when the add-on is installed.
# ---------------------------------------------------------------------------
module "lts" {
  source = "./modules/lts"

  name        = var.vpc_name
  environment = var.environment
  ttl_in_days = var.lts_ttl_in_days

  tags = local.tags
}

# ---------------------------------------------------------------------------
# CCE — Kubernetes cluster with ELB HTTPS ingress
#
# Set cce_high_availability = true for a 3-master / 3-worker HA cluster.
# TLS certificate files must be placed under modules/cce/cert/ before apply:
#   modules/cce/cert/tls.crt  — PEM certificate chain
#   modules/cce/cert/tls.key  — PEM private key
# ---------------------------------------------------------------------------
module "cce" {
  source = "./modules/cce"

  cluster_name      = var.vpc_name
  environment       = var.environment
  region            = var.region
  high_availability = var.cce_high_availability

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  network_id        = module.network.network_id
  neutron_subnet_id = module.network.neutron_subnet_id
  node_keypair      = var.node_keypair

  node_count        = var.cce_node_count

  tls_cert_file     = "${path.module}/modules/cce/cert/tls.crt"
  tls_key_file      = "${path.module}/modules/cce/cert/tls.key"

  dns_zone          = var.dns_zone
  k8s_version       = var.cce_k8s_version

  bastion_sg_id     = module.bastion.bastion_sg_id
  node_subnet_cidr  = "${var.vpc_cidr_prefix}.1.0/24"

  # LTS — log-agent add-on destination
  lts_log_group_id         = module.lts.log_group_id
  lts_kubernetes_stream_id = module.lts.kubernetes_stream_id
  lts_audit_stream_id      = module.lts.audit_stream_id

  tags = local.tags
}

# ---------------------------------------------------------------------------
# DDS — MongoDB-compatible Document Database
#
# Security group rule: allows CCE worker nodes to reach DDS on port 8635.
# Note: OTC DDS uses port 8635, not MongoDB's default 27017.
# ---------------------------------------------------------------------------

module "dds" {
  source = "./modules/dds"

  name        = var.vpc_name
  environment = var.environment

  high_availability = var.dds_high_availability
  db_version        = var.dds_db_version
  spec_code         = var.dds_spec_code
  volume_size_gb    = var.dds_volume_size_gb
  password          = var.dds_password

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.datastore_subnet_id
  cce_node_sg_id    = module.cce.node_sg_id
  availability_zone = "${var.region}-01"

  maintain_begin = "02:00"
  maintain_end   = "03:00"

  backup_enabled    = var.dds_backup_enabled
  backup_start_time = var.dds_backup_start_time
  backup_keep_days  = var.dds_backup_keep_days
  backup_period     = var.dds_backup_period

  tags = local.tags
}

# ---------------------------------------------------------------------------
# ASM bootstrap tfvars — generated after apply so node IDs are known.
#
# This file captures everything needed to deploy the ASM module later.
# Copy it to a new project or add it to this one with:
#   tofu apply -var-file=asm-bootstrap.auto.tfvars
#
# NOTE: installation_nodes will be empty on the very first apply (before
# nodes exist). Run a second tofu apply to regenerate with real node IDs.
# ---------------------------------------------------------------------------

# NOTE: installation_nodes will be empty on the very first apply (before
# nodes exist). Run a second tofu apply to regenerate with real node IDs.
# ---------------------------------------------------------------------------

resource "local_file" "asm_bootstrap" {
  filename        = "${path.module}/exports/asm-bootstrap.tfvars"
  file_permission = "0600"

  content = templatefile("${path.module}/asm-bootstrap.tfvars.tpl", {
    cluster_id         = module.cce.cluster_id
    cluster_name       = module.cce.cluster_name
    vpc_id             = module.network.vpc_id
    subnet_id          = module.network.subnet_id
    node_sg_id         = module.cce.node_sg_id
    installation_nodes = module.cce.worker_node_ids
    region             = var.region
    environment        = var.environment
    elb_id             = module.cce.elb_id
    high_availability  = module.cce.high_availability
  })
}

resource "local_file" "cce_env" {
  filename        = "${path.module}/exports/kube.env"
  file_permission = "0600"
  content = <<-EOT
    EXT_BASTION_HOST="${module.bastion.bastion_ext_dns}"
    BASTION_DNS_NAME="${module.bastion.bastion_int_dns}"
    GRAFANA_DNS_NAME="mern-grafana.${var.dns_zone}"
  EOT

}

# ---------------------------------------------------------------------------
# kubeconfig — written to exports/ for use by 2-asm and 3-workloads.
#
# Route traffic through the bastion SOCKS5 proxy:
#   ssh -D 1080 -N user@<bastion-ext-ip>
#   KUBECONFIG=exports/kubeconfig HTTPS_PROXY=socks5://localhost:1080 kubectl get nodes
# ---------------------------------------------------------------------------

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/exports/kubeconfig"
  file_permission = "0600"

  content = templatefile("${path.module}/kubeconfig.tpl", {
    cluster_name     = module.cce.cluster_name
    cluster_endpoint = module.cce.cluster_endpoint
    cluster_ca       = module.cce.cluster_ca
    cluster_token    = module.cce.cluster_token
    cluster_key      = module.cce.cluster_key
  })
}

# ---------------------------------------------------------------------------
# istio.env — sourced by 2-asm scripts to pick up HA flag, version, and
# kubeconfig path without requiring manual environment setup.
# ---------------------------------------------------------------------------

resource "local_file" "istio_env" {
  filename        = "${path.module}/exports/istio.env"
  file_permission = "0640"

  content = templatefile("${path.module}/istio.env.tpl", {
    high_availability = module.cce.high_availability
    istio_version     = "1.21.2"
    kubeconfig_path   = abspath("${path.module}/exports/kubeconfig")
  })
}
