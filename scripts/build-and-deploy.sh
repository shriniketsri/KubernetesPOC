#!/bin/bash

# Build and Deploy Healthcare Microservices
# This script builds Docker images and deploys the healthcare microservices to Kubernetes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="healthcare"
TAG="latest"
NAMESPACE="healthcare"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if Kind cluster exists and set context
    if kind get clusters | grep -q "healthcare-cluster"; then
        log_info "Setting kubectl context to healthcare-cluster..."
        kind export kubeconfig --name healthcare-cluster || true
        kubectl config use-context kind-healthcare-cluster || true
    fi
    
    # Check if kubectl is configured (try both regular and sudo)
    if kubectl cluster-info &> /dev/null; then
        log_info "kubectl configured successfully"
    elif sudo kubectl cluster-info &> /dev/null; then
        log_warning "kubectl requires sudo - using sudo for all kubectl commands"
        # Create alias for kubectl with sudo
        alias kubectl="sudo kubectl"
    else
        log_error "kubectl is not configured or cluster is not accessible"
        log_info "Try running: kind export kubeconfig --name healthcare-cluster"
        exit 1
    fi
    
    # Check if kind cluster exists
    if ! kind get clusters | grep -q healthcare-cluster; then
        log_error "healthcare-cluster not found. Please run setup-wsl.sh first."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Pre-load base images into Kind cluster to avoid SSL issues
preload_base_images() {
    log_info "Pre-loading base images into Kind cluster..."
    
    # Pull and load MongoDB image
    docker pull mongo:7.0 || log_warning "Failed to pull mongo:7.0 - will try alternative"
    if docker images | grep -q "mongo.*7.0"; then
        kind load docker-image mongo:7.0 --name healthcare-cluster
        log_success "MongoDB image loaded into cluster"
    fi
    
    # Pull and load PostgreSQL image  
    docker pull postgres:15-alpine || log_warning "Failed to pull postgres:15-alpine - will try alternative"
    if docker images | grep -q "postgres.*15-alpine"; then
        kind load docker-image postgres:15-alpine --name healthcare-cluster
        log_success "PostgreSQL image loaded into cluster"
    fi
}

# Build Docker images
build_images() {
    log_info "Building Docker images..."
    
    # Patient Service (Node.js)
    log_info "Checking patient-service image..."
    if docker images | grep -q "${REGISTRY}/patient-service.*${TAG}"; then
        log_info "Patient service image already exists, loading into cluster..."
        kind load docker-image ${REGISTRY}/patient-service:${TAG} --name healthcare-cluster
        log_success "Patient service image loaded"
    else
        log_info "Building patient-service..."
        cd ../services/patient-service
        if docker build -t ${REGISTRY}/patient-service:${TAG} .; then
            kind load docker-image ${REGISTRY}/patient-service:${TAG} --name healthcare-cluster
            log_success "Patient service image built and loaded"
        else
            log_error "Failed to build patient-service image"
            exit 1
        fi
        cd -
    fi
    
    # Appointment Service (Python)
    log_info "Checking appointment-service image..."
    if docker images | grep -q "${REGISTRY}/appointment-service.*${TAG}"; then
        log_info "Appointment service image already exists, loading into cluster..."
        kind load docker-image ${REGISTRY}/appointment-service:${TAG} --name healthcare-cluster
        log_success "Appointment service image loaded"
    else
        log_info "Building appointment-service..."
        cd ../services/appointment-service
        if docker build -t ${REGISTRY}/appointment-service:${TAG} .; then
            kind load docker-image ${REGISTRY}/appointment-service:${TAG} --name healthcare-cluster
            log_success "Appointment service image built and loaded"
        else
            log_error "Failed to build appointment-service image"
            exit 1
        fi
        cd -
    fi
    
    # Medical Records Service (Go)
    log_info "Checking medical-records-service image..."
    if docker images | grep -q "${REGISTRY}/medical-records-service.*${TAG}"; then
        log_info "Medical records service image already exists, loading into cluster..."
        kind load docker-image ${REGISTRY}/medical-records-service:${TAG} --name healthcare-cluster
        log_success "Medical records service image loaded"
    else
        log_info "Building medical-records-service..."
        cd ../services/medical-records-service
        if docker build -t ${REGISTRY}/medical-records-service:${TAG} .; then
            kind load docker-image ${REGISTRY}/medical-records-service:${TAG} --name healthcare-cluster
            log_success "Medical records service image built and loaded"
        else
            log_error "Failed to build medical-records-service image"
            exit 1
        fi
        cd -
        
        # Build healthcare dashboard
        log_info "Building healthcare dashboard..."
        cd ../services/healthcare-dashboard
        if docker build -t ${REGISTRY}/healthcare-dashboard:${TAG} .; then
            kind load docker-image ${REGISTRY}/healthcare-dashboard:${TAG} --name healthcare-cluster
            log_success "Healthcare dashboard image built and loaded"
        else
            log_error "Failed to build healthcare-dashboard image"
            exit 1
        fi
        cd -
    fi

    log_success "All images built and loaded successfully"
    
    # Restart deployments to pick up newly loaded images
    log_info "Restarting deployments to pick up new images..."
    kubectl rollout restart deployment/patient-service -n ${NAMESPACE} || true
    kubectl rollout restart deployment/appointment-service -n ${NAMESPACE} || true
    kubectl rollout restart deployment/medical-records-service -n ${NAMESPACE} || true
    kubectl rollout restart deployment/healthcare-dashboard -n ${NAMESPACE} || true
}

