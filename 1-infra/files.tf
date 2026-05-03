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

# * TLS certificate and key for Kubernetes secret creation
resource "local_sensitive_file" "tls_cert" {
  content         = module.dnstls.certificate_pem
  filename        = "${path.module}/exports/tls.crt"
  file_permission = "0600"
}

resource "local_sensitive_file" "tls_key" {
  content         = module.dnstls.private_key_pem
  filename        = "${path.module}/exports/tls.key"
  file_permission = "0600"
}

# * ssh private key
resource "local_sensitive_file" "private_key" {
  content         = module.cce.keypair_privatekey
  filename        = "${path.module}/exports/keypair.pem"
  file_permission = "0600"
}

# * admin access
resource "local_sensitive_file" "admin_env" {
  filename        = "${path.module}/exports/kube.env"
  file_permission = "0600"
  content = <<-EOT
    EXT_BASTION_HOST="${module.bastion.bastion_ext_dns}"
    BASTION_HOST="${module.bastion.bastion_int_dns}"
    # internal ELB — used by 2-shared to wire Kubernetes Ingress resources
    ELB_ID="${module.ingress.elb_id}"
    ELB_VIP="${module.ingress.elb_vip}"
    GRAFANA_HOST="${local.domains.grafana}.${var.dns_zone}"
    HELLO_HOST="${local.domains.hello}.${var.dns_zone}"
    ASM_HOST="${local.domains.asm_console}.${var.dns_zone}"
    DEMO_HOST="${local.domains.demo}.${var.dns_zone}"
    # OTC ELB certificate ID
    CERT_ID="${module.dnstls.cert_id}"
    CERT_NAME="${module.dnstls.cert_name}"
    # DDS (MongoDB-compatible) — port 8635, SSL always on
    DDS_HOST="${module.dds.primary_ip}"
    DDS_PORT="${module.dds.port}"
    DDS_PASSWORD="${var.dds_password}"

  EOT
}

