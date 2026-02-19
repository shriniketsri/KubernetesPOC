# Healthcare Microservices with Kubernetes and Istio

A comprehensive example of healthcare microservices architecture using Kubernetes and Istio service mesh, designed for Ubuntu WSL environments. This project demonstrates cloud-native best practices, including microservices design, service mesh implementation, observability, security, and monitoring.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Istio Service Mesh                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Patient Service │  │Appointment Svc  │  │Medical Records  │  │
│  │    (Node.js)    │  │    (Python)     │  │     (Go)        │  │
│  │      :3001      │  │      :3002      │  │     :3003       │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │    MongoDB      │  │   PostgreSQL    │  │    MongoDB      │  │
│  │     :27017      │  │      :5432      │  │     :27017      │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring & Observability                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │  Grafana    │  │ Prometheus  │  │   Jaeger    │  │  Kiali  │ │
│  │    :3000    │  │    :9090    │  │   :16686    │  │ :20001  │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 🚀 Features

### Microservices
- **Patient Service (Node.js/Express)**: Patient management and profiles
- **Appointment Service (Python/Flask)**: Appointment scheduling and availability
- **Medical Records Service (Go/Gin)**: Medical records and patient history

### Infrastructure
- **Kubernetes**: Container orchestration with best practices
- **Istio Service Mesh**: Traffic management, security, and observability
- **Docker**: Containerization with multi-stage builds and security hardening

### Observability & Monitoring
- **Prometheus**: Metrics collection and alerting
- **Grafana**: Visualization and dashboards
- **Jaeger**: Distributed tracing
- **Kiali**: Service mesh observability

### Security
- **mTLS**: Mutual TLS between services
- **RBAC**: Role-based access control
- **Network Policies**: Traffic segmentation
- **Security Contexts**: Non-root containers and read-only filesystems

## 📋 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ (WSL2 recommended for Windows)
- **RAM**: Minimum 8GB, Recommended 16GB
- **CPU**: Minimum 4 cores
- **Disk**: 20GB available space

### Tools (Auto-installed by setup script)
- Docker 24.0+
- kubectl 1.28+
- kind 0.20+
- Helm 3.12+
- istioctl 1.19+

## 🛠️ Quick Start

### 1. Clone and Setup
```bash
# Clone the repository
git clone <repository-url>
cd docker

# Make scripts executable
cd scripts
chmod +x *.sh

# Run the complete setup (installs all dependencies)
./setup-wsl.sh
```

### 2. Deploy Services
```bash
# Build and deploy all services
./build-and-deploy.sh
```

### 3. Access Services
Once deployed, services will be available at:

| Service | URL | Description |
|---------|-----|-------------|
| Patient Service | http://localhost:3001 | Patient management API |
| Appointment Service | http://localhost:3002 | Appointment scheduling API |
| Medical Records | http://localhost:3003 | Medical records API |
| API Gateway | http://localhost:8080 | Istio ingress gateway |
| Grafana | http://localhost:3000 | Monitoring dashboards (admin/admin123) |
| Prometheus | http://localhost:9090 | Metrics and alerting |
| Jaeger | http://localhost:16686 | Distributed tracing |
| Kiali | http://localhost:20001 | Service mesh dashboard |

## 📁 Project Structure

```
.
├── services/                   # Microservices source code
│   ├── patient-service/       # Node.js patient management service
│   ├── appointment-service/   # Python appointment scheduling service
│   └── medical-records-service/ # Go medical records service
├── k8s/                       # Kubernetes manifests
│   ├── base/                  # Base Kubernetes resources
│   └── overlays/             # Environment-specific overlays
├── istio/                     # Istio service mesh configurations
│   ├── gateway.yaml          # Ingress gateway and virtual services
│   ├── destination-rules.yaml # Load balancing and circuit breaking
│   ├── security.yaml         # mTLS and authorization policies
│   └── service-entries.yaml  # External service definitions
├── monitoring/                # Observability stack
│   ├── prometheus.yaml       # Metrics collection
│   ├── grafana.yaml          # Dashboards and visualization
│   ├── jaeger.yaml           # Distributed tracing
│   └── kiali.yaml            # Service mesh observability
├── scripts/                   # Automation scripts
│   ├── setup-wsl.sh          # Complete environment setup
│   ├── build-and-deploy.sh   # Build and deploy services
│   ├── cleanup.sh            # Clean up resources
│   └── setup-monitoring.sh   # Setup monitoring stack
├── config/                    # Configuration files
└── docker-compose.yml         # Local development environment
```

