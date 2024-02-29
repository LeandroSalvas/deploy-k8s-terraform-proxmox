k8s_masters = {
 m1 = { target_node = "pve", vcpu = "2", memory = "4096", disk_size = "15", name = "k8sm1",notes = "Kubernetes Master 1", ip = "192.168.15.221", gw = "192.168.15.1" }
}


k8s_workers = {
 w1 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw1",notes = "Kubernetes Worker 1", ip = "192.168.15.222", gw = "192.168.15.1" },
 w2 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw2",notes = "Kubernetes Worker 2", ip = "192.168.15.223", gw = "192.168.15.1" },
 w3 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw3",notes = "Kubernetes Worker 3", ip = "192.168.15.224", gw = "192.168.15.1" },
 w4 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw4",notes = "Kubernetes Worker 4", ip = "192.168.15.225", gw = "192.168.15.1" },
 #w5 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw5",notes = "Kubernetes Worker 5", ip = "192.168.15.226", gw = "192.168.15.1" },
 #w6 = { target_node = "pve", vcpu = "2", memory = "2048", disk_size = "15", name = "k8sw6",notes = "Kubernetes Worker 6", ip = "192.168.15.227", gw = "192.168.15.1" }
}
