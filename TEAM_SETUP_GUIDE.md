# Message Publisher - Team Setup Guide

## Overview
This guide walks you through setting up your local development environment for the Message Publisher project. Our architecture uses:
- **Jenkins Master**: Running on EC2 (centralized build coordination)
- **Jenkins Agents**: Running locally on each developer's machine
- **Kind Clusters**: Local Kubernetes clusters for isolated development
- **ArgoCD**: GitOps deployment management

## Prerequisites
- Windows 10/11 or macOS 10.15+
- Admin/sudo privileges on your machine
- Internet connection

---

## Step 1: Install Required Software

### Windows Setup

1. **Install Chocolatey** (if not already installed):
   ```powershell
   # Run PowerShell as Administrator
   Set-ExecutionPolicy Bypass -Scope Process -Force
   [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
   iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
   ```

2. **Install Software Packages**:
   ```powershell
   # Install essential tools
   choco install openjdk21 -y
   choco install nodejs-lts -y
   choco install git -y
   choco install kubectl -y
   choco install kind -y
   choco install docker-desktop -y
   
   # Refresh environment variables
   refreshenv
   ```

3. **Start Docker Desktop**:
   - Launch Docker Desktop from Start Menu
   - Wait for it to fully start (Docker icon in system tray shows "Docker Desktop is running")

### macOS Setup

1. **Install Homebrew** (if not already installed):
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Install Software Packages**:
   ```bash
   # Install essential tools
   brew install openjdk@21
   brew install node@20
   brew install git
   brew install kubectl
   brew install kind
   brew install --cask docker
   
   # Add Java to PATH
   echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **Start Docker Desktop**:
   - Launch Docker from Applications
   - Wait for it to fully start

---

## Step 2: Create Local Kubernetes Cluster

1. **Download cluster configuration** (get this from your team lead):
   - `kind-cluster-config.yaml`
   - `create-standard-kind-cluster.bat` (Windows) or `create-standard-kind-cluster.sh` (macOS)

2. **Create Kind cluster**:

   **Windows:**
   ```cmd
   # Run the cluster creation script
   create-standard-kind-cluster.bat
   ```

   **macOS:**
   ```bash
   # Make script executable and run
   chmod +x create-standard-kind-cluster.sh
   ./create-standard-kind-cluster.sh
   ```

3. **Verify cluster is running**:
   ```bash
   kubectl cluster-info --context kind-message-publisher
   kubectl get nodes
   ```

   You should see output showing your cluster is running with one control-plane node.

---

## Step 3: Setup ArgoCD

1. **Install ArgoCD**:
   ```bash
   # Create namespace
   kubectl create namespace argocd
   
   # Install ArgoCD
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   
   # Wait for pods to be ready (this may take 2-3 minutes)
   kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
   ```

2. **Get ArgoCD admin password**:
   
   **Windows:**
   ```powershell
   # Get the base64 encoded password
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
   
   # Copy the output and decode it online at https://www.base64decode.org/
   # Or use PowerShell to decode:
   $encodedPassword = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
   [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encodedPassword))
   ```
   
   **macOS:**
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```
   
   **Save this password!** You'll need it to login to ArgoCD.

---

## Step 4: Get Jenkins Agent Connection Details

Contact your team lead to get your unique Jenkins agent connection details:
- **Agent Name**: (e.g., `windows-john-agent`, `mac-sarah-dev`)
- **Connection Command**: Java command with your unique secret
- **Credential ID**: `kubeconfig-kind-{your-agent-name}`

Example connection command:
```bash
java -jar agent.jar -jnlpUrl http://ec2-xxx:8080/computer/windows-john-agent/jenkins-agent.jnlp -secret abc123xyz -workDir ./jenkins-work
```

---

## Step 5: Setup Jenkins Agent

1. **Create Jenkins work directory**:
   ```bash
   # Windows
   mkdir C:\jenkins-work
   cd C:\jenkins-work
   
   # macOS
   mkdir ~/jenkins-work
   cd ~/jenkins-work
   ```

2. **Download Jenkins agent**:
   ```bash
   # Download agent.jar from Jenkins master
   curl -O http://your-ec2-jenkins:8080/jnlpJars/agent.jar
   ```

