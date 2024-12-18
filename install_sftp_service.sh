#!/bin/bash

CONFIG_FILE="/etc/ssh/sshd_config"

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

echo "Updating package lists..."
apt update

echo "Installing OpenSSH server..."
apt install -y openssh-server openssh-sftp-server

# Enable and start SSH service
echo "Enabling SSH service on boot..."
systemctl enable ssh

echo "Starting SSH service..."
systemctl start ssh

# Ensure only one valid Subsystem sftp line exists
if grep -Pq "^Subsystem\s+sftp" "$CONFIG_FILE"; then
    echo "Updating existing Subsystem sftp entry..."
    sed -i 's|^Subsystem\s\+sftp.*|Subsystem sftp /usr/lib/openssh/sftp-server|' "$CONFIG_FILE"
else
    echo "Adding Subsystem sftp entry to sshd_config..."
    echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> "$CONFIG_FILE"
fi

# Restart SSH service to apply changes
echo "Restarting SSH service to apply changes..."
if systemctl restart ssh; then
    echo "SFTP server is installed, enabled, and running."
else
    echo "Failed to restart the SSH service. Check the logs for more details."
    exit 1
fi

