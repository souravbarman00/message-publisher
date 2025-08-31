@echo off 
echo Starting ArgoCD port forwarding... 
echo Access ArgoCD at: https://localhost:8080 
echo Username: admin 
echo Password: B0rO7X74VKI7w1h4 
kubectl port-forward -n argocd svc/argocd-server 8080:443 
