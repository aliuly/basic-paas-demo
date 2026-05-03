# ---------------------------------------------------------------------------
# modules/dds — Outputs
# ---------------------------------------------------------------------------

output "instance_id" {
  description = "DDS instance ID"
  value       = opentelekomcloud_dds_instance_v3.this.id
}

output "instance_name" {
  description = "DDS instance full name"
  value       = opentelekomcloud_dds_instance_v3.this.name
}

output "status" {
  description = "DDS instance status"
  value       = opentelekomcloud_dds_instance_v3.this.status
}

output "db_username" {
  description = "Database administrator username (rwuser)"
  value       = opentelekomcloud_dds_instance_v3.this.db_username
}

output "port" {
  description = "Database access port (default 8635 — note: NOT 27017)"
  value       = opentelekomcloud_dds_instance_v3.this.port
}

output "mode" {
  description = "Instance mode: Single or ReplicaSet"
  value       = opentelekomcloud_dds_instance_v3.this.mode
}

output "nodes" {
  description = <<-EOT
    Node information list. Each node has:
      id, name, role, type, private_ip, status
    private_ip is populated for replica set nodes — use these to build
    the MongoDB connection string, e.g.:
      mongodb://rwuser:<password>@<ip1>:8635,<ip2>:8635,<ip3>:8635/mydb?replicaSet=<name>&ssl=true
  EOT
  value = opentelekomcloud_dds_instance_v3.this.nodes
}

output "connection_string" {
  description = <<-EOT
    Convenience connection string template for application use.
    ReplicaSet: lists all node private IPs on port 8635.
    Single:     single node private IP on port 8635.
    Replace <password> and <database> before use.
    Pods must use OTC VPC-internal DNS — do not override dnsConfig in pod specs.
  EOT
  sensitive = true
  value = var.high_availability ? join("", [
    "mongodb://",
    opentelekomcloud_dds_instance_v3.this.db_username,
    ":<password>@",
    join(",", [
      for node in opentelekomcloud_dds_instance_v3.this.nodes :
      "${node.private_ip}:${opentelekomcloud_dds_instance_v3.this.port}"
      if node.private_ip != "" && node.private_ip != null
    ]),
    "/<database>?ssl=true&authSource=admin"
  ]) : join("", [
    "mongodb://",
    opentelekomcloud_dds_instance_v3.this.db_username,
    ":<password>@",
    [for node in opentelekomcloud_dds_instance_v3.this.nodes : "${node.private_ip}:${opentelekomcloud_dds_instance_v3.this.port}" if node.private_ip != "" && node.private_ip != null][0],
    "/<database>?ssl=true&authSource=admin"
  ])
}

output "high_availability" {
  description = "Whether the instance was deployed as a replica set"
  value       = var.high_availability
}

output "db_version" {
  description = "MongoDB-compatible version deployed"
  value       = var.db_version
}

output "sg_id" {
  description = "DDS security group ID"
  value       = opentelekomcloud_networking_secgroup_v2.this.id
}

output "primary_ip" {
  description = "Private IP of the primary (or only) DDS node — use for single-target tooling and health checks"
  value       = [for n in opentelekomcloud_dds_instance_v3.this.nodes : n.private_ip if n.private_ip != "" && n.private_ip != null][0]
}
