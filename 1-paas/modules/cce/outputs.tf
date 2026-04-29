# ---------------------------------------------------------------------------
# modules/cce — Outputs
# ---------------------------------------------------------------------------

output "cluster_id" {
  description = "CCE cluster ID"
  value       = opentelekomcloud_cce_cluster_v3.this.id
}

output "cluster_name" {
  description = "CCE cluster full name"
  value       = opentelekomcloud_cce_cluster_v3.this.name
}

# The cluster resource exposes certificate_clusters / certificate_users blocks
# (documented as "all arguments can be exported as attribute parameters").
# Index 0 is the internal endpoint entry.

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint (private — access via bastion kubectl proxy)"
  value       = opentelekomcloud_cce_cluster_v3.this.certificate_clusters[0].server
}

output "cluster_ca" {
  description = "Base64-encoded cluster CA certificate"
  value       = opentelekomcloud_cce_cluster_v3.this.certificate_clusters[0].certificate_authority_data
  sensitive   = true
}

output "cluster_token" {
  description = "Base64-encoded client certificate for kubectl / provider auth"
  value       = opentelekomcloud_cce_cluster_v3.this.certificate_users[0].client_certificate_data
  sensitive   = true
}

output "cluster_key" {
  description = "Base64-encoded client key for kubectl / provider auth"
  value       = opentelekomcloud_cce_cluster_v3.this.certificate_users[0].client_key_data
  sensitive   = true
}

output "elb_vip" {
  description = "Private VIP address of the ingress ELB"
  value       = opentelekomcloud_lb_loadbalancer_v2.ingress.vip_address
}

output "elb_id" {
  description = "ELB ID — pass to Kubernetes Ingress annotations"
  value       = opentelekomcloud_lb_loadbalancer_v2.ingress.id
}

output "elb_pool_id" {
  description = "ELB backend pool ID"
  value       = opentelekomcloud_lb_pool_v2.backend.id
}

output "elb_listener_id" {
  description = "ELB HTTPS listener ID"
  value       = opentelekomcloud_lb_listener_v2.https.id
}

output "elb_sg_id" {
  description = "Security group attached to the ELB VIP port"
  value       = opentelekomcloud_networking_secgroup_v2.elb.id
}

output "node_sg_id" {
  description = "Security group attached to worker nodes"
  value       = opentelekomcloud_networking_secgroup_v2.cce_node.id
}

output "elb_dns_name" {
  description = "Internal DNS name resolving to the ELB VIP"
  value       = "${var.cluster_name}.${var.dns_zone}"
}

output "api_dns_name" {
  description = "Internal DNS name resolving to the CCE API server"
  value       = "api-${local.cluster_full_name}.${var.dns_zone}"
}

output "api_ip" {
  description = "CCE API server private IP address"
  value       = local.api_ip
}

output "node_pool_id" {
  description = "CCE worker node pool ID"
  value       = opentelekomcloud_cce_node_pool_v3.workers.id
}

output "high_availability" {
  description = "Whether the cluster was deployed in HA mode"
  value       = var.high_availability
}

output "worker_node_ids" {
  description = "Individual worker node IDs — populated after first apply once nodes are Ready. Used as installation_nodes for ASM."
  value       = data.opentelekomcloud_cce_node_ids_v3.workers.ids
}
