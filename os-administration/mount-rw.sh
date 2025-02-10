#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root. Please use sudo or switch to the root user."
  exit 1
fi

# Get the actual mount status for the root filesystem
root_status=$(mount | grep "on / " | head -n 1 | grep -oP "\((rw|ro)[,)]")

# Extract "rw" or "ro" from the result
if [[ "$root_status" == *"(rw"* ]]; then
  echo "The root filesystem is already mounted as read-write."
  exit 0
elif [[ "$root_status" == *"(ro"* ]]; then
  echo "The root filesystem is currently mounted as read-only. Proceeding to remount as read-write..."
else
  echo "Error: Unable to determine the mount status of the root filesystem."
  exit 1
fi

# Attempt to remount the root filesystem as read-write
if mount -o remount,rw /; then
  echo "Success: The root filesystem has been remounted as read-write."
else
  echo "Error: Failed to remount the root filesystem as read-write. Please check for errors."
  exit 1
fi

