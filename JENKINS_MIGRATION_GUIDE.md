# Jenkins Migration Guide - Local (8081) to AWS EC2

This guide will help you migrate your current Jenkins setup from localhost:8081 to AWS EC2 with identical configuration.

## 📋 **Step 1: Export Current Jenkins Configuration**

### **1.1 Access Your Local Jenkins**
- Open: `http://localhost:8081`
- Login with your current credentials

### **1.2 Export Job Configurations**
For each job in your Jenkins:

1. **Go to job** → Configure
2. **Copy the entire configuration** or download config.xml:
   ```bash
   # For each job, save the config.xml
   curl -u username:password http://localhost:8081/job/YOUR_JOB_NAME/config.xml > job_config.xml
   ```

### **1.3 Export Plugin List**
1. **Manage Jenkins** → **Plugins** → **Installed**
2. **Copy the list** or run:
   ```bash
   # Get installed plugins
   curl -u username:password http://localhost:8081/pluginManager/api/json?depth=1 > plugins.json
   ```

### **1.4 Export Global Configuration**
1. **Manage Jenkins** → **Configure System**
2. **Copy all settings** (Global properties, tool locations, etc.)

---

## 🚀 **Step 2: Create AWS EC2 Instance**

### **2.1 Launch EC2 Instance**
```
Name: jenkins-server
AMI: Ubuntu Server 22.04 LTS (Free tier eligible)
Instance Type: t2.micro
Key Pair: Create/select your key pair
```

### **2.2 Security Group Settings**
```
Inbound Rules:
- SSH (22): Your IP / 0.0.0.0/0
- Custom TCP (8081): 0.0.0.0/0    [Same port as local]
- HTTP (80): 0.0.0.0/0
- HTTPS (443): 0.0.0.0/0
```

### **2.3 Storage**
```
Root Volume: 20-30 GB gp3 (Free tier allows up to 30GB)
```

---

## ⚙️ **Step 3: Install Jenkins on EC2 (Exact Same Version)**

### **3.1 Connect to EC2**
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### **3.2 Install Prerequisites**
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Java 11 (same as local Jenkins likely uses)
sudo apt install openjdk-11-jdk -y

