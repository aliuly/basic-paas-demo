

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
  subnets      = ["${var.vpc_cidr_prefix}.1.0/24", "${var.vpc_cidr_prefix}.2.0/24", "${var.vpc_cidr_prefix}.3.0/24"]
  peer_subnets = var.peer_subnets

  vpn_psk      = var.vpn_psk
  vpn_name     = var.vpn_name

  eip_1        = module.network.vpngw_ip_1_id
  eip_2        = module.network.vpngw_ip_2_id
  dns_zone     = var.dns_zone

  common_tags         = var.common_tags
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

  dns_zone          = var.dns_zone
  k8s_version       = var.cce_k8s_version

  common_tags = var.common_tags
}


