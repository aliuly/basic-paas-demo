# ---------------------------------------------------------------------------
# modules/dds — OTC Document Database Service (MongoDB-compatible)
#
# Topology (var.high_availability):
#   false → Single node   — mode = "Single",     1× single node flavor
#   true  → Replica Set   — mode = "ReplicaSet", 3× repset node flavor
#                           3 nodes gives automatic primary election and
#                           failover; the hidden node takes over if a
#                           secondary fails.
#
# Storage engine is derived from db_version:
#   3.2 / 3.4 / 4.0  → wiredTiger
#   4.2 / 4.4         → rocksDB
#
# Port: OTC DDS uses 8635 (not MongoDB's default 27017).
# SSL:  Enabled by default. Changing ssl triggers a background restart.
#
# Backups: controlled by backup_enabled + backup_keep_days + backup_period.
#   backup_enabled = false  → keep_days = 0, no automated backups
#   backup_enabled = true   → uses var.backup_start_time / keep_days / period
# ---------------------------------------------------------------------------

locals {
  instance_name = "dds-${var.name}-${var.environment}"

  # DDS mode and node type driven purely by high_availability flag
  mode      = var.high_availability ? "ReplicaSet" : "Single"
  node_type = var.high_availability ? "replica" : "single"

  # ReplicaSet must have 3 nodes; Single always has 1
  node_num = var.high_availability ? 3 : 1

  # Storage engine follows version: rocksDB for 4.2+ otherwise wiredTiger
  storage_engine = contains(["4.2", "4.4"], var.db_version) ? "rocksDB" : "wiredTiger"

  # Effective backup keep_days — zero disables automated backups
  effective_keep_days = var.backup_enabled ? var.backup_keep_days : 0
}

# ---------------------------------------------------------------------------
# Security group — allow inbound on DDS port (8635) from CCE node SG
# The caller passes in an existing security_group_id so the DDS instance
# sits behind a tightly controlled SG.  No extra SG resource is created here;
# the caller (root module) is expected to create the inbound rule:
#
#   opentelekomcloud_networking_secgroup_rule_v2 allowing tcp/8635 from the
#   CCE node security group to the DDS security group.
# ---------------------------------------------------------------------------

resource "opentelekomcloud_dds_instance_v3" "this" {
  name              = local.instance_name
  availability_zone = var.availability_zone
  vpc_id            = var.vpc_id
  subnet_id         = var.subnet_id
  security_group_id = var.security_group_id
  password          = var.password
  mode              = local.mode
  ssl               = var.ssl

  disk_encryption_id = var.disk_encryption_id

  maintain_begin = var.maintain_begin
  maintain_end   = var.maintain_end

  datastore {
    type           = "DDS-Community"
    version        = var.db_version
    storage_engine = local.storage_engine
  }

  flavor {
    type      = local.node_type
    num       = local.node_num
    storage   = "ULTRAHIGH"
    size      = var.volume_size_gb
    spec_code = var.spec_code
  }

  backup_strategy {
    start_time = var.backup_start_time
    keep_days  = local.effective_keep_days
    # period is only meaningful when backups are enabled
    period = var.backup_enabled ? var.backup_period : null
  }

  tags = var.tags

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
