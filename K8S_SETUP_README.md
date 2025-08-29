# Kubernetes & ArgoCD Setup Guide

This guide provides fully automated setup scripts for deploying your message publisher system to a local Kubernetes cluster with ArgoCD for GitOps monitoring.

## Overview

The setup includes:
- **Local Kubernetes cluster** using kind (Kubernetes in Docker)
- **ArgoCD** for GitOps-based deployment monitoring
- **NGINX Ingress Controller** for external access
- **Automated deployment** of all your services (API, Workers, Frontend)
- **Port forwarding scripts** for easy access to services

## Port Allocation

- **Kafka UI**: 8080 (existing, unchanged)
- **ArgoCD UI**: 8090
- **Frontend**: 3000
- **API**: 4000

## Quick Start

### Windows
```powershell
# Run the setup script (requires Admin privileges for Chocolatey installation)
.\setup-k8s.bat
```

### macOS/Linux
```bash
# Make the script executable and run it
chmod +x setup-k8s.sh
./setup-k8s.sh
```

## ArgoCD Credentials

**The setup script automatically extracts and displays the ArgoCD admin password:**
- Password is decoded from the Kubernetes secret automatically
- Displayed in terminal output during setup
- Embedded in the `access-argocd.bat/.sh` script for convenience
- Username is always: `admin`

## Jenkins Integration - IMPORTANT

### .kube/config File Location

After running the Kubernetes setup, the kubectl configuration file is created at:
- **Windows**: `C:\Users\<username>\.kube\config`
- **macOS/Linux**: `~/.kube/config`

### Making Kubernetes Accessible to Jenkins

**For Jenkins to access your Kubernetes cluster, you have two options:**

**Option 1: Automatic (Recommended)**
The updated Jenkinsfile automatically copies your .kube/config to the Jenkins workspace. No manual action required.

**Option 2: Manual Setup**
If you encounter issues, manually copy the config file to a location Jenkins can access:

```bash
# Windows - Copy to Jenkins user directory
copy "C:\Users\%USERNAME%\.kube\config" "C:\Users\<jenkins-user>\.kube\config"

# Or copy to project directory for Jenkins to use
copy "C:\Users\%USERNAME%\.kube\config" "C:\path\to\your\project\.kube\config"

# macOS/Linux - Copy to Jenkins accessible location
sudo cp ~/.kube/config /var/jenkins_home/.kube/config
# OR copy to project directory
cp ~/.kube/config /path/to/your/project/.kube/config
```

### Jenkins Service Account

If Jenkins runs as a service account, ensure the service account has access to the .kube directory:
```bash
# Windows - Grant permissions to Jenkins service
icacls "C:\Users\<jenkins-user>\.kube" /grant "Jenkins:(F)"

# Linux - Set proper ownership
sudo chown -R jenkins:jenkins /var/jenkins_home/.kube
```

## What the Setup Does

### 1. Prerequisites Installation
- **Windows**: Installs Chocolatey, kubectl, and kind
- **macOS**: Uses Homebrew to install kubectl and kind
- **Linux**: Downloads and installs kubectl and kind binaries

### 2. Kubernetes Cluster Creation
- Creates a kind cluster named "message-publisher"
- Uses custom configuration from `kind-config.yaml`
- Sets up port forwarding for ingress (8081:80, 8444:443)
- **Creates .kube/config automatically**

### 3. Infrastructure Setup
- Installs NGINX Ingress Controller
- Creates necessary namespaces (argocd, message-publisher)
- Configures kubectl context

### 4. ArgoCD Installation
- Deploys ArgoCD to the cluster
- **Extracts admin password automatically**
- Sets up GitOps application monitoring
- **Displays credentials in terminal output**

### 5. Application Deployment
- Builds Docker images for all services
- Loads images into the kind cluster
- Deploys Kubernetes manifests
- Waits for all deployments to be ready

### 6. Access Scripts Creation
Creates convenient scripts for accessing services:
- `access-argocd.bat/.sh` - ArgoCD UI access **with embedded password**
- `access-frontend.bat/.sh` - Frontend application access
- `access-api.bat/.sh` - API service access
- `k8s-status.bat/.sh` - Cluster status checker
- `cleanup-k8s.bat/.sh` - Complete cleanup script

## Post-Setup Usage

### Access ArgoCD Dashboard
```bash
# Windows
.\access-argocd.bat

# macOS/Linux
./access-argocd.sh
```
Opens ArgoCD at https://localhost:8090 with auto-extracted credentials displayed.

