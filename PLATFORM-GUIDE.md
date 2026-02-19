# Healthcare Platform Quick Start Guide

## Start the Healthcare Platform

### Option 1: Automated Scripts (Recommended)

**Step 1: One-time Windows networking setup (Run as Administrator)**
```powershell
Start-Process PowerShell -Verb RunAs -ArgumentList "-File", "C:\docker\scripts\setup-windows-networking.ps1"
```

**Step 2: Start all services**
```bash
# From WSL/Linux terminal
cd /mnt/c/docker
./scripts/start-platform.sh
```

**Step 3: Stop when done**
```bash
./scripts/stop-platform.sh
```

### Option 2: Manual Dashboard Only

For just the dashboard (simplest approach):
```bash
# From WSL terminal
cd /mnt/c/docker
kubectl port-forward -n healthcare svc/healthcare-dashboard 4000:4000 --address=0.0.0.0
```

## Access the Services

Once the platform is running, access these URLs:

### 🏥 Healthcare Services
- **Healthcare Dashboard**: http://localhost:4000 (Main UI showing service health)
- **Patient Service**: http://localhost:3001 
- **Appointment Service**: http://localhost:3002
- **Medical Records Service**: http://localhost:3003

### 📊 Monitoring & Observability  
- **Grafana**: http://localhost:3000 (Metrics & Dashboards - admin/admin123)
- **Prometheus**: http://localhost:9090 (Metrics Collection)
- **Jaeger**: http://localhost:16686 (Distributed Tracing)
- **Kiali**: http://localhost:20001 (Service Mesh Visualization)

## Stop the Platform

To stop port forwarding (services remain running in cluster):

```bash
# From WSL/Linux terminal
./scripts/stop-platform.sh
```

Or manually:
```bash
pkill -f 'kubectl.*port-forward'
```

## Platform Features

✅ **Microservices Architecture** with Node.js, Python, and Go services  
✅ **Kubernetes Orchestration** with Kind cluster  
✅ **Istio Service Mesh** with mTLS security  
✅ **React Dashboard** with health monitoring  
✅ **Complete Observability** with Prometheus, Grafana, Jaeger, Kiali  
✅ **Database Integration** with MongoDB and PostgreSQL  

## Troubleshooting

### Healthcare Services Issues:
- If dashboard shows "site can't be reached", ensure port forwarding is running
- All 3 services should show as "healthy" (green) in the dashboard
- Check Windows port forwarding rules if needed: `netsh interface portproxy show v4tov4`

### Monitoring Services Issues:
- If Grafana/Jaeger/Kiali show "site can't be reached", restart monitoring port forwarding:
  ```bash
  # Restart monitoring services only
  cd /mnt/c/docker/scripts
  ./start-platform.sh
  ```
- Check if monitoring pods are running: `kubectl get pods -n istio-system`
- Kiali may take longer to start up (check for CrashLoopBackOff status)

### Manual Port Forwarding (if scripts fail):
```bash
# Healthcare services
kubectl port-forward -n healthcare svc/healthcare-dashboard 4000:4000 --address=0.0.0.0 &
kubectl port-forward -n healthcare svc/patient-service 3001:3001 --address=0.0.0.0 &
kubectl port-forward -n healthcare svc/appointment-service 3002:3002 --address=0.0.0.0 &
kubectl port-forward -n healthcare svc/medical-records-service 3003:3003 --address=0.0.0.0 &

# Monitoring services
kubectl port-forward -n istio-system svc/grafana 3000:3000 --address=0.0.0.0 &
kubectl port-forward -n istio-system svc/prometheus 9090:9090 --address=0.0.0.0 &
kubectl port-forward -n istio-system svc/jaeger-query 16686:16686 --address=0.0.0.0 &
kubectl port-forward -n istio-system svc/kiali 20001:20001 --address=0.0.0.0 &
```