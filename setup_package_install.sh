#!/bin/bash

# Directories and file paths
BACKUP_DIR="/boot/Image/scripts/backup"
RESOLV_CONF="/etc/resolv.conf"
SOURCES_LIST="/etc/apt/sources.list"
NEW_RESOLV_CONF="/boot/Image/scripts/resolv.conf"
NEW_SOURCES_LIST="/boot/Image/scripts/sources.list"

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Create the backup directory if it doesn't exist
if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "Creating backup directory at $BACKUP_DIR..."
    mkdir -p "$BACKUP_DIR"
fi

# Backup and replace resolv.conf
if [[ -f "$RESOLV_CONF" ]]; then
    echo "Backing up $RESOLV_CONF to $BACKUP_DIR..."
    cp "$RESOLV_CONF" "$BACKUP_DIR/resolv.conf.bak"
else
    echo "$RESOLV_CONF not found, skipping backup."
fi

if [[ -f "$NEW_RESOLV_CONF" ]]; then
    echo "Installing new resolv.conf..."
    cp "$NEW_RESOLV_CONF" "$RESOLV_CONF"
else
    echo "New resolv.conf not found at $NEW_RESOLV_CONF. Skipping replacement."
fi

# Backup and replace sources.list
if [[ -f "$SOURCES_LIST" ]]; then
    echo "Backing up $SOURCES_LIST to $BACKUP_DIR..."
    cp "$SOURCES_LIST" "$BACKUP_DIR/sources.list.bak"
else
    echo "$SOURCES_LIST not found, skipping backup."
fi

if [[ -f "$NEW_SOURCES_LIST" ]]; then
    echo "Installing new sources.list..."
    cp "$NEW_SOURCES_LIST" "$SOURCES_LIST"
else
    echo "New sources.list not found at $NEW_SOURCES_LIST. Skipping replacement."
fi

echo "Configuration files updated successfully."

