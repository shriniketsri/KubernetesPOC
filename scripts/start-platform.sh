#!/bin/bash

# Healthcare Platform Startup Script
echo "🏥 Starting Healthcare Platform services..."

# Function to check if a port is in use
check_port() {
    netstat -an | grep ":$1 " > /dev/null 2>&1
}

# Function to start port forwarding with retry
start_port_forward() {
    local service=$1
    local namespace=$2
    local port=$3
    local service_name=$4
    
    echo "Starting $service_name on port $port..."
    
    # Kill any existing process on this port
    pkill -f "kubectl.*port-forward.*:$port" > /dev/null 2>&1
    sleep 1
    
    # Start port forwarding in background with nohup for persistence
    nohup kubectl port-forward -n $namespace svc/$service $port:$port --address=0.0.0.0 > "/tmp/${service_name// /-}-port-forward.log" 2>&1 &
    local pid=$!
    
    # Store PID for cleanup
    echo "$service_name:$pid" >> /tmp/healthcare-pids.txt
    
    # Wait a moment and check if process is still running
    sleep 3
    if kill -0 $pid 2>/dev/null; then
        echo "✅ $service_name started successfully (PID: $pid)"
        return 0
    else
        echo "❌ Failed to start $service_name"
        return 1
    fi
}

# Clean up any existing processes and PID file
echo "Cleaning up existing port forwarding processes..."
pkill -f 'kubectl.*port-forward' > /dev/null 2>&1
rm -f /tmp/healthcare-pids.txt
touch /tmp/healthcare-pids.txt

echo ""
echo "🚀 Starting Healthcare Services..."

# Start healthcare services
start_port_forward "healthcare-dashboard" "healthcare" "4000" "Healthcare Dashboard"
start_port_forward "patient-service" "healthcare" "3001" "Patient Service"
start_port_forward "appointment-service" "healthcare" "3002" "Appointment Service"  
start_port_forward "medical-records-service" "healthcare" "3003" "Medical Records Service"

echo ""
echo "📊 Starting Monitoring Services..."

# Start monitoring services
start_port_forward "grafana" "istio-system" "3000" "Grafana"
start_port_forward "prometheus" "istio-system" "9090" "Prometheus"
start_port_forward "jaeger-query" "istio-system" "16686" "Jaeger"
start_port_forward "kiali" "istio-system" "20001" "Kiali"

# Wait for services to stabilize
echo ""
echo "⏳ Waiting for services to stabilize..."
sleep 5

# Test connectivity
echo ""
echo "🔍 Testing service connectivity..."

test_service() {
    local url=$1
    local name=$2
    local expected_code=${3:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 $url | grep -q $expected_code; then
        echo "✅ $name: accessible"
    else
        echo "⚠️  $name: not responding (may still be starting)"
    fi
}

test_service "http://localhost:4000" "Healthcare Dashboard"
test_service "http://localhost:3000" "Grafana"  
test_service "http://localhost:9090" "Prometheus"
test_service "http://localhost:16686" "Jaeger"
test_service "http://localhost:20001/kiali/" "Kiali"

# Show running processes
active_processes=$(ps aux | grep 'kubectl.*port-forward' | grep -v grep | wc -l)
echo ""
echo "📈 Status Summary:"
echo "   Active port forwarding processes: $active_processes"
echo "   PID file: /tmp/healthcare-pids.txt"

echo ""
echo "🎉 Healthcare Platform is ready!"
echo ""
echo "📊 Access URLs:"
echo "   🏥 Healthcare Dashboard: http://localhost:4000"
echo "   👥 Patient Service: http://localhost:3001" 
echo "   📅 Appointment Service: http://localhost:3002"
echo "   📋 Medical Records: http://localhost:3003"
echo "   📈 Grafana: http://localhost:3000"
echo "   📊 Prometheus: http://localhost:9090"
echo "   🔍 Jaeger: http://localhost:16686"
echo "   🕸️ Kiali: http://localhost:20001"
echo ""
echo "🛑 To stop all services: ./scripts/stop-platform.sh"
echo "📝 Logs are available in /tmp/healthcare-pids.txt"
echo ""
echo "ℹ️  Services are running in background. You can close this terminal."