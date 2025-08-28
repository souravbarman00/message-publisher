#!/bin/bash

# 🔄 Message Publisher Rollback Script
# This script allows you to rollback to a previous Docker image version

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DOCKER_IMAGES_PATH="${DOCKER_IMAGES_PATH:-/var/jenkins/docker-images}"
PROJECT_NAME="message-publisher"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Functions
print_header() {
    echo -e "${BLUE}🔄 Message Publisher Rollback Utility${NC}"
    echo -e "${BLUE}=================================${NC}"
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

# Check if Docker is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not available in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Docker is available"
}

# List available versions
list_versions() {
    local manifest_path="$DOCKER_IMAGES_PATH/manifests"
    
    if [ ! -d "$manifest_path" ]; then
        print_error "Manifests directory not found: $manifest_path"
        print_info "Make sure Jenkins pipeline has run at least once"
        return 1
    fi
    
    echo -e "${BLUE}📦 Available Versions:${NC}"
    echo "----------------------------------------"
    
    local count=0
    for manifest in "$manifest_path"/build-*.json; do
        if [ -f "$manifest" ]; then
            local version=$(basename "$manifest" | sed 's/build-//g' | sed 's/.json//g')
            local build_info=$(jq -r '.build | "Build #\(.number) | \(.timestamp) | \(.commit)"' "$manifest" 2>/dev/null || echo "Invalid manifest")
            
            # Check if this is the current version
            if [ -L "$manifest_path/latest.json" ]; then
                local current_target=$(readlink "$manifest_path/latest.json")
                if [ "$(basename "$current_target")" = "build-${version}.json" ]; then
                    echo -e "${GREEN}👆 $version ${NC}(CURRENT) - $build_info"
                else
                    echo "   $version - $build_info"
                fi
            else
                echo "   $version - $build_info"
            fi
            
            ((count++))
        fi
    done
    
    if [ $count -eq 0 ]; then
        print_warning "No versions found"
        return 1
    fi
    
    echo "----------------------------------------"
    echo "Total versions available: $count"
    echo ""
}

# Get version details
get_version_details() {
    local version="$1"
    local manifest_file="$DOCKER_IMAGES_PATH/manifests/build-${version}.json"
    
    if [ ! -f "$manifest_file" ]; then
        print_error "Version $version not found"
        return 1
    fi
    
    echo -e "${BLUE}📋 Version Details: $version${NC}"
    echo "----------------------------------------"
    
    # Parse manifest using jq if available
    if command -v jq &> /dev/null; then
        echo "Build Number: $(jq -r '.build.number' "$manifest_file")"
        echo "Timestamp: $(jq -r '.build.timestamp' "$manifest_file")"
        echo "Commit: $(jq -r '.build.commit' "$manifest_file")"
        echo "Branch: $(jq -r '.build.branch' "$manifest_file")"
        echo ""
        echo "Images:"
        jq -r '.images | to_entries[] | "  \(.key): \(.value.name)"' "$manifest_file"
        echo ""
        echo "Image Sizes:"
        jq -r '.images | to_entries[] | "  \(.key): \(.value.size | tonumber / 1024 / 1024 | floor)MB"' "$manifest_file" 2>/dev/null || echo "  Size information not available"
    else
        print_warning "jq not available, showing raw manifest:"
        cat "$manifest_file"
    fi
    
    echo "----------------------------------------"
}

# Verify image files exist
verify_images() {
    local version="$1"
    local manifest_file="$DOCKER_IMAGES_PATH/manifests/build-${version}.json"
    
    print_info "Verifying image files exist..."
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is required for rollback operations"
        print_info "Install jq: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
        return 1
    fi
    
    local services=("api" "frontend" "workers")
    
    for service in "${services[@]}"; do
        local image_file=$(jq -r ".images.${service}.file" "$manifest_file")
        
        if [ "$image_file" = "null" ] || [ ! -f "$image_file" ]; then
            print_error "Image file not found for $service: $image_file"
            return 1
        fi
        
        print_success "$service image verified: $(basename "$image_file")"
    done
    
    return 0
}

