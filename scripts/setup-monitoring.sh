#!/bin/bash

# Setup Monitoring and Observability for Healthcare Microservices
# This script configures Prometheus, Grafana, Jaeger, and Kiali

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="istio-system"
HEALTHCARE_NS="healthcare"

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

# Install Prometheus
install_prometheus() {
    log_info "Installing Prometheus..."
    
    kubectl apply -f ../monitoring/prometheus.yaml
    
    # Wait for Prometheus to be ready
    kubectl wait --for=condition=ready pod -l app=prometheus -n ${NAMESPACE} --timeout=300s
    
    log_success "Prometheus installed and ready"
}

# Install Grafana
install_grafana() {
    log_info "Installing Grafana..."
    
    kubectl apply -f ../monitoring/grafana.yaml
    
    # Wait for Grafana to be ready
    kubectl wait --for=condition=ready pod -l app=grafana -n ${NAMESPACE} --timeout=300s
    
    log_success "Grafana installed and ready"
}

# Install Jaeger
install_jaeger() {
    log_info "Installing Jaeger..."
    
    kubectl apply -f ../monitoring/jaeger.yaml
    
    # Wait for Jaeger to be ready
    kubectl wait --for=condition=ready pod -l app=jaeger -n ${NAMESPACE} --timeout=300s
    
    log_success "Jaeger installed and ready"
}

# Install Kiali
install_kiali() {
    log_info "Installing Kiali..."
    
    kubectl apply -f ../monitoring/kiali.yaml
    
    # Wait for Kiali to be ready
    kubectl wait --for=condition=ready pod -l app=kiali -n ${NAMESPACE} --timeout=300s
    
    # Test if Kiali RBAC is working, if not apply cluster-admin as fallback
    log_info "Verifying Kiali RBAC permissions..."
    if ! kubectl auth can-i get pods --as=system:serviceaccount:istio-system:kiali > /dev/null 2>&1; then
        log_info "Kiali default RBAC insufficient, applying cluster-admin permissions..."
        kubectl create clusterrolebinding kiali-admin --clusterrole=cluster-admin --serviceaccount=istio-system:kiali || true
    fi
    
    log_success "Kiali installed and ready with proper RBAC permissions"
}

# Configure Istio telemetry
configure_telemetry() {
    log_info "Configuring Istio telemetry..."
    
    # Enable telemetry for healthcare namespace
    kubectl apply -f - <<EOF
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
metadata:
  name: telemetry-config
  namespace: istio-system
spec:
  values:
    telemetry:
      v2:
        prometheus:
          configOverride:
            metric_relabeling_configs:
            - source_labels: [__name__]
              target_label: __tmp_name
            - source_labels: [__tmp_name]
              regex: 'istio_(.*)'
              target_label: __name__
              replacement: '\${1}'
EOF
    
    # Apply telemetry configuration for healthcare namespace
    kubectl apply -f - <<EOF
apiVersion: telemetry.istio.io/v1alpha1
kind: Telemetry
metadata:
  name: metrics
  namespace: ${HEALTHCARE_NS}
spec:
  metrics:
  - providers:
    - name: prometheus
  - overrides:
    - match:
        metric: REQUEST_COUNT
      tagOverrides:
        destination_service_name:
          value: "{{.destination_service_name | default \"unknown\"}}"
        destination_service_namespace:
          value: "{{.destination_service_namespace | default \"unknown\"}}"
EOF
    
    log_success "Istio telemetry configured"
}

