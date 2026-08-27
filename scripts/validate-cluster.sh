#!/bin/bash
# =============================================================================
# validate-cluster.sh - Validates the Kubernetes cluster is healthy
# Run after terraform apply completes
# =============================================================================
set -euo pipefail

echo "============================================"
echo " Kubernetes Cluster Validation"
echo "============================================"
echo ""

# Check if kubectl is available
if ! command -v kubectl &>/dev/null; then
  echo "[ERROR] kubectl not found in PATH"
  exit 1
fi

# Check nodes
echo "--- Checking Nodes ---"
NODES=$(kubectl get nodes --no-headers 2>/dev/null)
if [ -z "$NODES" ]; then
  echo "[ERROR] No nodes found"
  exit 1
fi

echo "$NODES"
echo ""

# Check all nodes are Ready
NOT_READY=$(echo "$NODES" | grep -v " Ready " || true)
if [ -n "$NOT_READY" ]; then
  echo "[WARNING] Some nodes are not Ready:"
  echo "$NOT_READY"
  FAILED=1
else
  echo "[OK] All nodes are Ready"
fi
echo ""

# Check control plane pods
echo "--- Checking Control Plane Pods ---"
CP_PODS=$(kubectl get pods -n kube-system --no-headers -l component=kube-apiserver 2>/dev/null)
if [ -z "$CP_PODS" ]; then
  echo "[WARNING] No kube-apiserver pods found"
else
  echo "$CP_PODS"
fi
echo ""

# Check system pods
echo "--- Checking System Pods ---"
kubectl get pods -n kube-system --no-headers | grep -v "Running\|Completed" || echo "[OK] All system pods are Running or Completed"
echo ""

# Check CNI
echo "--- Checking Calico/CNI ---"
CALICO=$(kubectl get pods -n kube-system --no-headers -l k8s-app=calico-node 2>/dev/null)
if [ -z "$CALICO" ]; then
  echo "[WARNING] Calico pods not found (may be using different CNI)"
else
  echo "[OK] Calico pods found"
fi
echo ""

# Check Metrics Server
echo "--- Checking Metrics Server ---"
MS=$(kubectl get pods -n kube-system --no-headers -l k8s-app=metrics-server 2>/dev/null)
if [ -z "$MS" ]; then
  echo "[WARNING] Metrics Server pods not found"
else
  echo "[OK] Metrics Server running"
fi
echo ""

# Check MetalLB
echo "--- Checking MetalLB ---"
MLB=$(kubectl get pods -n metallb-system --no-headers 2>/dev/null)
if [ -z "$MLB" ]; then
  echo "[WARNING] MetalLB pods not found"
else
  echo "[OK] MetalLB pods found"
fi
echo ""

# Check DNS resolution
echo "--- Checking DNS Resolution ---"
kubectl run dns-test --image=busybox:1.36 --rm --restart=Never -- nslookup kubernetes.default.svc.cluster.local --timeout=5 2>/dev/null && echo "[OK] DNS resolution works" || echo "[WARNING] DNS test failed"
echo ""

# Summary
echo "============================================"
echo " Validation Complete"
echo "============================================"
echo ""
echo "Next steps:"
echo "  1. Deploy test app: kubectl apply -f app_mario/app.yml"
echo "  2. Check services: kubectl get svc"
