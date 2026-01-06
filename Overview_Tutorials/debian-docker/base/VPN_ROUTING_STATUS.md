# VPN Routing Implementation Status

## Overview
This document summarizes the current status of VPN routing implementation for the Docker container to access VPN networks through the Windows 11 host.

## Current Implementation

### Files Modified/Created

1. **`configure-vpn-routing.sh`** - VPN routing configuration script
   - Supports single or multiple VPN networks (comma-separated)
   - Automatically detects host IP (prefers IPv4)
   - Uses route metrics to handle conflicts with Docker's 172.17.0.0/16 network
   - Handles networks that conflict with Docker bridge (uses metric 50) vs others (metric 100)

2. **`Dockerfile`** - Updated to include VPN routing script
   - Copies and installs `configure-vpn-routing.sh`
   - Script is executable and line endings normalized

3. **`start_rdp.sh`** - Entrypoint script updated
   - Calls VPN routing script at startup (as root)
   - Only runs if `VPN_NETWORK` environment variable is set

4. **`start-container.bat`** - Container startup script updated
   - Reads `VPN_NETWORK` from `.env` file
   - Adds `--cap-add=NET_ADMIN` for route modification
   - Adds `--add-host=host.docker.internal:host-gateway` for host access
   - Passes `VPN_NETWORK` as environment variable to container

5. **`.env` and `.env.example`** - Configuration files
   - `VPN_NETWORK` variable added (supports comma-separated networks)
   - Currently configured with: `VPN_NETWORK=10.8.0.0/24,172.17.5.0/24`

6. **`.gitignore`** - Updated to track `.env.example` but ignore `.env`

## Current Status

### ✅ What Works

1. **Container can reach VPN gateway (10.8.0.1)**
   - Route for `10.8.0.0/24` is successfully added
   - Container can ping `10.8.0.1` successfully

