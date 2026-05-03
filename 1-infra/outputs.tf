#~ output "cluster_endpoint" {
  #~ description = "CCE cluster API endpoint"
  #~ value       = module.cce.cluster_endpoint
  #~ sensitive   = true
#~ }

output "vpc_id" {
  description = "VPC ID"
  value       = module.network.vpc_id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = module.network.subnet_id
}

output "bastion_int_ip" {
  value = module.bastion.bastion_int_ip
}

output "bastion_ext_ip" {
  value = module.bastion.bastion_ext_ip
}

output "bastion_int_dns" {
  value = module.bastion.bastion_int_dns
}

output "bastion_ext_dns" {
  value = module.bastion.bastion_ext_dns
}


output "vpngw_ip_1" {
  value = module.network.vpngw_ip_1
}
output "vpngw_dns_1" {
  value = module.network.vpngw_dns_1
}

output "vpngw_ip_2" {
  value = module.network.vpngw_ip_2
}
output "vpngw_dns_2" {
  value = module.network.vpngw_dns_2
}

output "elb_id" {
  description = "Ingress ELB ID — use in CCE Ingress annotations (kubernetes.io/elb.id)"
  value       = module.ingress.elb_id
}

output "elb_vip" {
  description = "Ingress ELB VIP address (VPC-internal, reachable from on-prem via VPN)"
  value       = module.ingress.elb_vip
}

output "dnstls_common_name" {
  description = "The primary domain name on the certificate."
  value = module.dnstls.common_name
}
output "dnstls_fqdns" {
  description = "List of all fqdns"
  value = module.dnstls.dns_names
}
output "dnstls_expiration" {
  description = "Expiration date of issued certificate"
  value = module.dnstls.certificate_expires
}

