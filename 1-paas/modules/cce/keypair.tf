resource "tls_private_key" "nodes" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "opentelekomcloud_compute_keypair_v2" "nodes" {
  name       = "keypair-mern2"
  public_key = tls_private_key.nodes.public_key_openssh
}

