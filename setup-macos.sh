#!/bin/bash

# =============================================================================
#                MESSAGE PUBLISHER - COMPLETE MACOS SETUP
# =============================================================================
# This script sets up everything needed for local development:
# 1. Installs all required software (Java, Node.js, Docker, kubectl, kind)
# 2. Creates standardized Kind Kubernetes cluster  
# 3. Installs and configures ArgoCD
# 4. Sets up Jenkins agent connection
# 5. Provides port forwarding commands for local access
# =============================================================================

set -e

# Colors and emojis for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"
GEAR="⚙️"

print_header() {
    echo ""
    echo "================================================================"
    echo "            MESSAGE PUBLISHER - MACOS SETUP"
    echo "================================================================"
    echo ""
}

print_status() {
    echo -e "${BLUE}${INFO} [INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}${CHECK} [SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING} [WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}${ERROR} [ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

print_header

# ====================
# STEP 1: Install Software
# ====================
print_status "[1/6] Installing required software..."
echo

# Install Homebrew if not present
if ! command_exists brew; then
    print_status "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

print_status "Installing Java 21..."
brew install openjdk@21

print_status "Installing Node.js LTS..."
brew install node@20

print_status "Installing Git..."
brew install git

print_status "Installing kubectl..."
brew install kubectl

print_status "Installing Kind..."
brew install kind

print_status "Installing Docker Desktop..."
brew install --cask docker

# Add Java to PATH
echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"

print_success "Software installation completed!"
echo

# ====================
# STEP 2: Start Docker
# ====================
print_status "[2/6] Starting Docker Desktop..."
echo

print_warning "Please ensure Docker Desktop is running before continuing."
print_status "1. Launch Docker from Applications"
print_status "2. Wait for Docker to fully start (whale icon in menu bar)"
echo
read -p "Press Enter when Docker Desktop is running..."

# ====================
# STEP 3: Create Kind Cluster
# ====================
print_status "[3/6] Creating standardized Kind Kubernetes cluster..."
echo

# Delete existing cluster if any
kind delete cluster --name message-publisher >/dev/null 2>&1 || true

# Create cluster with standardized config
print_status "Creating cluster with standardized configuration..."
if ! kind create cluster --config=kind-cluster-config.yaml --name=message-publisher; then
    print_error "Failed to create Kind cluster"
    print_status "Make sure Docker Desktop is running and try again"
    exit 1
fi

# Verify cluster
kubectl cluster-info --context kind-message-publisher
kubectl get nodes

print_success "Kubernetes cluster created successfully!"
echo

# ====================
# STEP 4: Install ArgoCD
# ====================
print_status "[4/6] Installing ArgoCD..."
echo

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

print_status "Waiting for ArgoCD to be ready (this may take 2-3 minutes)..."
if ! kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s; then
    print_warning "ArgoCD installation may still be in progress"
    print_status "You can check status with: kubectl get pods -n argocd"
fi

# Get ArgoCD admin password
echo
print_status "Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo
echo "================================================================"
echo "                   ARGOCD ADMIN PASSWORD"
echo "================================================================"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo
echo "SAVE THIS PASSWORD! You'll need it to login to ArgoCD"
echo "================================================================"
echo
read -p "Press Enter to continue..."

# ====================
# STEP 5: Jenkins Agent Setup
# ====================
print_status "[5/6] Jenkins Agent Setup Instructions..."
echo

echo "================================================================"
echo "                 JENKINS AGENT CONNECTION"
echo "================================================================"
echo
echo "TO COMPLETE SETUP, YOU NEED:"
echo
echo "1. Agent connection details from your team lead:"
echo "   - Agent Name (e.g., mac-john-agent)"
echo "   - Connection Command with secret"
echo
echo "2. Download Jenkins agent:"
echo "   curl -O http://your-ec2-jenkins:8080/jnlpJars/agent.jar"
echo
echo "3. Start agent with provided command:"
echo "   java -jar agent.jar -jnlpUrl http://your-ec2:8080/computer/your-agent/jenkins-agent.jnlp -secret your-secret -workDir ./jenkins-work"
echo
echo "4. Upload your kubeconfig to Jenkins with credential ID:"
echo "   kubeconfig-kind-{your-agent-name}"
echo
echo "================================================================"
echo

# Create jenkins work directory
mkdir -p ~/jenkins-work

# ====================
# STEP 6: Port Forwarding Helper
# ====================
print_status "[6/6] Creating port forwarding scripts..."
echo

# Create frontend port forwarding script
cat > port-forward-frontend.sh << 'EOF'
#!/bin/bash
echo "Starting frontend port forwarding..."
echo "Access frontend at: http://localhost:3000"
kubectl port-forward -n message-publisher svc/message-publisher-frontend 3000:80
EOF

# Create ArgoCD port forwarding script
cat > port-forward-argocd.sh << EOF
#!/bin/bash
echo "Starting ArgoCD port forwarding..."
echo "Access ArgoCD at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
kubectl port-forward -n argocd svc/argocd-server 8080:443
EOF

# Create API port forwarding script  
cat > port-forward-api.sh << 'EOF'
#!/bin/bash
echo "Starting API port forwarding..."
echo "Access API at: http://localhost:8000"
kubectl port-forward -n message-publisher svc/message-publisher-api 8000:8000
EOF

# Create combined port forwarding script
cat > start-all-services.sh << EOF
#!/bin/bash
echo "Starting all port forwarding services..."
echo
echo "Frontend will be available at: http://localhost:3000"
echo "ArgoCD will be available at: https://localhost:8080"
echo "API will be available at: http://localhost:8000"
echo
echo "ArgoCD Login:"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo
echo "Press Ctrl+C to stop all services"
echo

# Start services in background
kubectl port-forward -n message-publisher svc/message-publisher-frontend 3000:80 &
FRONTEND_PID=\$!

kubectl port-forward -n argocd svc/argocd-server 8080:443 &
ARGOCD_PID=\$!

kubectl port-forward -n message-publisher svc/message-publisher-api 8000:8000 &
API_PID=\$!

echo "All services started!"
echo "PIDs: Frontend=\$FRONTEND_PID, ArgoCD=\$ARGOCD_PID, API=\$API_PID"
echo

# Wait for interrupt
trap 'echo "Stopping all services..."; kill \$FRONTEND_PID \$ARGOCD_PID \$API_PID 2>/dev/null; exit' INT

# Keep script running
wait
EOF

# Make scripts executable
chmod +x port-forward-frontend.sh
chmod +x port-forward-argocd.sh  
chmod +x port-forward-api.sh
chmod +x start-all-services.sh

echo
echo "================================================================"
echo "                    SETUP COMPLETED!"
echo "================================================================"
echo
print_success "WHAT'S BEEN SET UP:"
echo "✓ Java 21, Node.js, Git, Docker, kubectl, Kind installed"
echo "✓ Kind Kubernetes cluster 'message-publisher' created"
echo "✓ ArgoCD installed and configured"
echo "✓ Port forwarding scripts created"
echo
print_status "NEXT STEPS:"
echo "1. Get Jenkins agent connection details from team lead"
echo "2. Download and start Jenkins agent"
echo "3. Upload kubeconfig to Jenkins credentials"
echo "4. Run your first build in Jenkins"
echo "5. Use port forwarding scripts to access applications:"
echo
echo "   ./port-forward-frontend.sh  - Access frontend"
echo "   ./port-forward-argocd.sh    - Access ArgoCD"  
echo "   ./port-forward-api.sh       - Access API"
echo "   ./start-all-services.sh     - Start all services"
echo
print_status "ARGOCD LOGIN:"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo
print_status "DOCUMENTATION: See TEAM_SETUP_GUIDE.md for detailed instructions"
echo
echo "================================================================"
echo