**ArgoCD Login:**
- URL: https://localhost:8090
- Username: admin  
- Password: (automatically displayed by setup script and in access script)

### Access Your Applications
```bash
# Frontend
.\access-frontend.bat    # Windows
./access-frontend.sh     # macOS/Linux
# Available at http://localhost:3000

# API
.\access-api.bat         # Windows
./access-api.sh          # macOS/Linux
# Available at http://localhost:4000
```

### Check Cluster Status
```bash
# Windows
.\k8s-status.bat

# macOS/Linux
./k8s-status.sh
```

## ArgoCD Features

Once setup is complete, ArgoCD provides:
- **Visual Dashboard** - See all your deployments, pods, and services
- **Git Sync Status** - Monitor sync between your repo and cluster
- **Health Monitoring** - Real-time health checks for all components
- **Rollback Capability** - Easy rollback to previous versions
- **Multi-Environment Management** - Scale to multiple environments

## Troubleshooting

### Script Fails During Prerequisites
- **Windows**: Run PowerShell as Administrator
- **macOS**: Ensure you have Xcode Command Line Tools installed
- **Docker**: Ensure Docker Desktop is running

### Jenkins Can't Access Kubernetes
1. **Check if .kube/config exists**:
   ```bash
   # Windows
   dir "C:\Users\%USERNAME%\.kube\config"
   
   # macOS/Linux
   ls -la ~/.kube/config
   ```

2. **Verify kubectl works locally**:
   ```bash
   kubectl get nodes
   kubectl config current-context
   ```

3. **Check Jenkins logs for kubectl errors** in the pipeline output

4. **Manual fix** - Copy config to Jenkins workspace:
   ```bash
   # In your project root
   mkdir .kube
   copy "%USERPROFILE%\.kube\config" ".kube\config"  # Windows
   cp ~/.kube/config .kube/config                     # macOS/Linux
   ```

### Cluster Creation Fails
- Check if port 8081 is already in use
- Ensure Docker has sufficient resources (4GB+ RAM recommended)
- Try deleting existing cluster: `kind delete cluster --name message-publisher`

### Applications Won't Start
```bash
# Check pod status
kubectl get pods -n message-publisher

# Check pod logs
kubectl logs deployment/message-publisher-api -n message-publisher

# Restart deployment
kubectl rollout restart deployment/message-publisher-api -n message-publisher
```

### ArgoCD UI Not Accessible
```bash
# Check ArgoCD pods
kubectl get pods -n argocd

# Get password manually if needed
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Restart port forward
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

## Cleanup

To completely remove the Kubernetes setup:
```bash
# Windows
.\cleanup-k8s.bat

# macOS/Linux
./cleanup-k8s.sh
```

This removes:
- The entire kind cluster
- All created access scripts
- Docker images (optional)

## Integration with CI/CD

The setup works seamlessly with your Jenkins pipeline. The updated Jenkinsfile automatically:
- Copies .kube/config to Jenkins workspace
- Detects the kind cluster
- Loads new images into the cluster
- Updates Kubernetes deployments
- Triggers ArgoCD sync

**Jenkins Pipeline Features:**
- Automatic kubectl configuration
- Context switching between kind and docker-desktop
- Error handling for missing configurations
- Workspace-specific .kube/config setup

## Customization

### Modify Resources
Edit the files in `k8s/` directory:
- `api-deployment.yaml` - API service configuration
- `workers-deployment.yaml` - Workers service configuration
- `frontend-deployment.yaml` - Frontend service configuration
- `argocd-application.yaml` - ArgoCD application settings

### Change Ports
Modify `kind-config.yaml` to change port mappings:
```yaml
extraPortMappings:
- containerPort: 80
  hostPort: 8081    # Change this
  protocol: TCP
```

### Scale Services
```bash
# Scale API service to 3 replicas
kubectl scale deployment message-publisher-api --replicas=3 -n message-publisher

# Scale workers
kubectl scale deployment message-publisher-workers --replicas=5 -n message-publisher
```

## Security Considerations

This setup is designed for local development. For production:
- Use proper TLS certificates
- Configure proper RBAC
- Use secrets management
- Enable pod security policies
- Configure network policies

## Next Steps

1. **Run the setup script** for your platform
2. **Note the ArgoCD password** displayed in the terminal
3. **Access ArgoCD** using the credentials provided
4. **Test your services** using the access scripts
5. **Run Jenkins pipeline** to see CI/CD integration
6. **Modify and deploy** changes through Git
7. **Monitor through ArgoCD** dashboard

The setup provides a complete local Kubernetes environment with GitOps capabilities, giving you experience with production-like deployment workflows.
