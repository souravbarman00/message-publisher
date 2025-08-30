# Jenkins EC2 + Local Development Setup

**Goal**: Jenkins on AWS EC2 for CI/CD automation, but all actual builds and deployments happen locally on your machine.

## 🎯 **Architecture**

```
GitHub → Jenkins (EC2) → Webhook → Your Local Machine → Local Docker + K8s
```

## 🚀 **AWS EC2 Jenkins Setup (Minimal)**

### **Step 1: Create EC2 Instance**

1. **AWS Console** → EC2 → Launch Instance
   ```
   Name: jenkins-server
   AMI: Ubuntu Server 22.04 LTS
   Instance Type: t2.micro (Free tier)
   Security Group: Allow ports 22, 8080
   Storage: 8GB (minimum for Jenkins)
   ```

### **Step 2: Install Jenkins on EC2**

```bash
# SSH to EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# Install Java
sudo apt update
sudo apt install openjdk-11-jdk -y

# Install Jenkins
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
    /usr/share/keyrings/jenkins-keyring.asc > /dev/null

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
    https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
    /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update
sudo apt install jenkins -y
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Get initial password
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

### **Step 3: Basic Jenkins Configuration**

1. **Access**: `http://your-ec2-ip:8080`
2. **Install plugins**: Suggested plugins + Generic Webhook Trigger
3. **Create admin user**

## 🔗 **GitHub Integration Setup**

### **Step 4: Create Simple Notification Pipeline**

1. **New Item** → Pipeline → `message-publisher-trigger`

2. **Pipeline Configuration**:
   ```groovy
   pipeline {
       agent any
       
       triggers {
           GenericTrigger(
               genericVariables: [
                   [key: 'ref', value: '$.ref'],
                   [key: 'repository', value: '$.repository.name']
               ],
               causeString: 'Triggered by GitHub push',
               token: 'your-webhook-token',
               regexpFilterText: '$ref',
               regexpFilterExpression: 'refs/heads/main'
           )
       }
       
       stages {
           stage('Notify Local Machine') {
               steps {
                   script {
                       echo "🚀 New push detected to main branch"
                       echo "Repository: ${env.repository}"
                       echo "Branch: ${env.ref}"
                       echo "Timestamp: ${new Date()}"
                       
                       // Optional: Send notification to your local machine
                       // You can configure this to call your local webhook endpoint
                       // or send an email/Slack message
                       
                       // Example: HTTP request to your local machine (if accessible)
                       // sh 'curl -X POST http://your-local-ip:3001/webhook/build-trigger'
                   }
               }
           }
       }
       
       post {
           success {
               echo '✅ Local build trigger sent successfully!'
           }
           failure {
               echo '❌ Failed to trigger local build'
           }
       }
   }
   ```

### **Step 5: GitHub Webhook Setup**

1. **GitHub Repository** → Settings → Webhooks
2. **Add Webhook**:
   ```
   Payload URL: http://your-ec2-ip:8080/generic-webhook-trigger/invoke?token=your-webhook-token
   Content type: application/json
   Events: Just the push event
   ```

## 💻 **Local Machine Setup**

### **Step 6: Create Local Build Script**

Create `scripts/local-build.sh`:

```bash
#!/bin/bash
echo "🔄 Starting local build and deployment..."

# Pull latest changes
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

# Deploy to K8s
echo "🚀 Deploying to Kubernetes..."
kubectl rollout restart deployment/message-publisher-api -n message-publisher
kubectl rollout restart deployment/message-publisher-workers -n message-publisher
kubectl rollout restart deployment/message-publisher-frontend -n message-publisher

# Wait for rollout
echo "⏳ Waiting for deployment..."
kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s
kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=300s

echo "✅ Local deployment completed!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔍 API: http://localhost:3000/api/health"
```

Make it executable:
```bash
chmod +x scripts/local-build.sh
```

### **Step 7: Optional - Local Webhook Listener**

If you want Jenkins to automatically trigger your local build, create a simple webhook listener:

Create `scripts/webhook-server.js`:

