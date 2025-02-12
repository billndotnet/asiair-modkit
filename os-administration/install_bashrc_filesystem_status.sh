#!/bin/bash

# Modifies the systemwide bashrc to provide a status on the command line prompt that the system is in an unprotected
# mode, with / mounted in a read-write state.

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please use sudo or switch to the root user."
  exit 1
fi

# Backup the existing /etc/bash.bashrc
BASHRC_PATH="/etc/bash.bashrc"
BACKUP_PATH="/etc/bash.bashrc.backup.$(date +%Y%m%d%H%M%S)"

echo "Backing up the existing /etc/bash.bashrc to $BACKUP_PATH..."
cp "$BASHRC_PATH" "$BACKUP_PATH"

# Add the custom prompt logic to /etc/bash.bashrc
echo "Adding custom prompt logic to /etc/bash.bashrc..."

cat << 'EOF' >> "$BASHRC_PATH"

# Custom prompt logic to reflect root filesystem status
if [ -f /tmp/root_rw_status ] && [ "$(cat /tmp/root_rw_status)" = "rw" ]; then
    PS1="\[\033[0;31m\]\u@\h:\w [UNLOCKED]\$\[\033[0m\] "
else
    PS1="\[\033[0;32m\]\u@\h:\w\$\[\033[0m\] "
fi
EOF

echo "Custom prompt logic successfully added to $BASHRC_PATH."

# Inform the user about the changes
echo "The /etc/bash.bashrc file has been modified to reflect the root filesystem status in the shell prompt."
echo "To activate the changes in the current session, run: source /etc/bash.bashrc"
echo "This will apply automatically in any new SSH or terminal session."

