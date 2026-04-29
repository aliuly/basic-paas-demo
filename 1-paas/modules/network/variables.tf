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

variable "bastion_subnet_name" {
  description = "Bastion subnet name"
  type        = string
}

variable "bastion_subnet_cidr" {
  description = "Bastion subnet CIDR block"
  type        = string
  default     = "10.0.2.0/24"
}

variable "bastion_subnet_gateway_ip" {
  description = "Bastion subnet gateway IP"
  type        = string
  default     = "10.0.2.1"
}

variable "vpn_subnet_name" {
  description = "VPN gateway subnet name"
  type        = string
}

variable "vpn_subnet_cidr" {
  description = "VPN gateway subnet CIDR block"
  type        = string
  default     = "10.0.3.0/24"
}

variable "vpn_subnet_gateway_ip" {
  description = "VPN gateway subnet gateway IP"
  type        = string
  default     = "10.0.3.1"
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

variable "datastore_subnet_name" {
  description = "Datastore subnet name"
  type        = string
}

variable "datastore_subnet_cidr" {
  description = "Datastore subnet CIDR block"
  type        = string
  default     = "10.0.4.0/24"
}

variable "datastore_subnet_gateway_ip" {
  description = "Datastore subnet gateway IP"
  type        = string
  default     = "10.0.4.1"
}
