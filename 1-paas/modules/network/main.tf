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
  tags   = var.tags
}

resource "opentelekomcloud_vpc_subnet_v1" "this" {
  name              = var.subnet_name
  cidr              = var.subnet_cidr
  gateway_ip        = var.subnet_gateway_ip
  vpc_id            = opentelekomcloud_vpc_v1.this.id
  #~ availability_zone = var.availability_zone
  #~ dns_list          = ["100.125.4.25", "8.8.8.8"]
  tags              = var.tags
}

# ---------------------------------------------------------------------------
# ELB Security Group — created here with no rules so its ID is available
# to modules/cce without depending on modules/waf.
# The WAF IP inbound rules are added in the environment main.tf after
# both modules/cce and modules/waf outputs are known.
# ---------------------------------------------------------------------------
resource "opentelekomcloud_networking_secgroup_v2" "elb" {
  name        = "${var.vpc_name}-elb-sg"
  description = "Internal ELB — inbound 443 from WAF IPs added post-provisioning"
  region      = var.region
}

