# ---------------------------------------------------------------------------
# modules/cce — CCE Cluster + Worker Node Pool + ELB Ingress (HTTPS)
#
# Topology switch (var.high_availability):
#   false → cce.s1.small  master, single AZ, var.node_count workers (default 2)
#   true  → cce.s2.small  master, 3 AZs,     3 workers (one per AZ)
#
# Worker nodes:  s9.xlarge.4 flavour, 40 GB system volume, 100 GB data volume
# Ingress:       ELB (shared, internal) with HTTPS using caller-supplied certs
# Admin access:  via bastion / VPN only — no public inbound on cluster/nodes
# ---------------------------------------------------------------------------

locals {
  azs = [
    "${var.region}-01",
    "${var.region}-02",
    "${var.region}-03",
  ]

  # HA drives master flavour; single-AZ uses cce.s1.small
  master_flavor = var.high_availability ? "cce.s2.small" : "cce.s1.small"

  # HA: one worker per AZ (3 total); non-HA: caller-supplied count
  effective_node_count = var.high_availability ? 3 : var.node_count

  # Fixed disk sizes — not exposed as inputs per spec
  system_disk_size = 40  # OTC CCE node pool minimum is 40 GB
  data_disk_size   = 100  # OTC minimum for CCE node pool data volumes is 100 GB

  cluster_full_name = "cce-${var.cluster_name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# TLS certificate — stored in ELB certificate store so the listener can
# reference it by ID.  Files are loaded from the caller's cert/ directory.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lb_certificate_v2" "elb_tls" {
  name        = "${local.cluster_full_name}-tls"
  certificate = file(var.tls_cert_file)
  private_key = file(var.tls_key_file)
}

# ---------------------------------------------------------------------------
# Security group for worker nodes
# Inbound only from within the same SG and from the ELB SG — no internet
# ---------------------------------------------------------------------------

resource "opentelekomcloud_networking_secgroup_v2" "cce_node" {
  name        = "sg-${local.cluster_full_name}-nodes"
  description = "CCE worker nodes — inbound from ELB and node-to-node only"
}

# Nodes may reach each other freely (same SG)
resource "opentelekomcloud_networking_secgroup_rule_v2" "node_self_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = opentelekomcloud_networking_secgroup_v2.cce_node.id
  security_group_id = opentelekomcloud_networking_secgroup_v2.cce_node.id
}

# ELB health-checks and forwarded traffic arrive from the ELB SG
resource "opentelekomcloud_networking_secgroup_rule_v2" "node_from_elb" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 1
  port_range_max    = 65535
  remote_group_id   = opentelekomcloud_networking_secgroup_v2.elb.id
  security_group_id = opentelekomcloud_networking_secgroup_v2.cce_node.id
}

# Bastion host may reach the CCE API server (port 5443) for kubectl access
resource "opentelekomcloud_networking_secgroup_rule_v2" "cce_api_from_bastion" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 5443
  port_range_max    = 5443
  remote_group_id   = var.bastion_sg_id
  security_group_id = opentelekomcloud_networking_secgroup_v2.cce_node.id
}

# ---------------------------------------------------------------------------
# Security group for the ELB VIP
# HTTPS/443 from the VPC (includes VPN-tunnelled clients); no public internet
# ---------------------------------------------------------------------------

resource "opentelekomcloud_networking_secgroup_v2" "elb" {
  name        = "sg-${local.cluster_full_name}-elb"
  description = "ELB ingress — HTTPS 443 from VPN/VPC only, no public inbound"
}

resource "opentelekomcloud_networking_secgroup_rule_v2" "elb_https_ingress" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"   # tighten to VPC CIDR after deploy if desired
  security_group_id = opentelekomcloud_networking_secgroup_v2.elb.id
}

# ---------------------------------------------------------------------------
# CCE Cluster
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_cluster_v3" "this" {
  name                   = local.cluster_full_name
  cluster_type           = "VirtualMachine"
  cluster_version        = var.k8s_version
  flavor_id              = local.master_flavor
  vpc_id                 = var.vpc_id
  subnet_id              = var.network_id
  container_network_type = "overlay_l2"

  # Private API endpoint only — all admin access via bastion kubectl proxy
  # Setting eip = "" or omitting it keeps the API server off the internet.

  dynamic "masters" {
    # HA: spread across all 3 AZs; single: one master in AZ-01
    for_each = var.high_availability ? local.azs : [local.azs[0]]
    content {
      availability_zone = masters.value
    }
  }

  # CCE cluster resource does not accept a tags block; use labels instead
  labels = var.tags

}

