# Healthcare Microservices Kubernetes Cluster Architecture

## Cluster Overview
```
Windows Host (localhost)
    ↓ (Windows netsh port forwarding)
Ubuntu WSL (172.18.254.24)
    ↓ (kubectl port-forward)
Kind Kubernetes Cluster (Docker Network: 172.19.0.x)
```

## Physical Infrastructure

### Kind Cluster Nodes
```
┌─────────────────────────────────────────────────────────────────┐
│                         Kind Cluster                           │
├─────────────────────────────────────────────────────────────────┤
│  Control Plane (172.19.0.4)                                    │
│  ├── etcd-healthcare-cluster-control-plane                     │
│  ├── kube-apiserver-healthcare-cluster-control-plane           │
│  ├── kube-controller-manager-healthcare-cluster-control-plane  │
│  ├── kube-scheduler-healthcare-cluster-control-plane           │
│  └── kube-proxy-phscl                                          │
├─────────────────────────────────────────────────────────────────┤
│  Worker Node 1 (172.19.0.2)                                    │
│  ├── kube-proxy-bdscv                                          │
│  └── kindnet-76ztm (CNI)                                       │
├─────────────────────────────────────────────────────────────────┤
│  Worker Node 2 (172.19.0.3)                                    │
│  ├── kube-proxy-vhjtj                                          │
│  └── kindnet-xp2mn (CNI)                                       │
└─────────────────────────────────────────────────────────────────┘
```

## Network Architecture

### Port Forwarding Chain
```
Windows Browser                           WSL                                  Kubernetes Services
├── localhost:3001 ────┬──── netsh ────┬──── kubectl port-forward ────────── patient-service:3001
├── localhost:3002 ────┼──── proxy ────┼──── (172.18.254.24:300x) ────────── appointment-service:3002
├── localhost:3003 ────┼─── (0.0.0.0 ──┼──── --address=0.0.0.0) ───────────── medical-records-service:3003
├── localhost:4000 ────┼─── :300x → ───┼──── 0.0.0.0:300x) ──────────────── healthcare-dashboard:4000
├── localhost:3000 ────┼─── WSL IP: ───┼──── → Cluster Services ────────────── grafana:3000
├── localhost:16686 ───┼─── 300x) ─────┼──── (ClusterIP/NodePort) ──────────── jaeger:16686
└── localhost:20001 ───┴───────────────┴─────────────────────────────────────── kiali:20001
```

### NodePort Mappings
```
Service                  ClusterIP       NodePort    External Access
├── patient-service      10.96.154.4     30001      localhost:30001
├── appointment-service  10.96.118.106   30002      localhost:30002
├── medical-records      10.96.16.14     30003      localhost:30003
└── dashboard            10.96.19.104    30004      localhost:30004
```

## Application Architecture

### Healthcare Namespace (Core Services)
```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Healthcare Namespace                         │
├─────────────────────────────────────────────────────────────────────────┤
│  Frontend Layer                                                         │
│  ├── healthcare-dashboard-77c8b8664b-69652 (React + Nginx)             │
│  │   └── Container: dashboard (Port 4000)                              │
│  └── healthcare-dashboard-77c8b8664b-cx657                             │
│      └── Container: dashboard + istio-proxy                            │
├─────────────────────────────────────────────────────────────────────────┤
│  Microservices Layer                                                   │
│  ├── Patient Service (Node.js/Express)                                 │
│  │   ├── patient-service-c55bd7946-jfrqx (10.244.1.18)                │
│  │   │   ├── Container: patient-service (Port 3001)                   │
│  │   │   └── Container: istio-proxy (Envoy Sidecar)                   │
│  │   └── patient-service-c55bd7946-v5sf7 (10.244.2.8)                 │
│  │                                                                     │
│  ├── Appointment Service (Python/Flask)                               │
│  │   ├── appointment-service-85b6f797dd-bvvlr (10.244.1.12)           │
│  │   │   ├── Container: appointment-service (Port 3002)               │
│  │   │   └── Container: istio-proxy (Envoy Sidecar)                   │
│  │   └── appointment-service-85b6f797dd-qhc8r (10.244.2.4)            │
│  │                                                                     │
│  └── Medical Records Service (Go/Gin)                                  │
│      ├── medical-records-service-5cfccd47d6-dkddf (10.244.2.5)        │
│      │   ├── Container: medical-records-service (Port 3003)           │
│      │   └── Container: istio-proxy (Envoy Sidecar)                   │
│      └── medical-records-service-5cfccd47d6-nsh54 (10.244.1.13)       │
├─────────────────────────────────────────────────────────────────────────┤
│  Database Layer                                                        │
│  ├── MongoDB (Document Database)                                       │
│  │   └── mongo-54b7df5bcb-2lzbh (10.244.1.8)                         │
│  │       └── Container: mongo:7.0 (Port 27017)                        │
│  │                                                                     │
│  └── PostgreSQL (Relational Database)                                  │
│      └── postgres-54dcf4756-5nkjx (10.244.1.10)                      │
│          └── Container: postgres:15-alpine (Port 5432)                │
└─────────────────────────────────────────────────────────────────────────┘
```

