locals {
  vm_name = "bastion-${var.environment}-1"
}


data "opentelekomcloud_images_image_v2" "std_image" {
  name = "Standard_Ubuntu_22.04_latest"
  #~ name = "Standard_Ubuntu_24.04_amd64_bios_latest"
  #~ name = "Standard_Debian_13_amd64_bios_latest"
  #~ name = "Standard_Debian_12_amd64_bios_latest"
  most_recent = true
}

# 1. Define the Security Group
resource "opentelekomcloud_networking_secgroup_v2" "sg_bastion" {
  name        = "sg-bastion-${var.environment}"
  description = "Security group for bastion host (SSH and HTTPS)"
}

# 2. Allow Inbound SSH (Port 22)
resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_ssh" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 22
  port_range_max    = 22
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.sg_bastion.id
}

# 3. Allow Inbound HTTPS (Port 443)
resource "opentelekomcloud_networking_secgroup_rule_v2" "allow_https" {
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = "tcp"
  port_range_min    = 443
  port_range_max    = 443
  remote_ip_prefix  = "0.0.0.0/0"
  security_group_id = opentelekomcloud_networking_secgroup_v2.sg_bastion.id
}

resource "opentelekomcloud_compute_instance_v2" "ecs_bastion1" {
  name            = local.vm_name
  flavor_name     = "s2.medium.1"
  key_pair        = var.node_keypair

  security_groups = [ opentelekomcloud_networking_secgroup_v2.sg_bastion.name ]
  network {
    uuid = var.subnet_id
  }

  # 1. System Disk (Bootable)
  block_device {
    uuid                  = data.opentelekomcloud_images_image_v2.std_image.id
    source_type           = "image"
    destination_type      = "volume"
    boot_index            = 0
    volume_size           = 32   # System Disk: 32 GB
    delete_on_termination = true
  }

  # Cloud-init configuration
  user_data = replace(templatefile("${path.module}/bastion.yaml", {
      more_users = var.local_users
      region = var.region
      dns_zone = var.dns_zone
    }), "\r", "")
  tags = var.tags
}

#~ resource "local_file" "bastion_user_data" {
  #~ filename = "${path.module}/user_data.tmp"

  #~ content = replace(templatefile("${path.module}/bastion.yaml", {
      #~ user = var.cloud_user.name
      #~ passwd = var.cloud_user.passwd
      #~ ssh_keys = var.cloud_user.ssh_keys
      #~ more_users = var.local_users
      #~ region = var.region
      #~ dns_zone = var.dns_zone
      #~ device_path = local.dev_path
    #~ }), "\r", "")

  #~ file_permission = "0644"
#~ }



# Create EIP for Bastion host
resource "opentelekomcloud_vpc_eip_v1" "eip_bastion1" {
  publicip {
    type = "5_bgp"
    name = "eip-${local.vm_name}"
  }
  bandwidth {
    name = "bw-${local.vm_name}"
    size = 10
    share_type = "PER"
  }
  tags = var.tags
}

# Add DNAT mappings
resource "opentelekomcloud_nat_dnat_rule_v2" "natfw_bastion1_22" {
  nat_gateway_id        = var.natgw_id
  floating_ip_id        = opentelekomcloud_vpc_eip_v1.eip_bastion1.id
  protocol              = "tcp"
  internal_service_port = 22
  external_service_port = 22
  port_id               = opentelekomcloud_compute_instance_v2.ecs_bastion1.network[0].port
}

resource "opentelekomcloud_nat_dnat_rule_v2" "natfw_bastion1_443" {
  nat_gateway_id        = var.natgw_id
  floating_ip_id        = opentelekomcloud_vpc_eip_v1.eip_bastion1.id
  protocol              = "tcp"
  internal_service_port = 443
  external_service_port = 443
  port_id               = opentelekomcloud_compute_instance_v2.ecs_bastion1.network[0].port
}

# Public DNS records
data "opentelekomcloud_dns_zone_v2" "extdns" {
  name = "${var.dns_zone}."
}
resource "opentelekomcloud_dns_recordset_v2" "dnsext_a_bastion1" {
  zone_id     = data.opentelekomcloud_dns_zone_v2.extdns.id
  name        = "www-${local.vm_name}.${var.dns_zone}."
  type        = "A"
  records     = [ opentelekomcloud_vpc_eip_v1.eip_bastion1.publicip[0].ip_address ]
  tags = var.tags
}

# Private DNS records
resource "opentelekomcloud_dns_recordset_v2" "dnsint_a_bastion1" {
  zone_id     = data.opentelekomcloud_dns_zone_v2.extdns.id
  name        = "${local.vm_name}.${var.dns_zone}."
  type        = "A"
  records     = [ opentelekomcloud_compute_instance_v2.ecs_bastion1.access_ip_v4 ]
  tags = var.tags
}
