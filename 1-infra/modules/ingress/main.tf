locals {
  availability_zones = var.high_availability ? [
    "${var.region}-01",
    "${var.region}-02",
  ] : ["${var.region}-01"]
  elb_name = split(".",var.elb_dns_name)[0]
}


# ---------------------------------------------------------------------------
# Security group for the ELB — no rules yet, added per exposed service
# ---------------------------------------------------------------------------
resource "opentelekomcloud_networking_secgroup_v2" "elb" {
  name        = "sg-ingress-elb"
  description = "Ingress ELB — add inbound rules per exposed service"
}

# 2. Allow Inbound HTTP (Port 80)
resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_http" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 80
  port_range_max    = 80
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.elb.id
}

# 3. Allow Inbound HTTPS (Port 443)
resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.elb.id
}

# ---------------------------------------------------------------------------
# Dedicated internal ELB — no public_ip block = VPC-internal only.
# Reachable from on-prem via VPN through the ingress subnet (10.200.5.0/24).
# HA: spans eu-de-01 + eu-de-02; non-HA: eu-de-01 only.
# ---------------------------------------------------------------------------
resource "opentelekomcloud_lb_loadbalancer_v3" "this" {
  name               = "elb-ingress"
  router_id          = var.vpc_id
  subnet_id          = var.ingress_neutron_subnet_id
  network_ids        = [var.ingress_network_id]
  availability_zones = local.availability_zones
  l7_flavor          = var.l7_flavor
  tags               = var.common_tags
}

#
# Update DNS records
data "opentelekomcloud_dns_zone_v2" "intdns" {
  name = "${var.dns_zone}."
}

resource "opentelekomcloud_dns_recordset_v2" "elp_a" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = var.elb_dns_name
  type    = "A"
  records = [ opentelekomcloud_lb_loadbalancer_v3.this.vip_address ]
  tags    = var.common_tags
}
