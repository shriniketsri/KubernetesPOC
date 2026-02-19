# Healthcare Platform Management Scripts

## Recommended Script Consolidation

After analysis, we can reduce from 5 scripts to 3 optimized scripts:

### 1. `setup-windows-networking.ps1` (Replace setup-port-forward.ps1 & add-dashboard-port-forward.ps1)
- **Purpose**: One-time Windows netsh setup
- **Combines**: Both PowerShell scripts into one clean version
- **Features**: Auto WSL IP detection, better error handling, all ports

### 2. `start-platform.sh` (Replace start-all-port-forward.sh & start-healthcare-platform.sh) 
- **Purpose**: Start all kubectl port-forward processes
- **Combines**: Both start scripts into one robust version
- **Features**: Background processes, status checking, log management

### 3. `stop-platform.sh` (Keep stop-healthcare-platform.sh)
- **Purpose**: Clean shutdown of port forwarding
- **Keep**: Already simple and effective

## Issues Found:

### Current Problems:
- **`setup-port-forward.ps1`**: Has duplicate port entries (3002, 3003, 8080, 16686, 20001 listed twice)
- **Script overlap**: Multiple scripts doing similar things with slight differences
- **Inconsistent sudo usage**: Some use sudo, others don't
- **Different approaches**: nohup vs background jobs vs simple &

### Proposed Solution:
Consolidate to 3 clean, non-overlapping scripts with clear purposes.