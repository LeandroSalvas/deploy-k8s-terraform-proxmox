# =============================================================================
# Kubernetes on Proxmox VE - Root Module
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.68.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.pmox_api_url
  username = var.pmox_user
  password = var.pmox_password
  insecure = true

  ssh {
    agent    = false
    username = "root"
    password = var.pmox_password
  }
}

module "k8s_cluster" {
  source = "./modules/k8s-cluster"

  providers = {
    proxmox = proxmox
  }

  # Connection
  node_config = {
    target_node          = try(values(var.k8s_masters)[0].target_node, "pve")
    template_name        = var.template_name
    storage              = "local-lvm"
    cpu_type             = "host"
    bridge               = "vmbr0"
    ssh_user             = "ubuntu"
    ssh_private_key_path = var.ssh_private_key_path
  }

  # Cluster
  k8s_version         = var.k8s_version
  control_plane_nodes = var.k8s_masters
  worker_nodes        = var.k8s_workers

  # Network
  vip_address  = var.vip_address
  pod_cidr     = var.pod_cidr
  service_cidr = var.service_cidr

  # SSH
  ssh_public_key = var.ssh_public_key

  # Proxmox password for cloud-init API calls
  pmox_password = var.pmox_password

  # MetalLB
  metallb_ip_pool = var.metallb_ip_pool
}
