# Jenkins Agent Setup Guide

This guide shows how to set up Jenkins agents on local machines (Windows/macOS) that connect to the central Jenkins server running on EC2.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐
│   EC2 Jenkins   │    │  Your Local PC  │
│   (Master)      │    │                 │
│  - Web UI       │◄──►│  - Jenkins Agent│
│  - Job Queue    │    │  - Docker       │
│  - Build History│    │  - Kubernetes   │
└─────────────────┘    │  - ArgoCD       │
                       │  - Your Apps    │
                       └─────────────────┘
```

## Jenkins Dashboard Access

**URL:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`

## Complete Setup Prerequisites

### **Step 1: Install Required Software**

#### **Windows:**

1. **Java 17+ (Required for Jenkins Agent)**
   ```cmd
   # Download and install from: https://adoptium.net/
   # Or via chocolatey:
   choco install temurin21
   
   # Verify installation
   java -version
   ```

2. **Docker Desktop (Required for containers & K8s)**
   ```cmd
   # Download from: https://www.docker.com/products/docker-desktop/
   # During installation, ensure "Use WSL 2 instead of Hyper-V" is checked
   
   # After installation, enable Kubernetes:
   # Docker Desktop → Settings → Kubernetes → Enable Kubernetes → Apply & Restart
   ```

3. **Node.js & npm (Required for builds)**
   ```cmd
   # Download from: https://nodejs.org/ (LTS version)
   # Or via chocolatey:
   choco install nodejs
   
   # Verify installation
   node --version
   npm --version
   ```

4. **Git (Required for source control)**
   ```cmd
   # Download from: https://git-scm.com/download/win
   # Or via chocolatey:
   choco install git
   
   # Verify installation
   git --version
   ```

5. **kubectl (Required for K8s management)**
   ```cmd
   # Via chocolatey:
   choco install kubernetes-cli
   
   # Or download manually from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
   
   # Verify installation
   kubectl version --client
   ```

#### **macOS:**

1. **Java 17+ (Required for Jenkins Agent)**
   ```bash
   # Via Homebrew:
   brew install temurin21
   
   # Or download from: https://adoptium.net/
   
   # Verify installation
   java -version
   ```

2. **Docker Desktop (Required for containers & K8s)**
   ```bash
   # Download from: https://www.docker.com/products/docker-desktop/
   # Or via Homebrew:
   brew install --cask docker
   
   # After installation, enable Kubernetes:
   # Docker Desktop → Preferences → Kubernetes → Enable Kubernetes → Apply & Restart
   ```

3. **Node.js & npm (Required for builds)**
   ```bash
   # Via Homebrew:
   brew install node
   
   # Or download from: https://nodejs.org/
   
   # Verify installation
   node --version
   npm --version
   ```

4. **Git (Required for source control)**
   ```bash
   # Via Homebrew:
   brew install git
   
   # Usually pre-installed on macOS
   
   # Verify installation
   git --version
   ```

5. **kubectl (Required for K8s management)**
   ```bash
   # Via Homebrew:
   brew install kubectl
   
   # Verify installation
   kubectl version --client
   ```

### **Step 2: Verify Docker Desktop Kubernetes**

#### **Both Windows & macOS:**

1. **Start Docker Desktop**
2. **Enable Kubernetes:**
   - Windows: Docker Desktop → Settings → Kubernetes → Enable Kubernetes
   - macOS: Docker Desktop → Preferences → Kubernetes → Enable Kubernetes
3. **Wait for K8s to start** (green indicator in Docker Desktop)
4. **Verify kubectl connection:**
   ```bash
   kubectl config current-context
   # Should show: docker-desktop
   
   kubectl get nodes
   # Should show your local node
   ```

### **Step 3: Install ArgoCD in Local Kubernetes**

#### **Both Windows & macOS:**

1. **Install ArgoCD:**
   ```bash
   # Create ArgoCD namespace
   kubectl create namespace argocd
   
   # Install ArgoCD
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   
   # Wait for ArgoCD to be ready (this may take 2-3 minutes)
   kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
   ```

2. **Get ArgoCD admin password:**
   
   **Windows (PowerShell):**
   ```powershell
   $password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
   [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
   ```
   
   **macOS/Linux:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

3. **Start ArgoCD UI (keep this running):**
   ```bash
   # Port forward to access ArgoCD on localhost:8090
   kubectl port-forward svc/argocd-server -n argocd 8090:443
   ```

