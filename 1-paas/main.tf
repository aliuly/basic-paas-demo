
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
  subnet_id    = module.network.subnet_id
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
  dmz_id       = module.network.subnet_id
  subnets      = ["${var.vpc_cidr_prefix}.1.0/24"]
  peer_subnets = var.peer_subnets

  vpn_psk      = var.vpn_psk
  vpn_name     = var.vpn_name

  eip_1        = module.network.vpngw_ip_1_id
  eip_2        = module.network.vpngw_ip_2_id
  dns_zone     = var.dns_zone

  tags         = local.tags
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

  tags              = local.tags
}

# ---------------------------------------------------------------------------
# DDS — MongoDB-compatible Document Database
#
# Security group rule: allows CCE worker nodes to reach DDS on port 8635.
# Note: OTC DDS uses port 8635, not MongoDB's default 27017.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_networking_secgroup_v2" "dds" {
  name        = "sg-dds-${var.vpc_name}-${var.environment}"
  description = "DDS instance — inbound 8635 from CCE nodes only"
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "dds_from_cce_nodes" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 8635
  port_range_max    = 8635
  remote_group_id   = module.cce.node_sg_id
  security_group_id = opentelekomcloud_networking_secgroup_v2.dds.id
}

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
  subnet_id         = module.network.subnet_id
  security_group_id = opentelekomcloud_networking_secgroup_v2.dds.id
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
