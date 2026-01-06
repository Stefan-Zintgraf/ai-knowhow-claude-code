#!/bin/sh
# SPDX-License-Identifier: BSD-3-Clause

# This Source Code Form is subject to the terms of the BSD-3-Clause License.
# If a copy of the BSD-3-Clause License was not distributed with this file, You can obtain one at https://opensource.org/licenses/BSD-3-Clause.
#
# Stefan Zintgraf, stefan@zintgraf.de

# Configure VPN routing through host (if VPN_NETWORK is set)
# This runs as root before switching to user, allowing route configuration
if [ -n "$VPN_NETWORK" ]; then
    echo "Configuring VPN routing..."
    /usr/bin/configure-vpn-routing.sh || echo "VPN routing configuration completed (may be skipped if VPN not connected)"
fi

# Clean up any stale socket files and PID files from previous runs
# This is important when the container is restarted
rm -f /var/run/xrdp/xrdp-sesman.pid
rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/sesman.socket
rm -f /var/run/xrdp/xrdp.socket

# Ensure the xrdp runtime directory exists
mkdir -p /var/run/xrdp

# Start dbus if not already running (xrdp may need it)
if [ ! -S /var/run/dbus/system_bus_socket ]; then
    service dbus start || true
fi

# Start SSH server
echo "Starting SSH server..."
mkdir -p /var/run/sshd
if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    ssh-keygen -A
fi
/usr/sbin/sshd
echo "SSH server started."

# Start xrdp sesman service in background
/usr/sbin/xrdp-sesman

# Give sesman a moment to start and create its socket
sleep 2

# Start xrdp in foreground (this keeps the container running)
/usr/sbin/xrdp --nodaemon
