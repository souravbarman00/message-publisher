#!/bin/bash

# =============================================================================
#                MESSAGE PUBLISHER - MACOS SETUP
# =============================================================================
# Interactive setup script with menu options
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
    clear
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

show_menu() {
    print_header
    echo "What would you like to do?"
    echo
    echo "1. 🔧 Install Development Tools (Java, Node.js, Docker, kubectl, Kind)"
    echo "2. 🐳 Start Docker Desktop"
    echo "3. ☸️  Create Kind Kubernetes Cluster"
    echo "4. 🤖 Setup Jenkins Agent & Credentials"
    echo "5. 🔄 Install ArgoCD"
    echo "6. 🔑 Apply Secrets & ConfigMap"
    echo "7. 📊 Start Local Development Services (Kafka & Kafka UI)"
    echo "8. 🌐 Start Port Forwarding (Frontend & ArgoCD)"
    echo "9. 🔥 Full Setup (All above steps)"
    echo "10. 🚪 Exit"
    echo
    read -p "Enter your choice (1-10): " choice
}

install_dev_tools() {
    print_status "Installing development tools..."
    echo
    
    # Install Homebrew if not present
    if ! command_exists brew; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        print_success "Homebrew already installed"
    fi

    # Install Java 21 if not present
    if ! command_exists java || ! java -version 2>&1 | grep -q "21\." ; then
        print_status "Installing Java 21..."
        brew install openjdk@21
    else
        print_success "Java 21 already installed"
    fi

    # Install Node.js 18 if not present
    if ! command_exists node; then
        print_status "Installing Node.js 18..."
        brew install node@18
    else
        print_success "Node.js already installed ($(node --version))"
    fi

    # Install Git if not present
    if ! command_exists git; then
        print_status "Installing Git..."
        brew install git
    else
        print_success "Git already installed ($(git --version))"
    fi

    # Install kubectl if not present
    if ! command_exists kubectl; then
        print_status "Installing kubectl..."
        brew install kubectl
    else
        print_success "kubectl already installed"
    fi

    # Install Kind if not present
    if ! command_exists kind; then
        print_status "Installing Kind..."
        brew install kind
    else
        print_success "Kind already installed ($(kind --version))"
    fi

    # Install Docker Desktop if not present
    if ! command_exists docker; then
        print_status "Installing Docker Desktop..."
        brew install --cask docker
    else
        print_success "Docker already installed ($(docker --version))"
    fi

    # Add Java to PATH
    echo 'export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"' >> ~/.zshrc
    export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"

    print_success "Development tools installation completed!"
    echo
    read -p "Press Enter to continue..."
}

start_docker() {
    print_status "Checking Docker Desktop status..."
    echo
    
    if docker ps >/dev/null 2>&1; then
        print_success "Docker Desktop is already running!"
    else
        print_warning "Docker Desktop is not running."
        print_status "Please start Docker Desktop manually:"
        print_status "1. Open Docker Desktop from Applications"
        print_status "2. Wait for Docker to fully start (whale icon in menu bar)"
        echo
        read -p "Press Enter when Docker Desktop is running..."
        
        # Verify Docker is running
        if docker ps >/dev/null 2>&1; then
            print_success "Docker Desktop is now running!"
        else
            print_error "Docker Desktop is still not running. Please check and try again."
        fi
    fi
    echo
    read -p "Press Enter to continue..."
}