# Deploy to Kubernetes
deploy_kubernetes() {
    log_info "Deploying to Kubernetes..."
    
    # Apply base manifests in order
    kubectl apply -f ../k8s/base/namespace.yaml
    kubectl apply -f ../k8s/base/configmaps.yaml
    kubectl apply -f ../k8s/base/secrets.yaml
    kubectl apply -f ../k8s/base/rbac.yaml
    kubectl apply -f ../k8s/base/mongo.yaml
    kubectl apply -f ../k8s/base/postgres.yaml
    kubectl apply -f ../k8s/base/patient-service.yaml
    kubectl apply -f ../k8s/base/appointment-service.yaml
    kubectl apply -f ../k8s/base/medical-records-service.yaml
    kubectl apply -f ../k8s/base/healthcare-dashboard.yaml
    
    # Wait for namespace to be available (check if exists)
    while ! kubectl get namespace ${NAMESPACE} &> /dev/null; do
        log_info "Waiting for namespace ${NAMESPACE} to be available..."
        sleep 5
    done
    log_success "Namespace ${NAMESPACE} is available"
    
    # Wait for databases to be ready
    log_info "Waiting for databases to be ready..."
    if ! kubectl wait --for=condition=ready pod -l app=mongo -n ${NAMESPACE} --timeout=300s; then
        log_warning "MongoDB pods not ready - checking status..."
        kubectl get pods -l app=mongo -n ${NAMESPACE}
        kubectl describe pods -l app=mongo -n ${NAMESPACE} | grep -A 10 "Events:"
    fi
    
    if ! kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s; then
        log_warning "PostgreSQL pods not ready - checking status..."
        kubectl get pods -l app=postgres -n ${NAMESPACE}
        kubectl describe pods -l app=postgres -n ${NAMESPACE} | grep -A 10 "Events:"
    fi
    
    # Wait for services to be ready
    log_info "Waiting for healthcare services to be ready..."
    if ! kubectl wait --for=condition=ready pod -l app=patient-service -n ${NAMESPACE} --timeout=300s; then
        log_warning "Patient service not ready - checking status..."
        kubectl get pods -l app=patient-service -n ${NAMESPACE}
        kubectl describe pods -l app=patient-service -n ${NAMESPACE} | grep -A 10 "Events:"
    fi
    
    if ! kubectl wait --for=condition=ready pod -l app=appointment-service -n ${NAMESPACE} --timeout=300s; then
        log_warning "Appointment service not ready - checking status..."
        kubectl get pods -l app=appointment-service -n ${NAMESPACE}
        kubectl describe pods -l app=appointment-service -n ${NAMESPACE} | grep -A 10 "Events:"
    fi
    
    if ! kubectl wait --for=condition=ready pod -l app=medical-records-service -n ${NAMESPACE} --timeout=300s; then
        log_warning "Medical records service not ready - checking status..."
        kubectl get pods -l app=medical-records-service -n ${NAMESPACE}
        kubectl describe pods -l app=medical-records-service -n ${NAMESPACE} | grep -A 10 "Events:"
    fi
    
    log_success "Kubernetes deployment completed"
}

# Deploy Istio configurations
deploy_istio() {
    log_info "Deploying Istio configurations..."
    
    # Apply Istio configurations
    kubectl apply -f ../istio/
    kubectl apply -f ../k8s/istio/dashboard-gateway.yaml
    
    # Wait for virtual services to be applied
    sleep 10
    
    log_success "Istio configurations deployed"
}

