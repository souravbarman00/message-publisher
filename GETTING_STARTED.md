# Message Publisher - Getting Started Guide

Welcome to the Message Publisher project! This guide will help you set up your local development environment and start contributing.

## 🎯 **What You Need (Minimal Setup)**

### **Required Tools**
1. **Docker Desktop** - Container runtime
2. **Kind** - Local Kubernetes clusters  
3. **kubectl** - Kubernetes CLI
4. **Git** - Version control

### **Optional but Recommended**
- **VS Code** with Kubernetes extension
- **Helm** (auto-installed by scripts)

---

## 🚀 **Quick Start (5 Minutes)**

### **1. Clone the Repository**
```bash
git clone <your-repo-url>
cd message-publisher
```

### **2. Install Prerequisites**

#### **Windows (PowerShell/CMD)**
```bash
# Install Docker Desktop from https://docker.com/products/docker-desktop
# Install Kind
curl -Lo kind-windows-amd64.exe https://kind.sigs.k8s.io/dl/v0.20.0/kind-windows-amd64
move kind-windows-amd64.exe C:\Windows\System32\kind.exe

# Install kubectl
curl -LO https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe
move kubectl.exe C:\Windows\System32\
```

#### **macOS**
```bash
# Install Docker Desktop from https://docker.com/products/docker-desktop
brew install kind kubectl
```

#### **Linux**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# Install Kind
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

### **3. Create Local Kubernetes Cluster**
```bash
# Create Kind cluster
kind create cluster --name message-publisher --config k8s/kind-config.yaml

# Verify cluster
kubectl cluster-info
```

### **4. Deploy Application**
```bash
# Run the automated setup script
./scripts/deploy-local.sh

# Or manually step by step:
kubectl apply -f k8s/secrets.yaml
kubectl apply -f k8s/
```

### **5. Access the Application**
```bash
# Set up port forwarding (runs in background)
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80 &

# Open your browser
open http://localhost:3000
```

**🎉 You're ready to develop!**

---

## 📁 **Project Structure**

```
message-publisher/
├── api/                    # Express.js backend
├── workers/               # Message processing workers  
├── frontend/              # React.js application
├── k8s/                   # Kubernetes manifests
│   ├── api-deployment.yaml
│   ├── workers-deployment.yaml
│   ├── frontend-deployment.yaml
│   └── secrets.yaml
├── scripts/               # Automation scripts
├── Jenkinsfile           # CI/CD pipeline
├── ACCESS_GUIDE.md       # Deployment access guide
└── GETTING_STARTED.md    # This file
```

---

## 🛠 **Development Workflow**

### **Daily Development**
1. **Start your local cluster**:
   ```bash
   kind get clusters  # Check if cluster exists
   kubectl cluster-info  # Verify connection
   ```

2. **Make code changes** in `api/`, `workers/`, or `frontend/`

3. **Build and deploy locally**:
   ```bash
   ./scripts/build-and-deploy.sh
   ```

4. **Test your changes**:
   ```bash
   # Frontend: http://localhost:3000
   # API: http://localhost:3000/api/health
   ```

5. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: your feature description"
   git push origin your-branch
   ```

### **Jenkins Integration**
- **Auto-builds**: Push to `main` triggers Jenkins build
- **Registry**: Jenkins pushes images to shared Docker registry
- **Notifications**: Build status via webhooks/Slack

---

## 🐳 **No Local Installation Needed!**

### **What Runs in Kubernetes**
- ✅ **Frontend** (React + nginx)
- ✅ **API** (Express.js)  
- ✅ **Workers** (Node.js)
- ✅ **Kafka** (Bitnami Helm chart)
- ✅ **Zookeeper** (Part of Kafka)

### **What You DON'T Need to Install**
- ❌ Node.js/npm (runs in containers)
- ❌ Kafka (deployed with Helm)
- ❌ Zookeeper (included with Kafka)
- ❌ nginx (containerized)
- ❌ Redis/databases (if added later)

**Everything runs in containers!**

---

## 🔧 **Useful Commands**

### **Cluster Management**
```bash
# Create cluster
kind create cluster --name message-publisher

# Delete cluster (clean slate)
kind delete cluster --name message-publisher

# Load local Docker images into Kind
kind load docker-image your-image:tag --name message-publisher
```

### **Development**
```bash
# Check all pods
kubectl get pods -n message-publisher