## Service Mesh (Istio) Architecture

### Istio System Namespace
```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Istio Service Mesh                            │
├─────────────────────────────────────────────────────────────────────────┤
│  Control Plane                                                         │
│  └── istiod-64994d4fc6-fntcb (10.244.2.2)                             │
│      ├── Pilot (Service Discovery & Configuration)                     │
│      ├── Citadel (Certificate Management)                              │
│      └── Galley (Configuration Validation)                             │
├─────────────────────────────────────────────────────────────────────────┤
│  Data Plane (Ingress Gateway)                                          │
│  └── istio-ingressgateway-9874dd759-rw6jj (10.244.1.2)                │
│      └── Envoy Proxy (Traffic Entry Point)                             │
├─────────────────────────────────────────────────────────────────────────┤
│  Observability Stack                                                   │
│  ├── Grafana (Dashboards & Visualization)                              │
│  │   └── grafana-7954585779-g8kgm (10.244.1.4)                        │
│  │       └── Container: grafana (Port 3000)                            │
│  │                                                                     │
│  ├── Prometheus (Metrics Collection)                                   │
│  │   └── prometheus-86bd494757-b82n8 (10.244.1.3)                     │
│  │       └── Container: prometheus (Port 9090)                         │
│  │                                                                     │
│  ├── Jaeger (Distributed Tracing)                                      │
│  │   └── jaeger-58b57f69f9-sbr6c (10.244.1.5)                         │
│  │       └── Container: jaeger (Port 16686)                            │
│  │                                                                     │
└── Kiali (Service Mesh Visualization) [Running ✅]             │
      └── kiali-7c4946b9fc-dhcfd (10.244.1.6)                           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Architecture

### Request Flow (With Istio)
```
1. Windows Browser Request
   └── http://localhost:3001/api/patients
       └── Windows netsh proxy
           └── WSL kubectl port-forward
               └── Kubernetes Service (patient-service:3001)
                   └── Istio Envoy Sidecar
                       ├── mTLS Encryption
                       ├── Traffic Metrics
                       ├── Distributed Tracing
                       └── Load Balancing
                           └── Patient Service Container
                               └── MongoDB Database
```

### Service-to-Service Communication
```
Patient Service ──┬── mTLS ──→ Appointment Service
                  │           ├── Circuit Breaker
                  │           ├── Retry Logic
                  │           └── Load Balancing
                  │
                  └── mTLS ──→ Medical Records Service
                              ├── Request Timeout
                              ├── Traffic Splitting
                              └── Health Checks
```

## Security Architecture

### Network Policies & mTLS
```
┌─────────────────────────────────────────────────────────────────┐
│                    Security Layer                              │
├─────────────────────────────────────────────────────────────────┤
│  Istio mTLS (Automatic)                                        │
│  ├── Service-to-Service Encryption                             │
│  ├── Certificate Rotation                                      │
│  └── Identity Verification                                     │
├─────────────────────────────────────────────────────────────────┤
│  RBAC (Role-Based Access Control)                              │
│  ├── healthcare-admin (ClusterRole)                            │
│  ├── healthcare-reader (ClusterRole)                           │
│  └── ServiceAccount permissions                                │
├─────────────────────────────────────────────────────────────────┤
│  Network Isolation                                             │
│  ├── Namespace separation                                      │
│  ├── Pod-to-Pod communication                                  │
│  └── Database access restrictions                              │
└─────────────────────────────────────────────────────────────────┘
```

## Storage Architecture

### Persistent Storage
```
┌─────────────────────────────────────────────────────────────────┐
│                    Storage Layer                               │
├─────────────────────────────────────────────────────────────────┤
│  Local Path Provisioner (Kind Default)                         │
│  └── local-path-provisioner-6bc4bddd6b-vvlxr                  │
├─────────────────────────────────────────────────────────────────┤
│  Database Storage                                              │
│  ├── MongoDB Data Volume                                       │
│  │   └── /data/db (Container Path)                             │
│  └── PostgreSQL Data Volume                                    │
│      └── /var/lib/postgresql/data (Container Path)             │
└─────────────────────────────────────────────────────────────────┘
```

## Resource Allocation

### Pod Distribution Across Nodes
```
Control Plane Node (172.19.0.4):
├── CoreDNS × 2
├── Local Path Provisioner
└── System Components (etcd, apiserver, etc.)