# Install Docker (since your local Jenkins uses Docker)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# Install Kind (for local K8s testing)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### **3.3 Install Jenkins (Same Version)**
```bash
# Add Jenkins repository
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt update
sudo apt install jenkins -y

# Change Jenkins port to 8081 (same as your local)
sudo sed -i 's/HTTP_PORT=8080/HTTP_PORT=8081/g' /etc/default/jenkins
sudo sed -i 's/JENKINS_PORT=8080/JENKINS_PORT=8081/g' /etc/default/jenkins

# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Start Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial admin password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

---

## 🔧 **Step 4: Configure Jenkins (Match Your Local Setup)**

### **4.1 Initial Setup**
1. **Access Jenkins**: `http://your-ec2-ip:8081`
2. **Unlock Jenkins**: Use the initial admin password
3. **Skip plugin installation for now** (we'll install exact plugins)

### **4.2 Create Admin User (Same as Local)**
- Use the same username/password as your local Jenkins

### **4.3 Set Jenkins URL**
```
Jenkins URL: http://your-ec2-ip:8081
```

---

## 🔌 **Step 5: Install Exact Same Plugins**

### **5.1 Go to Your Local Jenkins**
- `http://localhost:8081` → Manage Jenkins → Plugins → Installed
- **List all installed plugins** (copy the names)

### **5.2 Install Plugins on EC2 Jenkins**
Common plugins (install these + any additional from your local):
```
✅ Git
✅ GitHub Integration Plugin
✅ Pipeline
✅ Pipeline: Stage View
✅ Docker Pipeline
✅ Docker Commons Plugin
✅ Generic Webhook Trigger
✅ Build Timeout
✅ Timestamper
✅ Workspace Cleanup
✅ Blue Ocean (if you use it)
```

**To install**: Manage Jenkins → Plugins → Available → Search and install

---

## 📁 **Step 6: Migrate Job Configuration**

### **6.1 Create New Pipeline Job**
1. **New Item** → **Pipeline** → Same name as your local job
2. **Copy configuration from local Jenkins**:
   - General settings
   - Build triggers
   - Pipeline script/SCM settings

### **6.2 Copy Your Jenkinsfile**
Make sure your current `Jenkinsfile` is in your GitHub repo and accessible.

### **6.3 Test Job Configuration**
- **Build Now** to test the pipeline
- **Check console output** for any issues

---

## 🔗 **Step 7: GitHub Integration (Exact Same Setup)**

### **7.1 GitHub Personal Access Token**
If you don't have one:
1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token with `repo` and `admin:repo_hook` scopes
3. **Copy token** (save securely)

### **7.2 Add GitHub Credentials to EC2 Jenkins**
1. **Manage Jenkins** → **Credentials** → **System** → **Global credentials**
2. **Add Credentials**:
   ```
   Kind: Username with password
   Username: your-github-username
   Password: [GitHub Personal Access Token]
   ID: github-token (same as local)
   Description: GitHub Access Token
   ```

### **7.3 Configure Job for GitHub Integration**
In your pipeline job configuration:
```
✅ GitHub project: https://github.com/your-username/message-publisher

Build Triggers:
✅ GitHub hook trigger for GITScm polling

Pipeline:
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/your-username/message-publisher.git
Credentials: github-token
Branch: */main
Script Path: Jenkinsfile
```

---

## 🌐 **Step 8: GitHub Webhook Setup**

### **8.1 Add Webhook to GitHub Repository**
1. **GitHub repo** → **Settings** → **Webhooks** → **Add webhook**
2. **Configuration**:
   ```
   Payload URL: http://your-ec2-ip:8081/github-webhook/
   Content type: application/json
   Secret: (leave empty)
   Events: ✅ Just the push event
   ✅ Active
   ```

---

## 🎯 **Step 9: Update Jenkinsfile for EC2 Environment**

### **9.1 Modify Your Local Jenkinsfile**
Since you want to keep everything local, update your `Jenkinsfile` to:

```groovy
pipeline {
    agent any
    
    options {
        timeout(time: 30, unit: 'MINUTES')
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "🔄 Code checked out successfully"
                echo "📝 Commit: ${env.GIT_COMMIT}"
                echo "🌿 Branch: ${env.GIT_BRANCH}"
            }
        }
        
        stage('Notify Developer') {
            steps {
                script {
                    echo "🚀 NEW PUSH DETECTED!"
                    echo "📊 Repository: message-publisher"
                    echo "🌿 Branch: ${env.GIT_BRANCH}"
                    echo "👤 Author: ${env.GIT_AUTHOR_NAME}"
                    echo "💬 Message: ${env.GIT_COMMIT_MESSAGE}"
                    echo "🕐 Timestamp: ${new Date()}"
                    echo ""
                    echo "💻 ACTION REQUIRED:"
                    echo "Run locally: ./scripts/local-build.sh"
                    echo "Or trigger via webhook to your local machine"
                }
            }
        }
        
        stage('Log Build Details') {
            steps {
                script {
                    // Log to Jenkins for team visibility
                    def buildInfo = [
                        timestamp: new Date(),
                        commit: env.GIT_COMMIT,
                        author: env.GIT_AUTHOR_NAME,
                        branch: env.GIT_BRANCH,
                        buildNumber: env.BUILD_NUMBER
                    ]
                    
                    writeJSON file: 'build-info.json', json: buildInfo
                    archiveArtifacts artifacts: 'build-info.json', allowEmptyArchive: true
                    
                    echo "📋 Build information logged and archived"
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Jenkins notification completed successfully!'
            echo '💡 Remember to run local build: ./scripts/local-build.sh'
        }
        failure {
            echo '❌ Jenkins pipeline failed!'
        }
        always {
            echo "🏁 Pipeline completed for build #${env.BUILD_NUMBER}"
            cleanWs()
        }
    }
}
```

### **9.2 Create Local Build Script**
Create `scripts/local-build.sh` (if not exists):

```bash
#!/bin/bash
echo "🔄 Starting local build triggered by Jenkins..."

# Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin main

# Build Docker images
echo "🐳 Building Docker images..."
docker build -t message-publisher-api:latest ./api
docker build -t message-publisher-workers:latest ./workers
docker build -t message-publisher-frontend:latest ./frontend

# Load images into Kind cluster
echo "📦 Loading images into Kind cluster..."
kind load docker-image message-publisher-api:latest --name message-publisher
kind load docker-image message-publisher-workers:latest --name message-publisher
kind load docker-image message-publisher-frontend:latest --name message-publisher

# Restart deployments
echo "🚀 Restarting Kubernetes deployments..."
kubectl rollout restart deployment/message-publisher-api -n message-publisher
kubectl rollout restart deployment/message-publisher-workers -n message-publisher
kubectl rollout restart deployment/message-publisher-frontend -n message-publisher

# Wait for rollout
echo "⏳ Waiting for deployment to complete..."
kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=300s

echo ""
echo "✅ LOCAL BUILD COMPLETED SUCCESSFULLY!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔍 API Health: http://localhost:3000/api/health"
echo "📊 Jenkins: http://your-ec2-ip:8081"
```

Make it executable:
```bash
chmod +x scripts/local-build.sh
```

---

## ✅ **Step 10: Test Complete Setup**

### **10.1 Test Local to EC2 Flow**
1. **Make a small change** to your code
2. **Commit and push**:
   ```bash
   git add .
   git commit -m "test: Jenkins EC2 integration"
   git push origin main
   ```
3. **Check EC2 Jenkins**: Should trigger build automatically
4. **Run local build**: `./scripts/local-build.sh`
5. **Verify application**: `http://localhost:3000`

### **10.2 Verify Everything Works**
- ✅ GitHub push triggers Jenkins build
- ✅ Jenkins shows build details and notifications
- ✅ Local build script updates your local environment
- ✅ Application runs same as before

---

## 🔒 **Step 11: Security & Optimization**

### **11.1 Configure Firewall**
```bash
sudo ufw enable
sudo ufw allow 22
sudo ufw allow 8081
sudo ufw status
```

### **11.2 Set Up Domain (Optional)**
If you have a domain:
```bash
# Point subdomain to EC2
jenkins.yourdomain.com → your-ec2-ip

# Install nginx reverse proxy
sudo apt install nginx -y

# Configure nginx for port 8081
sudo tee /etc/nginx/sites-available/jenkins <<EOF
server {
    listen 80;
    server_name jenkins.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8081;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## 🎉 **Final Result**

After completion, you'll have:

✅ **Jenkins on EC2**: Identical to your local setup  
✅ **Same port 8081**: Consistent access  
✅ **GitHub Integration**: Auto-triggers on push  
✅ **Local Development**: All builds happen locally  
✅ **Team Ready**: Shareable Jenkins URL for collaboration  
✅ **Cost Effective**: Only EC2 t2.micro ($3-5/month)  

**Workflow**: 
```
Code Change → Git Push → Jenkins EC2 (Notification) → Run Local Build → Updated Local App
```

Ready to start with creating the EC2 instance?


saurav_barman00
Sourav@123