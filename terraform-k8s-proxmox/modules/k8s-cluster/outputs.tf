# =============================================================================
# Module: k8s-cluster - Outputs
# =============================================================================

output "control_plane_ips" {
  description = "IP addresses of control plane nodes"
  value       = { for k, v in var.control_plane_nodes : k => v.ip }
}

output "worker_ips" {
  description = "IP addresses of worker nodes"
  value       = { for k, v in var.worker_nodes : k => v.ip }
}

output "first_master_ip" {
  description = "IP of the first control plane node (init master)"
  value       = local.first_master_ip
}

output "vip_address" {
  description = "Virtual IP for kube-apiserver"
  value       = var.vip_address
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = "https://${var.vip_address}:6443"
}

output "node_names" {
  description = "Names of all nodes"
  value = {
    control_planes = [for k, v in var.control_plane_nodes : v.name]
    workers        = [for k, v in var.worker_nodes : v.name]
  }
}
