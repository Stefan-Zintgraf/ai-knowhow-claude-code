#!/bin/bash
# SPDX-License-Identifier: BSD-3-Clause
#
# This Source Code Form is subject to the terms of the BSD-3-Clause License.
# If a copy of the BSD-3-Clause License was not distributed with this file, You can obtain one at https://opensource.org/licenses/BSD-3-Clause.
#
# Stefan Zintgraf, stefan@zintgraf.de
#
# Configure VPN routing through Docker host
# This allows containers to access VPN networks via the Windows host
# Works gracefully if VPN is not connected

# Get the VPN network(s) from environment variable (default: empty, will skip if not set)
# Can be a single network (10.8.0.0/24) or multiple networks separated by commas (10.8.0.0/24,172.17.5.0/24)
VPN_NETWORK="${VPN_NETWORK:-}"

if [ -z "$VPN_NETWORK" ]; then
    echo "VPN_NETWORK environment variable not set. Skipping VPN routing configuration."
    echo "To enable VPN routing, set VPN_NETWORK environment variable (e.g., VPN_NETWORK=10.8.0.0/24)"
    echo "For multiple networks, use: VPN_NETWORK=10.8.0.0/24,172.17.5.0/24"
    exit 0
fi

# Get the host IP (Docker Desktop provides host.docker.internal)
# Prefer IPv4 addresses over IPv6
HOST_IP=$(getent hosts host.docker.internal | awk '{print $1}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)

if [ -z "$HOST_IP" ]; then
    # Fallback: Use the default gateway (Docker bridge gateway)
    # This is the IP of the Windows host from the container's perspective
    HOST_IP=$(ip route | grep default | awk '{print $3}' | head -n 1)
fi

# If still no IP, try to get it from the route to a known external IP
if [ -z "$HOST_IP" ]; then
    HOST_IP=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'via \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
fi

if [ -z "$HOST_IP" ]; then
    echo "Warning: Could not determine host IP for VPN routing. VPN routing will be skipped."
    exit 0
fi

echo "Configuring VPN routing for network(s): $VPN_NETWORK through host $HOST_IP"

# Split VPN_NETWORK by comma to handle multiple networks
IFS=',' read -ra NETWORKS <<< "$VPN_NETWORK"
SUCCESS_COUNT=0
FAIL_COUNT=0

for network in "${NETWORKS[@]}"; do
    # Trim whitespace
    network=$(echo "$network" | xargs)
    
    if [ -z "$network" ]; then
        continue
    fi
    
    echo "  Adding route for $network..."
    
    # Remove existing route if it exists (ignore errors)
    ip route del "$network" via $HOST_IP 2>/dev/null || true
    
    # Add route for VPN network through host
    # Use metric to ensure it takes precedence over conflicting routes (lower metric = higher priority)
    # For networks that conflict with Docker's 172.17.0.0/16, use a lower metric (50)
    # For other networks, use a higher metric (100)
    if echo "$network" | grep -q "^172\.17\."; then
        METRIC=50
    else
        METRIC=100
    fi
    
    ip route add "$network" via $HOST_IP dev eth0 metric $METRIC 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "    Successfully configured route: $network -> $HOST_IP (metric $METRIC)"
        # Verify the route was added
        if ip route | grep -q "$network"; then
            echo "    Route verified: $(ip route | grep "$network")"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            echo "    Warning: Route added but verification failed"
            FAIL_COUNT=$((FAIL_COUNT + 1))
        fi
    else
        echo "    Warning: Failed to add route for $network (VPN may not be connected on host)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

echo "VPN routing configuration complete: $SUCCESS_COUNT succeeded, $FAIL_COUNT failed"

