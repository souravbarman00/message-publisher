#!/bin/bash

# 🚀 Jenkins Docker Setup Script for Message Publisher
# This script sets up Jenkins in Docker with all required configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}🚀 Jenkins Docker Setup for Message Publisher${NC}"
    echo -e "${BLUE}============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Get Docker group ID
get_docker_group_id() {
    if getent group docker &> /dev/null; then
        DOCKER_GID=$(getent group docker | cut -d: -f3)
        print_info "Docker group ID: $DOCKER_GID"
    else
        print_warning "Docker group not found, using default GID 999"
        DOCKER_GID=999
    fi
}

# Setup directories
setup_directories() {
    print_info "Setting up directories..."
    
    # Create required directories
    mkdir -p jenkins_home
    mkdir -p docker-images/{api,frontend,workers,manifests}
    mkdir -p scripts
    
    # Set permissions
    sudo chown -R $USER:$USER jenkins_home
    sudo chown -R $USER:$USER docker-images
    chmod -R 755 jenkins_home docker-images scripts
    
    print_success "Directories created and configured"
}

# Create environment file
create_env_file() {
    print_info "Creating environment configuration..."
    
    cat > .env.jenkins << EOF
# Jenkins Docker Configuration
COMPOSE_PROJECT_NAME=message-publisher-ci

# User and Group IDs
HOST_UID=$(id -u)
HOST_GID=$(id -g)
DOCKER_GID=$DOCKER_GID

# Jenkins Configuration
JENKINS_HTTP_PORT=8081
JENKINS_AGENT_PORT=50000

# Java Options
JAVA_OPTS=-Djenkins.install.runSetupWizard=false -Xmx2g

# Paths
JENKINS_HOME=./jenkins_home
DOCKER_IMAGES_PATH=./docker-images
SCRIPTS_PATH=./scripts
EOF

    print_success "Environment file created: .env.jenkins"
}

# Update docker-compose.yml with environment variables
update_docker_compose() {
    print_info "Updating Docker Compose configuration..."
    
    cat > docker-compose.jenkins.yml << EOF
version: '3.8'

services:
  jenkins:
    image: jenkins/jenkins:lts
    container_name: message-publisher-jenkins
    restart: unless-stopped
    
    ports:
      - "\${JENKINS_HTTP_PORT:-8081}:8081"
      - "\${JENKINS_AGENT_PORT:-50000}:50000"
    
    environment:
      - JENKINS_OPTS=--httpPort=8081
      - JAVA_OPTS=\${JAVA_OPTS}
    
    volumes:
      # Jenkins data persistence
      - \${JENKINS_HOME}:/var/jenkins_home
      
      # Docker access
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /usr/bin/docker:/usr/bin/docker:ro
      
      # Project directories
      - \${DOCKER_IMAGES_PATH}:/var/jenkins/docker-images
      - \${SCRIPTS_PATH}:/var/jenkins/scripts
      
      # Project source (for local builds)
      - .:/var/jenkins/workspace/message-publisher
    
    user: "\${HOST_UID}:\${DOCKER_GID}"
    
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8081/login"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 60s
    
    networks:
      - jenkins

networks:
  jenkins:
    name: message-publisher-jenkins
    driver: bridge

volumes:
  jenkins_data:
    external: false
EOF

    print_success "Docker Compose configuration updated"
}

# Copy rollback script
copy_scripts() {
    if [ -f "scripts/rollback.sh" ]; then
        cp scripts/rollback.sh scripts/
        chmod +x scripts/rollback.sh
        print_success "Rollback script copied and made executable"
    else
        print_warning "Rollback script not found in scripts/ directory"
    fi
}

# Start Jenkins
start_jenkins() {
    print_info "Starting Jenkins..."
    
    # Load environment variables
    export $(cat .env.jenkins | xargs)
    
    # Start Jenkins with Docker Compose
    docker-compose -f docker-compose.jenkins.yml --env-file .env.jenkins up -d
    
    if [ $? -eq 0 ]; then
        print_success "Jenkins started successfully!"
        echo ""
        print_info "Jenkins is starting up... This may take a few minutes."
        print_info "You can monitor the logs with:"
        echo "  docker-compose -f docker-compose.jenkins.yml logs -f jenkins"
        echo ""
        print_info "Once ready, access Jenkins at:"
        echo "  http://localhost:${JENKINS_HTTP_PORT:-8081}"
        echo ""
        print_info "Get the initial admin password with:"
        echo "  docker exec message-publisher-jenkins cat /var/jenkins_home/secrets/initialAdminPassword"
    else
        print_error "Failed to start Jenkins"
        exit 1
    fi
}

# Show Jenkins status
show_status() {
    print_info "Jenkins Status:"
    docker-compose -f docker-compose.jenkins.yml ps
    echo ""
    
    if docker ps | grep -q message-publisher-jenkins; then
        print_success "Jenkins is running"
        
        # Wait for Jenkins to be ready
        print_info "Waiting for Jenkins to be ready..."
        
        for i in {1..60}; do
            if curl -s http://localhost:8081/login > /dev/null 2>&1; then
                print_success "Jenkins is ready!"
                break
            fi
            echo -n "."
            sleep 5
        done
        echo ""
        
        # Get initial admin password
        if docker exec message-publisher-jenkins test -f /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null; then
            echo ""
            print_info "🔑 Initial Admin Password:"
            docker exec message-publisher-jenkins cat /var/jenkins_home/secrets/initialAdminPassword
            echo ""
        fi
        
        echo ""
        print_info "🌐 Access Jenkins at: http://localhost:8081"
        print_info "📚 Follow the setup guide in .github/jenkins-setup.md"
        
    else
        print_error "Jenkins is not running"
    fi
}

# Main setup function
main() {
    print_header
    
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            get_docker_group_id
            setup_directories
            create_env_file
            update_docker_compose
            copy_scripts
            start_jenkins
            show_status
            ;;
        "start")
            print_info "Starting Jenkins..."
            docker-compose -f docker-compose.jenkins.yml --env-file .env.jenkins up -d
            show_status
            ;;
        "stop")
            print_info "Stopping Jenkins..."
            docker-compose -f docker-compose.jenkins.yml down
            ;;
        "restart")
            print_info "Restarting Jenkins..."
            docker-compose -f docker-compose.jenkins.yml restart
            show_status
            ;;
        "status")
            show_status
            ;;
        "logs")
            docker-compose -f docker-compose.jenkins.yml logs -f jenkins
            ;;
        "password")
            if docker ps | grep -q message-publisher-jenkins; then
                print_info "Initial Admin Password:"
                docker exec message-publisher-jenkins cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || print_error "Password file not found"
            else
                print_error "Jenkins container is not running"
            fi
            ;;
        "clean")
            print_warning "This will remove Jenkins container and data. Continue? (y/N)"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                docker-compose -f docker-compose.jenkins.yml down -v
                sudo rm -rf jenkins_home docker-images
                print_success "Jenkins data cleaned"
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Jenkins Docker Setup for Message Publisher"
            echo ""
            echo "Usage: $0 [COMMAND]"
            echo ""
            echo "Commands:"
            echo "  setup     - Complete Jenkins setup (default)"
            echo "  start     - Start Jenkins containers"
            echo "  stop      - Stop Jenkins containers"
            echo "  restart   - Restart Jenkins"
            echo "  status    - Show Jenkins status"
            echo "  logs      - Show Jenkins logs"
            echo "  password  - Show initial admin password"
            echo "  clean     - Remove Jenkins data (destructive)"
            echo "  help      - Show this help"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Use '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"