#!/bin/bash
echo "Starting both port forwarding services..."
echo
echo "Frontend will be available at: http://localhost:3000"
echo "ArgoCD will be available at: https://localhost:8080"
echo
echo "ArgoCD Login:"
echo "Username: admin"
echo "Password: oV2qiYNTFq1FEuRX"
echo
echo "Press Ctrl+C to stop all services"
echo

# Start services in background
kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80 &
FRONTEND_PID=$!

kubectl port-forward -n argocd svc/argocd-server 8080:443 &
ARGOCD_PID=$!

echo "Both services started!"
echo "PIDs: Frontend=$FRONTEND_PID, ArgoCD=$ARGOCD_PID"
echo

# Wait for interrupt
trap 'echo "Stopping all services..."; kill $FRONTEND_PID $ARGOCD_PID 2>/dev/null; exit' INT

# Keep script running
wait
