#!/bin/bash
# NVIDIA Display Monitor Daemon
# Polls for display changes and applies layout when detected
# More reliable than udev for NVIDIA proprietary drivers

SCREENLAYOUT_DIR="$HOME/.screenlayout"
LOGFILE="/tmp/nvidia-display-monitor.log"
STATEFILE="/tmp/nvidia-display-state"
POLL_INTERVAL=3  # seconds between checks

# Find X display
find_display() {
    for disp in :0 :1 :2; do
        if xdpyinfo -display "$disp" &>/dev/null 2>&1; then
            echo "$disp"
            return 0
        fi
    done
    return 1
}

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

get_display_state() {
    nvidia-settings -q dpys 2>/dev/null | grep -E "(DPY-[0-9]+|connected|enabled)" | md5sum | cut -d' ' -f1
}

# Setup
export DISPLAY=$(find_display) || { echo "No X display found"; exit 1; }
export XAUTHORITY="$HOME/.Xauthority"

log "Display monitor started (DISPLAY=$DISPLAY, PID=$$)"
echo "NVIDIA Display Monitor running (PID $$)"
echo "Polling every ${POLL_INTERVAL}s for display changes..."
echo "Log: $LOGFILE"

# Get initial state
LAST_STATE=$(get_display_state)
echo "$LAST_STATE" > "$STATEFILE"
log "Initial state: $LAST_STATE"

# Monitor loop
while true; do
    sleep "$POLL_INTERVAL"
    
    CURRENT_STATE=$(get_display_state)
    
    if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        log "Display change detected! Old: $LAST_STATE New: $CURRENT_STATE"
        echo "$(date): Display change detected, applying layout..."
        
        # Small delay for hardware to stabilize
        sleep 1
        
        if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
            "$SCREENLAYOUT_DIR/apply-layout.sh" >> "$LOGFILE" 2>&1
            log "Layout applied"
        fi
        
        LAST_STATE="$CURRENT_STATE"
        echo "$LAST_STATE" > "$STATEFILE"
    fi
done