# Load Docker images
load_images() {
    local version="$1"
    local manifest_file="$DOCKER_IMAGES_PATH/manifests/build-${version}.json"
    
    print_info "Loading Docker images for version: $version"
    
    local services=("api" "frontend" "workers")
    
    for service in "${services[@]}"; do
        local image_file=$(jq -r ".images.${service}.file" "$manifest_file")
        local image_name=$(jq -r ".images.${service}.name" "$manifest_file")
        
        print_info "Loading $service image..."
        if docker load -i "$image_file"; then
            print_success "$service image loaded: $image_name"
        else
            print_error "Failed to load $service image"
            return 1
        fi
    done
    
    return 0
}

# Tag images as latest
tag_as_latest() {
    local version="$1"
    local manifest_file="$DOCKER_IMAGES_PATH/manifests/build-${version}.json"
    
    print_info "Tagging images as latest..."
    
    local services=("api" "frontend" "workers")
    
    for service in "${services[@]}"; do
        local image_name=$(jq -r ".images.${service}.name" "$manifest_file")
        local latest_tag="${PROJECT_NAME}-${service}:latest"
        
        if docker tag "$image_name" "$latest_tag"; then
            print_success "$service tagged as latest"
        else
            print_error "Failed to tag $service as latest"
            return 1
        fi
    done
    
    return 0
}

# Update latest manifest
update_latest_manifest() {
    local version="$1"
    local manifest_file="$DOCKER_IMAGES_PATH/manifests/build-${version}.json"
    local latest_file="$DOCKER_IMAGES_PATH/manifests/latest.json"
    
    print_info "Updating latest manifest..."
    
    if cp "$manifest_file" "$latest_file"; then
        print_success "Latest manifest updated"
    else
        print_error "Failed to update latest manifest"
        return 1
    fi
    
    return 0
}

# Perform rollback
perform_rollback() {
    local version="$1"
    
    print_header
    print_info "🔄 Starting rollback to version: $version"
    echo ""
    
    # Step 1: Verify version exists
    get_version_details "$version" || return 1
    echo ""
    
    # Step 2: Verify image files
    verify_images "$version" || return 1
    echo ""
    
    # Step 3: Confirm rollback
    print_warning "⚠️  This will rollback to version $version"
    print_warning "Current deployments using 'latest' tags will use the rolled-back images"
    echo ""
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Rollback cancelled"
        return 0
    fi
    
    echo ""
    print_info "🚀 Proceeding with rollback..."
    echo ""
    
    # Step 4: Load images
    load_images "$version" || return 1
    echo ""
    
    # Step 5: Tag as latest
    tag_as_latest "$version" || return 1
    echo ""
    
    # Step 6: Update latest manifest
    update_latest_manifest "$version" || return 1
    echo ""
    
    print_success "🎉 Rollback completed successfully!"
    echo ""
    print_info "Next steps:"
    echo "1. Restart your services using the updated 'latest' tags"
    echo "2. Verify the application is working correctly"
    echo "3. Monitor logs for any issues"
    echo ""
    print_info "Rollback commands for different deployment methods:"
    echo ""
    echo "📦 Docker Compose:"
    echo "   cd $PROJECT_ROOT"
    echo "   docker-compose down"
    echo "   docker-compose up -d"
    echo ""
    echo "⚙️  Kubernetes:"
    echo "   kubectl rollout restart deployment message-publisher-api"
    echo "   kubectl rollout restart deployment message-publisher-frontend"
    echo "   kubectl rollout restart deployment message-publisher-workers"
    echo ""
    echo "🐳 Docker Swarm:"
    echo "   docker service update --force message-publisher-api"
    echo "   docker service update --force message-publisher-frontend"
    echo "   docker service update --force message-publisher-workers"
    
    return 0
}

