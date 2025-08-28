# 🔧 Jenkins Setup Guide for Message Publisher

## Prerequisites

### 1. Jenkins Installation Requirements
- Jenkins 2.400+ with required plugins
- Docker installed on Jenkins agent
- Node.js 18+ installed on Jenkins agent
- Git configured on Jenkins agent

### 2. Required Jenkins Plugins
Install these plugins via Jenkins → Manage Jenkins → Manage Plugins:

```
- Pipeline
- Git Plugin
- GitHub Plugin
- Docker Pipeline Plugin
- HTML Publisher Plugin
- Slack Notification Plugin (optional)
- Blue Ocean (optional, for better UI)
- Build Timeout Plugin
- Timestamper Plugin
- Workspace Cleanup Plugin
```

## 🚀 Jenkins Job Setup

### Step 1: Create New Pipeline Job

1. **Navigate to Jenkins Dashboard**
2. **Click "New Item"**
3. **Enter name**: `message-publisher-main-pipeline`
4. **Select**: "Pipeline"
5. **Click "OK"**

### Step 2: Configure Pipeline Job

#### General Configuration
- **Description**: `CI/CD pipeline for Message Publisher - triggered on main branch push`
- **GitHub Project**: `https://github.com/your-org/message-publisher`
- **✅ Discard old builds**: Keep maximum 10 builds

#### Build Triggers
- **✅ GitHub hook trigger for GITScm polling**
- **✅ Poll SCM**: `H/5 * * * *` (every 5 minutes as fallback)

#### Pipeline Configuration
- **Definition**: `Pipeline script from SCM`
- **SCM**: `Git`
- **Repository URL**: `https://github.com/your-org/message-publisher.git`
- **Credentials**: Add your Git credentials
- **Branches to build**: `*/main`
- **Script Path**: `Jenkinsfile`

### Step 3: Configure Credentials

Navigate to Jenkins → Manage Jenkins → Manage Credentials:

#### 1. GitHub Access Token
```
ID: github-token
Description: GitHub access token for repository access
Kind: Secret text
Secret: [Your GitHub Personal Access Token]
```

#### 2. Docker Registry Credentials
```
ID: docker-hub-credentials
Description: Docker Hub credentials
Kind: Username with password
Username: [Your Docker Hub username]
Password: [Your Docker Hub password/token]
```

#### 3. Docker Registry URL
```
ID: docker-registry-url
Description: Docker registry URL
Kind: Secret text
Secret: docker.io (or your private registry URL)
```

#### 4. Slack Webhook (Optional)
```
ID: slack-webhook
Description: Slack webhook for notifications
Kind: Secret text
Secret: [Your Slack webhook URL]
```

### Step 4: Configure System Settings

Navigate to Jenkins → Manage Jenkins → Configure System:

#### Global Tool Configuration
1. **Node.js**
   - Name: `NodeJS-18`
   - Install automatically: ✅
   - Version: `18.x.x`

2. **Docker**
   - Name: `docker`
   - Install automatically: ✅
   - Add installer: "Download from docker.com"

#### System Configuration
1. **GitHub**
   - API URL: `https://api.github.com`
   - Credentials: Select your GitHub token
   - ✅ Manage hooks

2. **Slack Configuration** (Optional)
   - Workspace: `your-workspace`
   - Default channel: `#deployments`
   - Integration token credential: Select slack webhook

## 🔗 GitHub Webhook Setup

### Step 1: Configure Repository Webhook
1. Go to your GitHub repository
2. Navigate to **Settings** → **Webhooks**
3. Click **Add webhook**
4. Configure webhook:
   ```
   Payload URL: http://your-jenkins-url/github-webhook/
   Content type: application/json
   Secret: (leave empty or add if you have authentication)
   Events: 
     ✅ Push events
     ✅ Pull request events
   ✅ Active
   ```

### Step 2: Test Webhook
1. Push a commit to main branch
2. Check Jenkins for triggered build
3. Verify webhook deliveries in GitHub settings

## 📁 Docker Images Storage Structure

The pipeline creates the following directory structure:

```
/var/jenkins/docker-images/
├── api/
│   ├── message-publisher-api:1-abc123-20240828-143022.tar
│   ├── message-publisher-api:2-def456-20240828-150315.tar
│   └── ... (keeps last 5 builds)
├── frontend/
│   ├── message-publisher-frontend:1-abc123-20240828-143022.tar
│   ├── message-publisher-frontend:2-def456-20240828-150315.tar
│   └── ... (keeps last 5 builds)
├── workers/
│   ├── message-publisher-workers:1-abc123-20240828-143022.tar
│   ├── message-publisher-workers:2-def456-20240828-150315.tar
│   └── ... (keeps last 5 builds)
└── manifests/
    ├── build-1-abc123-20240828-143022.json
    ├── build-2-def456-20240828-150315.json
    ├── latest.json → build-2-def456-20240828-150315.json
    └── ... (keeps last 10 builds)
```

### Sample Build Manifest (latest.json)
```json
{
  "build": {
    "number": 2,
    "timestamp": "20240828-150315",
    "version": "2-def456-20240828-150315",
    "commit": "def456",
    "branch": "main"
  },
  "images": {
    "api": {
      "name": "message-publisher-api:2-def456-20240828-150315",
      "file": "/var/jenkins/docker-images/api/message-publisher-api:2-def456-20240828-150315.tar",
      "size": "245678912"
    },
    "frontend": {
      "name": "message-publisher-frontend:2-def456-20240828-150315",
      "file": "/var/jenkins/docker-images/frontend/message-publisher-frontend:2-def456-20240828-150315.tar",
      "size": "156789234"
    },
    "workers": {
      "name": "message-publisher-workers:2-def456-20240828-150315",
      "file": "/var/jenkins/docker-images/workers/message-publisher-workers:2-def456-20240828-150315.tar",
      "size": "198765432"
    }
  }
}
```

