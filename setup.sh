#!/bin/bash

# Message Publisher Development Setup Script
# This script helps you set up and run the message publisher system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
port_in_use() {
    lsof -ti:$1 >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command_exists node; then
        print_error "Node.js is not installed. Please install Node.js 18+ first."
        exit 1
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18+ is required. Current version: $(node -v)"
        exit 1
    fi
    
    if ! command_exists npm; then
        print_error "npm is not installed."
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Check if Kafka is running
check_kafka() {
    print_status "Checking Kafka connectivity..."
    
    if ! command_exists nc; then
        print_warning "netcat (nc) not available, skipping Kafka check"
        return
    fi
    
    if nc -z localhost 9092 2>/dev/null; then
        print_success "Kafka is running on localhost:9092"
    else
        print_warning "Kafka is not running on localhost:9092"
        print_warning "Please start Kafka before running the workers"
    fi
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Root dependencies
    if [ -f "package.json" ]; then
        npm install
    fi
    
    # API dependencies
    if [ -d "api" ] && [ -f "api/package.json" ]; then
        print_status "Installing API dependencies..."
        cd api && npm install && cd ..
    fi
    
    # Workers dependencies
    if [ -d "workers" ] && [ -f "workers/package.json" ]; then
        print_status "Installing Workers dependencies..."
        cd workers && npm install && cd ..
    fi
    
    # Frontend dependencies
    if [ -d "frontend" ] && [ -f "frontend/package.json" ]; then
        print_status "Installing Frontend dependencies..."
        cd frontend && npm install && cd ..
    fi
    
    print_success "Dependencies installed successfully"
}

# Setup environment files
setup_env() {
    print_status "Setting up environment files..."
    
    # API .env
    if [ ! -f "api/.env" ] && [ -f "api/.env" ]; then
        print_status "Creating API .env file..."
        cp api/.env api/.env
        print_warning "Please update api/.env with your AWS credentials and service URLs"
    fi
    
    # Workers .env
    if [ ! -f "workers/.env" ] && [ -f "workers/.env" ]; then
        print_status "Creating Workers .env file..."
        cp workers/.env workers/.env
        print_warning "Please update workers/.env with your AWS credentials and service URLs"
    fi
    
    if [ ! -f "api/.env" ] || [ ! -f "workers/.env" ]; then
        print_warning "Environment files need to be configured with your AWS credentials"
        print_warning "Update the following files:"
        print_warning "  - api/.env"
        print_warning "  - workers/.env"
    fi
}

# Check ports
check_ports() {
    print_status "Checking port availability..."
    
    if port_in_use 3000; then
        print_warning "Port 3000 is in use (Frontend)"
    fi
    
    if port_in_use 4000; then
        print_warning "Port 4000 is in use (API)"
    fi
}

# Start services
start_services() {
    print_status "Starting services..."
    
    # Check if we should start all services or specific ones
    case "${1:-all}" in
        "api")
            print_status "Starting API service..."
            cd api && npm run dev
            ;;
        "workers")
            print_status "Starting Worker services..."
            cd workers && npm run dev:all
            ;;
        "frontend")
            print_status "Starting Frontend..."
            cd frontend && npm start
            ;;
        "all")
            print_status "Starting all services..."
            print_status "This will open multiple terminal sessions"
            
            # Start API in background
            if command_exists gnome-terminal; then
                gnome-terminal --tab --title="API" -- bash -c "cd api && npm run dev; exec bash"
                gnome-terminal --tab --title="Workers" -- bash -c "cd workers && npm run dev:all; exec bash"
                gnome-terminal --tab --title="Frontend" -- bash -c "cd frontend && npm start; exec bash"
            elif command_exists osascript; then
                # macOS
                osascript -e 'tell app "Terminal" to do script "cd '$(pwd)'/api && npm run dev"'
                osascript -e 'tell app "Terminal" to do script "cd '$(pwd)'/workers && npm run dev:all"'
                osascript -e 'tell app "Terminal" to do script "cd '$(pwd)'/frontend && npm start"'
            else
                print_warning "Cannot detect terminal. Please start services manually:"
                print_warning "Terminal 1: cd api && npm run dev"
                print_warning "Terminal 2: cd workers && npm run dev:all"
                print_warning "Terminal 3: cd frontend && npm start"
            fi
            ;;
        *)
            print_error "Unknown service: $1"
            print_error "Available options: api, workers, frontend, all"
            exit 1
            ;;
    esac
}

# Show help
show_help() {
    echo "Message Publisher Development Setup"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup     - Install dependencies and setup environment"
    echo "  start     - Start all services"
    echo "  start-api - Start API service only"
    echo "  start-workers - Start worker services only"
    echo "  start-frontend - Start frontend only"
    echo "  check     - Check system prerequisites"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 setup              # Initial setup"
    echo "  $0 start              # Start all services"
    echo "  $0 start-api          # Start API only"
    echo ""
}

# Main script logic
main() {
    case "${1:-setup}" in
        "setup")
            check_prerequisites
            check_kafka
            install_dependencies
            setup_env
            check_ports
            print_success "Setup completed!"
            print_status "Run '$0 start' to start all services"
            ;;
        "start")
            start_services "all"
            ;;
        "start-api")
            start_services "api"
            ;;
        "start-workers")
            start_services "workers"
            ;;
        "start-frontend")
            start_services "frontend"
            ;;
        "check")
            check_prerequisites
            check_kafka
            check_ports
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
