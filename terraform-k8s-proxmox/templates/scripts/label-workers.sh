#!/bin/bash
# =============================================================================
# Label worker nodes with the worker role AFTER they have joined the cluster.
# Runs on the first master (m1) where /etc/kubernetes/admin.conf is available.
#
# Purpose: node-role.kubernetes.io/* labels cannot be applied by the workers
# themselves (the kubelet rejects them in --node-labels validation, and its
# certificate lacks permission to patch node labels due to NodeRestriction).
# The documented approach is to apply them via the Kubernetes API using a
# cluster-admin credential, which this script does.
#
# This script derives the worker node names dynamically: every Ready node that
# does NOT carry the node-role.kubernetes.io/control-plane label is labeled as
# a worker. This keeps the script free of parameters and idempotent.
# =============================================================================
set -euo pipefail

KUBECTL="sudo kubectl --kubeconfig /etc/kubernetes/admin.conf"
MAX=60

# Only nodes WITHOUT the control-plane role label. Using the negative label
# selector here avoids fragile JSONPath escaping of keys that contain dots
# (which would otherwise return empty and relabel masters as workers).
mapfile -t NODES < <(${KUBECTL} get nodes -l '!node-role.kubernetes.io/control-plane' -o custom-columns=NAME:.metadata.name --no-headers 2>/dev/null)

if [ "${#NODES[@]}" -eq 0 ]; then
  echo "No unlabeled (worker) nodes found; nothing to do"
  exit 0
fi

for node in "${NODES[@]}"; do
  echo "==> [Label] Waiting for worker node \"${node}\" to be Ready..."
  i=0
  while [ "$(${KUBECTL} get node "${node}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')" != "True" ]; do
    i=$((i + 1))
    if [ "${i}" -ge "${MAX}" ]; then
      echo "ERROR: worker node \"${node}\" not Ready in time"
      exit 1
    fi
    sleep 10
  done

  echo "==> [Label] Labeling \"${node}\" as worker..."
  ${KUBECTL} label node "${node}" node-role.kubernetes.io/worker= --overwrite
done

echo "==> [Label] All worker nodes labeled successfully"
