# ---------------------------------------------------------------------------
# modules/cce/addons.tf — CCE managed add-ons
#
# Add-on install order:
#   metrics-server, node-problem-detector  (no dependencies)
#   cloud-native-cluster-monitoring        (no dependencies)
#   log-agent                              (needs LTS group + stream IDs)
# ---------------------------------------------------------------------------

locals {
  cluster_id = opentelekomcloud_cce_cluster_v3.this.id
}

# ---------------------------------------------------------------------------
# 1. Kubernetes Metrics Server
#
# template_name confirmed from OTC API response.
# template_version 1.3.60 is the newest version supporting v1.29.* clusters.
# basic.swr_addr confirmed from the 1.3.104 entry in the API response.
# basic.swr_user confirmed as "cce-addons" (changed from "hwofficial" in 1.2.1+).
#
# The custom block mirrors the default "custom" parameters from the API spec:
#   multiAZEnabled        — spread add-on pods across AZs (false = pack into one AZ)
#   node_match_expressions — node selector expressions (empty = any node)
#   tolerations           — default OTC tolerations for not-ready / unreachable nodes
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_addon_v3" "metrics_server" {
  cluster_id       = local.cluster_id
  template_name    = "metrics-server"
  template_version = "1.3.60"

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
}

# ---------------------------------------------------------------------------
# 3. Cloud Native Cluster Monitoring (kube-prometheus-stack + Grafana)
#
# TODO: template_name needs to be confirmed — the OTC API returned items:null
# for "cloud-native-cluster-monitoring". Candidates from OTC docs:
#   "cce-cluster-monitoring", "cloud-native-cluster-monitoring",
#   "kube-prometheus-stack"
# Template version also needs to be confirmed from the same API call.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_addon_v3" "monitoring" {
  cluster_id       = local.cluster_id
  template_name    = "cie-collector"
  template_version = "3.12.2"							# TODO: unconfirmed

  values {
    basic = {
      swr_addr = "swr.eu-de.otc.t-systems.com"
      swr_user = "cce-addons"
    }
    custom = {
      retention        = "7d"
      storage          = "10Gi"
      storageClassName = "csi-disk"
      highAvailability = tostring(var.high_availability)
    }
  }
}

# ---------------------------------------------------------------------------
# 4. Cloud Native Log Collection (log-agent → LTS)
#
# template_name and versions confirmed from OTC API response in apply error.
# Latest stable version is 1.7.6 (supports v1.29.*, released 2026-03-18).
#
# basic block confirmed from the 1.7.6 entry — swr_addr switched to the
# public hostname in this version (matches what we already use).
#
# The custom block uses the field names from the 1.7.6 parameters schema:
#   ltsGroupID       → log group to ship all log types to
#   ltsStdoutStreamID → stream for container stdout/stderr
#   ltsAuditStreamID  → stream for Kubernetes audit log
#   clusterID         → required so the agent knows which cluster it is in
#   projectID         → OTC project ID (leave empty to use instance metadata)
#
# lts_log_group_id and lts_*_stream_id are passed from the lts module
# via root main.tf.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_cce_addon_v3" "log_agent" {
  cluster_id       = local.cluster_id
  template_name    = "log-agent"
  template_version = "1.7.6"

  values {
    basic = {
      swr_addr          = "swr.eu-de.otc.t-systems.com"
      swr_user          = "cce-addons"
      region            = var.region
      ltsEndpoint       = "https://lts.eu-de.otc.t-systems.com"
      ltsAccessEndpoint = "https://lts-access.eu-de.otc.t-systems.com:8102"
      aomEndpoint       = "https://aom.eu-de.otc.t-systems.com"
      iam_url           = "iam.eu-de.otc.t-systems.com"
    }
    custom = {
      clusterID        = local.cluster_id
      ltsGroupID       = var.lts_log_group_id
      ltsStdoutStreamID = var.lts_kubernetes_stream_id
      ltsAuditStreamID  = var.lts_audit_stream_id
      projectID         = ""
      paasakskEnable    = "true"
    }
    flavor = jsonencode({ name = "Low" })
  }
}
