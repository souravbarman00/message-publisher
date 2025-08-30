# Quick Start Guide

For users who want to get started quickly with the Jenkins + Local K8s setup.

## 🚀 One-Time Setup (Windows)

### **1. Install Prerequisites (Run as Administrator)**
```cmd
# Install chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install all required tools
choco install temurin21 nodejs git kubernetes-cli -y

# Install Docker Desktop manually from: https://www.docker.com/products/docker-desktop/
```

### **2. Configure Docker Desktop**
1. **Start Docker Desktop**
2. **Go to Settings → Kubernetes**
3. **Check "Enable Kubernetes"**
4. **Click "Apply & Restart"**
5. **Wait for green K8s indicator**

### **3. Setup ArgoCD**
```cmd
# Install ArgoCD in local K8s
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for installation (2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
powershell -Command "$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'; [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))"

# Start ArgoCD UI (keep running)
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

### **4. Stop Local Jenkins (if running)**
- **Services.msc** → Find "Jenkins" → Stop
- Or close Jenkins application

### **5. Setup Jenkins Agent**
```cmd
# Create agent directory
mkdir C:\jenkins-agent
cd C:\jenkins-agent

# Download agent
curl -o agent.jar http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/jnlpJars/agent.jar
```

### **6. Create Agent Node in Jenkins**
1. **Go to:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
2. **Manage Jenkins** → **Manage Nodes** → **New Node**
3. **Name:** `windows-local-k8s`
4. **Type:** Permanent Agent → **Create**
5. **Configure:**
   - **Labels:** `local-k8s windows`
   - **Remote root directory:** `C:\jenkins-agent`
   - **Launch method:** Launch agent by connecting it to the master
   - **Save**

### **7. Connect Agent**
```cmd
# Get the secret from the node page, then run:
java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/windows-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir C:\jenkins-agent
```

## 🚀 One-Time Setup (macOS)

### **1. Install Prerequisites**
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install all required tools
brew install temurin21 node git kubectl docker
```

### **2. Configure Docker Desktop**
1. **Start Docker Desktop**
2. **Go to Preferences → Kubernetes**
3. **Check "Enable Kubernetes"**
4. **Click "Apply & Restart"**
5. **Wait for green K8s indicator**

### **3. Setup ArgoCD**
```bash
# Install ArgoCD in local K8s
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for installation (2-3 minutes)
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Start ArgoCD UI (keep running)
kubectl port-forward svc/argocd-server -n argocd 8090:443
```

### **4. Stop Local Jenkins (if running)**
```bash
# If installed via Homebrew
brew services stop jenkins

# Or find and kill process
ps aux | grep jenkins
kill [jenkins-process-id]
```

### **5. Setup Jenkins Agent**
```bash
# Create agent directory
mkdir ~/jenkins-agent
cd ~/jenkins-agent

# Download agent
curl -o agent.jar http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/jnlpJars/agent.jar
```

### **6. Create Agent Node in Jenkins**
1. **Go to:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
2. **Manage Jenkins** → **Manage Nodes** → **New Node**
3. **Name:** `macos-local-k8s`
4. **Type:** Permanent Agent → **Create**
5. **Configure:**
   - **Labels:** `local-k8s macos`
   - **Remote root directory:** `/Users/$(whoami)/jenkins-agent`
   - **Launch method:** Launch agent by connecting it to the master
   - **Save**

### **7. Connect Agent**
```bash
# Get the secret from the node page, then run:
java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/macos-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir ~/jenkins-agent
```

## 🎯 Daily Usage

### **Start Your Development Environment:**

1. **Start Docker Desktop** (if not running)
2. **Start ArgoCD:**
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8090:443
   ```
3. **Start Jenkins Agent:**
   ```bash
   # Windows
   cd C:\jenkins-agent
   java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/windows-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir C:\jenkins-agent
   
   # macOS
   cd ~/jenkins-agent
   java -jar agent.jar -jnlpUrl http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080/computer/macos-local-k8s/jenkins-agent.jnlp -secret YOUR-SECRET -workDir ~/jenkins-agent
   ```

### **Access Points:**
- **Jenkins Dashboard:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`
- **ArgoCD Dashboard:** `https://localhost:8090`
- **Your Applications:** Check `kubectl get services -n message-publisher` for service ports

### **Trigger a Build:**
1. **Push code** to your Git repository
2. **Jenkins automatically** triggers the pipeline
3. **Build executes** on your local machine
4. **Applications deploy** to your local Kubernetes
5. **View results** in Jenkins dashboard
6. **Monitor deployments** in ArgoCD

## 🔧 Daily Commands

```bash
# Check your local applications
kubectl get pods -n message-publisher
kubectl get services -n message-publisher

# View application logs
kubectl logs -f deployment/message-publisher-api -n message-publisher

# Access your frontend (example)
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80
# Then visit: http://localhost:3000

# Check ArgoCD applications
# Visit: https://localhost:8090
```

## ⚠️ Important Notes

- **Keep ArgoCD port-forward running** in a terminal for dashboard access
- **Keep Jenkins agent running** in a terminal for builds to work
- **Ensure Docker Desktop is always running** before triggering builds
- **Your applications run locally** - no internet required after initial setup
- **Jenkins dashboard is accessible** to your whole team on the internet
- **Only you can access your local ArgoCD** and applications (secure)

---

**Need help?** Check the detailed [JENKINS_AGENT_SETUP.md](JENKINS_AGENT_SETUP.md) for troubleshooting and advanced configuration.