Worker Node 1 (172.19.0.2):
├── patient-service-c55bd7946-jfrqx (2/2 containers)
├── appointment-service-85b6f797dd-bvvlr (2/2 containers)
├── healthcare-dashboard-77c8b8664b-cx657 (2/2 containers)
├── medical-records-service-5cfccd47d6-nsh54 (2/2 containers)
├── mongo-54b7df5bcb-2lzbh (1/1 container)
├── postgres-54dcf4756-5nkjx (1/1 container)
├── grafana-7954585779-g8kgm (1/1 container)
├── istio-ingressgateway-9874dd759-rw6jj (1/1 container)
├── prometheus-86bd494757-b82n8 (1/1 container)
├── jaeger-58b57f69f9-sbr6c (1/1 container)
└── kiali-5447fb5b4-wkj47 (0/1 - CrashLoopBackOff)

Worker Node 2 (172.19.0.3):
├── patient-service-c55bd7946-v5sf7 (2/2 containers)
├── appointment-service-85b6f797dd-qhc8r (2/2 containers)
├── healthcare-dashboard-77c8b8664b-69652 (2/2 containers)
├── medical-records-service-5cfccd47d6-dkddf (2/2 containers)
└── istiod-64994d4fc6-fntcb (1/1 container)
```

## Access Points Summary

### External Access URLs
```
Healthcare Services:
├── Dashboard:      http://localhost:4000
├── Patient API:    http://localhost:3001/api/patients
├── Appointment:    http://localhost:3002/api/appointments
└── Medical Records: http://localhost:3003/api/medical-records

Monitoring & Observability:
├── Grafana:        http://localhost:3000
├── Prometheus:     http://localhost:9090
├── Jaeger Tracing: http://localhost:16686
└── Kiali:          http://localhost:20001 (Currently down)

Direct NodePort Access:
├── Patient:        http://localhost:30001
├── Appointment:    http://localhost:30002
├── Medical Records: http://localhost:30003
└── Dashboard:      http://localhost:30004
```

## Technology Stack Summary

```
┌─────────────────────────────────────────────────────────────────┐
│  Frontend: React + Material-UI + Nginx                         │
├─────────────────────────────────────────────────────────────────┤
│  Backend Services:                                             │
│  ├── Patient Service: Node.js + Express + Winston             │
│  ├── Appointment Service: Python + Flask + SQLAlchemy         │
│  └── Medical Records: Go + Gin + GORM                          │
├─────────────────────────────────────────────────────────────────┤
│  Databases:                                                    │
│  ├── MongoDB 7.0 (Document Store)                             │
│  └── PostgreSQL 15-alpine (Relational)                        │
├─────────────────────────────────────────────────────────────────┤
│  Infrastructure:                                               │
│  ├── Kubernetes 1.27.3 (Kind Cluster)                         │
│  ├── Istio Service Mesh                                        │
│  ├── Docker Containers                                         │
│  └── Ubuntu WSL on Windows                                     │
├─────────────────────────────────────────────────────────────────┤
│  Observability:                                                │
│  ├── Grafana (Dashboards)                                      │
│  ├── Prometheus (Metrics)                                      │
│  ├── Jaeger (Distributed Tracing)                             │
│  └── Kiali (Service Mesh Visualization)                        │
└─────────────────────────────────────────────────────────────────┘
```

---
*Generated: December 19, 2025*
*Cluster: healthcare-cluster (Kind)*
*Services: 4 microservices + monitoring stack*
*Pods: 20+ total across 3 nodes*