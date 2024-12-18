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

# Add the new user
if id "$USERNAME" &>/dev/null; then
    echo "User '$USERNAME' already exists."
else
    echo "Adding user '$USERNAME'..."
    useradd -m "$USERNAME" || { echo "Failed to add user."; exit 1; }
fi

# Set the user's password
echo "Setting password for user '$USERNAME'..."
echo "$USERNAME:$PASSWORD" | chpasswd || { echo "Failed to set password."; exit 1; }

# Add the user to the sudoers file
echo "Adding user '$USERNAME' to sudoers..."
if ! grep -q "^$USERNAME " /etc/sudoers; then
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
else
    echo "User '$USERNAME' is already in the sudoers file."
fi

echo "User '$USERNAME' has been added and granted sudo access."

