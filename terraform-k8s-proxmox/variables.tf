# =============================================================================
# Kubernetes on Proxmox VE - Root Variables
# =============================================================================

# --- Proxmox Connection ---
variable "pmox_api_url" {
  description = "Proxmox VE API URL"
  type        = string

  validation {
    condition     = can(regex("^https?://.*:8006/api2/json$", var.pmox_api_url))
    error_message = "Proxmox API URL must end with :8006/api2/json"
  }
}

variable "pmox_user" {
  description = "Proxmox VE authentication user"
  type        = string
  default     = "terraform-prov@pve"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+@(pam|pve)$", var.pmox_user))
    error_message = "Proxmox user must be in format user@pam or user@pve"
  }
}

variable "pmox_password" {
  description = "Proxmox VE password (set via TF_VAR_pmox_password)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.pmox_password) > 0
    error_message = "Proxmox password cannot be empty."
  }
}

# --- SSH ---
variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|dss) AAAA", var.ssh_public_key))
    error_message = "Must be a valid SSH public key."
  }
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

# --- VM Template ---
variable "template_name" {
  description = "Name of the Proxmox VM template to clone"
  type        = string
  default     = "ubuntu2404-template"
}

# --- Kubernetes ---
variable "k8s_version" {
  description = "Kubernetes version to install"
  type        = string
  default     = "v1.31"

  validation {
    condition     = can(regex("^v1\\.(2[0-9]|3[0-2])$", var.k8s_version))
    error_message = "Kubernetes version must be v1.2x or v1.3x."
  }
}

# --- Network ---
variable "vip_address" {
  description = "Virtual IP for kube-apiserver"
  type        = string

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.vip_address))
    error_message = "Must be a valid IPv4 address."
  }
}

variable "pod_cidr" {
  description = "CIDR for pod networking"
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "CIDR for service networking"
  type        = string
  default     = "10.96.0.0/12"
}

# --- Cluster Nodes ---
variable "k8s_masters" {
  description = "Control plane nodes"
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

  validation {
    condition     = length(var.k8s_masters) >= 1
    error_message = "At least 1 control plane is required."
  }
}

variable "k8s_workers" {
  description = "Worker nodes"
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

  validation {
    condition     = length(var.k8s_workers) >= 1
    error_message = "At least 1 worker is required."
  }
}

# --- MetalLB ---
variable "metallb_ip_pool" {
  description = "IP range for MetalLB"
  type        = string
}
