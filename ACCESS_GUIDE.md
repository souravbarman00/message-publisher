# Message Publisher - Kubernetes Access Guide

This guide provides step-by-step instructions for verifying your Kubernetes deployment and accessing the Message Publisher application.

## Prerequisites

- Kubernetes cluster running (Kind, Minikube, or any K8s cluster)
- kubectl configured and connected to your cluster
- Docker images built and loaded into the cluster

## 1. Verify Deployment Status

### Check All Pods are Running
```bash
kubectl get pods -n message-publisher
```
**Expected Output:** All pods should show `STATUS: Running` and `READY: 1/1`
```
NAME                                          READY   STATUS    RESTARTS   AGE
message-publisher-api-64d6b48784-gnsvk        1/1     Running   0          22m
message-publisher-api-64d6b48784-p82mc        1/1     Running   0          22m
message-publisher-frontend-74b75fcd44-bcphk   1/1     Running   0          94s
message-publisher-frontend-74b75fcd44-lwf4l   1/1     Running   0          92s
message-publisher-workers-7d5dffdbf4-bqc6z    1/1     Running   0          22m
message-publisher-workers-7d5dffdbf4-gmjph    1/1     Running   0          22m
message-publisher-workers-7d5dffdbf4-pj5f4    1/1     Running   0          22m
```

### Check Services
```bash
kubectl get services -n message-publisher
```
**Expected Output:**
```
NAME                                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
message-publisher-api-service         ClusterIP   10.96.xxx.xxx   <none>        80/TCP    22m
message-publisher-frontend-service    ClusterIP   10.96.xxx.xxx   <none>        80/TCP    22m
```

### Check Deployments
```bash
kubectl get deployments -n message-publisher
```
**Expected Output:** All deployments should show desired replicas are available
```
NAME                          READY   UP-TO-DATE   AVAILABLE   AGE
message-publisher-api         2/2     2            2           22m
message-publisher-frontend    2/2     2            2           94s
message-publisher-workers     3/3     3            3           22m
```

### Verify Configuration and Secrets
```bash
kubectl get configmap -n message-publisher
kubectl get secrets -n message-publisher
```

## 2. Set Up Port Forwarding

### Frontend Service (Main Application)
```bash
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80
```
**What this does:** Routes localhost:3000 to the frontend service (port 80)

### API Service (Direct API Access - Optional)
```bash
kubectl port-forward svc/message-publisher-api-service -n message-publisher 4000:80
```
**What this does:** Routes localhost:4000 to the API service (port 80)

### ArgoCD (GitOps Dashboard - Optional)
```bash
kubectl port-forward svc/argocd-server -n argocd 8090:80
```
**What this does:** Routes localhost:8090 to ArgoCD dashboard

### Run Port Forwarding in Background
To run port forwarding in background (Windows):
```bash
start /b kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80
```

## 3. Access the Application

### Frontend Application
1. **Open your browser** and navigate to:
   ```
   http://localhost:3000
   ```

2. **Application Features:**
   - Message publishing interface
   - Support for Kafka, AWS SNS, and SQS
   - Real-time status updates
   - Message history

### API Endpoints (via Frontend Proxy)
All API endpoints are accessible through the frontend at `localhost:3000/api/...`

**Health Check:**
```bash
curl http://localhost:3000/api/health
```

**Publish Message:**
```bash
curl -X POST http://localhost:3000/api/publish \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello from K8s!",
    "platforms": ["sns", "kafka"]
  }'
```

### Direct API Access (Alternative)
If you set up API port forwarding on port 4000:
```bash
curl http://localhost:4000/api/health
```

### ArgoCD Dashboard (Optional)
If you set up ArgoCD port forwarding:
```
http://localhost:8090
```
- Username: `admin`
- Password: Get with `kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d`

## 4. Troubleshooting

### Pods Not Starting
```bash
# Check pod logs
kubectl logs <pod-name> -n message-publisher

# Describe pod for events
kubectl describe pod <pod-name> -n message-publisher
```

### Port Forwarding Issues
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Check if ports are in use
netstat -ano | findstr :3000
```

### API Connection Issues
```bash
# Test from inside cluster
kubectl exec -it <api-pod-name> -n message-publisher -- curl http://localhost:4000/api/health

# Check service endpoints
kubectl get endpoints -n message-publisher
```

### Image Pull Issues
```bash
# For Kind clusters, load images manually
kind load docker-image message-publisher-frontend:latest --name <cluster-name>
kind load docker-image message-publisher-api:latest --name <cluster-name>
kind load docker-image message-publisher-workers:latest --name <cluster-name>
```

## 5. Stopping the Application

### Stop Port Forwarding
- Press `Ctrl+C` in the terminal running port forward
- Or kill all: `pkill -f "kubectl port-forward"`

### Scale Down Deployments
```bash
kubectl scale deployment message-publisher-api --replicas=0 -n message-publisher
kubectl scale deployment message-publisher-frontend --replicas=0 -n message-publisher  
kubectl scale deployment message-publisher-workers --replicas=0 -n message-publisher
```

### Delete All Resources
```bash
kubectl delete namespace message-publisher
```

## 6. Application Architecture

- **Frontend**: React application served by nginx with API proxy configuration
- **API**: Express.js REST API with health checks and message publishing
- **Workers**: Node.js workers for consuming messages from Kafka/SQS
- **Configuration**: Uses Kubernetes ConfigMaps and Secrets for environment variables

## 7. External Dependencies

The application connects to external services:
- **AWS SNS/SQS**: Requires valid AWS credentials in secrets
- **Kafka**: Connects to Docker Kafka running on host machine (192.168.0.103:9092)
- **Docker Services**: Kafka, Zookeeper, and Kafka UI running in Docker containers

---

**Note:** This application is designed to work with external Docker services (Kafka) and AWS services. Ensure these dependencies are running and properly configured before accessing the application.