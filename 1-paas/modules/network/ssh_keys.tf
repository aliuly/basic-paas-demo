
resource "opentelekomcloud_compute_keypair_v2" "sshkey" {
  name       = var.node_keypair
  public_key = var.my_ssh_key
}