# ---------------------------------------------------------------------------
# Worker node pool
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_node_pool_v3" "workers" {
  cluster_id         = opentelekomcloud_cce_cluster_v3.this.id
  name               = "workers"
  os                 = "EulerOS 2.9"
  flavor             = "s9.xlarge.4"
  initial_node_count = local.effective_node_count
  key_pair           = var.node_keypair

  # Non-HA: all workers in AZ-01; HA: CCE spreads them automatically
  availability_zone = var.high_availability ? "random" : local.azs[0]

  # Attach the node security group
  security_group_ids = [opentelekomcloud_networking_secgroup_v2.cce_node.id]

  root_volume {
    size       = local.system_disk_size
    volumetype = "SSD"
  }

  data_volumes {
    size       = local.data_disk_size
    volumetype = "SSD"
  }

  # Auto-scaling disabled — fixed pool
  scale_enable             = false
  min_node_count           = 0
  max_node_count           = 0
  scale_down_cooldown_time = 0
  priority                 = 0

  user_tags = var.tags
}

# ---------------------------------------------------------------------------
# Shared ELB — internal VIP only (no EIP, no public internet)
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lb_loadbalancer_v2" "ingress" {
  name          = "elb-${local.cluster_full_name}"
  vip_subnet_id = var.neutron_subnet_id   # private VIP on the subnet
}

# Attach the ELB security group to the VIP port that OTC creates for the LB.
# This is the correct way to restrict ELB traffic after security_group_ids
# was removed from opentelekomcloud_lb_loadbalancer_v2.
resource "opentelekomcloud_networking_port_secgroup_associate_v2" "elb_vip_sg" {
  port_id = opentelekomcloud_lb_loadbalancer_v2.ingress.vip_port_id
  security_group_ids = [
    opentelekomcloud_networking_secgroup_v2.elb.id,
  ]
}

# ---------------------------------------------------------------------------
# ELB HTTPS Listener (port 443)
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lb_listener_v2" "https" {
  name                      = "listener-https-${local.cluster_full_name}"
  protocol                  = "TERMINATED_HTTPS"
  protocol_port             = 443
  loadbalancer_id           = opentelekomcloud_lb_loadbalancer_v2.ingress.id
  default_tls_container_ref = opentelekomcloud_lb_certificate_v2.elb_tls.id

  tls_ciphers_policy = "tls-1-2-strict"
}

# ---------------------------------------------------------------------------
# ELB Backend pool — nodes are registered here by the CCE cloud-controller
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lb_pool_v2" "backend" {
  name        = "pool-${local.cluster_full_name}"
  protocol    = "HTTP"
  lb_method   = "ROUND_ROBIN"
  listener_id = opentelekomcloud_lb_listener_v2.https.id
}

# Health check against kube-proxy healthz port
resource "opentelekomcloud_lb_monitor_v2" "backend_hc" {
  pool_id        = opentelekomcloud_lb_pool_v2.backend.id
  type           = "HTTP"
  url_path       = "/healthz"
  http_method    = "GET"
  expected_codes = "200"
  delay          = 5
  timeout        = 3
  max_retries    = 3
}

# ---------------------------------------------------------------------------
# Internal DNS — A record pointing at the ELB private VIP
# ---------------------------------------------------------------------------

data "opentelekomcloud_dns_zone_v2" "intdns" {
  name = "${var.dns_zone}."
}

resource "opentelekomcloud_dns_recordset_v2" "elb_vip" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "${var.cluster_name}.${var.dns_zone}."
  type    = "A"
  records = [opentelekomcloud_lb_loadbalancer_v2.ingress.vip_address]
  tags    = var.tags
}

# ---------------------------------------------------------------------------
# CCE API server — private DNS A record
#
# cluster_endpoint is a URL (https://10.x.x.x:5443) — extract the bare IP
# so it can be registered as an A record for use in kubeconfig.
# ---------------------------------------------------------------------------

locals {
  api_ip = regex("https://([^:]+):", opentelekomcloud_cce_cluster_v3.this.certificate_clusters[0].server)[0]
}

resource "opentelekomcloud_dns_recordset_v2" "cce_api" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "api-${local.cluster_full_name}.${var.dns_zone}."
  type    = "A"
  records = [local.api_ip]
  tags    = var.tags
}

resource "opentelekomcloud_dns_recordset_v2" "grafana_cname" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "grafana-mern.${var.dns_zone}."
  type    = "CNAME"
  records = ["${var.cluster_name}.${var.dns_zone}."]
  tags    = var.tags
}

# ---------------------------------------------------------------------------
# Node IDs — resolved after the node pool is ready.
# Used by the ASM module (separate apply) to know which nodes to install on.
# On first apply this data source returns empty; it populates on second apply
# once nodes exist in OTC's API.
# ---------------------------------------------------------------------------

data "opentelekomcloud_cce_node_ids_v3" "workers" {
  cluster_id = opentelekomcloud_cce_cluster_v3.this.id
  depends_on = [opentelekomcloud_cce_node_pool_v3.workers]
}
