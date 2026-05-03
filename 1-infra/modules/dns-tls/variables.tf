variable "common_tags" {
  description = "Common tags for environment"
  type = map(string)
  default = {
    environment = "development"
    managed_by = "OpenTofu"
    CASIO = "Use2"
  }
}

variable "elb_dns_name" {
  description = "CNAME target"
  type = string
}

variable "domains" {
  description = "domains to configure"
  type = list(string)
}

variable "le_email" {
  description = "E-Mail address to send to Let's Encrypt"
  type = string
}

variable "acme_otc_creds" {
  description = "Used to configure the OTC ACME provider"
  type = object({
    OTC_USER_NAME    = string
    OTC_PASSWORD     = string
    OTC_DOMAIN_NAME  = string
    OTC_PROJECT_NAME = string
  })
}

variable "dns_zone" {
  description = "DNS zone to populate DNS records"
  type = string
}