create_kind_cluster() {
    print_status "Creating Kind Kubernetes cluster..."
    echo

    # Check if cluster already exists
    if kind get clusters 2>/dev/null | grep -q "message-publisher"; then
        print_warning "Kind cluster 'message-publisher' already exists."
        read -p "Do you want to recreate it? (y/N): " recreate
        if [[ $recreate =~ ^[Yy]$ ]]; then
            print_status "Deleting existing cluster..."
            kind delete cluster --name message-publisher
        else
            print_success "Using existing cluster."
            echo
            setup_jenkins_integration
            return
        fi
    fi

    # Create cluster
    print_status "Creating cluster 'message-publisher'..."
    if kind create cluster --name=message-publisher; then
        print_success "Kind cluster created successfully!"
        
        # Verify cluster
        kubectl cluster-info --context kind-message-publisher
        kubectl get nodes
        
        echo
        setup_jenkins_integration
    else
        print_error "Failed to create Kind cluster"
        print_status "Make sure Docker Desktop is running and try again"
        echo
        read -p "Press Enter to continue..."
    fi
}

setup_jenkins_agent() {
    print_status "Setting up Jenkins Agent & Credentials..."
    echo

    # Create jenkins work directory
    print_status "Creating Jenkins work directory..."
    mkdir -p ~/jenkins-work
    print_success "Jenkins work directory created at: ~/jenkins-work"
    echo

    echo "================================================================"
    echo "                 JENKINS AGENT & CREDENTIALS SETUP"
    echo "================================================================"
    echo
    echo "STEP 1: Jenkins Agent Details"
    echo "Node Name: $(hostname)-local-k8s"
    echo "Work Directory: ~/jenkins-work"
    echo
    
    read -p "Enter your EC2 Jenkins URL (e.g., http://your-ec2-ip:8080): " JENKINS_URL
    if [[ -z "$JENKINS_URL" ]]; then
        print_warning "Jenkins URL not provided. Using placeholder."
        JENKINS_URL="http://your-ec2-jenkins:8080"
    fi

    echo
    echo "STEP 2: Download Jenkins Agent"
    echo "================================================================"
    echo "Command to run:"
    echo "curl -O ${JENKINS_URL}/jnlpJars/agent.jar"
    echo
    
    read -p "Download Jenkins agent now? (y/N): " download_agent
    if [[ $download_agent =~ ^[Yy]$ ]]; then
        print_status "Downloading Jenkins agent..."
        if curl -O "${JENKINS_URL}/jnlpJars/agent.jar"; then
            print_success "Jenkins agent downloaded successfully!"
        else
            print_error "Failed to download Jenkins agent. Please check Jenkins URL."
        fi
    fi

    echo
    echo "STEP 3: Kubeconfig Credential Setup"
    echo "================================================================"
    echo "Kubeconfig file location: ~/.kube/config"
    echo "Current cluster: $(kubectl config current-context 2>/dev/null || echo 'Not set')"
    echo "Credential ID to use: kubeconfig-kind-$(hostname)-local-k8s"
    echo
    echo "Manual steps in Jenkins UI:"
    echo "1. Go to Jenkins → Manage Jenkins → Credentials"
    echo "2. Add new 'Secret file' credential"
    echo "3. Upload file: ~/.kube/config" 
    echo "4. ID: kubeconfig-kind-$(hostname)-local-k8s"
    echo "5. Description: 'Kind cluster kubeconfig for $(hostname)'"

    echo
    read -p "Open kubeconfig directory? (y/N): " open_config
    if [[ $open_config =~ ^[Yy]$ ]]; then
        print_status "Opening kubeconfig directory..."
        open ~/.kube/ 2>/dev/null || echo "Please navigate to: ~/.kube/"
    fi

    echo
    echo "STEP 4: Jenkins Agent Connection"
    echo "================================================================"
    read -p "Enter your Jenkins agent secret (from team lead): " AGENT_SECRET
    
    if [[ -n "$AGENT_SECRET" ]]; then
        echo
        echo "Jenkins Agent Start Command:"
        echo "================================================================"
        AGENT_COMMAND="java -jar agent.jar -jnlpUrl ${JENKINS_URL}/computer/$(hostname)-local-k8s/jenkins-agent.jnlp -secret ${AGENT_SECRET} -workDir ~/jenkins-work"
        echo "$AGENT_COMMAND"
        echo
        echo "This command has been saved to: start-jenkins-agent.sh"
        
        # Create start script
        cat > start-jenkins-agent.sh << EOF
#!/bin/bash
echo "Starting Jenkins Agent for $(hostname)-local-k8s..."
echo "Work Directory: ~/jenkins-work"
echo "Jenkins URL: ${JENKINS_URL}"
echo "Press Ctrl+C to stop the agent"
echo
$AGENT_COMMAND
EOF
        chmod +x start-jenkins-agent.sh
        print_success "Jenkins agent start script created!"
        
        echo
        read -p "Start Jenkins agent now? (y/N): " start_agent
        if [[ $start_agent =~ ^[Yy]$ ]]; then
            print_status "Starting Jenkins agent..."
            exec ./start-jenkins-agent.sh
        fi
    else
        print_warning "Agent secret not provided. You can run this option again later."
    fi

    echo
    read -p "Press Enter to continue..."
}

