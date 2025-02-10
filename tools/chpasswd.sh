#!/bin/bash

# Ensure the script is run with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Check for correct number of arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <username> <password>"
    exit 1
fi

# Capture command-line arguments
USERNAME="$1"
PASSWORD="$2"

# Validate username (alphanumeric only)
if [[ ! "$USERNAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
    echo "Error: Username must be alphanumeric and can include underscores."
    exit 1
fi

# Set the user's password
echo "Setting password for user '$USERNAME'..."
echo "$USERNAME:$PASSWORD" | chpasswd || { echo "Failed to set password."; exit 1; }
