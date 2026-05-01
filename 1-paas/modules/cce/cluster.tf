locals {
  azs = [
    "${var.region}-01",
    "${var.region}-02",
    "${var.region}-03",
  ]

  # HA drives master flavour; single-AZ uses cce.s1.small
  master_flavor = var.high_availability ? "cce.s2.small" : "cce.s1.small"

  # HA: one worker per AZ (At least 3); non-HA: caller-supplied count
  effective_node_count = var.high_availability ? (var.node_count < 3 ? 3 : var.node_count) : var.node_count

  # Fixed disk sizes — not exposed as inputs per spec
  system_disk_size = 40  # OTC CCE node pool minimum is 40 GB
  data_disk_size   = 100  # OTC minimum for CCE node pool data volumes is 100 GB

  cluster_full_name = "cce-mern"
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
  labels = var.common_tags

}

# ---------------------------------------------------------------------------
# Worker node pool
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_node_pool_v3" "workers" {
  cluster_id         = opentelekomcloud_cce_cluster_v3.this.id
  name               = "workers"
  os                 = "EulerOS 2.9"
  flavor             = var.worker_node_flavor
  initial_node_count = local.effective_node_count
  key_pair           = opentelekomcloud_compute_keypair_v2.nodes.name

  # Non-HA: all workers in AZ-01; HA: CCE spreads them automatically
  availability_zone = var.high_availability ? "random" : local.azs[0]

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

  user_tags = var.common_tags
}