## 🔧 Configuration

### Environment Variables
Each service supports environment-based configuration:

#### Patient Service (Node.js)
```bash
PORT=3001
MONGO_URI=mongodb://admin:password@mongo:27017/patient_db?authSource=admin
NODE_ENV=production
JWT_SECRET=your-jwt-secret-key
```

#### Appointment Service (Python)
```bash
PORT=3002
DATABASE_URL=postgresql://postgres:password@postgres:5432/appointment_db
PATIENT_SERVICE_URL=http://patient-service:3001
JWT_SECRET_KEY=your-jwt-secret-key
```

#### Medical Records Service (Go)
```bash
PORT=3003
MONGO_URI=mongodb://admin:password@mongo:27017/medical_records_db?authSource=admin
GIN_MODE=release
JWT_SECRET=your-jwt-secret-key
```

### Kubernetes Configuration
Configuration is managed through:
- **ConfigMaps**: Non-sensitive configuration
- **Secrets**: Sensitive data (passwords, tokens)
- **Environment**: Runtime environment variables

## 🔍 API Documentation

### Patient Service Endpoints
```bash
# Get all patients
GET /api/patients?page=1&limit=10&search=john

# Get patient by ID
GET /api/patients/{id}

# Create new patient
POST /api/patients
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john.doe@example.com",
  "phone": "+1234567890",
  "dateOfBirth": "1990-01-01",
  "gender": "Male"
}

# Update patient
PUT /api/patients/{id}

# Delete patient
DELETE /api/patients/{id}
```

### Appointment Service Endpoints
```bash
# Get appointments
GET /api/appointments?patient_id=123&doctor_id=456&date_from=2023-01-01

# Create appointment
POST /api/appointments
{
  "patient_id": "patient123",
  "doctor_id": "doctor456",
  "appointment_date": "2023-12-01T10:00:00Z",
  "duration_minutes": 30,
  "appointment_type": "consultation"
}

# Check availability
GET /api/availability/{doctor_id}?date=2023-12-01
```

### Medical Records Service Endpoints
```bash
# Get medical records
GET /api/medical-records?patient_id=123&record_type=consultation

# Create medical record
POST /api/medical-records
{
  "patient_id": "patient123",
  "doctor_id": "doctor456",
  "record_type": "consultation",
  "title": "Regular Checkup",
  "description": "Patient general health assessment"
}

# Get patient summary
GET /api/patients/{patient_id}/summary
```

## 📊 Monitoring and Observability

### Metrics Collection
- **Application Metrics**: Custom business metrics from each service
- **Infrastructure Metrics**: CPU, memory, disk, network usage
- **Istio Metrics**: Request rate, latency, error rate, traffic flow

### Dashboards
Pre-configured Grafana dashboards include:
- Healthcare Services Overview
- Individual service performance
- Kubernetes cluster metrics
- Istio service mesh metrics

### Alerting Rules
Configured alerts for:
- High error rates (>10%)
- High latency (P99 > 1000ms)
- Service downtime
- Database connection failures

### Distributed Tracing
Jaeger provides end-to-end request tracing across all services, helping with:
- Performance bottleneck identification
- Error root cause analysis
- Service dependency visualization

## 🔒 Security Best Practices

### Service Mesh Security
- **mTLS**: All service-to-service communication encrypted
- **Authorization Policies**: Fine-grained access control
- **Network Policies**: Traffic segmentation at network level