4. **Access ArgoCD:**
   - **URL:** `https://localhost:8090`
   - **Username:** `admin`
   - **Password:** [from step 2 above]
   - **Accept the self-signed certificate warning**

### **Step 4: Optional - Set up Kind Cluster (Alternative to Docker Desktop)**

If you prefer kind over Docker Desktop Kubernetes:

#### **Windows:**
```cmd
# Install kind via chocolatey
choco install kind

# Create kind cluster
kind create cluster --name message-publisher

# Verify cluster
kubectl config current-context
# Should show: kind-message-publisher
```

#### **macOS:**
```bash
# Install kind via Homebrew
brew install kind

# Create kind cluster
kind create cluster --name message-publisher

# Verify cluster
kubectl config current-context
# Should show: kind-message-publisher
```

## Stop Your Local Jenkins First

### Windows:
- Stop Jenkins service from Services.msc, or
- Close Jenkins application if running standalone

### macOS:
```bash
# If installed via Homebrew
brew services stop jenkins

# If running standalone - find and kill the Jenkins process
ps aux | grep jenkins
kill [jenkins-process-id]
```

## Windows Agent Setup

### 1. Create Jenkins Agent Directory
```cmd
mkdir C:\jenkins-agent
cd C:\jenkins-agent
```

### 2. Download Agent JAR
```cmd
curl -o agent.jar http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/jnlpJars/agent.jar
```

### 3. Create Windows Agent Node in EC2 Jenkins
1. Go to `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
2. **Manage Jenkins** → **Manage Nodes and Clouds**
3. **New Node** → Enter name: `windows-local-k8s` → **Permanent Agent** → **Create**
4. **Configuration:**
   - **Description:** `Windows local machine with Docker Desktop K8s`
   - **Number of executors:** `2`
   - **Remote root directory:** `C:\jenkins-agent`
   - **Labels:** `local-k8s windows`
   - **Usage:** `Use this node as much as possible`
   - **Launch method:** `Launch agent by connecting it to the master`
   - **Availability:** `Keep this agent online as much as possible`
5. **Save**

### 4. Start Windows Agent
```cmd
# Replace YOUR-SECRET with the actual secret from the node page
java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/windows-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir C:\jenkins-agent
```

## macOS Agent Setup

### 1. Create Jenkins Agent Directory
```bash
mkdir ~/jenkins-agent
cd ~/jenkins-agent
```

### 2. Download Agent JAR
```bash
curl -o agent.jar http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/jnlpJars/agent.jar
```

### 3. Create macOS Agent Node in EC2 Jenkins
1. Go to `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
2. **Manage Jenkins** → **Manage Nodes and Clouds**
3. **New Node** → Enter name: `macos-local-k8s` → **Permanent Agent** → **Create**
4. **Configuration:**
   - **Description:** `macOS local machine with Docker Desktop K8s`
   - **Number of executors:** `2`
   - **Remote root directory:** `/Users/$(whoami)/jenkins-agent`
   - **Labels:** `local-k8s macos`
   - **Usage:** `Use this node as much as possible`
   - **Launch method:** `Launch agent by connecting it to the master`
   - **Availability:** `Keep this agent online as much as possible`
5. **Save**

### 4. Start macOS Agent
```bash
# Replace YOUR-SECRET with the actual secret from the node page
java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/macos-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir ~/jenkins-agent
```

## How to Find the Secret

### Step-by-Step:

1. **Go to Jenkins dashboard:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`

2. **Navigate to:** **Manage Jenkins** → **Manage Nodes and Clouds**

3. **Click on your node name** (e.g., `windows-local-k8s` or `macos-local-k8s`)

4. **Find the connection command:** On the node details page, look for:
   ```
   Run from agent command line:
   java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/windows-local-k8s/jenkins-agent.jnlp -secret a1b2c3d4e5f6g7h8i9j0 -workDir "C:\jenkins-agent"
   ```

5. **Copy the secret:** The long string after `-secret` (e.g., `a1b2c3d4e5f6g7h8i9j0`)

## Workflow

1. **Developer pushes code** to Git repository
2. **EC2 Jenkins detects** the push (webhook/polling)
3. **Jenkins queues build** and assigns it to available local agent
4. **Local agent executes** the pipeline:
   - Downloads code
   - Installs npm dependencies
   - Runs tests and linting
   - Builds Docker images
   - Deploys to local Kubernetes cluster
5. **Build results** are visible in EC2 Jenkins dashboard
6. **Team can view** build status, logs, and artifacts from anywhere

## Quick Setup Verification

After installing all prerequisites, verify everything is working:

### **Both Windows & macOS:**

```bash
# Verify all tools are installed
java -version          # Should show Java 17+
docker --version       # Should show Docker
node --version         # Should show Node.js
npm --version          # Should show npm
git --version          # Should show Git
kubectl version --client  # Should show kubectl

