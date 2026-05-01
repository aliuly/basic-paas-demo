# ---------------------------------------------------------------------------
# CCE managed add-ons — installed via OTC's addon API, same as in 1-paas.
# Both register aggregated APIServices that are permanently unavailable on
# OTC CCE because the managed control plane cannot reach service ClusterIPs.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 1. metrics-server — registers v1beta1.metrics.k8s.io
# Breaks: kubectl top nodes/pods, HPA based on CPU/memory metrics
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_addon_v3" "metrics_server" {
  cluster_id       = opentelekomcloud_cce_cluster_v3.this.id
  template_name    = "metrics-server"
  template_version = "1.3.104"

  values {
    basic = {
      swr_addr      = "swr.eu-de.otc.t-systems.com"
      swr_user      = "cce-addons"
      image_version = "v0.6.2"
    }
    custom = {
      multiAZEnabled = "false"
    }
    flavor = jsonencode({ name = "Single" })
  }

  depends_on = [opentelekomcloud_cce_node_pool_v3.workers]
}

# ---------------------------------------------------------------------------
# 2. cie-collector — Prometheus + Grafana stack
# Registers v1beta1.custom.metrics.k8s.io via the bundled Prometheus Adapter
# Breaks: HPA based on custom/external metrics, custom metrics queries
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_addon_v3" "cie_collector" {
  cluster_id       = opentelekomcloud_cce_cluster_v3.this.id
  template_name    = "cie-collector"
  template_version = "3.12.2"

  values {
    basic = {
      swr_addr = "swr.eu-de.otc.t-systems.com"
      swr_user = "cce-addons"
    }
    custom = {
      retention        = "7d"
      storage          = "10Gi"
      storageClassName = "csi-disk"
      highAvailability = "false"
    }
  }

  depends_on = [opentelekomcloud_cce_node_pool_v3.workers]
}