2. **VPN routing script executes correctly**
   - Script runs at container startup
   - Successfully adds routes for configured networks
   - Handles missing VPN gracefully (doesn't fail container startup)

3. **Multi-network support implemented**
   - Script supports comma-separated networks in `VPN_NETWORK`
   - Uses appropriate route metrics for network conflicts

### ❌ Current Issues

1. **Cannot reach 172.17.5.2 from container**
   - Route for `172.17.5.0/24` is added successfully
   - Windows shows "Redirect Host" ICMP messages
   - Windows tries to send packets directly to `172.17.5.2`, which fails
   - Root cause: Windows packet forwarding limitation between Docker bridge and VPN interface

2. **Network conflict with Docker bridge**
   - Docker uses `172.17.0.0/16` by default
   - VPN network `172.17.5.0/24` conflicts with this
   - Route is added with lower metric (50) but Windows forwarding is the issue

## Technical Details

### Network Configuration

- **VPN Network**: `10.8.0.0/24` (VPN gateway: `10.8.0.1`)
- **Target Network**: `172.17.5.0/24` (target IP: `172.17.5.2`)
- **Docker Bridge**: `172.17.0.0/16` (gateway: `172.17.0.1`)
- **Container IP**: `172.17.0.2`

### Routing Flow (Current)

```
Container (172.17.0.2) 
  → Route: 172.17.5.0/24 via 172.17.0.1
  → Docker Host (172.17.0.1)
  → Windows receives packet
  → Windows tries to send directly to 172.17.5.2 (ICMP redirect)
  → FAILS: 172.17.5.2 not on Docker bridge network
```

### Expected Routing Flow

```
Container (172.17.0.2)
  → Route: 172.17.5.0/24 via 172.17.0.1
  → Docker Host (172.17.0.1)
  → Windows forwards to VPN gateway (10.8.0.1)
  → VPN gateway routes to 172.17.5.2
  → SUCCESS
```

## Next Steps / Potential Solutions

### Option 1: Enable IP Forwarding on Windows (Recommended)

**Action**: Enable IP forwarding on the Docker/WSL network interface

```powershell
# Run PowerShell as Administrator
Set-NetIPInterface -Forwarding Enabled -InterfaceAlias "vEthernet (WSL)"
# Or for Docker Desktop:
Set-NetIPInterface -Forwarding Enabled -InterfaceAlias "vEthernet (Default Switch)"
```

**Pros**: 
- Should allow Windows to forward packets correctly
- No code changes needed

**Cons**: 
- Requires administrator privileges
- May need to be done after each Docker Desktop restart

**Test**: After enabling, restart container and test:
```batch
docker exec debian-dev-container ping -c 2 172.17.5.2
```

### Option 2: Use Different Docker Network

**Action**: Create a custom Docker network that doesn't conflict with VPN networks

```batch
docker network create --subnet=192.168.100.0/24 vpn-compatible-network
```

Then modify `start-container.bat` to use this network:
```batch
docker run ... --network vpn-compatible-network ...
```

**Pros**: 
- Avoids network conflicts entirely
- Cleaner solution

**Cons**: 
- Requires changing container startup
- May affect other networking

### Option 3: Use VPN Gateway as Next Hop

**Action**: Route through VPN gateway (10.8.0.1) instead of Docker host

**Challenge**: VPN gateway is only reachable through the `10.8.0.0/24` route, which already goes through the host. This creates a routing loop.

**Status**: Not viable without additional configuration

### Option 4: Proxy/NAT Solution

**Action**: Use a proxy or NAT on Windows to forward traffic

**Pros**: 
- Can work around forwarding limitations

**Cons**: 
- Complex to implement
- Requires additional software/configuration

### Option 5: Manual Route After Container Start (Temporary Workaround)

**Action**: Manually add route after container starts

```batch
docker exec -u root debian-dev-container ip route add 172.17.5.0/24 via 172.17.0.1 dev eth0 metric 10
```

**Status**: Route is added but still doesn't work due to Windows forwarding issue

## Testing Commands

### Check Container Routes
```batch
docker exec debian-dev-container ip route
```

### Test VPN Gateway Connectivity
```batch
docker exec debian-dev-container ping -c 2 10.8.0.1
```

### Test Target IP Connectivity
```batch
docker exec debian-dev-container ping -c 2 172.17.5.2
```

### Check Container Logs for VPN Routing
```batch
docker logs debian-dev-container | findstr -i "vpn routing"
```

### Check Windows Routes
```batch
route print | findstr "10.8.0"
route print | findstr "172.17"
```

### Test from Windows
```batch
ping 172.17.5.2
tracert 172.17.5.2
```

## Configuration

### Current `.env` Configuration
```
VPN_NETWORK=10.8.0.0/24,172.17.5.0/24
```

### How to Change VPN Networks

1. Edit `.env` file:
   ```
   VPN_NETWORK=10.8.0.0/24,172.17.5.0/24,192.168.100.0/24
   ```

2. Rebuild image (if script changed):
   ```batch
   build-docker-image.bat
   ```

3. Recreate container:
   ```batch
   docker stop debian-dev-container
   docker rm debian-dev-container
   start-container.bat
   ```

## Known Limitations

1. **Windows Packet Forwarding**: Windows may not forward packets between Docker bridge and VPN interface by default
2. **Network Conflicts**: VPN networks that overlap with Docker's default `172.17.0.0/16` network cause routing conflicts
3. **ICMP Redirects**: Windows sends ICMP redirects that confuse the container's routing
4. **IPv6 Resolution**: `host.docker.internal` may resolve to IPv6, but script now filters for IPv4

## Files to Review

- `configure-vpn-routing.sh` - Main routing script (lines 1-94)
- `start-container.bat` - Container startup (line 32: `--cap-add=NET_ADMIN`)
- `start_rdp.sh` - Entrypoint (lines 11-14: VPN routing call)
- `.env` - Current VPN network configuration

## Questions to Investigate

1. Does Windows need IP forwarding enabled for Docker bridge interface?
2. Can we use a different Docker network to avoid conflicts?
3. Is there a way to disable ICMP redirects from Windows?
4. Can we use Windows routing table to auto-detect VPN-accessible networks?
5. Would using `--network host` mode work on Windows? (Answer: No, not supported on Windows Docker Desktop)

## Related Documentation

- Docker Desktop networking: https://docs.docker.com/desktop/networking/
- Windows IP forwarding: https://docs.microsoft.com/en-us/windows-server/networking/technologies/ip-forwarding
- OpenVPN routing: https://community.openvpn.net/openvpn/wiki/Routing

## Last Updated
2025-01-06

## Status Summary
🟡 **Partially Working**: VPN gateway (10.8.0.1) is reachable, but target network (172.17.5.0/24) is not accessible due to Windows packet forwarding limitations.

