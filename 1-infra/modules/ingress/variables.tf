variable "region" {
  description = "OTC region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (router_id for the ELB)"
  type        = string
}

variable "ingress_network_id" {
  description = "Neutron network ID of the ingress subnet (opentelekomcloud_vpc_subnet_v1.network_id)"
  type        = string
}

variable "ingress_neutron_subnet_id" {
  description = "Neutron subnet ID of the ingress subnet (opentelekomcloud_vpc_subnet_v1.subnet_id) — sets the ELB VIP subnet"
  type        = string
}

variable "high_availability" {
  description = "false → single AZ (eu-de-01); true → two AZs (eu-de-01, eu-de-02)"
  type        = bool
  default     = false
}

variable "l7_flavor" {
  description = "Dedicated ELB L7 flavor ID (default: L7_flavor.elb.s1.small in eu-de)"
  type        = string
  default     = "4e3f64bb-96d5-4713-9d1c-48752b93012f"
}

variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "elb_dns_name" {
  description = "Name to register the ELB on DNS"
  type = string
}

variable "dns_zone" {
  description = "Zone where we create the DNS records"
  type        = string
}
