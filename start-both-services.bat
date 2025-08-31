@echo off 
echo Starting both port forwarding services... 
echo. 
echo Frontend will be available at: http://localhost:3000 
echo ArgoCD will be available at: https://localhost:8080 
echo. 
echo ArgoCD Login: 
echo Username: admin 
echo Password: B0rO7X74VKI7w1h4 
echo. 
echo Press Ctrl+C to stop all services 
echo. 
start "Frontend" cmd /k "kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80" 
start "ArgoCD" cmd /k "kubectl port-forward -n argocd svc/argocd-server 8080:443" 
echo Both services started in separate windows 
pause 
