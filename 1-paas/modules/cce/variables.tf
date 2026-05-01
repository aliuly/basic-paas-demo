variable "region" {
  description = "OTC region"
  type        = string
}

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
  description = "DNS zone used for internal DNS records"
  type        = string
}


# ---- Topology ----

variable "high_availability" {
  description = <<-EOT
    false → single-master cluster  (cce.s1.small, 1 AZ, cheaper)
    true  → three-master HA cluster (cce.s2.small, 3 AZs, production-grade)
  EOT
  type    = bool
  default = false
}

 variable "worker_node_flavor" {
   type = string
   default ="x1.xlarge.3"
 }


# ---- Network ----

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID (VPC subnet, not neutron)"
  type        = string
}

variable "network_id" {
  description = "Neutron network ID (opentelekomcloud_vpc_subnet_v1.network_id) — required by cce_cluster_v3 subnet_id field"
  type        = string
}

variable "neutron_subnet_id" {
  description = "Neutron subnet ID — required by CCE internally"
  type        = string
}

# ---- Worker node count ----

variable "node_count" {
  description = "Number of worker nodes (ignored in HA mode — overridden to 3)"
  type        = number
  default     = 2
}
# ---- Kubernetes ----

variable "k8s_version" {
  description = "Kubernetes version to deploy (e.g. v1.28)"
  type        = string
  default     = "v1.29"
}

