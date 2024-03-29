terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "3.0.1-rc1"
    }
  }
}

provider "proxmox" {
  # url is the hostname (FQDN if you have one) for the proxmox host you'd like to connect to to issue the commands. my proxmox host is 'prox-1u'. Add /api2/json at the end for the API

   pm_api_url = var.pmox_api_url
   pm_user = var.pmox_user
   pm_password = var.pmox_password
   
  # leave tls_insecure set to true unless you have your proxmox SSL certificate situation fully sorted out (if you do, you will know)
  pm_tls_insecure = true

}


###############################################
############ CREATING MASTERS #################
###############################################
resource "proxmox_vm_qemu" "k8s_masters" {
 
  
  for_each = var.k8s_masters #using variables in terraform.tfvars
  name = each.value.name 
  qemu_os = "other"
  desc = each.value.notes
  target_node = each.value.target_node
  os_type = "cloud-init"
  full_clone = true
  memory = each.value.memory
  sockets = 1
  cores = each.value.vcpu
  cpu = "host"
  scsihw = "virtio-scsi-pci"
  # another variable with contents "ubuntu-template"
  clone = var.template_name
  cloudinit_cdrom_storage = "local-lvm"
  # basic VM settings here. agent refers to guest agent
  agent = 1
  

 #######Working on 3.0.1-rc1
  #configuring disk settings
    disks{
    scsi{
      scsi0{
        disk{
        storage = "local-lvm"
        size = each.value.disk_size
        }
      }
    }
  }
  
  
    
  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model = "virtio"
    bridge = "vmbr0"
  }


  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # Configuring IP for VM
  ipconfig0 = "ip=${each.value.ip}/24,gw=${each.value.gw}"
  
  # sshkeys set using variables. the variable contains the text of the key.
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF

#ssh connection for copy files and exec remote-exec
 connection {
    host        = "${each.value.ip}"
    type        = "ssh"
    private_key = file("ssh-keys/id_rsa")
    port        = 22
    user        = "ubuntu"
    agent       = false
    timeout     = "1m"
  }

# Copy files to VM
provisioner "file" {
    source      = "scripts"
    destination = "/home/ubuntu/scripts"
  }


#exec some scripts and commands on VM
provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/scripts/*",
      "sudo /home/ubuntu/scripts/common.sh",
      "sudo /home/ubuntu/scripts/master.sh",
      "cd /terraform/configs/",
      "nohup python3 -m http.server &",
      "sleep 1",
    ]
  }
}

###############################################
############ CREATING WORKERS #################
###############################################

resource "proxmox_vm_qemu" "k8s_workers" {
 
  for_each = var.k8s_workers #using variables in terraform.tfvars
  name = each.value.name 
  qemu_os = "other"
  desc = each.value.notes
  target_node = each.value.target_node
  os_type = "cloud-init"
  full_clone = true
  memory = each.value.memory
  sockets = 1
  cores = each.value.vcpu
  cpu = "host"
  scsihw = "virtio-scsi-pci"
  # another variable with contents "ubuntu-template"
  clone = var.template_name
  cloudinit_cdrom_storage = "local-lvm"
  # basic VM settings here. agent refers to guest agent
  agent = 1
  


 #######Working on 3.0.1-rc1
  #configuring disk settings
    disks{
    scsi{
      scsi0{
        disk{
        storage = "local-lvm"
        size = each.value.disk_size
        }
      }
    }
  }

  
  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model = "virtio"
    bridge = "vmbr0"
  }

  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
  
  # Configuring IP for VM
  ipconfig0 = "ip=${each.value.ip}/24,gw=${each.value.gw}"
  
  # sshkeys set using variables. the variable contains the text of the key.
  sshkeys = <<EOF
  ${var.ssh_key}
  EOF

   connection {
    host        = "${each.value.ip}"
    type        = "ssh"
    private_key = file("ssh-keys/id_rsa")
    port        = 22
    user        = "ubuntu"
    agent       = false
    timeout     = "1m"
  }

provisioner "file" {
    source      = "scripts"
    destination = "/home/ubuntu/scripts"
  }



provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /home/ubuntu/scripts/*",
      "sudo /home/ubuntu/scripts/common.sh",
      "sudo /home/ubuntu/scripts/node.sh",
    ]
  }

  #only start workers creation only if master's is finished successfully
  depends_on = [
    proxmox_vm_qemu.k8s_masters
  ]
}  