setup_jenkins_integration() {
    setup_jenkins_agent
}

install_argocd() {
    print_status "Installing ArgoCD..."
    echo

    # Check if ArgoCD is already installed
    if kubectl get namespace argocd >/dev/null 2>&1; then
        print_warning "ArgoCD namespace already exists."
        read -p "Do you want to reinstall ArgoCD? (y/N): " reinstall
        if [[ ! $reinstall =~ ^[Yy]$ ]]; then
            print_success "Using existing ArgoCD installation."
            echo
            read -p "Press Enter to continue..."
            return
        fi
    fi

    # Create namespace and install ArgoCD
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    print_status "Waiting for ArgoCD to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

    # Get ArgoCD admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    echo
    echo "================================================================"
    echo "                   ARGOCD ADMIN CREDENTIALS"
    echo "================================================================"
    echo "Username: admin"
    echo "Password: $ARGOCD_PASSWORD"
    echo
    echo "SAVE THIS PASSWORD! You'll need it to login to ArgoCD"
    echo "================================================================"
    echo

    print_success "ArgoCD installation completed!"
    echo
    read -p "Press Enter to continue..."
}

apply_secrets() {
    print_status "Applying secrets and configmaps..."
    echo

    # Create namespace first
    print_status "Creating message-publisher namespace..."
    kubectl create namespace message-publisher --dry-run=client -o yaml | kubectl apply -f -
    
    if kubectl apply -f k8s/secrets.yaml; then
        print_success "Secrets and ConfigMap applied successfully!"
    else
        print_error "Failed to apply secrets. Make sure k8s/secrets.yaml exists."
    fi
    echo
    read -p "Press Enter to continue..."
}

start_local_services() {
    print_status "Starting local development services..."
    echo

    # Check if Docker is running
    if ! docker ps >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker Desktop first."
        read -p "Press Enter to continue..."
        return
    fi

    # Check if docker-compose.yml exists
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found in current directory."
        print_status "Make sure you're running this script from the project root directory."
        read -p "Press Enter to continue..."
        return
    fi

    # Check if services are already running
    if docker-compose ps | grep -q "Up"; then
        print_warning "Some services are already running."
        docker-compose ps
        echo
        read -p "Do you want to restart all services? (y/N): " restart_services
        if [[ $restart_services =~ ^[Yy]$ ]]; then
            print_status "Stopping existing services..."
            docker-compose down
        else
            print_success "Using existing services."
            echo
            read -p "Press Enter to continue..."
            return
        fi
    fi

    # Start services
    print_status "Starting local development services (Kafka, Zookeeper, Kafka UI)..."
    docker-compose up -d

    if [ $? -eq 0 ]; then
        print_success "Local development services started successfully!"
        echo
        print_status "Services running:"
        print_status "- Kafka: localhost:9092"
        print_status "- Kafka UI: http://localhost:9090"
        echo
        print_status "Waiting for Kafka to be ready..."
        sleep 10
        
        # Verify Kafka is accessible
        if docker-compose exec -T kafka kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
            print_success "Kafka is ready and accessible!"
        else
            print_warning "Kafka may still be starting up. Give it a few more seconds."
        fi
    else
        print_error "Failed to start local development services."
        print_status "Check Docker logs with: docker-compose logs"
    fi

    echo
    read -p "Press Enter to continue..."
}