# Show current version
show_current_version() {
    local latest_file="$DOCKER_IMAGES_PATH/manifests/latest.json"
    
    if [ ! -f "$latest_file" ]; then
        print_warning "No current version information found"
        return 1
    fi
    
    echo -e "${BLUE}📍 Current Version:${NC}"
    echo "----------------------------------------"
    
    if command -v jq &> /dev/null; then
        echo "Build Number: $(jq -r '.build.number' "$latest_file")"
        echo "Version: $(jq -r '.build.version' "$latest_file")"
        echo "Timestamp: $(jq -r '.build.timestamp' "$latest_file")"
        echo "Commit: $(jq -r '.build.commit' "$latest_file")"
        echo "Branch: $(jq -r '.build.branch' "$latest_file")"
    else
        print_warning "jq not available, showing raw latest.json:"
        cat "$latest_file"
    fi
    
    echo "----------------------------------------"
    echo ""
}

# Show help
show_help() {
    echo -e "${BLUE}🔄 Message Publisher Rollback Utility${NC}"
    echo ""
    echo "Usage: $0 [COMMAND] [VERSION]"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo "  list                    - List all available versions"
    echo "  current                 - Show current version information"
    echo "  details <version>       - Show details for specific version"
    echo "  rollback <version>      - Rollback to specific version"
    echo "  verify <version>        - Verify version files exist"
    echo "  help                    - Show this help message"
    echo ""
    echo -e "${BLUE}Examples:${NC}"
    echo "  $0 list                           # List available versions"
    echo "  $0 current                        # Show current version"
    echo "  $0 details 1-abc123-20240828      # Show version details"
    echo "  $0 rollback 1-abc123-20240828     # Rollback to version"
    echo "  $0 verify 1-abc123-20240828       # Verify version exists"
    echo ""
    echo -e "${BLUE}Environment Variables:${NC}"
    echo "  DOCKER_IMAGES_PATH      - Path to Docker images directory"
    echo "                           (default: /var/jenkins/docker-images)"
    echo ""
    echo -e "${BLUE}Requirements:${NC}"
    echo "  - Docker installed and running"
    echo "  - jq installed (for JSON parsing)"
    echo "  - Access to Jenkins Docker images directory"
    echo ""
}

# Interactive mode
interactive_mode() {
    print_header
    
    while true; do
        echo -e "${BLUE}🔄 Rollback Menu${NC}"
        echo "1. List available versions"
        echo "2. Show current version"
        echo "3. Show version details"
        echo "4. Perform rollback"
        echo "5. Verify version"
        echo "6. Exit"
        echo ""
        read -p "Choose an option (1-6): " choice
        
        case $choice in
            1)
                echo ""
                list_versions
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            2)
                echo ""
                show_current_version
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            3)
                echo ""
                read -p "Enter version: " version
                if [ -n "$version" ]; then
                    echo ""
                    get_version_details "$version"
                fi
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            4)
                echo ""
                list_versions
                echo ""
                read -p "Enter version to rollback to: " version
                if [ -n "$version" ]; then
                    perform_rollback "$version"
                    break
                fi
                ;;
            5)
                echo ""
                read -p "Enter version to verify: " version
                if [ -n "$version" ]; then
                    echo ""
                    verify_images "$version"
                fi
                echo ""
                read -p "Press Enter to continue..."
                clear
                ;;
            6)
                print_info "Goodbye! 👋"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1-6."
                sleep 1
                clear
                ;;
        esac
    done
}

# Main execution
main() {
    # Check if Docker is available
    check_docker
    
    # Handle command line arguments
    case "${1:-}" in
        "list")
            list_versions
            ;;
        "current")
            show_current_version
            ;;
        "details")
            if [ -z "$2" ]; then
                print_error "Version required for details command"
                echo "Usage: $0 details <version>"
                exit 1
            fi
            get_version_details "$2"
            ;;
        "rollback")
            if [ -z "$2" ]; then
                print_error "Version required for rollback command"
                echo "Usage: $0 rollback <version>"
                exit 1
            fi
            perform_rollback "$2"
            ;;
        "verify")
            if [ -z "$2" ]; then
                print_error "Version required for verify command"
                echo "Usage: $0 verify <version>"
                exit 1
            fi
            verify_images "$2"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        "")
            # No arguments - start interactive mode
            interactive_mode
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"