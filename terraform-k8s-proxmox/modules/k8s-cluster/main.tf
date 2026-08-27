# =============================================================================
# Module: k8s-cluster - Main Resources (bpg/proxmox provider)
# =============================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.68.0"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.2.0"
    }
  }
}

locals {
  first_master_key  = keys(var.control_plane_nodes)[0]
  first_master_ip   = var.control_plane_nodes[local.first_master_key].ip
  first_master_name = var.control_plane_nodes[local.first_master_key].name

  # Map of additional control plane nodes (excludes the first)
  additional_masters = {
    for k, v in var.control_plane_nodes : k => v
    if k != local.first_master_key
  }
}

# =============================================================================
# First Control Plane Node (kubeadm init)
# =============================================================================

resource "proxmox_virtual_environment_vm" "k8s_master_first" {
  name      = var.control_plane_nodes[local.first_master_key].name
  node_name = var.control_plane_nodes[local.first_master_key].target_node

  started = true

  clone {
    vm_id     = 9000
    node_name = var.control_plane_nodes[local.first_master_key].target_node
    full      = true
  }

  scsi_hardware = "virtio-scsi-pci"

  cpu {
    cores = var.control_plane_nodes[local.first_master_key].vcpu
    type  = "host"
  }

  memory {
    dedicated = var.control_plane_nodes[local.first_master_key].memory
    floating  = var.control_plane_nodes[local.first_master_key].memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  description = var.control_plane_nodes[local.first_master_key].notes

  connection {
    host        = var.control_plane_nodes[local.first_master_key].ip
    type        = "ssh"
    private_key = file(var.node_config.ssh_private_key_path)
    user        = var.node_config.ssh_user
    port        = 22
    agent       = false
    timeout     = "10m"
  }

  # Step 1: Configure cloud-init via Proxmox API and start VM
  provisioner "local-exec" {
    command = <<-EOT
      bash ${path.module}/../../scripts/configure-cloudinit.sh \
        "${self.vm_id}" \
        "${var.control_plane_nodes[local.first_master_key].ip}" \
        "${var.control_plane_nodes[local.first_master_key].gw}" \
        "${var.ssh_public_key}" \
        "${var.node_config.ssh_user}" \
        "${var.control_plane_nodes[local.first_master_key].target_node}"
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

  # Step 4: Upload master-init.sh and run kubeadm init
  provisioner "file" {
    content = templatefile("${path.module}/../../templates/scripts/master-init.sh", {
      k8s_version     = var.k8s_version
      vip_address     = var.vip_address
      pod_cidr        = var.pod_cidr
      service_cidr    = var.service_cidr
      master_ip       = var.control_plane_nodes[local.first_master_key].ip
      metallb_ip_pool = var.metallb_ip_pool
    })
    destination = "/tmp/k8s-init.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/k8s-init.sh"]
  }
}

# =============================================================================
# Additional Control Plane Nodes (kubeadm join)
# Runs sequentially AFTER the first master is fully initialized
# =============================================================================

resource "proxmox_virtual_environment_vm" "k8s_master_additional" {
  for_each = local.additional_masters

  name      = each.value.name
  node_name = each.value.target_node

  depends_on = [proxmox_virtual_environment_vm.k8s_master_first]

  started = true

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
    floating  = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  description = each.value.notes

  connection {
    host        = each.value.ip
    type        = "ssh"
    private_key = file(var.node_config.ssh_private_key_path)
    user        = var.node_config.ssh_user
    port        = 22
    agent       = false
    timeout     = "10m"
  }

  # Step 1: Configure cloud-init via Proxmox API and start VM
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

  # Step 4: Fetch control-plane join command from first master
  provisioner "local-exec" {
    command = "scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${local.first_master_ip}:/tmp/control-plane-join-command.txt /tmp/control-plane-join-command-${each.key}.txt 2>/dev/null || scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${local.first_master_ip}:/tmp/control-plane-join-command.txt /tmp/control-plane-join-command-${each.key}.txt"
  }

  provisioner "file" {
    source      = "/tmp/control-plane-join-command-${each.key}.txt"
    destination = "/tmp/control-plane-join-command.txt"
  }

  # Step 5: Upload master-join.sh and run kubeadm join
  provisioner "file" {
    content = templatefile("${path.module}/../../templates/scripts/master-join.sh", {
      vip_address = var.vip_address
    })
    destination = "/tmp/k8s-join.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/k8s-join.sh"]
  }
}

# =============================================================================
# Worker Nodes
# =============================================================================

resource "proxmox_virtual_environment_vm" "k8s_worker" {
  for_each = var.worker_nodes

  name      = each.value.name
  node_name = each.value.target_node

  started = true

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
    floating  = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  description = each.value.notes

  depends_on = [
    proxmox_virtual_environment_vm.k8s_master_first,
    proxmox_virtual_environment_vm.k8s_master_additional,
  ]

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
    command = "scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${local.first_master_ip}:/tmp/worker-join-command.txt /tmp/worker-join-command-${each.key}.txt 2>/dev/null || scp -i ${var.node_config.ssh_private_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ubuntu@${local.first_master_ip}:/tmp/worker-join-command.txt /tmp/worker-join-command-${each.key}.txt"
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

# =============================================================================
# Label worker nodes with the worker role AFTER they have joined.
#
# node-role.kubernetes.io/* labels cannot be applied by the workers themselves:
# the kubelet rejects them in --node-labels (validation) and the kubelet
# certificate lacks permission to patch node labels (NodeRestriction -> 403).
# The documented approach is to apply them via the Kubernetes API using a
# cluster-admin credential. We do that from the first master (m1), which
# holds /etc/kubernetes/admin.conf, once each worker is detected in the cluster.
# A null_resource is used on purpose: it does not modify any VM resource, so it
# never stops/rebuilds nodes.
# =============================================================================
resource "null_resource" "label_workers" {
  depends_on = [
    proxmox_virtual_environment_vm.k8s_master_first,
    proxmox_virtual_environment_vm.k8s_master_additional,
    proxmox_virtual_environment_vm.k8s_worker,
  ]

  connection {
    host        = local.first_master_ip
    user        = var.node_config.ssh_user
    private_key = file(var.node_config.ssh_private_key_path)
  }

  provisioner "file" {
    source      = "${path.module}/../../templates/scripts/label-workers.sh"
    destination = "/tmp/label-workers.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo bash /tmp/label-workers.sh"]
  }
}
