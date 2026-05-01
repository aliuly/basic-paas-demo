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
