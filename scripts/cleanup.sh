#!/bin/bash

# Cleanup Healthcare Microservices Deployment
# This script cleans up the deployed healthcare microservices and resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="healthcare"
CLUSTER_NAME="healthcare-cluster"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Stop port forwarding
stop_port_forwarding() {
    log_info "Stopping port forwarding processes..."
    
    # Kill kubectl port-forward processes
    pkill -f "kubectl port-forward" || true
    
    log_success "Port forwarding stopped"
}

# Delete Kubernetes resources
cleanup_kubernetes() {
    log_info "Cleaning up Kubernetes resources..."
    
    # Delete Istio configurations
    if [ -d "../istio" ]; then
        kubectl delete -f ../istio/ --ignore-not-found=true
    fi
    
    # Delete monitoring resources
    if [ -d "../monitoring" ]; then
        kubectl delete -f ../monitoring/ --ignore-not-found=true
    fi
    
    # Delete application resources
    if [ -d "../k8s/base" ]; then
        kubectl delete -f ../k8s/base/ --ignore-not-found=true
    fi
    
    # Delete namespace (this will cascade delete everything in it)
    kubectl delete namespace ${NAMESPACE} --ignore-not-found=true
    
    log_success "Kubernetes resources cleaned up"
}

# Remove Docker images
cleanup_docker_images() {
    log_info "Cleaning up Docker images..."
    
    # Remove healthcare images
    docker rmi healthcare/patient-service:latest 2>/dev/null || true
    docker rmi healthcare/appointment-service:latest 2>/dev/null || true
    docker rmi healthcare/medical-records-service:latest 2>/dev/null || true
    
    # Clean up dangling images
    docker image prune -f || true
    
    log_success "Docker images cleaned up"
}

# Destroy kind cluster
destroy_cluster() {
    read -p "Do you want to destroy the entire kind cluster? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Destroying kind cluster..."
        kind delete cluster --name ${CLUSTER_NAME}
        log_success "Kind cluster destroyed"
    else
        log_info "Keeping kind cluster intact"
    fi
}

# Display cleanup summary
display_summary() {
    log_success "Cleanup completed!"
    echo
    echo "========================================"
    echo "Cleanup Summary"
    echo "========================================"
    echo "✅ Port forwarding processes stopped"
    echo "✅ Kubernetes resources deleted"
    echo "✅ Docker images removed"
    
    if kind get clusters | grep -q ${CLUSTER_NAME} 2>/dev/null; then
        echo "ℹ️  Kind cluster '${CLUSTER_NAME}' is still running"
        echo "   Run 'kind delete cluster --name ${CLUSTER_NAME}' to remove it"
    else
        echo "✅ Kind cluster destroyed"
    fi
    
    echo
    echo "To redeploy, run './build-and-deploy.sh'"
    echo "To reinstall everything, run './setup-wsl.sh'"
    echo
}

# Main execution
main() {
    log_info "Starting cleanup process..."
    
    stop_port_forwarding
    cleanup_kubernetes
    cleanup_docker_images
    destroy_cluster
    display_summary
}

# Run main function
main "$@"