# ---------------------------------------------------------------------------
# modules/lts — Log Tank Service (LTS) log group and streams
#
# Creates one log group per environment and one stream per entry in
# var.services.  The log-agent CCE add-on references the kubernetes and
# node stream IDs; the audit stream can be wired to the CCE audit-log
# forwarding feature separately.
#
# Outputs expose IDs for every stream so callers can pass the right ones
# to whichever add-on or service needs them.
# ---------------------------------------------------------------------------

locals {
  group_name = "lts-${var.name}-${var.environment}"
}

# ---------------------------------------------------------------------------
# Log Group — one per cluster / environment
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lts_group_v2" "this" {
  group_name  = local.group_name
  ttl_in_days = var.ttl_in_days

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Log Streams — one per entry in var.services
# ---------------------------------------------------------------------------

resource "opentelekomcloud_lts_stream_v2" "this" {
  for_each = var.services

  group_id    = opentelekomcloud_lts_group_v2.this.id
  stream_name = "${var.name}-${each.key}"

  # OTC stream resources carry no tags block — name is the only identifier
}
