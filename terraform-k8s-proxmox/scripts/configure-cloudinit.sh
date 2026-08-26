#!/bin/bash
# =============================================================================
# configure-cloudinit.sh - Configure cloud-init via Proxmox API and reboot
# Usage: configure-cloudinit.sh <vmid> <ip> <gateway> <ssh_pub_key> <username> <node>
# =============================================================================

set -euo pipefail

PROXMOX_URL="${PROXMOX_URL:-https://192.168.15.58:8006/api2/json}"
PROXMOX_USER="${PROXMOX_USER:-terraform-prov@pve}"
PROXMOX_PASS="${PROXMOX_PASS:-}"

VMID="${1:?VMID required}"
IP="${2:?IP required}"
GATEWAY="${3:?Gateway required}"
SSH_KEY="${4:?SSH key required}"
USERNAME="${5:-ubuntu}"
NODE="${6:-pve}"

# Get auth ticket
TICKET=$(curl -sk -X POST "$PROXMOX_URL/access/ticket" \
  -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['ticket'])")
CSRF=$(curl -sk -X POST "$PROXMOX_URL/access/ticket" \
  -d "username=$PROXMOX_USER&password=$PROXMOX_PASS" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['CSRFPreventionToken'])")

AUTH="PVEAuthCookie=$TICKET"

# URL-encode SSH key
SSH_KEY_ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$SSH_KEY")

# Configure cloud-init
echo "Configuring cloud-init for VM $VMID..."
curl -sk -b "$AUTH" -H "CSRFPreventionToken: $CSRF" -X POST \
  "$PROXMOX_URL/nodes/$NODE/qemu/$VMID/config" \
  --data-urlencode "ciuser=$USERNAME" \
  --data-urlencode "ipconfig0=ip=$IP/24,gw=$GATEWAY" \
  --data-urlencode "sshkeys=$SSH_KEY_ENC" 2>/dev/null

echo "Cloud-init configured: VM $VMID -> IP=$IP GW=$GATEWAY USER=$USERNAME"

# Start VM if not running
STATUS=$(curl -sk -b "$AUTH" "$PROXMOX_URL/nodes/$NODE/qemu/$VMID/status/current" 2>/dev/null \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('status','unknown'))" 2>/dev/null || echo "unknown")

if [ "$STATUS" != "running" ]; then
  echo "Starting VM $VMID..."
  curl -sk -b "$AUTH" -H "CSRFPreventionToken: $CSRF" -X POST \
    "$PROXMOX_URL/nodes/$NODE/qemu/$VMID/status/start" 2>/dev/null
  echo "VM $VMID started"
else
  echo "VM $VMID is already running, rebooting..."
  curl -sk -b "$AUTH" -H "CSRFPreventionToken: $CSRF" -X POST \
    "$PROXMOX_URL/nodes/$NODE/qemu/$VMID/status/reboot" 2>/dev/null
  echo "VM $VMID rebooting"
fi

echo "Done. Wait for cloud-init to finish before SSH."
