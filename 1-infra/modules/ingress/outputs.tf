output "elb_id" {
  description = "Dedicated ELB ID — use in CCE Ingress annotations (kubernetes.io/elb.id)"
  value       = opentelekomcloud_lb_loadbalancer_v3.this.id
}

output "elb_vip" {
  description = "ELB VIP address (VPC-internal, reachable from on-prem via VPN)"
  value       = opentelekomcloud_lb_loadbalancer_v3.this.vip_address
}

output "security_group_id" {
  description = "ELB security group ID — add inbound rules per service"
  value       = opentelekomcloud_networking_secgroup_v2.elb.id
}
