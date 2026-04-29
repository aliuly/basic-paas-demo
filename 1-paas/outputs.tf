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

output "bastion_dns_name" {
  value = module.bastion.bastion_dns_name
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



# ---------------------------------------------------------------------------
# CCE
# ---------------------------------------------------------------------------

output "cce_cluster_id" {
  description = "CCE cluster ID"
  value       = module.cce.cluster_id
}

output "cce_cluster_endpoint" {
  description = "Kubernetes API endpoint (private — access via bastion kubectl proxy)"
  value       = module.cce.cluster_endpoint
  sensitive   = true
}

output "cce_elb_vip" {
  description = "Private VIP of the ingress ELB (HTTPS)"
  value       = module.cce.elb_vip
}

output "cce_elb_dns" {
  description = "Internal DNS name resolving to the ELB VIP"
  value       = module.cce.elb_dns_name
}

output "cce_high_availability" {
  description = "Whether the cluster was deployed in HA mode"
  value       = module.cce.high_availability
}

# ---------------------------------------------------------------------------
# DDS
# ---------------------------------------------------------------------------

output "dds_instance_id" {
  description = "DDS instance ID"
  value       = module.dds.instance_id
}

output "dds_status" {
  description = "DDS instance status"
  value       = module.dds.status
}

output "dds_connection_string" {
  description = "MongoDB connection string (sensitive — contains placeholder for password)"
  value       = module.dds.connection_string
  sensitive   = true
}

output "dds_port" {
  description = "DDS port (8635)"
  value       = module.dds.port
}

output "dds_high_availability" {
  description = "Whether DDS is deployed as a replica set"
  value       = module.dds.high_availability
}

# ---------------------------------------------------------------------------
# CCE worker node IDs — needed for ASM installation_nodes
# ---------------------------------------------------------------------------

output "cce_worker_node_ids" {
  description = "Worker node IDs — populated after first apply. Used for ASM installation_nodes."
  value       = module.cce.worker_node_ids
}
