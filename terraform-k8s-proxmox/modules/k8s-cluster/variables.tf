# =============================================================================
# Module: k8s-cluster - Variables
# =============================================================================

variable "node_config" {
  description = "Base VM configuration for all nodes"
  type = object({
    target_node          = string
    template_name        = string
    storage              = string
    cpu_type             = string
    bridge               = string
    ssh_user             = string
    ssh_private_key_path = string
  })
}

variable "pmox_password" {
  description = "Proxmox password for API calls"
  type        = string
  sensitive   = true
}

variable "k8s_version" {
  description = "Kubernetes version"
  type        = string
}

variable "control_plane_nodes" {
  description = "Map of control plane node configurations"
  type = map(object({
    target_node = string
    vcpu        = number
    memory      = number
    disk_size   = number
    name        = string
    notes       = string
    ip          = string
    gw          = string
  }))
}

variable "worker_nodes" {
  description = "Map of worker node configurations"
  type = map(object({
    target_node = string
    vcpu        = number
    memory      = number
    disk_size   = number
    name        = string
    notes       = string
    ip          = string
    gw          = string
  }))
}

variable "ssh_public_key" {
  description = "SSH public key for cloud-init"
  type        = string
}

variable "vip_address" {
  description = "Virtual IP for kube-apiserver"
  type        = string
}

variable "pod_cidr" {
  description = "CIDR block for pod networking"
  type        = string
}

variable "service_cidr" {
  description = "CIDR block for service networking"
  type        = string
}

variable "metallb_ip_pool" {
  description = "IP range for MetalLB"
  type        = string
}
