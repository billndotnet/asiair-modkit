#!/usr/bin/env bash
# Monitors file system for changes, logs them

# Exit immediately on errors
set -euo pipefail

# Function to print usage
usage() {
    echo "Usage: $0 <log_directory> [directories_to_monitor]"
    echo "  <log_directory> - Directory where log files will be written"
    echo "  [directories_to_monitor] - Comma-separated list of directories to monitor (optional)"
    echo "                              Defaults to '/etc,/tmp,/home'"
    exit 1
}

# Verify at least one argument is provided
if [ $# -lt 1 ]; then
    usage
fi

LOG_DIR="$1"
DEFAULT_DIRS="/etc,/tmp,/home"
DIRS_TO_MONITOR="${2:-$DEFAULT_DIRS}"

# Convert comma-separated directory list to space-separated for use with inotifywait
IFS=',' read -ra MONITOR_DIRS <<< "$DIRS_TO_MONITOR"

# Verify the target log directory exists and is writable
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Target log directory '$LOG_DIR' does not exist."
    exit 1
fi

if [ ! -w "$LOG_DIR" ]; then
    echo "Error: Target log directory '$LOG_DIR' is not writable by the current user."
    exit 1
fi

# Create log file paths
RAW_LOG_FILE="$LOG_DIR/inotify_raw.log"
TIMESTAMPED_LOG_FILE="$LOG_DIR/inotify_timestamped.log"
RAM_DISK_LOG="/tmp/inotify_ram.log"

# Function to set up a RAM disk for temporary logging
setup_ramdisk() {
    echo "Setting up RAM disk for temporary logging..."
    mkdir -p /tmp/inotify_logs
    mountpoint -q /tmp/inotify_logs || mount -t tmpfs -o size=100M tmpfs /tmp/inotify_logs
    echo "RAM disk ready at /tmp/inotify_logs"
}

# Function to clean up RAM disk
cleanup_ramdisk() {
    echo "Cleaning up RAM disk..."
    umount /tmp/inotify_logs || true
    rmdir /tmp/inotify_logs || true
    echo "RAM disk cleaned up."
}

# Trap to clean up RAM disk on exit
trap cleanup_ramdisk EXIT

# Set up the RAM disk
setup_ramdisk

# Print starting message
echo "Starting inotifywait monitoring..."
echo "Monitoring directories: ${MONITOR_DIRS[*]}"
echo "Raw log will be written to:"
echo "  - $RAW_LOG_FILE"
echo "Timestamped log will be written to:"
echo "  - $TIMESTAMPED_LOG_FILE"

# Start monitoring the specified directories and log to RAM disk
stdbuf -oL inotifywait -m -r "${MONITOR_DIRS[@]}" \
    --exclude '^/(proc|sys|dev|run)' \
    --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w%f %e' \
    -e modify,attrib,close_write,move,create,delete \
    > /tmp/inotify_logs/inotify_raw.log 2>&1 &

INOTIFY_PID=$!

# Periodically sync logs from RAM disk to the target directory
while true; do
    if [ -f /tmp/inotify_logs/inotify_raw.log ]; then
        # Sync the raw log file
        cp /tmp/inotify_logs/inotify_raw.log "$RAW_LOG_FILE"
        # Add timestamps and sync the timestamped log file
        while read -r line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') $line"
        done < /tmp/inotify_logs/inotify_raw.log >> "$TIMESTAMPED_LOG_FILE"
    fi
    sleep 5  # Adjust sync interval as needed
done &

SYNC_PID=$!

# Trap to clean up child processes on exit
trap "kill $INOTIFY_PID $SYNC_PID; cleanup_ramdisk" EXIT

# Wait for processes to finish (or manual interruption)
wait $INOTIFY_PID

