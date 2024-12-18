#!/bin/bash

CONFIG_FILE="/etc/ssh/sshd_config"

# Define file paths
BACKUP_DIR="/boot/Image/scripts/backup"
BACKUP_FILE="$BACKUP_DIR/sshd_config.bak"

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use sudo."
   exit 1
fi

# Create backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
fi

# Ensure PasswordAuthentication is enabled
if grep -q "^#PasswordAuthentication" "$CONFIG_FILE"; then
    sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$CONFIG_FILE"
elif ! grep -q "^PasswordAuthentication" "$CONFIG_FILE"; then
    echo "PasswordAuthentication yes" >> "$CONFIG_FILE"
else
    sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$CONFIG_FILE"
fi

# Ensure PubkeyAuthentication is enabled
if grep -q "^#PubkeyAuthentication" "$CONFIG_FILE"; then
    sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' "$CONFIG_FILE"
elif ! grep -q "^PubkeyAuthentication" "$CONFIG_FILE"; then
    echo "PubkeyAuthentication yes" >> "$CONFIG_FILE"
else
    sed -i 's/^PubkeyAuthentication.*/PubkeyAuthentication yes/' "$CONFIG_FILE"
fi

# Restart the SSH service to apply changes
if systemctl is-active --quiet sshd; then
    systemctl restart sshd
else
    service ssh restart
fi

echo "SSH configuration updated. PasswordAuthentication and PubkeyAuthentication enabled."

