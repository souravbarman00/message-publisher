#!/bin/bash
echo "Starting ArgoCD port forwarding..."
echo "Access ArgoCD at: https://localhost:8080"
echo "Username: admin"
echo "Password: oV2qiYNTFq1FEuRX"
kubectl port-forward -n argocd svc/argocd-server 8080:443