# Verify Kubernetes is running
kubectl get nodes      # Should show 1 node (Ready status)
kubectl get namespaces # Should show default namespaces

# Verify ArgoCD is installed
kubectl get pods -n argocd  # Should show argocd pods (Running status)

# Start ArgoCD UI (if not already running)
kubectl port-forward svc/argocd-server -n argocd 8090:443
# Keep this terminal open and visit https://localhost:8090
```

## Troubleshooting

### **Prerequisites Issues:**

#### **Java Not Found:**
```bash
# Windows: Add Java to PATH or reinstall
# macOS: brew install temurin21
```

#### **Docker Issues:**
- **Windows:** Ensure WSL 2 is enabled and Docker Desktop is running
- **macOS:** Ensure Docker Desktop is running
- **Both:** Verify Kubernetes is enabled in Docker Desktop settings

#### **kubectl Not Working:**
```bash
# Check if kubectl is in PATH
kubectl version --client

# Verify Kubernetes context
kubectl config current-context

# Should be either 'docker-desktop' or 'kind-message-publisher'
```

### **Agent Connection Issues:**

#### **Agent Won't Connect:**
- Check firewall settings (allow outbound to port 8080)
- Verify Jenkins master is accessible: `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
- Ensure correct secret from Jenkins node page
- Check Java version: `java -version`

#### **Agent Disconnects:**
- Network issues - check internet connection
- Java heap space - increase with `-Xmx512m` flag
- Restart Docker Desktop if Docker commands fail

### **Build Issues:**

#### **npm Command Not Found:**
```bash
# Verify npm is in PATH
npm --version

# Windows: Restart Command Prompt after Node.js installation
# macOS: Run 'source ~/.bash_profile' or restart terminal
```

#### **Docker Build Fails:**
```bash
# Verify Docker is running
docker ps

# Check available disk space
# Windows: dir C:\
# macOS: df -h

# Clean up Docker if low on space
docker system prune -a -f
```

#### **kubectl Commands Fail:**
```bash
# Check Kubernetes is running
kubectl get nodes

# Verify context is correct
kubectl config current-context

# Switch to correct context if needed
kubectl config use-context docker-desktop
# or
kubectl config use-context kind-message-publisher
```

#### **ArgoCD Issues:**

**Can't Access ArgoCD UI:**
```bash
# Verify ArgoCD is running
kubectl get pods -n argocd

# Restart port-forward
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

**ArgoCD Login Issues:**
- Use username: `admin`
- Get fresh password with the PowerShell/bash commands above
- Accept self-signed certificate in browser

#### **Disk Space Issues:**
```bash
# Windows: Clean up temp files
cleanmgr

# Both: Clean Docker
docker system prune -a -f
docker volume prune -f

# Clean Jenkins workspace
# Windows: rmdir /s /q C:\jenkins-agent\workspace
# macOS: rm -rf ~/jenkins-agent/workspace
```

### **Pipeline-Specific Issues:**

#### **Wrong Agent Selected:**
- Verify agent labels match Jenkinsfile: `agent { label 'local-k8s' }`
- Check node configuration in Jenkins UI

#### **Kubernetes Deployment Fails:**
```bash
# Check if namespace exists
kubectl get namespaces | grep message-publisher

# Check if images are loaded
docker images | grep message-publisher

# Check pod status
kubectl get pods -n message-publisher
kubectl describe pods -n message-publisher
```

## Pipeline Configuration

The Jenkinsfile is configured to:
- Use agent with label `local-k8s`
- Detect OS automatically (Windows/macOS/Linux)
- Run appropriate commands for each platform
- Deploy to local Kubernetes cluster

## Security Notes

- Agent connects outbound to Jenkins master (no inbound ports needed)
- Local Kubernetes cluster remains isolated
- Build artifacts stay local unless explicitly pushed to registries
- Jenkins master only receives build status and logs

## Support

For issues with this setup:
1. Check Jenkins master logs on EC2
2. Check agent logs on local machine
3. Verify network connectivity to EC2 instance
4. Ensure all prerequisites are installed locally