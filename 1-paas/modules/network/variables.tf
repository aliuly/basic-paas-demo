variable "region" {
  description = "OTC region"
  type        = string
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_gateway_ip" {
  description = "Subnet gateway IP"
  type        = string
  default     = "10.0.1.1"
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "node_keypair" {
  description = "SSH key pair name"
  type        = string
}

variable "environment" {
  description = "Assign this name to the VPN gateway"
  type        = string
}

variable "vpn_name" {
  description = "Name to allow other VPCs to find our VPNs"
  type = string
}

variable "dns_zone" {
  description = "DNS zone to populate DNS records"
  type = string
}

variable "my_ssh_key" {
  description = "SSH public key text"
  type = string
  sensitive = true
}
