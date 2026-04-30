data "opentelekomcloud_dns_zone_v2" "intdns" {
  name = "${var.dns_zone}."
}

resource "opentelekomcloud_dns_recordset_v2" "grafana_cname" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "mern-grafana.${var.dns_zone}."
  type    = "CNAME"
  records = ["${module.cce.elb_dns_name}."]
  tags    = local.tags
}

resource "opentelekomcloud_dns_recordset_v2" "mern_demo2_cname" {
  zone_id = data.opentelekomcloud_dns_zone_v2.intdns.id
  name    = "mern-demo2.${var.dns_zone}."
  type    = "CNAME"
  records = ["${module.cce.elb_dns_name}."]
  tags    = local.tags
}
