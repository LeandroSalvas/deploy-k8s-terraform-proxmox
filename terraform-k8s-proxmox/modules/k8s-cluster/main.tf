# =============================================================================
# Module: k8s-cluster - Main Resources (bpg/proxmox provider)
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.68.0"
    }
  }
}

locals {
  first_master_key  = keys(var.control_plane_nodes)[0]
  first_master_ip   = var.control_plane_nodes[local.first_master_key].ip
  first_master_name = var.control_plane_nodes[local.first_master_key].name
}

# =============================================================================
# Control Plane Nodes
# =============================================================================

resource "proxmox_virtual_environment_vm" "k8s_master" {
  for_each = var.control_plane_nodes

  name      = each.value.name
  node_name = each.value.target_node

  # Create but don't start - we configure cloud-init first
  started = false

  clone {
    vm_id     = 9000
    node_name = each.value.target_node
    full      = true
  }

  scsi_hardware = "virtio-scsi-pci"

  cpu {
    cores = each.value.vcpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  description = each.value.notes

  # NO initialization block - cloud-init ISO changes root UUID and breaks boot

  connection {
    host        = each.value.ip
    type        = "ssh"
    private_key = file(var.node_config.ssh_private_key_path)
    user        = var.node_config.ssh_user
    port        = 22
    agent       = false
    timeout     = "10m"
  }

  # Step 1: Configure cloud-init via Proxmox API (IP, SSH keys, user) and start VM
  provisioner "local-exec" {
    command = <<-EOT
      bash ${path.module}/../../scripts/configure-cloudinit.sh \
        "${self.vm_id}" \
        "${each.value.ip}" \
        "${each.value.gw}" \
        "${var.ssh_public_key}" \
        "${var.node_config.ssh_user}" \
        "${each.value.target_node}"
    EOT
    environment = {
      PROXMOX_PASS = var.pmox_password
    }
  }

  # Step 2: Wait for cloud-init to finish
  provisioner "local-exec" {
    command = "echo 'Waiting 90s for cloud-init to finish...' && sleep 90"
  }

  # Step 3: Upload and run common bootstrap
  provisioner "file" {
    content = templatefile("${path.module}/../../templates/scripts/common.sh", {
      k8s_version = var.k8s_version
    })
    destination = "/tmp/common.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/common.sh"]
  }

  # Step 4: Upload init/join script and run with sudo
  provisioner "file" {
    content = each.key == local.first_master_key ? templatefile("${path.module}/../../templates/scripts/master-init.sh", {
      k8s_version      = var.k8s_version
      vip_address      = var.vip_address
      pod_cidr         = var.pod_cidr
      service_cidr     = var.service_cidr
      master_ip        = each.value.ip
      metallb_ip_pool  = var.metallb_ip_pool
    }) : templatefile("${path.module}/../../templates/scripts/master-join.sh", {
      vip_address = var.vip_address
    })
    destination = "/tmp/k8s-init.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/k8s-init.sh"]
  }
}

# =============================================================================
# Worker Nodes
# =============================================================================

resource "proxmox_virtual_environment_vm" "k8s_worker" {
  for_each = var.worker_nodes

  name      = each.value.name
  node_name = each.value.target_node

  started = false

  clone {
    vm_id     = 9000
    node_name = each.value.target_node
    full      = true
  }

  scsi_hardware = "virtio-scsi-pci"

  cpu {
    cores = each.value.vcpu
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  description = each.value.notes

  depends_on = [proxmox_virtual_environment_vm.k8s_master]

  connection {
    host        = each.value.ip
    type        = "ssh"
    private_key = file(var.node_config.ssh_private_key_path)
    user        = var.node_config.ssh_user
    port        = 22
    agent       = false
    timeout     = "10m"
  }

  provisioner "local-exec" {
    command = <<-EOT
      bash ${path.module}/../../scripts/configure-cloudinit.sh \
        "${self.vm_id}" \
        "${each.value.ip}" \
        "${each.value.gw}" \
        "${var.ssh_public_key}" \
        "${var.node_config.ssh_user}" \
        "${each.value.target_node}"
    EOT
    environment = {
      PROXMOX_PASS = var.pmox_password
    }
  }

  provisioner "local-exec" {
    command = "echo 'Waiting 90s for cloud-init to finish...' && sleep 90"
  }

  provisioner "file" {
    content = templatefile("${path.module}/../../templates/scripts/common.sh", {
      k8s_version = var.k8s_version
    })
    destination = "/tmp/common.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/common.sh"]
  }

  # Fetch join command from first master to local, then upload to worker
  provisioner "local-exec" {
    command = "scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no root@${local.first_master_ip}:/tmp/worker-join-command.txt /tmp/worker-join-command-${each.key}.txt 2>/dev/null || scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no ubuntu@${local.first_master_ip}:/tmp/worker-join-command.txt /tmp/worker-join-command-${each.key}.txt"
  }

  provisioner "file" {
    source      = "/tmp/worker-join-command-${each.key}.txt"
    destination = "/tmp/worker-join-command.txt"
  }

  provisioner "file" {
    content = templatefile("${path.module}/../../templates/scripts/worker-join.sh", {})
    destination = "/tmp/k8s-join.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/k8s-join.sh"]
  }
}