```javascript
const express = require('express');
const { exec } = require('child_process');
const app = express();

app.use(express.json());

app.post('/webhook/build-trigger', (req, res) => {
    console.log('🔔 Received build trigger from Jenkins');
    
    // Run local build script
    exec('./scripts/local-build.sh', (error, stdout, stderr) => {
        if (error) {
            console.error('❌ Build failed:', error);
            return res.status(500).json({ error: 'Build failed' });
        }
        
        console.log('✅ Build output:', stdout);
        res.json({ status: 'Build triggered successfully' });
    });
});

app.listen(3001, () => {
    console.log('🎧 Webhook server listening on port 3001');
});
```

Run it:
```bash
node scripts/webhook-server.js
```

## 🔄 **Development Workflow**

### **Daily Development Process:**

1. **Make code changes** locally
2. **Test locally**: `./scripts/local-build.sh`
3. **Commit and push**:
   ```bash
   git add .
   git commit -m "feat: your changes"
   git push origin main
   ```
4. **Jenkins automatically detects** the push via webhook
5. **Optional**: Jenkins triggers your local build via webhook
6. **Continue developing** with updated local environment

### **Manual Trigger (Alternative)**

If you prefer manual control, just run locally after each push:
```bash
./scripts/local-build.sh
```

## 📊 **Benefits of This Setup**

✅ **Minimal AWS Costs**: Only t2.micro EC2 for Jenkins  
✅ **Fast Local Development**: No image pushing/pulling  
✅ **GitHub Integration**: Auto-detection of changes  
✅ **Local Control**: All builds happen on your machine  
✅ **Team Notifications**: Jenkins can notify team of changes  
✅ **Extensible**: Easy to add more CI/CD steps later  

## 🔧 **Enhanced Jenkins Pipeline (Optional)**

If you want Jenkins to do more than just notify, here's an enhanced version:

```groovy
pipeline {
    agent any
    
    environment {
        GITHUB_REPO = 'https://github.com/your-username/message-publisher.git'
        LOCAL_WEBHOOK_URL = 'http://your-local-ip:3001/webhook/build-trigger'
    }
    
    stages {
        stage('Detect Changes') {
            steps {
                script {
                    def changes = sh(
                        script: "curl -s https://api.github.com/repos/your-username/message-publisher/commits/main",
                        returnStdout: true
                    ).trim()
                    
                    def commitData = readJSON text: changes
                    env.COMMIT_MESSAGE = commitData.commit.message
                    env.COMMIT_AUTHOR = commitData.commit.author.name
                    env.COMMIT_SHA = commitData.sha
                    
                    echo "📝 New commit by ${env.COMMIT_AUTHOR}"
                    echo "💬 Message: ${env.COMMIT_MESSAGE}"
                    echo "🔗 SHA: ${env.COMMIT_SHA}"
                }
            }
        }
        
        stage('Trigger Local Build') {
            steps {
                script {
                    // Try to trigger local build
                    def response = sh(
                        script: "curl -X POST -f ${LOCAL_WEBHOOK_URL} || echo 'Local webhook not available'",
                        returnStdout: true
                    ).trim()
                    
                    if (response.contains('not available')) {
                        echo "ℹ️ Local machine webhook not available - manual build required"
                        echo "💡 Run: ./scripts/local-build.sh"
                    } else {
                        echo "✅ Local build triggered successfully"
                    }
                }
            }
        }
        
        stage('Team Notification') {
            steps {
                echo "📢 Notifying team about new deployment..."
                // Add Slack/email notification here if needed
                echo "🔔 Build notification sent"
            }
        }
    }
    
    post {
        always {
            echo "🏁 Pipeline completed for commit: ${env.COMMIT_SHA}"
        }
    }
}
```

## 🎯 **Summary**

This setup gives you:
- **Jenkins on EC2**: For GitHub integration and team notifications
- **Local Development**: All builds and deployments on your machine  
- **Auto-Detection**: Jenkins detects GitHub changes automatically
- **Simple Workflow**: Push → Jenkins notifies → You build locally
- **Cost Effective**: Only EC2 t2.micro running 24/7

**No Docker Hub, no complex registries - just clean CI/CD integration!**

Would you like me to help you implement any specific part of this setup?