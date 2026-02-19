# Healthcare Platform - Windows Networking Setup
# This script sets up Windows port forwarding rules to access services running in WSL
# Run this script as Administrator ONCE to set up networking

Write-Host "Setting up Windows port forwarding for Healthcare Platform..." -ForegroundColor Green

# Get current WSL IP address
$wslIP = (wsl hostname -I).Split()[0].Trim()
Write-Host "WSL IP Address: $wslIP" -ForegroundColor Yellow

# Define port forwarding rules
$ports = @(
    @{Port=4000; Service="Healthcare Dashboard"},
    @{Port=3001; Service="Patient Service"},
    @{Port=3002; Service="Appointment Service"},
    @{Port=3003; Service="Medical Records Service"},
    @{Port=3000; Service="Grafana"},
    @{Port=16686; Service="Jaeger"},
    @{Port=20001; Service="Kiali"}
)

# Add port forwarding rules
foreach ($rule in $ports) {
    $port = $rule.Port
    $service = $rule.Service
    
    # Remove existing rule if it exists
    netsh interface portproxy delete v4tov4 listenport=$port | Out-Null
    
    # Add new rule
    $result = netsh interface portproxy add v4tov4 listenport=$port listenaddress=0.0.0.0 connectport=$port connectaddress=$wslIP
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Added port forwarding for $service on port $port" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to add port forwarding for $service on port $port" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Port forwarding rules configured successfully!" -ForegroundColor Green
Write-Host "You can now access Healthcare Platform services at:" -ForegroundColor Cyan
Write-Host "  📊 Dashboard: http://localhost:4000" -ForegroundColor White
Write-Host "  👥 Patient Service: http://localhost:3001" -ForegroundColor White  
Write-Host "  📅 Appointment Service: http://localhost:3002" -ForegroundColor White
Write-Host "  📋 Medical Records: http://localhost:3003" -ForegroundColor White
Write-Host "  📈 Grafana: http://localhost:3000" -ForegroundColor White
Write-Host "  🔍 Jaeger: http://localhost:16686" -ForegroundColor White
Write-Host "  🕸️ Kiali: http://localhost:20001" -ForegroundColor White

Write-Host ""
Write-Host "Note: Run './scripts/start-platform.sh' from WSL to start kubectl port forwarding." -ForegroundColor Yellow
Write-Host "This script only sets up Windows networking rules." -ForegroundColor Yellow
pause