### Container Security
- **Non-root Users**: All containers run as non-root
- **Read-only Filesystems**: Containers use read-only root filesystems
- **Security Contexts**: Dropped capabilities and privilege restrictions
- **Image Scanning**: Multi-stage builds for minimal attack surface

### Secrets Management
- **Kubernetes Secrets**: Encrypted at rest
- **Environment Separation**: Different secrets per environment
- **Rotation**: Regular credential rotation support

## 🔄 Development Workflow

### Local Development
```bash
# Start local development environment
docker-compose up -d

# View logs
docker-compose logs -f [service-name]

# Stop services
docker-compose down
```

### Testing
```bash
# Run unit tests for each service
cd services/patient-service && npm test
cd services/appointment-service && python -m pytest
cd services/medical-records-service && go test ./...
```

### Building Images
```bash
# Build all images
./scripts/build-and-deploy.sh

# Build individual service
docker build -t healthcare/patient-service:latest services/patient-service/
```

## 🚀 Deployment Strategies

### Blue-Green Deployment
```bash
# Deploy new version
kubectl set image deployment/patient-service patient-service=healthcare/patient-service:v2 -n healthcare

# Verify deployment
kubectl rollout status deployment/patient-service -n healthcare

# Rollback if needed
kubectl rollout undo deployment/patient-service -n healthcare
```

### Canary Deployment with Istio
```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: patient-service-canary
spec:
  hosts:
  - patient-service
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: patient-service
        subset: v2
  - route:
    - destination:
        host: patient-service
        subset: v1
      weight: 90
    - destination:
        host: patient-service
        subset: v2
      weight: 10
```

## 🛠️ Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check pod status
kubectl get pods -n healthcare

# Check pod logs
kubectl logs <pod-name> -n healthcare

# Check events
kubectl get events -n healthcare --sort-by=.metadata.creationTimestamp
```

#### Database Connection Issues
```bash
# Check database pods
kubectl get pods -l app=mongo -n healthcare
kubectl get pods -l app=postgres -n healthcare

# Test database connectivity
kubectl exec -it <patient-service-pod> -n healthcare -- nc -zv mongo 27017
```

#### Network Issues
```bash
# Check Istio sidecar injection
kubectl get pods -n healthcare -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].name}{"\n"}{end}'

# Check Istio configuration
istioctl analyze -n healthcare

# Check virtual services
kubectl get virtualservices -n healthcare
```

### Debugging Commands
```bash
# Enter service container
kubectl exec -it <pod-name> -n healthcare -- /bin/bash

# Port forward for debugging
kubectl port-forward <pod-name> 3001:3001 -n healthcare

# Check Istio proxy configuration
istioctl proxy-config cluster <pod-name> -n healthcare

# View Envoy access logs
kubectl logs <pod-name> -c istio-proxy -n healthcare
```

## 📈 Performance Optimization

### Resource Limits
Each service has defined resource requests and limits:
```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "250m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

### Database Optimization
- Connection pooling enabled
- Query optimization with indexes
- Read replicas for read-heavy workloads
- Caching layer with Redis

### Istio Performance
- Circuit breaker patterns implemented
- Retry policies for resilience
- Load balancing algorithms optimized
- Timeout configurations tuned

## 🧹 Cleanup

### Clean Up Resources
```bash
# Clean up everything except cluster
./scripts/cleanup.sh

# Remove entire cluster
kind delete cluster --name healthcare-cluster

# Clean up Docker images
docker system prune -a
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

### Development Guidelines
- Follow microservice design principles
- Implement proper error handling
- Add comprehensive tests
- Update documentation
- Follow security best practices

## 📚 Learning Resources

### Kubernetes
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)

### Istio
- [Istio Documentation](https://istio.io/latest/docs/)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)

### Observability
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For questions and support:
- Create an issue in the repository
- Check the troubleshooting section
- Review the documentation

---

**Note**: This project is designed for educational and demonstration purposes. For production use, additional security hardening, high availability configurations, and monitoring should be implemented based on your specific requirements.