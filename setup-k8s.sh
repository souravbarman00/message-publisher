#!/bin/bash

# Kubernetes and ArgoCD Setup Script for macOS/Linux
# Fully automated setup with zero manual intervention required

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=======================================${NC}"
echo -e "${BLUE}  Kubernetes + ArgoCD Setup (macOS/Linux)  ${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Function definitions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

wait_for_condition() {
    local max_attempts=60
    local attempt=0
    while ! eval "$1" >/dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            print_error "Timeout waiting for condition: $2"
            return 1
        fi
        sleep 5
    done
}

# Step 1: Install Prerequisites
install_prerequisites() {
    print_status "Installing prerequisites..."
    
    # Detect OS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command_exists brew; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        if ! command_exists kubectl; then
            print_status "Installing kubectl..."
            brew install kubectl
        fi
        
        if ! command_exists kind; then
            print_status "Installing kind..."
            brew install kind
        fi
        
        if ! command_exists docker; then
            print_error "Docker is required but not installed. Please install Docker Desktop first."
            exit 1
        fi
        
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        print_status "Detected Linux system"
        
        # Install kubectl
        if ! command_exists kubectl; then
            print_status "Installing kubectl..."
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            sudo mv kubectl /usr/local/bin/
        fi
        
        # Install kind
        if ! command_exists kind; then
            print_status "Installing kind..."
            curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
        
        if ! command_exists docker; then
            print_error "Docker is required but not installed. Please install Docker first."
            exit 1
        fi
    fi
    
    print_success "Prerequisites installed successfully"
}

# Step 2: Create Kubernetes Cluster
create_cluster() {
    print_status "Setting up Kubernetes cluster..."
    
    # Check if cluster already exists
    if kind get clusters | grep -q "message-publisher"; then
        print_warning "Cluster 'message-publisher' already exists. Deleting and recreating..."
        kind delete cluster --name message-publisher
    fi
    
    print_status "Creating kind cluster with custom configuration..."
    kind create cluster --name message-publisher --config kind-config.yaml
    
    print_status "Setting kubectl context..."
    kubectl config use-context kind-message-publisher
    
    print_status "Waiting for cluster to be ready..."
    wait_for_condition "kubectl get nodes --no-headers | grep -q Ready" "cluster readiness"
    
    print_success "Kubernetes cluster created successfully"
}

# Step 3: Install Ingress Controller
install_ingress() {
    print_status "Installing NGINX Ingress Controller..."
    
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
    
    print_status "Waiting for ingress controller to be ready..."
    wait_for_condition "kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller --no-headers | grep -q Running" "ingress controller"
    
    print_success "Ingress controller installed successfully"
}

# Step 4: Install ArgoCD
install_argocd() {
    print_status "Installing ArgoCD..."
    
    kubectl create namespace argocd 2>/dev/null || true
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    print_status "Waiting for ArgoCD to be ready (this may take a few minutes)..."
    wait_for_condition "kubectl get deployment argocd-server -n argocd --no-headers | grep -E '1/1|2/2|3/3'" "ArgoCD server deployment"
    
    print_success "ArgoCD installed successfully"
}

# Step 5: Get ArgoCD Password and Setup Access
setup_argocd_access() {
    print_status "Setting up ArgoCD access..."
    
    # Get admin password
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    # Create ArgoCD access script
    cat > access-argocd.sh << EOF
#!/bin/bash
echo "Starting ArgoCD port forward..."
echo "ArgoCD will be available at: https://localhost:8090"
echo "Username: admin"
echo "Password: $admin_password"
echo ""
echo "Press Ctrl+C to stop port forwarding"
kubectl port-forward svc/argocd-server -n argocd 8090:443
EOF
    
    chmod +x access-argocd.sh
    
    print_success "ArgoCD access script created: access-argocd.sh"
    print_status "ArgoCD Credentials:"
    echo "  URL: https://localhost:8090"
    echo "  Username: admin"
    echo "  Password: $admin_password"
}

