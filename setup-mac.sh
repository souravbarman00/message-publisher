#!/bin/bash

# Message Publisher Development Setup Script for macOS
# This script is optimized for macOS with enhanced features and better integration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better UX
ROCKET="🚀"
CHECK="✅"
WARNING="⚠️"
ERROR="❌"
INFO="ℹ️"
GEAR="⚙️"
SPARKLE="✨"

# Function to print colored output with emojis
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

print_header() {
    echo -e "${PURPLE}${SPARKLE} $1 ${SPARKLE}${NC}"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if port is in use
port_in_use() {
    lsof -ti:$1 >/dev/null 2>&1
}

# Function to get macOS version
get_macos_version() {
    sw_vers -productVersion
}

# Function to check if Homebrew is installed
check_homebrew() {
    if ! command_exists brew; then
        print_warning "Homebrew not found. Would you like to install it? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_status "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    else
        print_success "Homebrew is installed: $(brew --version | head -1)"
    fi
}

# Enhanced prerequisites check for macOS
check_prerequisites() {
    print_header "System Prerequisites Check"
    
    # Check macOS version
    MACOS_VERSION=$(get_macos_version)
    print_status "macOS Version: $MACOS_VERSION"
    
    # Check Xcode Command Line Tools
    if xcode-select -p >/dev/null 2>&1; then
        print_success "Xcode Command Line Tools are installed"
    else
        print_warning "Installing Xcode Command Line Tools..."
        xcode-select --install
        print_status "Please complete the Xcode Command Line Tools installation and run this script again"
        exit 1
    fi
    
    # Check Homebrew
    check_homebrew
    
    # Check Node.js
    if ! command_exists node; then
        print_warning "Node.js is not installed. Would you like to install it via Homebrew? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_status "Installing Node.js via Homebrew..."
            brew install node
        else
            print_error "Node.js 18+ is required. Please install Node.js first."
            print_status "You can install it via: brew install node"
            exit 1
        fi
    fi
    
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VERSION" -lt 18 ]; then
        print_error "Node.js version 18+ is required. Current version: $(node -v)"
        print_status "Update with: brew upgrade node"
        exit 1
    fi
    print_success "Node.js $(node -v) is installed"
    
    # Check npm
    if ! command_exists npm; then
        print_error "npm is not installed."
        exit 1
    fi
    print_success "npm $(npm -v) is installed"
    
    # Check for optional tools
    if command_exists git; then
        print_success "Git is available: $(git --version | cut -d' ' -f3)"
    else
        print_warning "Git is not installed. Install with: brew install git"
    fi
    
    print_success "Prerequisites check completed!"
}

# Enhanced Kafka check with Homebrew integration
check_kafka() {
    print_status "Checking Kafka connectivity..."
    
    if nc -z localhost 9092 2>/dev/null; then
        print_success "Kafka is running on localhost:9092"
    else
        print_warning "Kafka is not running on localhost:9092"
        
        if command_exists brew; then
            if brew list kafka >/dev/null 2>&1; then
                print_status "Kafka is installed via Homebrew. You can start it with:"
                print_status "  brew services start kafka"
            else
                print_warning "Kafka not found. You can install it with:"
                print_status "  brew install kafka"
                print_status "  brew services start kafka"
            fi
        else
            print_warning "Please start Kafka before running the workers"
        fi
    fi
}

# Install dependencies with progress
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Check if we have a Brewfile for additional tools
    if [ -f "Brewfile" ]; then
        print_status "Installing system dependencies via Homebrew..."
        brew bundle
    fi
    
    # Function to install in directory with status
    install_in_dir() {
        local dir=$1
        local name=$2
        
        if [ -d "$dir" ] && [ -f "$dir/package.json" ]; then
            print_status "Installing $name dependencies..."
            cd "$dir"
            
            # Show package count
            if [ -f "package.json" ]; then
                PACKAGE_COUNT=$(grep -c '".*":' package.json | head -1)
                print_status "Found $PACKAGE_COUNT packages to install..."
            fi
            
            npm install --no-fund --no-audit
            cd ..
            print_success "$name dependencies installed"
        fi
    }
    
    # Root dependencies
    if [ -f "package.json" ]; then
        print_status "Installing root dependencies..."
        npm install --no-fund --no-audit
    fi
    
    # Install each service
    install_in_dir "api" "API"
    install_in_dir "workers" "Workers"
    install_in_dir "frontend" "Frontend"
    
    print_success "All dependencies installed successfully!"
}

