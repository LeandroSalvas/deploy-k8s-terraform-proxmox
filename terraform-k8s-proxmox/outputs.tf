# =============================================================================
# Kubernetes on Proxmox VE - Root Outputs
# =============================================================================

output "cluster_info" {
  description = "Cluster connection information"
  value = {
    api_endpoint = module.k8s_cluster.cluster_endpoint
    vip          = module.k8s_cluster.vip_address
    masters      = module.k8s_cluster.control_plane_ips
    workers      = module.k8s_cluster.worker_ips
  }
}

output "kubeconfig_command" {
  description = "Command to retrieve kubeconfig from first master"
  value       = "scp root@${module.k8s_cluster.first_master_ip}:/etc/kubernetes/admin.conf ~/.kube/config"
}
