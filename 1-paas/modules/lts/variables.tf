# ---------------------------------------------------------------------------
# modules/lts — Input Variables
# ---------------------------------------------------------------------------

variable "name" {
  description = "Short name used to derive log group / stream names (e.g. the VPC/project name)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod…)"
  type        = string
}

variable "ttl_in_days" {
  description = "Log retention period in days (1–365)"
  type        = number
  default     = 7

  validation {
    condition     = var.ttl_in_days >= 1 && var.ttl_in_days <= 365
    error_message = "ttl_in_days must be between 1 and 365."
  }
}

variable "services" {
  description = <<-EOT
    Map of log streams to create inside the log group.
    Each key becomes the stream name suffix; value is a human-readable description
    (used only in comments — OTC streams have no description field).

    Defaults cover the CCE add-on stack:
      kubernetes  — container stdout/stderr collected by log-agent
      node        — node-level logs (/var/log/messages, kubelet, etc.)
      audit       — Kubernetes API server audit log
  EOT
  type        = map(string)
  default = {
    kubernetes = "Container stdout/stderr (log-agent)"
    node       = "Node-level system and kubelet logs"
    audit      = "Kubernetes API server audit log"
  }
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}