# Enhanced environment setup
setup_env() {
    print_header "Environment Configuration"
    
    ENV_CREATED=0
    
    # Function to create env file with template
    create_env_file() {
        local dir=$1
        local service=$2
        
        if [ ! -f "$dir/.env" ]; then
            if [ -f "$dir/.env.example" ]; then
                print_status "Creating $service .env file from template..."
                cp "$dir/.env.example" "$dir/.env"
                ENV_CREATED=1
                print_success "$service .env file created"
            else
                print_warning "No .env.example found for $service"
            fi
        else
            print_status "$service .env file already exists"
        fi
    }
    
    create_env_file "api" "API"
    create_env_file "workers" "Workers"
    
    if [ $ENV_CREATED -eq 1 ]; then
        print_warning "Environment files created! Please configure them with your settings:"
        print_status "  - api/.env (API service configuration)"
        print_status "  - workers/.env (Worker services configuration)"
        print_status ""
        print_status "You can edit them now with your preferred editor:"
        print_status "  code api/.env workers/.env    # VS Code"
        print_status "  open -a TextEdit api/.env     # TextEdit"
        print_status "  nano api/.env                 # nano editor"
    fi
}

# Enhanced port checking
check_ports() {
    print_status "Checking port availability..."
    
    PORTS=(3000 4000 8080 9092)
    PORT_NAMES=("Frontend" "API" "Kafka-UI" "Kafka")
    
    for i in "${!PORTS[@]}"; do
        PORT=${PORTS[$i]}
        NAME=${PORT_NAMES[$i]}
        
        if port_in_use "$PORT"; then
            PROCESS=$(lsof -ti:"$PORT" | head -1)
            if [ ! -z "$PROCESS" ]; then
                PROCESS_NAME=$(ps -p "$PROCESS" -o comm= 2>/dev/null || echo "unknown")
                print_warning "Port $PORT is in use by $PROCESS_NAME (PID: $PROCESS) - $NAME"
            else
                print_warning "Port $PORT is in use - $NAME"
            fi
        else
            print_success "Port $PORT is available - $NAME"
        fi
    done
}

# Enhanced service startup with better macOS integration
start_services() {
    local service="${1:-all}"
    print_header "Starting Services"
    
    case "$service" in
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
            print_status "Starting all services in separate Terminal tabs..."
            
            # Create a new Terminal window with multiple tabs
            PROJECT_DIR=$(pwd)
            
            # Use osascript to create new Terminal tabs
            osascript <<EOF
tell application "Terminal"
    -- Create new window for API
    do script "cd '$PROJECT_DIR/api' && echo '${ROCKET} Starting API Service...' && npm run dev"
    delay 2
    
    -- Create new tab for Workers
    tell application "System Events" to keystroke "t" using command down
    do script "cd '$PROJECT_DIR/workers' && echo '${GEAR} Starting Worker Services...' && npm run dev:all" in front window
    delay 2
    
    -- Create new tab for Frontend
    tell application "System Events" to keystroke "t" using command down
    do script "cd '$PROJECT_DIR/frontend' && echo '${SPARKLE} Starting Frontend...' && npm start" in front window
    
    -- Bring Terminal to front
    activate
end tell
EOF
            
            print_success "All services started in separate Terminal tabs!"
            print_status "Services will be available at:"
            print_status "  ${SPARKLE} Frontend: http://localhost:3000"
            print_status "  ${GEAR} API: http://localhost:4000"
            print_status "  ${INFO} Health Check: http://localhost:4000/api/health"
            
            # Option to open in browser
            sleep 3
            print_status "Opening services in your default browser..."
            open "http://localhost:3000"
            ;;
        *)
            print_error "Unknown service: $service"
            print_error "Available options: api, workers, frontend, all"
            exit 1
            ;;
    esac
}

