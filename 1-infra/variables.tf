# ---------------------------------------------------------------------------
# envs/dev — Input Variables
# ---------------------------------------------------------------------------
variable "common_tags" {
  description = "Common tags for environment"
  type = map(string)
  default = {
    environment = "development"
    managed_by = "OpenTofu"
    CASIO = "Use2"
  }
}

variable "dns_zone" {
  description = "DNS zone to populate DNS records"
  type = string
}

variable "region" {
  description = "OTC region"
  type        = string
}

#
# Networking
#

variable "vpc_name" {
  description = "Name of VPC"
  type = string
}
variable "vpc_cidr_prefix" {
  description = "First two bytes of CIDR prefix"
  type = string
}

variable "vpn_name" {
  description = "Name of VPN used to generate DNS records"
  type = string
}

variable "vpn_psk" {
  description = "PSK to secure VPN"
  type = string
  sensitive = true
}


variable "peer_subnets" {
  type = list(string)
  description = "Networks on the far end of the VPN"
}


# ---- Bastion ----
# Users that can login to bastion host
variable "local_users" {
  description = "Small set of users to create"
  sensitive = true
  type = list(object({
    name = string
    gecos = optional(string,"")
    passwd = string
    ssh_keys = optional(list(string),[])
  }))
  default = []
}


# ---- CCE ----

variable "cce_high_availability" {
  description = <<-EOT
    false (default) → single-master cluster (cce.s1.small, 1 AZ) — dev/staging
    true            → three-master HA cluster (cce.s2.small, 3 AZs) — production
  EOT
  type    = bool
  default = false
}

variable "cce_node_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "cce_k8s_version" {
  description = "Kubernetes version to deploy (e.g. v1.29)"
  type        = string
  default     = "v1.29"
}
variable "cce_worker_flavor" {
  type = string
  default ="x1.xlarge.3"
}

# ----- TLS Certificates -----
variable "acme_otc_creds" {
  description = "Used to configure the OTC ACME provider"
  type = object({
    OTC_USER_NAME    = string
    OTC_PASSWORD     = string
    OTC_DOMAIN_NAME  = string
    OTC_PROJECT_NAME = string
  })
}
variable "le_email" {
  description = "E-Mail address to send to Let's Encrypt"
  type = string
}

# ---------------------------------------------------------------------------
# DDS — Document Database Service
# ---------------------------------------------------------------------------

variable "dds_high_availability" {
  description = <<-EOT
    false (default) → Single node instance — dev/test, no redundancy.
    true            → 3-node ReplicaSet — automatic failover, production-grade.
  EOT
  type    = bool
  default = false
}

variable "dds_db_version" {
  description = "DDS MongoDB-compatible version: 3.2, 3.4, 4.0 (wiredTiger) or 4.2, 4.4 (rocksDB)"
  type        = string
  default     = "4.4"
}

variable "dds_spec_code" {
  description = <<-EOT
    DDS node flavour spec_code. Examples:
      Single:     "dds.mongodb.s2.medium.4.single"
      ReplicaSet: "dds.mongodb.s2.medium.4.repset"
    Check available codes in the OTC console under DDS → Create Instance.
  EOT
  type = string
}

variable "dds_volume_size_gb" {
  description = "Storage volume size in GB (multiple of 10, 10–2000)"
  type        = number
  default     = 100
}

variable "dds_password" {
  description = "DDS administrator (rwuser) password"
  type        = string
  sensitive   = true
}

variable "dds_backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "dds_backup_start_time" {
  description = "Backup window in UTC, format hh:mm-HH:MM (e.g. \"03:00-04:00\")"
  type        = string
  default     = "03:00-04:00"
}

variable "dds_backup_keep_days" {
  description = "Number of days to retain backups (1–732)"
  type        = number
  default     = 7
}

variable "dds_backup_period" {
  description = "Comma-separated days of week for backups (1=Mon … 7=Sun). E.g. \"1,2,3,4,5,6,7\""
  type        = string
  default     = "1,2,3,4,5,6,7"
}
