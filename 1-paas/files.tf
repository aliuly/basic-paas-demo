#
# Generate files
#
# * kubeconfig
locals {
  kubeconfig_content = templatefile("${path.module}/templates/kubeconfig.tpl", {
    name = module.cce.cluster_name
    endpoint = module.cce.kubeconfig_endpoint
    ca     = module.cce.kubeconfig_ca
    cert = module.cce.kubeconfig_cert
    key = module.cce.kubeconfig_key
  })
}
resource "local_file" "kubeconfig" {
  filename = "${path.module}/exports/kubeconfig"
  file_permission = "0600"
  content = local.kubeconfig_content
}

# * ssh private key
resource "local_sensitive_file" "private_key" {
  content         = module.cce.keypair_privatekey
  filename        = "${path.module}/exports/keypair.pem"
  file_permission = "0600"
}

# * admin access
resource "local_file" "admin_env" {
  filename        = "${path.module}/exports/kube.env"
  file_permission = "0600"
  content = <<-EOT
    EXT_BASTION_HOST="${module.bastion.bastion_ext_dns}"
    BASTION_HOST="${module.bastion.bastion_int_dns}"
  EOT
}

