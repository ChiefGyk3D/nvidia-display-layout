#!/bin/bash
# NVIDIA Display Monitor Daemon
# Polls for display changes and applies layout when detected
# More reliable than udev for NVIDIA proprietary drivers

SCREENLAYOUT_DIR="$HOME/.screenlayout"
LOGFILE="/tmp/nvidia-display-monitor.log"
STATEFILE="/tmp/nvidia-display-state"
POLL_INTERVAL=3  # seconds between checks
MAX_STARTUP_WAIT=60  # max seconds to wait for X at startup

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Find X display - try multiple methods
find_display() {
    # Method 1: Check environment
    if [ -n "$DISPLAY" ]; then
        if xdpyinfo -display "$DISPLAY" &>/dev/null 2>&1; then
            echo "$DISPLAY"
            return 0
        fi
    fi
    
    # Method 2: Try common display numbers
    for disp in :0 :1 :2; do
        if xdpyinfo -display "$disp" &>/dev/null 2>&1; then
            echo "$disp"
            return 0
        fi
    done
    
    # Method 3: Check loginctl for graphical sessions
    if command -v loginctl &>/dev/null; then
        local session_display
        session_display=$(loginctl show-session $(loginctl | grep "$USER" | awk '{print $1}' | head -1) -p Display --value 2>/dev/null)
        if [ -n "$session_display" ] && xdpyinfo -display "$session_display" &>/dev/null 2>&1; then
            echo "$session_display"
            return 0
        fi
    fi
    
    return 1
}

get_display_state() {
    nvidia-settings -q dpys 2>/dev/null | grep -E "(DPY-[0-9]+|connected|enabled)" | md5sum | cut -d' ' -f1
}

# Wait for X to be fully available at startup
wait_for_x() {
    local waited=0
    log "Waiting for X display..."
    
    while [ $waited -lt $MAX_STARTUP_WAIT ]; do
        if DISPLAY=$(find_display); then
            export DISPLAY
            export XAUTHORITY="$HOME/.Xauthority"
            
            # Verify nvidia-settings works
            if nvidia-settings -q dpys &>/dev/null 2>&1; then
                log "X display ready: $DISPLAY (waited ${waited}s)"
                return 0
            fi
        fi
        
        sleep 2
        waited=$((waited + 2))
    done
    
    log "ERROR: Timeout waiting for X display after ${MAX_STARTUP_WAIT}s"
    return 1
}

# Main
main() {
    # Clear old log on fresh start
    echo "" > "$LOGFILE"
    
    # Wait for X at startup
    if ! wait_for_x; then
        echo "Failed to find X display. Exiting."
        exit 1
    fi
    
    log "Display monitor started (DISPLAY=$DISPLAY, PID=$$)"
    echo "NVIDIA Display Monitor running (PID $$)"
    echo "Polling every ${POLL_INTERVAL}s for display changes..."
    echo "Log: $LOGFILE"

    # Get initial state
    LAST_STATE=$(get_display_state)
    echo "$LAST_STATE" > "$STATEFILE"
    log "Initial state: $LAST_STATE"

    # Apply layout at startup
    if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
        log "Applying initial layout..."
        "$SCREENLAYOUT_DIR/apply-layout.sh" >> "$LOGFILE" 2>&1
        log "Initial layout applied"
    fi

    # Monitor loop
    while true; do
        sleep "$POLL_INTERVAL"
        
        # Re-verify display is still valid
        if ! xdpyinfo -display "$DISPLAY" &>/dev/null 2>&1; then
            log "WARNING: Lost X display, attempting to reconnect..."
            if DISPLAY=$(find_display); then
                export DISPLAY
                log "Reconnected to $DISPLAY"
            else
                log "ERROR: Could not reconnect to X display"
                continue
            fi
        fi
        
        CURRENT_STATE=$(get_display_state)
        
        if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
            log "Display change detected! Old: $LAST_STATE New: $CURRENT_STATE"
            echo "$(date): Display change detected, applying layout..."
            
            # Wait for HDMI handshake to complete (capture cards can be slow)
            log "Waiting for display handshake..."
            sleep 3
            
            # Apply layout, then re-check and re-apply if state changed during handshake
            if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
                "$SCREENLAYOUT_DIR/apply-layout.sh" >> "$LOGFILE" 2>&1
                log "Layout applied (first pass)"
                
                # Wait and check if HDMI became ready after initial apply
                sleep 2
                local post_state=$(get_display_state)
                if [ "$post_state" != "$CURRENT_STATE" ]; then
                    log "State changed during handshake, re-applying..."
                    sleep 1
                    "$SCREENLAYOUT_DIR/apply-layout.sh" >> "$LOGFILE" 2>&1
                    log "Layout applied (second pass)"
                    CURRENT_STATE="$post_state"
                fi
            fi
            
            LAST_STATE="$CURRENT_STATE"
            echo "$LAST_STATE" > "$STATEFILE"
        fi
    done
}

main "$@"
