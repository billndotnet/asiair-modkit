#!/usr/bin/env bash
# Monitors file system for changes, logs them

# Exit on any error
set -e

# Function to print usage and exit
usage() {
    echo "Usage: $0 <log_directory>"
    echo "  <log_directory> - Directory where log files will be written"
    exit 1
}

# Verify arguments
if [ $# -ne 1 ]; then
    usage
fi

LOG_DIR="$1"

# Verify the target log directory exists and is writable
if [ ! -d "$LOG_DIR" ]; then
    echo "Error: Target log directory '$LOG_DIR' does not exist."
    exit 1
fi

if [ ! -w "$LOG_DIR" ]; then
    echo "Error: Target log directory '$LOG_DIR' is not writable by the current user."
    exit 1
fi

# Set up log file paths
LOG_FILE="$LOG_DIR/inotify_log.txt"
TIMESTAMPED_LOG_FILE="$LOG_DIR/inotify_log_with_timestamps.txt"

# Print starting message
echo "Starting inotifywait monitoring..."
echo "Logs will be written to:"
echo "  - $LOG_FILE"
echo "  - $TIMESTAMPED_LOG_FILE"

# Start monitoring filesystem changes
inotifywait -m -r / \
    --timefmt '%Y-%m-%d %H:%M:%S' --format '%T %w%f %e' \
    -e modify,attrib,close_write,move,create,delete \
    2>&1 | tee "$LOG_FILE" | while read -r line; do
        # Append timestamped entries to the secondary log file
        echo "$(date '+%Y-%m-%d %H:%M:%S') $line" >> "$TIMESTAMPED_LOG_FILE"
    done

