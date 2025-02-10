#!/bin/bash

# Enables a server signing option that might improve connectivity from Windows11 clients
# https://www.tomshardware.com/pc-components/nas/windows-11-24h2-may-block-connections-to-unsecured-third-party-nas-devices-microsoft-enables-smb-signing-for-enhanced-security

# Define file paths
CONFIG_FILE="/etc/samba/smb.conf"
BACKUP_DIR="/boot/Image/scripts/backup"
BACKUP_FILE="$BACKUP_DIR/smb.conf.bak"

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

# Backup the configuration file
echo "Backing up $CONFIG_FILE to $BACKUP_FILE..."
cp "$CONFIG_FILE" "$BACKUP_FILE"

# Check if the line 'server signing = mandatory' exists
if grep -q "^server signing = mandatory" "$CONFIG_FILE"; then
    echo "'server signing = mandatory' is already present in $CONFIG_FILE."
else
    # Add the line to the configuration file
    echo "Adding 'server signing = mandatory' to $CONFIG_FILE..."
    echo -e "\nserver signing = mandatory" >> "$CONFIG_FILE"
fi

# Restart Samba to apply changes
echo "Restarting Samba services..."
if systemctl is-active --quiet smbd; then
    systemctl restart smbd
else
    echo "Samba service not running. Please start it manually if needed."
fi

echo "Configuration update complete."

