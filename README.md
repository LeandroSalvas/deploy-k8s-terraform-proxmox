# deploy-k8s-terraform-proxmox

### Consider to check some files to change network settings accord your lab network 
### ( In my case lab network is 192.168.15.xxx )

- /metallb/metallb-ip-pool.yml 
- /terraform-k8s-proxmox/variables.tf
- /terraform-k8s-proxmox/terraform.tdvars
- /terraform-k8s-proxmox/scripts/master.sh
- /terraform-k8s-proxmox/scripts/node.sh



## Preparing Environment to create VM

####  Reproduce this steps on PMOX Server

#### Step 1. Download Cloudinit image from Ubuntu 24.10

```
wget https://cloud-images.ubuntu.com/oracular/current/oracular-server-cloudimg-amd64.img
``` 

#### Step 2. install libguestfs-tools on PMOX Server
```
apt update -y && apt install libguestfs-tools -y
```

#### Step 3. Installing packages and updating cloudinit Ubuntu image
```
virt-customize -a oracular-server-cloudimg-amd64.img --install qemu-guest-agent
virt-customize -a oracular-server-cloudimg-amd64.img --run-command "apt update -y && apt upgrade -y"
```

#### Step 4. Create a VM Template based on cloudinit ubuntu image
```
qm create 9000 --name "ubuntu2410-template" --memory 2048 --cores 1 --net0 virtio,bridge=vmbr0
qm set 9000 --scsi0 local-lvm:0,import-from=/root/images/oracular-server-cloudimg-amd64.img
qm set 9000 --ide3 local-lvm:cloudinit
qm set 9000 --boot order=scsi0
qm set 9000 --serial0 socket --vga serial0
qm template 9000
```

#### Step 5. Create Credentials and role for user terraform-prov on PMOX to be able to perform deploy with terraform

Creating Role
```
pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.Cloudinit VM.Config.CPU VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
```
Creating User
```
pveum user add terraform-prov@pve --password \<YourPassHere\>
pveum aclmod / -user terraform-prov@pve -role TerraformProv
```

-------------------------------------------------------------------------------------------------------------------------------------------------------

## Deploying your Virtual Machines, Install and configure Kubernetes

#### On a terraform installed machine exec the steps below

#### Step 6. Clone the repo with the deploy files
```
git clone https://github.com/LeandroSalvas/deploy-k8s-terrafor-proxmox.git
``` 
#### Step 7. Enter on the terraform-k8s-proxmox
```
cd terraform-k8s-proxmox
```

#### Step 8. Init terraform to load all needed providers
```
terraform init
```
#### Step 9. Exec terraform plan to verify if everything is working as planned
```
terraform plan
```
If every information reported from "terraform plan" is correct exec:
```
terraform apply
```
Confirm one more time if everything is ok, and say **"yes"** to confirm.

Wait until Terraform finishes creating the virtual machines, install and configure Kubernetes

After Terraform finishes the deploy you'll see something like this:
```
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

-------------------------------------------------------------------------------------------------------------------------------------------------------

#### Step 10. To acceses Kubernetes trhough kubectl you'll need to configure your environment to this
```
mkdir -p $HOME/.kube
cd $HOME/.kube/
```

The config file is hosted by master node
```
wget http://192.168.15.221:8000/config
```

Now you'll be able to use kubectl to manage your cluster.


Use this command to check your nodes:
```
kubectl get nodes 
```
Something like that is the result of the above command: 
```
NAME    STATUS     ROLES                             AGE     VERSION
k8sm1    Ready     control-plane,master              7h54m   v1.23.6
k8sw1    Ready     worker                            7h45m   v1.23.6  
```

-------------------------------------------------------------------------------------------------------------------------------------------------------

## Configuring MetalLB to load balance and expose apps

#### Step 11. To install MetalLB, apply the manifest:
```
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.3/config/manifests/metallb-native.yaml
```

On cloned repo directory go to metallb directoy and run this commands to define IP Pool and Advertise the IP Address Pool
```
kubectl apply -f metallb-ip-pool.yml
kubectl apply -f metallb-pool-advertise.yml
```
Now you Metallb loadBlancing is done move on next step


-------------------------------------------------------------------------------------------------------------------------------------------------------


#### Step 12. Deploy a test app on Kubernets: 

On cloned repo directory go to app_mario directory and run this command:
```
kubectl apply -f app.yml
```
If everything goes right you be able to see your service and app running using this commands:
```
kubectl get services
NAME                                                   TYPE         CLUSTER-IP          EXTERNAL-IP      PORT(S)       AGE
kubernetes                                          ClusterIP        10.96.0.1            <none>         443/TCP       8h
supermario-loadbalancer-service                     LoadBalancer   10.111.114.155     192.168.15.240   80:32371/TCP    4h4m
```
```
$ kubectl get deployments
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
supermario      4/4        4           4        4h8m
```

### Use the EXTERNAL-IP on your favorite browser to access the test app and enjoy.
### http://192.168.15.240