start_port_forwarding() {
    print_status "Starting port forwarding..."
    echo

    # Check if services exist
    if ! kubectl get svc -n argocd argocd-server >/dev/null 2>&1; then
        print_error "ArgoCD service not found. Please install ArgoCD first."
        read -p "Press Enter to continue..."
        return
    fi

    if ! kubectl get svc -n message-publisher message-publisher-frontend-service >/dev/null 2>&1; then
        print_error "Frontend service not found. Please deploy the application first."
        read -p "Press Enter to continue..."
        return
    fi

    # Create port forwarding scripts
    cat > port-forward-frontend.sh << 'EOF'
#!/bin/bash
echo "Starting frontend port forwarding..."
echo "Access frontend at: http://localhost:3000"
kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80
EOF

    # Get ArgoCD password for the script
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "admin")
    
    cat > port-forward-argocd.sh << EOF
#!/bin/bash
echo "Starting ArgoCD port forwarding..."
echo "Access ArgoCD at: https://localhost:8080"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
kubectl port-forward -n argocd svc/argocd-server 8080:443
EOF

    cat > start-both-services.sh << EOF
#!/bin/bash
echo "Starting both port forwarding services..."
echo
echo "Frontend will be available at: http://localhost:3000"
echo "ArgoCD will be available at: https://localhost:8080"
echo
echo "ArgoCD Login:"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
echo
echo "Press Ctrl+C to stop all services"
echo

# Start services in background
kubectl port-forward -n message-publisher svc/message-publisher-frontend-service 3000:80 &
FRONTEND_PID=\$!

kubectl port-forward -n argocd svc/argocd-server 8080:443 &
ARGOCD_PID=\$!

echo "Both services started!"
echo "PIDs: Frontend=\$FRONTEND_PID, ArgoCD=\$ARGOCD_PID"
echo

# Wait for interrupt
trap 'echo "Stopping all services..."; kill \$FRONTEND_PID \$ARGOCD_PID 2>/dev/null; exit' INT

# Keep script running
wait
EOF

    # Make scripts executable
    chmod +x port-forward-frontend.sh port-forward-argocd.sh start-both-services.sh

    print_success "Port forwarding scripts created!"
    echo "Available scripts:"
    echo "  ./port-forward-frontend.sh  - Start frontend port forwarding"
    echo "  ./port-forward-argocd.sh    - Start ArgoCD port forwarding"
    echo "  ./start-both-services.sh    - Start both services"
    echo

    read -p "Do you want to start port forwarding now? (y/N): " start_now
    if [[ $start_now =~ ^[Yy]$ ]]; then
        print_status "Starting port forwarding for both services..."
        exec ./start-both-services.sh
    fi

    echo
    read -p "Press Enter to continue..."
}

full_setup() {
    print_status "Starting full setup..."
    install_dev_tools
    start_docker
    start_local_services
    create_kind_cluster
    install_argocd
    apply_secrets
    start_port_forwarding
}

# Main loop
while true; do
    show_menu
    case $choice in
        1)
            install_dev_tools
            ;;
        2)
            start_docker
            ;;
        3)
            create_kind_cluster
            ;;
        4)
            setup_jenkins_agent
            ;;
        5)
            install_argocd
            ;;
        6)
            apply_secrets
            ;;
        7)
            start_local_services
            ;;
        8)
            start_port_forwarding
            ;;
        9)
            full_setup
            ;;
        10)
            print_status "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice. Please select 1-10."
            read -p "Press Enter to continue..."
            ;;
    esac
done