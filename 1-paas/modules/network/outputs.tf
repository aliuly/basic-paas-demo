output "vpc_id" {
  description = "VPC ID"
  value       = opentelekomcloud_vpc_v1.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = var.vpc_cidr
}

output "subnet_id" {
  description = "Subnet ID"
  value       = opentelekomcloud_vpc_subnet_v1.this.id
}

output "neutron_subnet_id" {
  description = "Neutron subnet ID — required by ELB v2 and some CCE internals"
  value       = opentelekomcloud_vpc_subnet_v1.this.subnet_id
}

output "subnet_cidr" {
  description = "Subnet CIDR block"
  value       = var.subnet_cidr
}

output "elb_sg_id" {
  description = "ELB security group ID — rules added by the environment after WAF IPs are known"
  value       = opentelekomcloud_networking_secgroup_v2.elb.id
}


output "natgw_id" {
  value = opentelekomcloud_nat_gateway_v2.natgw.id
}

output "vpngw_ip_1_id" {
  value = opentelekomcloud_vpc_eip_v1.eip_vpngw_1.id
}
output "vpngw_ip_2_id" {
  value = opentelekomcloud_vpc_eip_v1.eip_vpngw_2.id
}
output "vpngw_ip_1" {
  value = opentelekomcloud_vpc_eip_v1.eip_vpngw_1.publicip[0].ip_address
}
output "vpngw_ip_2" {
  value = opentelekomcloud_vpc_eip_v1.eip_vpngw_2.publicip[0].ip_address
}

output "vpngw_dns_1" {
  value = opentelekomcloud_dns_recordset_v2.dns_a_vpngw_1.name
}
output "vpngw_dns_2" {
  value = opentelekomcloud_dns_recordset_v2.dns_a_vpngw_2.name
}

output "network_id" {
  description = "Neutron network ID (opentelekomcloud_vpc_subnet_v1.network_id) — required by opentelekomcloud_cce_cluster_v3.subnet_id"
  value       = opentelekomcloud_vpc_subnet_v1.this.network_id
}

output "cce_vpc_id" {
  description = "VPC ID as seen by the CCE/networking API (opentelekomcloud_vpc_subnet_v1.vpc_id) — use this for opentelekomcloud_cce_cluster_v3.vpc_id"
  value       = opentelekomcloud_vpc_subnet_v1.this.vpc_id
}