## 🔄 Rollback Procedure

### 1. List Available Versions
```bash
# SSH into Jenkins server
sudo su - jenkins
cd /var/jenkins/docker-images/manifests

# List available builds
ls -la build-*.json

# View specific build details
cat build-1-abc123-20240828-143022.json
```

### 2. Load Previous Docker Images
```bash
# Load specific version images
cd /var/jenkins/docker-images

# Load API image
docker load -i api/message-publisher-api:1-abc123-20240828-143022.tar

# Load Frontend image  
docker load -i frontend/message-publisher-frontend:1-abc123-20240828-143022.tar

# Load Workers image
docker load -i workers/message-publisher-workers:1-abc123-20240828-143022.tar

# Tag as latest for deployment
docker tag message-publisher-api:1-abc123-20240828-143022 message-publisher-api:latest
docker tag message-publisher-frontend:1-abc123-20240828-143022 message-publisher-frontend:latest
docker tag message-publisher-workers:1-abc123-20240828-143022 message-publisher-workers:latest
```

### 3. Deploy Rolled-back Images
```bash
# Update docker-compose or Kubernetes deployments
# Restart services with previous images
docker-compose down
docker-compose up -d
```

### 4. Automated Rollback Script
Create `/var/jenkins/scripts/rollback.sh`:

```bash
#!/bin/bash
# Rollback script for Message Publisher

BUILD_VERSION="$1"
IMAGES_PATH="/var/jenkins/docker-images"

if [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <build-version>"
    echo "Available versions:"
    ls -1 "$IMAGES_PATH/manifests/" | grep "build-" | sed 's/build-//g' | sed 's/.json//g'
    exit 1
fi

MANIFEST_FILE="$IMAGES_PATH/manifests/build-$BUILD_VERSION.json"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Build version $BUILD_VERSION not found"
    exit 1
fi

echo "Rolling back to version: $BUILD_VERSION"

# Load images
docker load -i "$IMAGES_PATH/api/message-publisher-api:$BUILD_VERSION.tar"
docker load -i "$IMAGES_PATH/frontend/message-publisher-frontend:$BUILD_VERSION.tar"
docker load -i "$IMAGES_PATH/workers/message-publisher-workers:$BUILD_VERSION.tar"

# Tag as latest
docker tag "message-publisher-api:$BUILD_VERSION" message-publisher-api:latest
docker tag "message-publisher-frontend:$BUILD_VERSION" message-publisher-frontend:latest
docker tag "message-publisher-workers:$BUILD_VERSION" message-publisher-workers:latest

# Update latest manifest
cp "$MANIFEST_FILE" "$IMAGES_PATH/manifests/latest.json"

echo "Rollback completed. Deploy the updated images using your deployment method."
```

## 🔍 Monitoring & Maintenance

### Pipeline Monitoring
1. **Build Status**: Check Jenkins dashboard regularly
2. **Disk Usage**: Monitor `/var/jenkins/docker-images` disk usage
3. **Log Reviews**: Review build logs for warnings/errors

### Maintenance Tasks

#### Daily
- Check build status notifications
- Review failed builds if any

#### Weekly  
- Review disk usage for Docker images storage
- Clean up old Docker images manually if needed
- Check Jenkins plugin updates

#### Monthly
- Review and update ESLint rules
- Update Node.js/Docker versions in pipeline
- Security scan of stored Docker images

### Cleanup Commands
```bash
# Manual cleanup if needed
sudo find /var/jenkins/docker-images -name "*.tar" -mtime +30 -delete

# Clean up Docker system
docker system prune -f
docker image prune -a -f
```

## 🚨 Troubleshooting

### Common Issues

#### 1. Build Fails at ESLint Stage
```bash
# Fix: Update code to pass ESLint rules
npm run lint          # Check errors
npm run lint -- --fix # Auto-fix some issues
```

#### 2. Docker Build Fails
```bash
# Check Dockerfile syntax
docker build -f api/Dockerfile api/ --no-cache

# Check available disk space
df -h
```

#### 3. GitHub Webhook Not Triggering
- Verify webhook URL is accessible
- Check GitHub webhook delivery logs
- Ensure Jenkins GitHub plugin is configured
- Test with manual trigger

#### 4. Permission Issues with Docker Images
```bash
# Fix ownership
sudo chown -R jenkins:jenkins /var/jenkins/docker-images
sudo chmod -R 755 /var/jenkins/docker-images
```

### Pipeline Recovery

If pipeline fails completely:

1. **Check Jenkins logs**:
   ```bash
   tail -f /var/log/jenkins/jenkins.log
   ```

2. **Manual build trigger**:
   - Go to Jenkins job
   - Click "Build Now"
   - Check console output

3. **Reset workspace**:
   - In Jenkins job → "Workspace" → "Wipe Out Workspace"
   - Trigger new build

This setup provides a robust CI/CD pipeline with proper ESLint checking, Docker image creation, versioning, and rollback capabilities for your Message Publisher project.