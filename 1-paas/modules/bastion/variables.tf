#
# Inputs for Bastion module
#

variable "subnet_id" {
  description = "Subnet where to place systems"
  type = string
}

variable "natgw_id" {
  description = "NATGW we use for inbound traffic"
  type = string
}

variable "node_keypair" {
  type = string
  description = "Key pair to use"
}

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

variable "dns_zone" {
  description = "DNS zone to use"
  type = string
}

variable "region" {
  description = "Region hosting us"
  type = string
}

#
# Generics
#
variable "tags" {
  description = "Common tags for environment"
  type = map(string)
  default = {
    environment = "development"
    managed_by = "OpenTofu"
    CASIO = "Use2"
  }
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
