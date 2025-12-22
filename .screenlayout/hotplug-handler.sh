#!/bin/bash
# NVIDIA Display Hotplug Handler
# Waits for display to be ready, then applies layout
# Called by udev rule

LOGFILE="/tmp/nvidia-hotplug.log"
SCREENLAYOUT_DIR="$HOME/.screenlayout"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

log "Hotplug event triggered"

# Find the active X display
find_display() {
    # Try common display numbers
    for disp in :0 :1 :2; do
        if xdpyinfo -display "$disp" &>/dev/null 2>&1; then
            echo "$disp"
            return 0
        fi
    done
    return 1
}

# Wait for X to be available and display to stabilize
wait_for_display() {
    local max_attempts=30
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if DISPLAY=$(find_display); then
            export DISPLAY
            export XAUTHORITY="$HOME/.Xauthority"
            
            # Check if nvidia-settings can query displays
            if nvidia-settings -q dpys &>/dev/null 2>&1; then
                log "Display ready: $DISPLAY"
                return 0
            fi
        fi
        
        ((attempt++))
        sleep 0.5
    done
    
    log "Timeout waiting for display"
    return 1
}

# Main execution
main() {
    # Initial delay to let hardware settle
    sleep 2
    
    if ! wait_for_display; then
        log "Failed to find ready display"
        exit 1
    fi
    
    # Additional stabilization delay
    sleep 1
    
    # Apply layout
    if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
        log "Applying layout..."
        "$SCREENLAYOUT_DIR/apply-layout.sh" >> "$LOGFILE" 2>&1
        log "Layout applied"
    else
        log "apply-layout.sh not found or not executable"
        exit 1
    fi
}

main "$@"
