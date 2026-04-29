# ---------------------------------------------------------------------------
# modules/cce — Input Variables
# ---------------------------------------------------------------------------

# ---- Cluster identity ----

variable "cluster_name" {
  description = "Name of the CCE cluster"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod…)"
  type        = string
}

variable "region" {
  description = "OTC region"
  type        = string
  default     = "eu-de"
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

variable "node_keypair" {
  description = "Name of the SSH key pair for worker nodes"
  type        = string
}

# ---- Worker node count ----

variable "node_count" {
  description = "Number of worker nodes (ignored in HA mode — overridden to 3)"
  type        = number
  default     = 2
}

# ---- TLS / ELB ingress ----

variable "tls_cert_file" {
  description = "Path to PEM-encoded TLS certificate (relative to the root module)"
  type        = string
  default     = "cert/tls.crt"
}

variable "tls_key_file" {
  description = "Path to PEM-encoded TLS private key (relative to the root module)"
  type        = string
  default     = "cert/tls.key"
}

variable "dns_zone" {
  description = "DNS zone used for internal DNS records"
  type        = string
}

# ---- Kubernetes ----

variable "k8s_version" {
  description = "Kubernetes version to deploy (e.g. v1.28)"
  type        = string
  default     = "v1.29"
}

# ---- Tags ----

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

# ---- LTS (log-agent add-on) ----

variable "lts_log_group_id" {
  description = "LTS log group ID — passed from the lts module, consumed by the log-agent add-on"
  type        = string
}

variable "lts_kubernetes_stream_id" {
  description = "LTS stream ID for container logs — passed from the lts module, consumed by the log-agent add-on"
  type        = string
}

variable "lts_audit_stream_id" {
  description = "LTS stream ID for Kubernetes audit logs — passed from the lts module, consumed by the log-agent add-on"
  type        = string
}

variable "bastion_sg_id" {
  description = "Bastion security group ID — permitted to reach the CCE API server on port 5443"
  type        = string
}
