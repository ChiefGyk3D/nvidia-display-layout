#!/bin/bash
# NVIDIA Multi-Monitor Setup - Dynamic Display Configuration
# Automatically detects displays, refresh rates, and applies optimal settings
# Works with any number of monitors, with or without a capture card
#
# If the nvidia-capture-card project's apply-layout.sh is installed,
# this script delegates to it. Otherwise, it auto-detects and applies
# ForceFullCompositionPipeline to all real displays.
#
# Usage:
#   ./nvidia-display-setup.sh          # Auto-detect and apply
#   ./nvidia-display-setup.sh --status # Show current display info
#   ./nvidia-display-setup.sh --setup  # Run the full setup wizard
#
# To auto-start on login, enable the systemd service:
#   systemctl --user enable apply-display-layout.service
#   systemctl --user enable nvidia-display-monitor.service

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCREENLAYOUT_DIR="$HOME/.screenlayout"

# Ensure DISPLAY is set
export DISPLAY="${DISPLAY:-:0}"
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# --- Helpers ---

log() {
    echo -e "${GREEN}[nvidia-display]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[nvidia-display]${NC} $1"
}

err() {
    echo -e "${RED}[nvidia-display]${NC} $1" >&2
}

# --- Delegated mode: use nvidia-capture-card project if installed ---

if [ "${1:-}" != "--status" ] && [ "${1:-}" != "--setup" ]; then
    if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
        log "Using installed layout from $SCREENLAYOUT_DIR/apply-layout.sh"
        "$SCREENLAYOUT_DIR/apply-layout.sh"
        exit $?
    fi
fi

# --- Setup wizard redirect ---

if [ "${1:-}" = "--setup" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Check for setup wizard in known locations
    for wizard in \
        "$SCRIPT_DIR/setup-wizard.sh" \
        "$HOME/src/nvidia-capture-card/setup-wizard.sh" \
        "/opt/nvidia-capture-card/setup-wizard.sh"; do
        if [ -x "$wizard" ]; then
            exec "$wizard"
        fi
    done
    err "Setup wizard not found. Install the nvidia-capture-card project first."
    err "  git clone https://github.com/ChiefGyk3D/nvidia-capture-card.git"
    exit 1
fi

# --- Status mode ---

if [ "${1:-}" = "--status" ]; then
    echo -e "${CYAN}═══ Connected Displays ═══${NC}"
    nvidia-settings -q dpys 2>/dev/null | grep -E "DPY-[0-9]+" | while read -r line; do
        if echo "$line" | grep -q "connected"; then
            echo -e "  ${GREEN}●${NC} $line"
        else
            echo -e "  ${RED}○${NC} $line"
        fi
    done
    echo ""
    echo -e "${CYAN}═══ Current MetaMode ═══${NC}"
    nvidia-settings -q CurrentMetaMode 2>/dev/null | grep -A1 "Attribute" | tail -1 | sed 's/^[[:space:]]*/  /'
    echo ""
    
    if [ -x "$SCREENLAYOUT_DIR/apply-layout.sh" ]; then
        echo -e "${GREEN}●${NC} Saved layout: $SCREENLAYOUT_DIR/apply-layout.sh"
    else
        echo -e "${YELLOW}○${NC} No saved layout found. Run: $0 --setup"
    fi
    
    if systemctl --user is-active apply-display-layout.service &>/dev/null; then
        echo -e "${GREEN}●${NC} Login layout service: active"
    else
        echo -e "${YELLOW}○${NC} Login layout service: inactive"
    fi
    
    if systemctl --user is-active nvidia-display-monitor.service &>/dev/null; then
        echo -e "${GREEN}●${NC} Display monitor: running"
    else
        echo -e "${YELLOW}○${NC} Display monitor: not running"
    fi
    exit 0
fi

# --- Fallback: Auto-detect and apply ForceFullCompositionPipeline ---
# This runs when no saved layout exists — useful for fresh installs

log "No saved layout found. Auto-detecting displays..."

if ! command -v nvidia-settings &>/dev/null; then
    err "nvidia-settings not found. Install NVIDIA drivers first."
    exit 1
fi

# Get current MetaMode and add ForceFullCompositionPipeline to each display
CURRENT_META=$(nvidia-settings -t -q CurrentMetaMode 2>/dev/null || true)

if [ -z "$CURRENT_META" ]; then
    err "Could not read current MetaMode. Is X11 running?"
    exit 1
fi

# Parse displays from current meta mode and add FFCP
# Format: DPY-X: RES +X+Y {options}, ...
NEW_META=""
FIRST=true

# Split by comma, process each display entry
while IFS=',' read -ra ENTRIES; do
    for entry in "${ENTRIES[@]}"; do
        entry=$(echo "$entry" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -z "$entry" ] && continue
        
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            NEW_META+=", "
        fi
        
        # Check if this entry already has ForceFullCompositionPipeline
        if echo "$entry" | grep -q "ForceFullCompositionPipeline"; then
            NEW_META+="$entry"
        elif echo "$entry" | grep -q "{"; then
            # Has existing options, append to them
            NEW_META+=$(echo "$entry" | sed 's/}/, ForceFullCompositionPipeline=On}/')
        else
            # No options block, add one
            NEW_META+="$entry {ForceFullCompositionPipeline=On}"
        fi
    done
done <<< "$CURRENT_META"

if [ -n "$NEW_META" ]; then
    nvidia-settings --assign "CurrentMetaMode=$NEW_META" 2>/dev/null
    log "Applied ForceFullCompositionPipeline to all displays"
    echo ""
    warn "This is a temporary auto-detection. For a persistent setup, run:"
    echo "  $0 --setup"
else
    err "Could not parse current display configuration"
    exit 1
fi
