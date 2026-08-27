# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).
Versioning follows [Semantic Versioning 2.0.0](https://semver.org/).

## [1.0.6] - 2026-08-27

### Changed

- Removed legacy cloud-init templates (`templates/cloud-init/*.yaml.tpl`) that were no longer referenced by the active Terraform config and contained the incorrect labeling pattern (`node-labels` via kubelet, rejected by the NodeRestriction admission controller) plus outdated CRI-O repository URLs.
- Deduplicated the MetalLB configuration: removed the root `metallb/` folder (two split manifests), keeping `terraform-k8s-proxmox/manifests/metallb-config.yaml` as the single reference (identical to what `master-init.sh` applies).
- `scripts/validate-cluster.sh`: removed the obsolete step that re-applied the MetalLB config; only the test app deployment remains in the next steps.
- Unified the duplicated `[1.0.4]` section in the CHANGELOG.
- Updated the directory trees in `README.md` and `README.pt-br.md` to reflect the new layout.

### Removed

- Un-tracked `terraform-k8s-proxmox/terraform.tfvars` and `terraform-k8s-proxmox/terraform.tfstate.backup` from git (`git rm --cached`); they are now correctly ignored, aligned with `.gitignore`.

## [1.0.5] - 2026-08-27

### Fixed

- Worker nodes now receive the `node-role.kubernetes.io/worker` role label correctly (previously they were left with `ROLES <none>`).
- Root cause: a worker node cannot assign role labels (`node-role.kubernetes.io/*`) to itself. The kubelet rejects them via `--node-labels` (flag validation) and the kubelet certificate lacks permission to patch node labels (the `NodeRestriction` admission controller returns `Forbidden`). The documented approach — Kubernetes API with a cluster-admin credential — is now used.
- Added a `null_resource` (`label_workers`) that runs on the first master (m1, which holds `/etc/kubernetes/admin.conf`), waits for each ready worker node that lacks the control-plane role to appear, and applies `kubectl label node <worker> node-role.kubernetes.io/worker=`.
- The `label_workers` step uses a `null_resource` on purpose so it never modifies any VM resource, therefore it cannot stop, rebuild, or interfere with existing nodes.
- `worker-join.sh` no longer attempts any labeling (removed the invalid `--node-labels` and the `kubelet.conf` "Forbidden" path); it only joins the cluster normally.
- The `label_workers` script selects worker candidates with the negative label selector `-l '!node-role.kubernetes.io/control-plane'`. This avoids a fragile JSONPath escape of the dotted label key that made the previous filter always return empty, which relabeled every master as a worker. Idempotent: only nodes lacking the control-plane role are touched.
- Fixed a destructive state drift: `started = false` in the VM resources (used to ensure the cluster boots only after cloud-init sets the static IP) conflicted with the VMs actually running (started by `configure-cloudinit.sh`). Any subsequent `terraform apply` therefore planned `started: true -> false` and shut the nodes down. The resources now declare `started = true`; `configure-cloudinit.sh` is already idempotent (it reboots a running VM to apply cloud-init), so this removes the drift for good.


## [1.0.4] - 2026-08-26

### Fixed

- Worker nodes now wait for ALL control plane nodes (first + additional) to complete before starting, preventing resource contention during cluster initialization

### Changed

- Example topology now includes 3 control plane nodes (m1/m2/m3) + 2 workers (w1/w2)
- Control plane memory reduced to 4096 MB (appropriate for control plane role)
- Enabled memory ballooning (`floating = memory`) on all VMs to return unused guest RAM to the Proxmox host, reducing memory overcommit

## [1.0.3] - 2026-08-26

### Fixed

- Control plane nodes now boot sequentially: additional masters wait for the first master to complete `kubeadm init` before joining
- Split `k8s_master` resource into `k8s_master_first` and `k8s_master_additional` with `depends_on` dependency
- Added SCP step for additional masters to fetch control-plane join command from first master
- Added join command validation in `master-join.sh` with retry loop and error handling

## [1.0.2] - 2026-08-26

### Added

- Documentation for Super Mario demo application deployment, verification, access, and removal in both English and Portuguese READMEs

## [1.0.1] - 2026-08-26

### Fixed

- Worker nodes now receive `node-role.kubernetes.io/worker` label after `kubeadm join`

## [1.0.0] - 2026-08-26

### Added

- Terraform modules for VM provisioning (`bpg/proxmox` provider)
- kubeadm cluster bootstrap with CRI-O container runtime
- kube-vip HA virtual IP (ARP mode) for kube-apiserver (`192.168.15.240`)
- Calico CNI via Tigera Operator with VXLAN CrossSubnet encapsulation
- MetalLB bare-metal load balancer (L2 mode) with configurable IP pool
- Metrics Server with control-plane toleration and `--kubelet-insecure-tls`
- Kubernetes Dashboard v7.x exposed via MetalLB LoadBalancer with RBAC
- HTTPS file server for kubeconfig/token distribution (port 8443, auto-shutdown after download)
- Cloud-init API configuration via Proxmox REST API (`configure-cloudinit.sh`)
- Bilingual documentation (English `README.md` + Portuguese `README.pt-br.md`)
- Cluster validation script (`scripts/validate-cluster.sh`)
- MIT License
- Demo application (Super Mario) for testing MetalLB LoadBalancer services
- Modular Terraform structure (`modules/k8s-cluster/`)
- Cloud-init templates for master and worker nodes
- `.gitignore` with comprehensive coverage (tfstate, SSH keys, env files, IDE)

### Changed

- Migrated from `telmate/proxmox` to `bpg/proxmox` provider (>= 0.68.0)
- Upgraded to Kubernetes v1.31 on Ubuntu 24.04 LTS
- Rewrote README with Mermaid diagrams, tech stack table, and Proxmox 9.x prerequisites
- Removed `VM.Monitor` from `pveum` role (discontinued in Proxmox VE 9.x)
- Worker nodes depend on master initialization (prevents join if init fails)
- `ln -sf` replaced with `cp -f` for kubeconfig (avoids broken symlinks in tarball)
- Template variables use `${var}` for Terraform, `$$` for shell escaping

### Removed

- Legacy monolithic scripts (`scripts/common.sh`, `scripts/master.sh`, `scripts/node.sh`)
- `telmate/proxmox` provider dependency
- `ssh-keys/id_rsa` and placeholder files from repository

## [0.3.0] - 2026-08-25

### Changed

- Upgraded to Kubernetes 1.31.2
- Updated Kubernetes Dashboard to v7.x (archived Helm repo)

## [0.2.0] - 2026-08-24

### Changed

- Migrated to Ubuntu 24.10 cloud image
- Adjusted Proxmox role parameters for Terraform provider

## [0.1.0] - 2026-08-23

### Added

- Initial project structure
- Terraform configuration for Proxmox VM cloning
- kubeadm cluster bootstrap scripts
- Basic README and `.gitignore`

[1.0.6]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.5...v1.0.6
[1.0.5]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/releases/tag/v0.1.0
