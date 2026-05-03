#~ output "cluster_api_public" {
  #~ description = "Public CCE API endpoint — use this as the server in kubeconfig"
  #~ value       = "https://${opentelekomcloud_vpc_eip_v1.cce_api.publicip[0].ip_address}:5443"
#~ }

#~ output "kubeconfig_path" {
  #~ description = "Path to the generated kubeconfig file"
  #~ value       = local_file.kubeconfig.filename
#~ }

# API point of cluster
#    server = "https://${opentelekomcloud_vpc_eip_v1.cce_api.publicip[0].ip_address}:5443"

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

output "kubeconfig_endpoint" {
  description = "Kubernetes API server endpoint (private — access via bastion kubectl proxy)"
  value       = opentelekomcloud_cce_cluster_v3.this.certificate_clusters[0].server
}


output "kubeconfig_ca" {
  description = "Used in kubeconfig"
  value = opentelekomcloud_cce_cluster_v3.this.certificate_clusters[0].certificate_authority_data
}
output "kubeconfig_cert" {
  description = "Used in kubeconfig"
  value = opentelekomcloud_cce_cluster_v3.this.certificate_users[0].client_certificate_data

}
output "kubeconfig_key" {
  description = "Used in kubeconfig"
  value = opentelekomcloud_cce_cluster_v3.this.certificate_users[0].client_key_data
}

output "keypair_privatekey" {
  description = "SSH private key used to connect to worker nodes"
  value =  tls_private_key.nodes.private_key_openssh
  sensitive = true
}

output "node_sg_id" {
  description = "Security group ID auto-created by CCE for worker nodes"
  value       = opentelekomcloud_cce_cluster_v3.this.security_group_node
}

