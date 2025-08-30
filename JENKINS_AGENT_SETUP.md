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
└─────────────────┘    │  - Your Apps    │
                       └─────────────────┘
```

## Jenkins Dashboard Access

**URL:** `http://ec2-54-151-242-134.ap-southeast-1.compute.amazonaws.com:8080`

## Prerequisites for Local Machine

### Both Windows & macOS:
- Java 11 or higher
- Docker Desktop with Kubernetes enabled
- Node.js & npm
- kubectl configured
- Git

### Windows specific:
```cmd
# Install kubectl via chocolatey (if not already installed)
choco install kubernetes-cli

# Verify Docker Desktop has Kubernetes enabled
# Go to Docker Desktop → Settings → Kubernetes → Enable Kubernetes
```

### macOS specific:
```bash
# Install kubectl via Homebrew (if not already installed)
brew install kubectl

# Verify Docker Desktop has Kubernetes enabled
# Go to Docker Desktop → Preferences → Kubernetes → Enable Kubernetes
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

## Troubleshooting

### Agent Won't Connect:
- Check firewall settings (port 8080)
- Verify Java version: `java -version`
- Ensure Jenkins master is accessible

### Build Fails:
- Check agent labels in Jenkinsfile match node labels
- Verify Docker is running locally
- Ensure Kubernetes is enabled in Docker Desktop
- Check kubectl context: `kubectl config current-context`

### Kubernetes Issues:
```bash
# Verify K8s is running
kubectl get nodes

# Check Docker Desktop K8s
kubectl config use-context docker-desktop
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