# Step 6: Deploy Applications
deploy_applications() {
    print_status "Deploying applications to Kubernetes..."
    
    # Create application namespace
    kubectl create namespace message-publisher 2>/dev/null || true
    
    # Build and load Docker images
    print_status "Building Docker images..."
    docker build -t message-publisher-api:latest ./api
    docker build -t message-publisher-workers:latest ./workers
    docker build -t message-publisher-frontend:latest ./frontend
    
    print_status "Loading images into kind cluster..."
    kind load docker-image message-publisher-api:latest --name message-publisher
    kind load docker-image message-publisher-workers:latest --name message-publisher
    kind load docker-image message-publisher-frontend:latest --name message-publisher
    
    # Apply Kubernetes manifests
    print_status "Applying Kubernetes manifests..."
    kubectl apply -f k8s/api-deployment.yaml -n message-publisher
    kubectl apply -f k8s/workers-deployment.yaml -n message-publisher
    kubectl apply -f k8s/frontend-deployment.yaml -n message-publisher
    
    # Wait for deployments to be ready
    print_status "Waiting for deployments to be ready..."
    kubectl rollout status deployment/message-publisher-api -n message-publisher --timeout=300s
    kubectl rollout status deployment/message-publisher-workers -n message-publisher --timeout=300s
    kubectl rollout status deployment/message-publisher-frontend -n message-publisher --timeout=300s
    
    print_success "Applications deployed successfully"
}

# Step 7: Setup ArgoCD Application
setup_argocd_app() {
    print_status "Setting up ArgoCD application..."
    
    # Apply ArgoCD application manifest
    kubectl apply -f k8s/argocd-application.yaml
    
    print_success "ArgoCD application configured"
}

# Step 8: Create Access Scripts
create_access_scripts() {
    print_status "Creating application access scripts..."
    
    # Frontend access script
    cat > access-frontend.sh << EOF
#!/bin/bash
echo "Starting frontend port forward..."
echo "Frontend available at: http://localhost:3000"
echo "Press Ctrl+C to stop"
kubectl port-forward svc/message-publisher-frontend-service -n message-publisher 3000:80
EOF
    
    # API access script
    cat > access-api.sh << EOF
#!/bin/bash
echo "Starting API port forward..."
echo "API available at: http://localhost:4000"
echo "Press Ctrl+C to stop"
kubectl port-forward svc/message-publisher-api-service -n message-publisher 4000:80
EOF
    
    # Combined status script
    cat > k8s-status.sh << EOF
#!/bin/bash
echo "Kubernetes Cluster Status:"
kubectl get nodes
echo ""
echo "Application Status:"
kubectl get pods -n message-publisher
echo ""
echo "Services:"
kubectl get services -n message-publisher
echo ""
echo "ArgoCD Status:"
kubectl get pods -n argocd
EOF
    
    chmod +x access-frontend.sh access-api.sh k8s-status.sh
    
    print_success "Access scripts created:"
    echo "  - access-argocd.sh    : Access ArgoCD UI"
    echo "  - access-frontend.sh  : Access Frontend"
    echo "  - access-api.sh       : Access API"
    echo "  - k8s-status.sh       : Check cluster status"
}

# Step 9: Final Setup
final_setup() {
    print_status "Completing setup..."
    
    # Create cleanup script
    cat > cleanup-k8s.sh << EOF
#!/bin/bash
echo "Cleaning up Kubernetes resources..."
kind delete cluster --name message-publisher
rm -f access-*.sh k8s-status.sh cleanup-k8s.sh
echo "Cleanup completed"
EOF
    
    chmod +x cleanup-k8s.sh
    
    print_success "Setup completed successfully!"
    echo ""
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${GREEN}        Setup Complete!               ${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Run: ./access-argocd.sh     (ArgoCD UI at https://localhost:8090)"
    echo "2. Run: ./access-frontend.sh   (Frontend at http://localhost:3000)"
    echo "3. Run: ./access-api.sh        (API at http://localhost:4000)"
    echo "4. Run: ./k8s-status.sh        (Check cluster status)"
    echo ""
    echo "Ports used:"
    echo "- Kafka UI:     8080 (existing)"
    echo "- ArgoCD:       8090"
    echo "- Frontend:     3000"
    echo "- API:          4000"
    echo ""
    echo "To cleanup everything: ./cleanup-k8s.sh"
}

# Main execution
main() {
    print_status "Starting Kubernetes and ArgoCD setup..."
    
    install_prerequisites
    create_cluster
    install_ingress
    install_argocd
    setup_argocd_access
    deploy_applications
    setup_argocd_app
    create_access_scripts
    final_setup
}

# Error handling
trap 'print_error "Script failed at line $LINENO"' ERR

# Execute main function
main "$@"
