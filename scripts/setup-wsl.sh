#!/bin/bash

# Healthcare Microservices Setup Script for Ubuntu WSL
# This script sets up the complete environment for running healthcare microservices
# with Kubernetes and Istio on Ubuntu WSL

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running in WSL
check_wsl() {
    if ! grep -qi microsoft /proc/version; then
        log_error "This script is designed to run on Ubuntu WSL"
        exit 1
    fi
    log_success "Running on Ubuntu WSL"
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    sudo apt-get update && sudo apt-get upgrade -y
    log_success "System packages updated"
}

# Install Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker is already installed"
        return
    fi
    
    log_info "Installing Docker..."
    
    # Install prerequisites
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up the repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo service docker start
    
    log_success "Docker installed successfully"
}

# Install kubectl
install_kubectl() {
    if command -v kubectl &> /dev/null; then
        log_info "kubectl is already installed"
        return
    fi
    
    log_info "Installing kubectl..."
    
    # Download kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    
    # Validate the binary
    curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
    echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check
    
    # Install kubectl
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm kubectl kubectl.sha256
    
    log_success "kubectl installed successfully"
}

# Install kind (Kubernetes in Docker)
install_kind() {
    if command -v kind &> /dev/null; then
        log_info "kind is already installed"
        return
    fi
    
    log_info "Installing kind..."
    
    # Download and install kind
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
    
    log_success "kind installed successfully"
}

# Install Helm , currently not used but may be needed for future enhancements
#install_helm() {
#    if command -v helm &> /dev/null; then
#        log_info "Helm is already installed"
#        return
#    fi
    
#    log_info "Installing Helm..."
    
#    curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
#    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
#    sudo apt-get update
#    sudo apt-get install -y helm
    
#    log_success "Helm installed successfully"
#}

# Install istioctl
install_istioctl() {
    if command -v istioctl &> /dev/null; then
        log_info "istioctl is already installed"
        return
    fi
    
    log_info "Installing istioctl..."
    
    # Download Istio
    curl -L https://istio.io/downloadIstio | sh -
    
    # Move istioctl to PATH
    sudo mv istio-*/bin/istioctl /usr/local/bin/
    
    # Clean up
    rm -rf istio-*
    
    log_success "istioctl installed successfully"
}

# Install additional tools
install_additional_tools() {
    log_info "Installing additional tools..."
    
    sudo apt-get install -y \
        curl \
        wget \
        git \
        jq \
        tree \
        htop \
        net-tools \
        iputils-ping \
        telnet \
        vim \
        nano
    
    log_success "Additional tools installed successfully"
}

# Create kind cluster
create_kind_cluster() {
    log_info "Creating kind cluster..."
    
    # Create cluster config
    cat <<EOF > /tmp/kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: healthcare-cluster
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 15021
    hostPort: 15021
    protocol: TCP
- role: worker
- role: worker
EOF
    
    # Create the cluster
    kind create cluster --config=/tmp/kind-config.yaml
    
    # Export kubeconfig to ensure kubectl can connect
    kind export kubeconfig --name healthcare-cluster
    
    # Set kubectl context
    kubectl cluster-info --context kind-healthcare-cluster
    
    log_success "Kind cluster created successfully"
}

# Install Istio
install_istio() {
    log_info "Installing Istio..."
    
    # Install Istio with demo profile
    istioctl install --set values.defaultRevision=default -y
    
    # Label default namespace for Istio injection
    kubectl label namespace default istio-injection=enabled --overwrite
    
    # Wait for Istio pods to be ready
    kubectl wait --for=condition=ready pod -l app=istiod -n istio-system --timeout=300s
    
    log_success "Istio installed successfully"
}

# Install monitoring stack
install_monitoring() {
    log_info "Installing monitoring stack..."
    
    # Apply monitoring configurations
    kubectl apply -f ../monitoring/
    
    # Wait for monitoring components to be ready
    log_info "Waiting for monitoring components to be ready..."
    kubectl wait --for=condition=ready pod -l app=prometheus -n istio-system --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n istio-system --timeout=300s
    kubectl wait --for=condition=ready pod -l app=jaeger -n istio-system --timeout=300s
    
    log_success "Monitoring stack installed successfully"
}

# Main execution
main() {
    log_info "Starting Healthcare Microservices setup for Ubuntu WSL..."
    
    check_wsl
    update_system
    install_docker
    install_kubectl
    install_kind
#    install_helm
    install_istioctl
    install_additional_tools
    create_kind_cluster
    install_istio
    install_monitoring
    
    log_success "Setup completed successfully!"
    log_info "Next steps:"
    echo "  1. Either:"
    echo "     - Restart your terminal/WSL session to apply Docker group changes, OR"
    echo "     - Run 'sudo service docker restart' and then 'docker ps' to test Docker access"
    echo "  2. Verify Docker works: sudo docker ps"
    echo "  3. Fix kubectl context: kind export kubeconfig --name healthcare-cluster"
    echo "  4. Verify cluster connection: kubectl cluster-info"
    echo "  5. Run './build-and-deploy.sh' to build and deploy the healthcare services"
    echo "  6. Access the services:"
    echo "     - Grafana: http://localhost:3000 (admin/admin123)"
    echo "     - Kiali: http://localhost:20001"
    echo "     - Jaeger: http://localhost:16686"
}

# Run main function
main "$@"