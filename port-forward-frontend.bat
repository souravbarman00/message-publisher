@echo off 
echo Starting frontend port forwarding... 
echo Access frontend at: http://localhost:3000 
kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80 
