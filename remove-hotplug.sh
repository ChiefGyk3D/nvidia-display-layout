#!/bin/bash
# =============================================================================
# Remove NVIDIA Display Hotplug/Monitor Support
# =============================================================================
# Cleanly removes the display monitor service and/or udev rules installed by
# install-hotplug.sh. The base layout scripts and systemd login service are
# NOT removed — only the hotplug detection components.
#
# Usage:
#   ./remove-hotplug.sh        # Remove monitor service (no root needed)
#   sudo ./remove-hotplug.sh   # Also remove udev rules
#
# To fully uninstall everything, see the Uninstalling section in README.md.
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Removing NVIDIA Display Hotplug/Monitor Support${NC}"
echo ""

# --- Stop and disable the polling-based monitor service (user-level, no root) ---
echo "Checking for display monitor service..."
if systemctl --user is-active nvidia-display-monitor.service &>/dev/null; then
    systemctl --user stop nvidia-display-monitor.service
    echo -e "${GREEN}✓ Stopped monitor service${NC}"
fi

if systemctl --user is-enabled nvidia-display-monitor.service &>/dev/null 2>&1; then
    systemctl --user disable nvidia-display-monitor.service
    echo -e "${GREEN}✓ Disabled monitor service${NC}"
fi

# --- Remove the systemd service unit file and reload ---
SERVICE_FILE="$HOME/.config/systemd/user/nvidia-display-monitor.service"
if [ -f "$SERVICE_FILE" ]; then
    rm -f "$SERVICE_FILE"
    systemctl --user daemon-reload
    echo -e "${GREEN}✓ Removed service file${NC}"
else
    echo -e "${YELLOW}⚠ Monitor service not installed${NC}"
fi

# --- Remove udev rule (alternative hotplug method, requires root) ---
UDEV_RULE="/etc/udev/rules.d/99-nvidia-display-hotplug.rules"

if [ -f "$UDEV_RULE" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo ""
        echo -e "${YELLOW}udev rule found. Run with sudo to remove it:${NC}"
        echo "  sudo $0"
    else
        rm -f "$UDEV_RULE"
        udevadm control --reload-rules
        echo -e "${GREEN}✓ Removed udev rule${NC}"
    fi
else
    echo -e "${YELLOW}⚠ udev rule not installed${NC}"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Removal complete!                       ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Display layout will no longer auto-apply on hotplug."
echo "You can still use:"
echo "  • Keyboard shortcut"
echo "  • systemd service (applies on login)"
echo ""
echo "To reinstall:"
echo "  ./install-hotplug.sh"
