locals {
  domains = {
    grafana = "mern-grafana"
    demo = "mern-demo2"
    hello = "mern-helloworld"
    asm_console = "mern-asm-console"
  }
  elb_dns_name = "mern-elb.${var.dns_zone}"
}


# ---------------------------------------------------------------------------
# Network — VPC, Subnet, NAT GW, VPN EIPs, SSH key
# ---------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  region            = var.region
  vpc_name          = var.vpc_name
  vpc_cidr          = "${var.vpc_cidr_prefix}.0.0/16"

  subnet_name       = "mern-subnet"
  subnet_cidr       = "${var.vpc_cidr_prefix}.1.0/24"
  subnet_gateway_ip = "${var.vpc_cidr_prefix}.1.1"

  bastion_subnet_name       = "mern-bastion-subnet"
  bastion_subnet_cidr       = "${var.vpc_cidr_prefix}.2.0/24"
  bastion_subnet_gateway_ip = "${var.vpc_cidr_prefix}.2.1"

  vpn_subnet_name       = "mern-dev-vpn-subnet"
  vpn_subnet_cidr       = "${var.vpc_cidr_prefix}.3.0/24"
  vpn_subnet_gateway_ip = "${var.vpc_cidr_prefix}.3.1"

  datastore_subnet_name       = "mern-datastore-subnet"
  datastore_subnet_cidr       = "${var.vpc_cidr_prefix}.4.0/24"
  datastore_subnet_gateway_ip = "${var.vpc_cidr_prefix}.4.1"

  ingress_subnet_name       = "mern-ingress-subnet"
  ingress_subnet_cidr       = "${var.vpc_cidr_prefix}.5.0/24"
  ingress_subnet_gateway_ip = "${var.vpc_cidr_prefix}.5.1"

  common_tags              = var.common_tags

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

  dns_zone     = var.dns_zone
  common_tags  = var.common_tags
}

# ---------------------------------------------------------------------------
# VPN — site-to-site tunnel to customer network
# ---------------------------------------------------------------------------
module "vpn" {
  source = "./modules/vpn"

  region       = var.region
  vpc_id       = module.network.vpc_id
  dmz_id       = module.network.vpn_subnet_id
  subnets      = ["${var.vpc_cidr_prefix}.1.0/24", "${var.vpc_cidr_prefix}.2.0/24", "${var.vpc_cidr_prefix}.5.0/24"]
  peer_subnets = var.peer_subnets

  vpn_psk      = var.vpn_psk
  vpn_name     = var.vpn_name

  eip_1        = module.network.vpngw_ip_1_id
  eip_2        = module.network.vpngw_ip_2_id
  dns_zone     = var.dns_zone

  common_tags         = var.common_tags
}

# ---------------------------------------------------------------------------
# Ingress — dedicated internal ELB for cluster ingress
# ---------------------------------------------------------------------------
module "ingress" {
  source = "./modules/ingress"

  dns_zone     = var.dns_zone
  elb_dns_name = "${local.elb_dns_name}."
  region                    = var.region
  vpc_id                    = module.network.vpc_id
  ingress_network_id        = module.network.ingress_network_id
  ingress_neutron_subnet_id = module.network.ingress_neutron_subnet_id
  high_availability         = var.cce_high_availability
  common_tags               = var.common_tags
}

# ---------------------------------------------------------------------------
# DNS+TLS — configure DNS names and certificates
# ---------------------------------------------------------------------------
module "dnstls" {
  source = "./modules/dns-tls"
  dns_zone = var.dns_zone
  elb_dns_name = "${local.elb_dns_name}."
  domains = [
    local.domains.grafana,
    local.domains.demo,
    local.domains.hello,
    local.domains.asm_console,
  ]
  acme_otc_creds = var.acme_otc_creds
  le_email = var.le_email
}


# ---------------------------------------------------------------------------
# CCE — Kubernetes cluster with ELB HTTPS ingress
#
# Set cce_high_availability = true for a 3-master / 3-worker HA cluster.
# ---------------------------------------------------------------------------
module "cce" {
  source = "./modules/cce"

  region            = var.region
  high_availability = var.cce_high_availability

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.subnet_id
  network_id        = module.network.network_id
  neutron_subnet_id = module.network.neutron_subnet_id

  node_count        = var.cce_node_count
  worker_node_flavor = var.cce_worker_flavor

  ingress_subnet_cidr = module.network.ingress_subnet_cidr
  bastion_subnet_cidr = module.network.bastion_subnet_cidr

  dns_zone          = var.dns_zone
  k8s_version       = var.cce_k8s_version

  common_tags = var.common_tags
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

  high_availability = var.dds_high_availability
  db_version        = var.dds_db_version
  spec_code         = var.dds_spec_code
  volume_size_gb    = var.dds_volume_size_gb
  password          = var.dds_password

  vpc_id            = module.network.vpc_id
  subnet_id         = module.network.datastore_subnet_id
  cce_node_sg_id    = module.cce.node_sg_id
  bastion_sg_id     = module.bastion.bastion_sg_id
  availability_zone = "${var.region}-01"

  maintain_begin = "02:00"
  maintain_end   = "03:00"

  backup_enabled    = var.dds_backup_enabled
  backup_start_time = var.dds_backup_start_time
  backup_keep_days  = var.dds_backup_keep_days
  backup_period     = var.dds_backup_period

  tags = var.common_tags
}