# Setup port forwarding
setup_port_forwarding() {
    log_info "Setting up port forwarding..."
    
    # Kill any existing port-forward processes
    pkill -f "kubectl port-forward" || true
    
    # Wait a bit for processes to clean up
    sleep 2
    
    # Port forward for services
    kubectl port-forward -n ${NAMESPACE} svc/patient-service 3001:3001 &
    kubectl port-forward -n ${NAMESPACE} svc/appointment-service 3002:3002 &
    kubectl port-forward -n ${NAMESPACE} svc/medical-records-service 3003:3003 &
    
    # Port forward for monitoring
    kubectl port-forward -n istio-system svc/grafana 3000:3000 &
    kubectl port-forward -n istio-system svc/prometheus 9090:9090 &
    kubectl port-forward -n istio-system svc/jaeger-query 16686:16686 &
    kubectl port-forward -n istio-system svc/kiali 20001:20001 &
    
    # Port forward for Istio Ingress Gateway
    kubectl port-forward -n istio-system svc/istio-ingressgateway 8080:80 &
    kubectl port-forward -n istio-system svc/istio-ingressgateway 8443:443 &
    
    log_success "Port forwarding setup completed"
}

# Health check
health_check() {
    log_info "Performing health checks..."
    
    # Wait for services to be accessible
    sleep 30
    
    # Check service health
    local services=("patient-service:3001" "appointment-service:3002" "medical-records-service:3003")
    
    for service in "${services[@]}"; do
        IFS=':' read -r name port <<< "$service"
        log_info "Checking $name health..."
        
        for i in {1..10}; do
            if curl -s http://localhost:$port/health > /dev/null; then
                log_success "$name is healthy"
                break
            else
                if [ $i -eq 10 ]; then
                    log_warning "$name health check failed after 10 attempts"
                else
                    log_info "Attempt $i failed, retrying in 10 seconds..."
                    sleep 10
                fi
            fi
        done
    done
}

# Display access information
display_info() {
    log_success "Deployment completed successfully!"
    echo
    echo "==========================================="
    echo "Healthcare Microservices Access Information"
    echo "==========================================="
    echo
    echo "🏥 Healthcare Services:"
    echo "  Patient Service:       http://localhost:3001"
    echo "  Appointment Service:   http://localhost:3002"
    echo "  Medical Records:       http://localhost:3003"
    echo
    echo "📊 Monitoring & Observability:"
    echo "  Grafana:              http://localhost:3000 (admin/admin123)"
    echo "  Prometheus:           http://localhost:9090"
    echo "  Jaeger (Tracing):     http://localhost:16686"
    echo "  Kiali (Service Mesh): http://localhost:20001"
    echo
    echo "🌐 API Gateway:"
    echo "  Istio Gateway:        http://localhost:8080"
    echo "  HTTPS Gateway:        https://localhost:8443"
    echo
    echo "📚 API Endpoints (via Gateway):"
    echo "  Patients:    GET/POST    http://localhost:8080/api/patients"
    echo "  Patient:     GET/PUT/DEL http://localhost:8080/api/patients/{id}"
    echo "  Appointments: GET/POST   http://localhost:8080/api/appointments"
    echo "  Appointment:  GET/PUT/DEL http://localhost:8080/api/appointments/{id}"
    echo "  Availability: GET        http://localhost:8080/api/availability/{doctor_id}"
    echo "  Records:      GET/POST   http://localhost:8080/api/medical-records"
    echo "  Record:       GET/PUT/DEL http://localhost:8080/api/medical-records/{id}"
    echo
    echo "🔧 Management Commands:"
    echo "  View Pods:       kubectl get pods -n healthcare"
    echo "  View Services:   kubectl get services -n healthcare"
    echo "  View Logs:       kubectl logs -f <pod-name> -n healthcare"
    echo "  Stop Deployment: ./cleanup.sh"
    echo
    echo "Note: All port-forwards are running in the background."
    echo "Use 'ps aux | grep kubectl' to see active port-forward processes."
    echo
}

# Main execution
main() {
    log_info "Starting build and deployment process..."
    
    check_prerequisites
    preload_base_images
    build_images
    deploy_kubernetes
    deploy_istio
    setup_port_forwarding
    health_check
    display_info
}

# Run main function
main "$@"