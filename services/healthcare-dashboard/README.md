# Healthcare Dashboard

A modern React-based web interface for the Healthcare Microservices Platform.

## Features

### 🏥 Healthcare Management
- **Patient Management**: Create, view, edit, and manage patient records
- **Appointment Scheduling**: Schedule and track healthcare appointments  
- **Medical Records**: Comprehensive medical record management with diagnosis, treatment, and notes

### 🔧 Technical Features
- **Real-time Service Health**: Monitor microservices health and database connectivity
- **Responsive Design**: Material-UI components for modern, accessible interface
- **API Integration**: Seamless integration with Node.js, Python, and Go microservices
- **Service Mesh Visualization**: Integration with Istio service mesh for traffic management

### 📊 Dashboard Overview
- Service health indicators
- Data visualization with charts
- Real-time metrics
- Architecture overview

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│ React Frontend  │────│ Nginx Reverse    │────│ Kubernetes Services │
│ (Port 3000)     │    │ Proxy            │    │ via Istio Gateway   │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
```

### Technology Stack
- **Frontend**: React 18, Material-UI, Recharts
- **Routing**: React Router DOM  
- **HTTP Client**: Axios
- **Date Handling**: Day.js
- **Build Tool**: Create React App
- **Web Server**: Nginx
- **Container**: Docker multi-stage build

## API Integration

The dashboard integrates with three healthcare microservices:

### Patient Service (Node.js/Express)
- **Endpoint**: `/api/patients`
- **Database**: MongoDB
- **Features**: Patient CRUD operations

### Appointment Service (Python/Flask)  
- **Endpoint**: `/api/appointments`
- **Database**: PostgreSQL
- **Features**: Appointment scheduling and management

### Medical Records Service (Go/Gin)
- **Endpoint**: `/api/medical-records`  
- **Database**: MongoDB
- **Features**: Medical record management

## Deployment

### Kubernetes Deployment
```yaml
# Deployed as part of healthcare-dashboard.yaml
- Replicas: 2 for high availability
- Resources: 128Mi-512Mi memory, 100m-500m CPU
- Security: Non-root user, read-only filesystem
- Health checks: Liveness and readiness probes
```

### Istio Integration
```yaml
# Service mesh integration via dashboard-gateway.yaml
- Virtual Service: Routes API calls to appropriate microservices
- Gateway: External access configuration
- Destination Rule: mTLS and traffic policies
```

## Access

### Local Development
```bash
# After deployment, access via:
http://localhost:4000  # Healthcare Dashboard
http://localhost:3001  # Patient Service API  
http://localhost:3002  # Appointment Service API
http://localhost:3003  # Medical Records API
```

### Production
- Kubernetes NodePort: 30004
- Istio Gateway: Port 80 with hostname routing
- Internal service communication via service mesh

## Key Components

### Dashboard.js
- Overview statistics and charts
- Service health monitoring  
- Architecture visualization

### Patients.js
- Patient list with search and filtering
- Create/Edit patient modal
- CRUD operations with MongoDB

### Appointments.js  
- Appointment calendar and management
- DateTime picker integration
- Status tracking and updates

### MedicalRecords.js
- Medical record viewer and editor
- Rich text support for notes
- Follow-up scheduling

### ServiceHealth.js
- Real-time service monitoring
- Health check visualization
- Infrastructure status overview

## Development

### Build Process
```dockerfile
# Multi-stage Docker build:
1. Node.js build stage - npm install & build
2. Nginx production stage - serve static files + API proxy
```

### Environment Variables
```bash
REACT_APP_API_BASE_URL=""  # API endpoint configuration
NODE_ENV="production"       # Production optimization
```

This UI demonstrates a complete healthcare platform showcasing:
- Modern React development practices
- Microservices integration patterns  
- Kubernetes-native deployment
- Service mesh integration with Istio
- Healthcare industry workflows