3. **Start Jenkins agent**:
   Run the connection command provided by your team lead:
   ```bash
   java -jar agent.jar -jnlpUrl http://your-ec2:8080/computer/your-agent-name/jenkins-agent.jnlp -secret your-secret -workDir ./jenkins-work
   ```

   **Keep this terminal open** - your agent needs to stay running to receive builds.

---

## Step 6: Upload Kubeconfig to Jenkins

1. **Get your kubeconfig**:
   ```bash
   # Windows
   copy %USERPROFILE%\.kube\config kubeconfig-kind.yaml
   
   # macOS
   cp ~/.kube/config kubeconfig-kind.yaml
   ```

2. **Login to Jenkins Dashboard**:
   - Open: `http://your-ec2-jenkins:8080`
   - Login with credentials provided by team lead

3. **Upload kubeconfig**:
   - Go to: **Manage Jenkins** → **Credentials**
   - Click on **(global)** domain
   - Click **Add Credentials**
   - Select **Secret file**
   - Upload your `kubeconfig-kind.yaml` file
   - **ID**: Use the exact credential ID provided by your team lead (e.g., `kubeconfig-kind-windows-john-agent`)
   - **Description**: "Kubeconfig for {your-name} local Kind cluster"
   - Click **Create**

---

## Step 7: Run Your First Build

1. **Trigger a build**:
   - Go to Jenkins dashboard
   - Find the **message-publisher-main-pipeline** job
   - Click **Build Now**

2. **Monitor the build**:
   - Your build should be assigned to your local agent
   - Watch the console output to see it building and deploying to your local Kind cluster

3. **Verify deployment**:
   ```bash
   # Check if applications are deployed
   kubectl get pods -n message-publisher
   kubectl get services -n message-publisher
   ```

---

## Step 8: Access Applications

### Frontend Application
```bash
# Port forward to frontend service
kubectl port-forward -n message-publisher svc/message-publisher-frontend 3000:80

# Access in browser
open http://localhost:3000
```

### ArgoCD Dashboard
```bash
# Port forward to ArgoCD server
kubectl port-forward -n argocd svc/argocd-server 8080:443

# Access in browser (ignore SSL warnings)
open https://localhost:8080

# Login credentials:
# Username: admin
# Password: (the password you saved from Step 3)
```

### API (if needed)
```bash
# Port forward to API service
kubectl port-forward -n message-publisher svc/message-publisher-api 8000:8000

# Access API
curl http://localhost:8000/health
```

---

## Troubleshooting

### Jenkins Agent Issues
- **Agent won't connect**: Check firewall settings, verify EC2 Jenkins is accessible
- **Build fails**: Ensure Docker is running and Kind cluster is healthy

### Kubernetes Issues
- **Pods not starting**: Check resources: `kubectl top nodes`
- **Services not accessible**: Verify port-forward commands and check service status

### ArgoCD Issues
- **Can't access ArgoCD**: Ensure port-forward is running and try different browser
- **Applications not syncing**: Check ArgoCD application status and Git repository access

### Port Conflicts
If ports 3000, 8080, or 8000 are in use:
```bash
# Use different local ports
kubectl port-forward -n message-publisher svc/message-publisher-frontend 3001:80
kubectl port-forward -n argocd svc/argocd-server 8081:443
kubectl port-forward -n message-publisher svc/message-publisher-api 8001:8000
```

---

## Daily Workflow

1. **Start your day**:
   ```bash
   # Ensure Docker is running
   # Start Jenkins agent (if not running as service)
   java -jar agent.jar -jnlpUrl http://your-ec2:8080/computer/your-agent/jenkins-agent.jnlp -secret your-secret -workDir ./jenkins-work
   ```

2. **Make changes and test**:
   - Push changes to Git
   - Jenkins automatically builds and deploys to your local cluster
   - Access applications via port-forward

3. **View build status**:
   - Check Jenkins dashboard for build results
   - View ArgoCD for deployment status

---

## Team Collaboration

- **Shared Jenkins**: All team members see builds in the same Jenkins dashboard
- **Isolated Environments**: Each person has their own local Kubernetes cluster
- **Consistent Setup**: Everyone uses the same cluster configuration but individual credentials
- **Build Distribution**: Jenkins automatically assigns builds to available agents

## Need Help?

Contact your team lead if you encounter issues with:
- Jenkins agent connection details
- EC2 Jenkins access
- Credential ID assignments
- Build pipeline problems