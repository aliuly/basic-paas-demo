#
# Configure DNS names so we can reach the ingress controller
#
data "opentelekomcloud_dns_zone_v2" "intdns" {
  name = "${var.dns_zone}."
}

locals {
  # Map the list of short names (api, shop) to full hostnames (api.example.com)
  full_hostnames = [for d in var.domains : "${d}.${var.dns_zone}"]
}

resource "opentelekomcloud_dns_recordset_v2" "cnames" {
  for_each = toset(var.domains)

  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "${each.value}.${var.dns_zone}."
  type    = "CNAME"
  records = [ var.elb_dns_name ]
  tags    = var.common_tags
}

# 2. Create a Private Key for your Let's Encrypt Account
resource "tls_private_key" "reg_private_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256" # P256 is the standard "sweet spot" for performance and security
}

# 3. Register your Account with Let's Encrypt
resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.reg_private_key.private_key_pem
  email_address   = var.le_email
}

# 4. Request the Certificate using DNS Challenge (OTC DNS)
resource "acme_certificate" "this" {
  account_key_pem           = acme_registration.reg.account_key_pem
  common_name               = "${local.full_hostnames[0]}"
  subject_alternative_names = length(local.full_hostnames) > 1 ? slice(local.full_hostnames, 1, length(local.full_hostnames)) : null

  dns_challenge {
    provider = "otc" # Uses OTC DNS to verify ownership
    config = var.acme_otc_creds
  }
}

# 5. Upload the Certificate to OTC ELB
resource "opentelekomcloud_lb_certificate_v3" "elb_cert" {
  name        = "letsencrypt-cert"
  description = "Managed by OpenTofu - Let's Encrypt"
  type        = "server"

  # ACME provides the cert and the chain separately or concatenated.
  # For OTC, we send the cert + the issuer (chain) in the 'content' field.
  certificate     = "${acme_certificate.this.certificate_pem}${acme_certificate.this.issuer_pem}"
  private_key = acme_certificate.this.private_key_pem
}
