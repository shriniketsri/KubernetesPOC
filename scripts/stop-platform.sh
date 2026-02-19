#!/bin/bash

# Healthcare Platform Stop Script
echo "🛑 Stopping Healthcare Platform services..."

# Show current processes before stopping
active_processes=$(ps aux | grep 'kubectl.*port-forward' | grep -v grep | wc -l)
if [ $active_processes -gt 0 ]; then
    echo "Found $active_processes active port forwarding processes"
    echo "Process details:"
    ps aux | grep 'kubectl.*port-forward' | grep -v grep | awk '{print "   PID " $2 ": " $11 " " $12 " " $13 " " $14 " " $15}'
    echo ""
fi

# Kill all kubectl port-forward processes
echo "Terminating port forwarding processes..."
pkill -f 'kubectl.*port-forward'

# Wait for processes to terminate
sleep 2

# Clean up PID files
echo "Cleaning up temporary files..."
rm -f /tmp/healthcare-pids.txt
rm -f /tmp/*-pf.log

# Verify all processes stopped
remaining=$(ps aux | grep 'kubectl.*port-forward' | grep -v grep | wc -l)
if [ $remaining -eq 0 ]; then
    echo "✅ All Healthcare Platform port forwarding stopped successfully."
else
    echo "⚠️  Warning: $remaining processes may still be running"
    echo "   You may need to run: sudo pkill -f 'kubectl.*port-forward'"
fi

echo ""
echo "ℹ️  Note: Kubernetes services are still running in the cluster."
echo "   Only local port forwarding has been stopped."
echo ""
echo "🚀 To restart: ./scripts/start-platform.sh"