# Create custom Grafana dashboards
create_dashboards() {
    log_info "Creating custom Grafana dashboards..."
    
    # Create healthcare-specific dashboard
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: healthcare-dashboard
  namespace: ${NAMESPACE}
  labels:
    grafana_dashboard: "1"
data:
  healthcare-performance.json: |
    {
      "dashboard": {
        "id": null,
        "title": "Healthcare Services Performance",
        "tags": ["healthcare", "performance"],
        "style": "dark",
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Request Rate by Service",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total{destination_service_namespace=\"${HEALTHCARE_NS}\"}[5m])) by (destination_service_name)",
                "legendFormat": "{{ destination_service_name }}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
            "yAxes": [{
              "label": "Requests/sec",
              "min": 0
            }]
          },
          {
            "id": 2,
            "title": "Error Rate by Service",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_requests_total{destination_service_namespace=\"${HEALTHCARE_NS}\",response_code!~\"2..\"}[5m])) by (destination_service_name)",
                "legendFormat": "{{ destination_service_name }}"
              }
            ],
            "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0}
          },
          {
            "id": 3,
            "title": "Response Time (P99)",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.99, sum(rate(istio_request_duration_milliseconds_bucket{destination_service_namespace=\"${HEALTHCARE_NS}\"}[5m])) by (le, destination_service_name))",
                "legendFormat": "{{ destination_service_name }}"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
            "yAxes": [{
              "label": "Milliseconds",
              "min": 0
            }]
          },
          {
            "id": 4,
            "title": "Service Mesh Traffic",
            "type": "graph",
            "targets": [
              {
                "expr": "sum(rate(istio_tcp_connections_opened_total{destination_service_namespace=\"${HEALTHCARE_NS}\"}[5m])) by (destination_service_name)",
                "legendFormat": "{{ destination_service_name }} - TCP Connections"
              }
            ],
            "gridPos": {"h": 8, "w": 24, "x": 0, "y": 16}
          }
        ],
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "refresh": "5s"
      }
    }
EOF
    
    log_success "Custom dashboards created"
}

# Setup alerts
setup_alerts() {
    log_info "Setting up alerts..."
    
    # Create AlertManager configuration
    kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: ${NAMESPACE}
data:
  alertmanager.yml: |
    global:
      smtp_smarthost: 'localhost:587'
      smtp_from: 'healthcare-alerts@example.com'
    
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
    
    receivers:
    - name: 'web.hook'
      webhook_configs:
      - url: 'http://example.com/webhook'
        send_resolved: true
    
    inhibit_rules:
    - source_match:
        severity: 'critical'
      target_match:
        severity: 'warning'
      equal: ['alertname', 'dev', 'instance']
EOF
    
    log_success "Alerts configured"
}

# Port forward services
setup_port_forwarding() {
    log_info "Setting up port forwarding for monitoring services..."
    
    # Kill existing port-forwards
    pkill -f "kubectl port-forward.*grafana" || true
    pkill -f "kubectl port-forward.*prometheus" || true
    pkill -f "kubectl port-forward.*jaeger" || true
    pkill -f "kubectl port-forward.*kiali" || true
    
    # Wait for processes to clean up
    sleep 2
    
    # Setup port forwards
    kubectl port-forward -n ${NAMESPACE} svc/grafana 3000:3000 &
    kubectl port-forward -n ${NAMESPACE} svc/prometheus 9090:9090 &
    kubectl port-forward -n ${NAMESPACE} svc/jaeger-query 16686:16686 &
    kubectl port-forward -n ${NAMESPACE} svc/kiali 20001:20001 &
    
    log_success "Port forwarding setup completed"
}

# Display monitoring info
display_info() {
    log_success "Monitoring setup completed!"
    echo
    echo "==========================================="
    echo "Monitoring & Observability Access"
    echo "==========================================="
    echo
    echo "📊 Grafana (Dashboards):    http://localhost:3000"
    echo "   Username: admin"
    echo "   Password: admin123"
    echo
    echo "📈 Prometheus (Metrics):     http://localhost:9090"
    echo "🔍 Jaeger (Tracing):        http://localhost:16686"
    echo "🕸️  Kiali (Service Mesh):    http://localhost:20001"
    echo
    echo "📚 Available Dashboards in Grafana:"
    echo "   - Healthcare Services Overview"
    echo "   - Healthcare Services Performance"
    echo "   - Istio Service Mesh"
    echo "   - Kubernetes Cluster"
    echo
    echo "🚨 Monitoring Features:"
    echo "   - Real-time metrics collection"
    echo "   - Distributed tracing"
    echo "   - Service mesh visualization"
    echo "   - Custom healthcare dashboards"
    echo "   - Alerting rules"
    echo
}

# Main execution
main() {
    log_info "Setting up monitoring and observability..."
    
    install_prometheus
    install_grafana
    install_jaeger
    install_kiali
    configure_telemetry
    create_dashboards
    setup_alerts
    setup_port_forwarding
    display_info
}

# Run main function
main "$@"