# ---------------------------------------------------------------------------
# modules/network — VPC, Subnet, and ELB Security Group
#
# The ELB security group is created here (with no rules initially) so that
# its ID can be passed to modules/cce without creating a cycle. WAF IP-based
# inbound rules are added in the environment main.tf after both modules/cce
# and modules/waf have been provisioned and their outputs are known.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_vpc_v1" "this" {
  name   = var.vpc_name
  cidr   = var.vpc_cidr
  region = var.region
  tags   = var.common_tags
}

resource "opentelekomcloud_vpc_subnet_v1" "this" {
  name              = var.subnet_name
  cidr              = var.subnet_cidr
  gateway_ip        = var.subnet_gateway_ip
  vpc_id            = opentelekomcloud_vpc_v1.this.id
  #~ availability_zone = var.availability_zone
  #~ dns_list          = ["100.125.4.25", "8.8.8.8"]
  tags              = var.common_tags
}

# ---------------------------------------------------------------------------
# Bastion Subnet — isolated subnet for the bastion host
# ---------------------------------------------------------------------------
resource "opentelekomcloud_vpc_subnet_v1" "bastion" {
  name       = var.bastion_subnet_name
  cidr       = var.bastion_subnet_cidr
  gateway_ip = var.bastion_subnet_gateway_ip
  vpc_id     = opentelekomcloud_vpc_v1.this.id
  tags       = var.common_tags
}




# ---------------------------------------------------------------------------
# VPN Subnet — isolated subnet for the VPN gateway
# ---------------------------------------------------------------------------
resource "opentelekomcloud_vpc_subnet_v1" "vpn" {
  name       = var.vpn_subnet_name
  cidr       = var.vpn_subnet_cidr
  gateway_ip = var.vpn_subnet_gateway_ip
  vpc_id     = opentelekomcloud_vpc_v1.this.id
  tags       = var.common_tags
}

# ---------------------------------------------------------------------------
# Datastore Subnet — isolated subnet for DDS (and future data services)
# ---------------------------------------------------------------------------
resource "opentelekomcloud_vpc_subnet_v1" "datastore" {
  name       = var.datastore_subnet_name
  cidr       = var.datastore_subnet_cidr
  gateway_ip = var.datastore_subnet_gateway_ip
  vpc_id     = opentelekomcloud_vpc_v1.this.id
  tags       = var.common_tags
}

# ---------------------------------------------------------------------------
# Ingress Subnet — dedicated subnet for the dedicated ELB ingress tier.
# OTC subnets are not AZ-bound; the ELB in modules/ingress draws IPs from
# here and spans 1 AZ (high_availability=false) or 2 AZs (true).
# Advertised to on-prem via VPN so clients can reach the ELB directly.
# ---------------------------------------------------------------------------
resource "opentelekomcloud_vpc_subnet_v1" "ingress" {
  name       = var.ingress_subnet_name
  cidr       = var.ingress_subnet_cidr
  gateway_ip = var.ingress_subnet_gateway_ip
  vpc_id     = opentelekomcloud_vpc_v1.this.id
  tags       = var.common_tags
}
