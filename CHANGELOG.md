# Changelog

All notable changes to this project will be documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/).
Versioning follows [Semantic Versioning 2.0.0](https://semver.org/).

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

[1.0.2]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/LeandroSalvas/deploy-k8s-terraform-proxmox/releases/tag/v0.1.0