# View logs
kubectl logs -f deployment/message-publisher-api -n message-publisher

# Execute into pod
kubectl exec -it <pod-name> -n message-publisher -- bash

# Port forwarding
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80
```

### **Troubleshooting**
```bash
# Restart deployments
kubectl rollout restart deployment/message-publisher-api -n message-publisher

# Check service endpoints
kubectl get endpoints -n message-publisher

# Describe resources for events
kubectl describe pod <pod-name> -n message-publisher
```

---

## 🌐 **Jenkins Collaboration Setup**

### **Jenkins Server**
- **URL**: `https://jenkins.yourdomain.com`
- **Access**: Contact admin for credentials
- **Webhooks**: Auto-configured for this repo

### **Docker Registry**
- **Registry**: `your-registry.com/message-publisher`
- **Access**: Jenkins pushes, developers pull
- **Tags**: `main-<commit-sha>`, `dev-latest`

### **Shared Resources**
- **AWS Account**: Shared for SNS/SQS testing
- **Kafka Topics**: Standardized across environments
- **Secrets**: Managed via Kubernetes secrets

---

## 🚀 **Advanced Setup**

### **IDE Configuration**
#### **VS Code Extensions**
```bash
# Install these extensions
- Kubernetes
- Docker  
- GitLens
- Thunder Client (API testing)
```

#### **Kubernetes Context**
```bash
# Set default context
kubectl config use-context kind-message-publisher

# VS Code will auto-detect your cluster
```

### **Auto-Deploy Script**
Create `scripts/build-and-deploy.sh`:
```bash
#!/bin/bash
echo "Building images..."
docker build -t message-publisher-api:latest ./api
docker build -t message-publisher-workers:latest ./workers  
docker build -t message-publisher-frontend:latest ./frontend

echo "Loading into Kind cluster..."
kind load docker-image message-publisher-api:latest --name message-publisher
kind load docker-image message-publisher-workers:latest --name message-publisher
kind load docker-image message-publisher-frontend:latest --name message-publisher

echo "Deploying to Kubernetes..."
kubectl rollout restart deployment/message-publisher-api -n message-publisher
kubectl rollout restart deployment/message-publisher-workers -n message-publisher
kubectl rollout restart deployment/message-publisher-frontend -n message-publisher

echo "Waiting for rollout..."
kubectl rollout status deployment/message-publisher-api -n message-publisher

echo "✅ Deployment complete!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔍 API: http://localhost:3000/api/health"
```

---

## 🆘 **Common Issues & Solutions**

### **Issue: Port 3000 already in use**
```bash
# Kill existing port forwards
pkill -f "kubectl port-forward"

# Or use different port
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3001:80
```

### **Issue: Images not updating**
```bash
# Force rebuild without cache
docker build --no-cache -t message-publisher-api:latest ./api

# Reload into Kind
kind load docker-image message-publisher-api:latest --name message-publisher

# Force restart
kubectl rollout restart deployment/message-publisher-api -n message-publisher
```

### **Issue: Cluster not responding**
```bash
# Delete and recreate cluster
kind delete cluster --name message-publisher
kind create cluster --name message-publisher
```

### **Issue: Jenkins build failing**
1. Check Jenkins logs at `https://jenkins.yourdomain.com`
2. Verify Docker registry access
3. Contact DevOps team if needed

---

## 📚 **Additional Resources**

- **API Documentation**: http://localhost:3000/api/docs
- **Kubernetes Docs**: https://kubernetes.io/docs
- **Kind Documentation**: https://kind.sigs.k8s.io
- **Project Slack**: #message-publisher-dev

---

## 🤝 **Contributing**

### **Branch Strategy**
- `main` - Production ready code
- `develop` - Integration branch  
- `feature/<name>` - Feature branches
- `hotfix/<issue>` - Emergency fixes

### **Pull Request Process**
1. Create feature branch from `develop`
2. Make changes and test locally
3. Push branch and create PR
4. Jenkins runs automated tests
5. Code review and merge

### **Coding Standards**
- **ESLint**: Enforced in CI/CD
- **Prettier**: Auto-formatting
- **Tests**: Required for new features
- **Documentation**: Update relevant docs

---

**Welcome to the team! 🎉**

Need help? Ping us in Slack or create an issue!