# ---------------------------------------------------------------------------
# modules/dds — Input Variables
# ---------------------------------------------------------------------------

# ---- Identity ----

variable "name" {
  description = "DDS instance name. Must be unique per tenant and type."
  type        = string
}


# ---- Topology ----

variable "high_availability" {
  description = <<-EOT
    false (default) → Single node instance — one node, no redundancy, dev/test only.
    true            → ReplicaSet instance — 3-node replica set, automatic failover.
    Node types and flavors change accordingly; see locals in main.tf.
  EOT
  type    = bool
  default = false
}

# ---- Database ----

variable "db_version" {
  description = <<-EOT
    MongoDB-compatible DDS version.
    Allowed: 3.2, 3.4, 4.0 (wiredTiger storage engine)
             4.2, 4.4        (rocksDB storage engine)
  EOT
  type    = string
  default = "4.4"

  validation {
    condition     = contains(["3.2", "3.4", "4.0", "4.2", "4.4"], var.db_version)
    error_message = "db_version must be one of: 3.2, 3.4, 4.0, 4.2, 4.4."
  }
}

variable "password" {
  description = "Administrator (rwuser) password. Must contain uppercase, lowercase, digits and a special character."
  type        = string
  sensitive   = true
}

# ---- Flavour / storage ----

variable "spec_code" {
  description = <<-EOT
    DDS flavour spec_code for the primary/data nodes.
    Single:      e.g. "dds.mongodb.s2.medium.4.single"
    ReplicaSet:  e.g. "dds.mongodb.s2.medium.4.repset"
    Find available spec codes in the OTC console under DDS → Create Instance → Specifications.
    OTC DDS port is 8635 (not 27017).
  EOT
  type = string
}

variable "volume_size_gb" {
  description = <<-EOT
    Disk size in GB. Must be a multiple of 10.
    Single node:   10–2000 GB
    ReplicaSet:    10–2000 GB
  EOT
  type    = number
  default = 100

  validation {
    condition     = var.volume_size_gb >= 10 && var.volume_size_gb <= 2000 && var.volume_size_gb % 10 == 0
    error_message = "volume_size_gb must be a multiple of 10 between 10 and 2000."
  }
}

# ---- Network ----

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "VPC subnet ID (opentelekomcloud_vpc_subnet_v1.id — the VPC-level UUID, same as module.network.subnet_id)"
  type        = string
}

variable "cce_node_sg_id" {
  description = "CCE node security group ID — permitted to reach DDS on port 8635"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion security group ID — permitted to reach DDS on port 8635 for admin access"
  type        = string
}

variable "availability_zone" {
  description = "Availability zone for the DDS instance (e.g. eu-de-01)"
  type        = string
}

# ---- Maintenance window ----

variable "maintain_begin" {
  description = "Maintenance window start time in UTC, HH:MM format (e.g. \"02:00\"). Gap to maintain_end must be at least 1 hour."
  type    = string
  default = "02:00"
}

variable "maintain_end" {
  description = "Maintenance window end time in UTC, HH:MM format (e.g. \"03:00\"). Gap from maintain_begin must be at least 1 hour."
  type    = string
  default = "03:00"
}

# ---- Backup ----

variable "backup_enabled" {
  description = "Whether to enable automated backups. When false, backup_keep_days is set to 0."
  type        = bool
  default     = true
}

variable "backup_start_time" {
  description = <<-EOT
    Backup window in UTC. Format: "hh:mm-HH:MM" where HH = hh+1 and mm/MM ∈ {00,15,30,45}.
    Example: "02:00-03:00"
  EOT
  type    = string
  default = "03:00-04:00"
}

variable "backup_keep_days" {
  description = <<-EOT
    Number of days to retain automated backup files (1–732).
    Setting backup_enabled = false overrides this to 0 (disables backups).
  EOT
  type    = number
  default = 7

  validation {
    condition     = var.backup_keep_days >= 1 && var.backup_keep_days <= 732
    error_message = "backup_keep_days must be between 1 and 732."
  }
}

variable "backup_period" {
  description = <<-EOT
    Days of the week on which backups run (comma-separated, 1=Mon … 7=Sun).
    For keep_days ≤ 6: must be "1,2,3,4,5,6,7" (daily).
    For keep_days 7–732: at least one day required, e.g. "1,3,5".
    Ignored when backup_enabled = false.
  EOT
  type    = string
  default = "1,2,3,4,5,6,7"
}

# ---- Encryption ----

variable "disk_encryption_id" {
  description = "Optional KMS key ID for disk encryption at rest. Leave null to use unencrypted volumes."
  type        = string
  default     = null
}

# ---- Tags ----

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
