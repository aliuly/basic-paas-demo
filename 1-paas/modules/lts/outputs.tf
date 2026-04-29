# ---------------------------------------------------------------------------
# modules/lts — Outputs
# ---------------------------------------------------------------------------

output "log_group_id" {
  description = "LTS log group ID"
  value       = opentelekomcloud_lts_group_v2.this.id
}

output "log_group_name" {
  description = "LTS log group name"
  value       = opentelekomcloud_lts_group_v2.this.group_name
}

# ---------------------------------------------------------------------------
# All stream IDs as a map — keyed by the same keys as var.services.
# Useful when a caller wants to iterate or pass the whole map downstream.
#
# Example:
#   module.lts.stream_ids["kubernetes"]
#   module.lts.stream_ids["node"]
# ---------------------------------------------------------------------------

output "stream_ids" {
  description = "Map of service key → LTS stream ID (matches var.services keys)"
  value       = { for k, s in opentelekomcloud_lts_stream_v2.this : k => s.id }
}

# ---------------------------------------------------------------------------
# Convenience outputs for the two streams the log-agent add-on needs
# directly.  Will be null if the caller removed those keys from var.services.
# ---------------------------------------------------------------------------

output "kubernetes_stream_id" {
  description = "Stream ID for container logs — pass to log-agent add-on custom.log_stream_id"
  value       = try(opentelekomcloud_lts_stream_v2.this["kubernetes"].id, null)
}

output "node_stream_id" {
  description = "Stream ID for node-level logs"
  value       = try(opentelekomcloud_lts_stream_v2.this["node"].id, null)
}

output "audit_stream_id" {
  description = "Stream ID for Kubernetes audit logs"
  value       = try(opentelekomcloud_lts_stream_v2.this["audit"].id, null)
}