# System information display
show_system_info() {
    print_header "System Information"
    echo "macOS Version: $(get_macos_version)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    if command_exists brew; then
        echo "Homebrew Version: $(brew --version | head -1)"
    fi
    if command_exists node; then
        echo "Node.js Version: $(node -v)"
    fi
    if command_exists npm; then
        echo "npm Version: $(npm -v)"
    fi
}

# Enhanced help with macOS-specific information
show_help() {
    echo -e "${PURPLE}${ROCKET} Message Publisher Development Setup for macOS ${ROCKET}${NC}"
    echo ""
    echo "This script is optimized for macOS with enhanced features:"
    echo "  • Homebrew integration for system dependencies"
    echo "  • Native Terminal tab management"
    echo "  • Automatic browser launching"
    echo "  • macOS-specific system checks"
    echo ""
    echo -e "${CYAN}Usage:${NC} $0 [COMMAND]"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  setup          - Complete system setup with dependencies"
    echo "  start          - Start all services in separate Terminal tabs"
    echo "  start-api      - Start API service only"
    echo "  start-workers  - Start worker services only"
    echo "  start-frontend - Start frontend only"
    echo "  check          - Check system prerequisites and ports"
    echo "  info           - Show system information"
    echo "  open           - Open project URLs in browser"
    echo "  clean          - Clean node_modules and reinstall"
    echo "  help           - Show this help message"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $0 setup                    # Complete setup"
    echo "  $0 start                    # Start all services"
    echo "  $0 check                    # System check"
    echo "  $0 open                     # Open in browser"
    echo ""
    echo -e "${CYAN}macOS-specific features:${NC}"
    echo "  • Automatic Homebrew package management"
    echo "  • Native Terminal window/tab handling"
    echo "  • Integrated browser launching"
    echo "  • Xcode Command Line Tools checking"
}

# Clean installation
clean_install() {
    print_header "Cleaning Installation"
    print_warning "This will remove all node_modules directories. Continue? (y/N)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_status "Removing node_modules directories..."
        find . -name "node_modules" -type d -exec rm -rf {} + 2>/dev/null || true
        print_status "Removing package-lock.json files..."
        find . -name "package-lock.json" -delete 2>/dev/null || true
        print_success "Clean completed! Run '$0 setup' to reinstall."
    fi
}

# Open project URLs
open_urls() {
    print_status "Opening project URLs in browser..."
    open "http://localhost:3000" 2>/dev/null || print_warning "Frontend may not be running"
    open "http://localhost:4000/api/health" 2>/dev/null || print_warning "API may not be running"
}

# Main script logic with enhanced argument handling
main() {
    # Trap to handle interruption gracefully
    trap 'echo -e "\n${YELLOW}Script interrupted. Goodbye! 👋${NC}"; exit 1' INT
    
    # Default to setup if no arguments
    local cmd="${1:-setup}"
    
    case "$cmd" in
        "setup")
            print_header "Message Publisher Setup for macOS"
            check_prerequisites
            check_kafka
            install_dependencies
            setup_env
            check_ports
            print_success "Setup completed! ${ROCKET}"
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
        "info")
            show_system_info
            ;;
        "clean")
            clean_install
            ;;
        "open")
            open_urls
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $cmd"
            print_status "Run '$0 help' to see available commands"
            exit 1
            ;;
    esac
}

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_warning "This script is optimized for macOS. Use setup.sh for other Unix systems."
    print_status "Falling back to standard Unix behavior..."
fi

# Run main function with all arguments
main "$@"