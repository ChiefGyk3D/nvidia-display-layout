#!/bin/bash
# Install hotplug/monitor support for NVIDIA display layout
# Must be run with sudo (for udev) OR without sudo (for monitor service only)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     NVIDIA Display Hotplug/Monitor Installer                 ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo "Choose installation method:"
echo ""
echo "  [1] Display Monitor Service (RECOMMENDED)"
echo "      - Polls for display changes every 3 seconds"
echo "      - Works reliably with NVIDIA proprietary drivers"
echo "      - Runs as user service, no root needed"
echo ""
echo "  [2] udev Rules (may not work with NVIDIA)"
echo "      - Triggers on kernel hotplug events"
echo "      - Requires root/sudo"
echo "      - NVIDIA drivers often don't send these events"
echo ""
read -p "Select [1/2] (default: 1): " choice
choice=${choice:-1}

if [ "$choice" = "1" ]; then
    # Install monitor service (no root needed)
    echo ""
    echo -e "${YELLOW}Installing Display Monitor Service...${NC}"
    
    # Copy monitor script
    MONITOR_SRC="$SCRIPT_DIR/.screenlayout/display-monitor.sh"
    MONITOR_DST="$HOME/.screenlayout/display-monitor.sh"
    
    if [ -f "$MONITOR_SRC" ]; then
        cp "$MONITOR_SRC" "$MONITOR_DST"
        chmod +x "$MONITOR_DST"
        echo -e "${GREEN}✓ Installed display-monitor.sh${NC}"
    else
        echo -e "${RED}Error: display-monitor.sh not found${NC}"
        exit 1
    fi
    
    # Copy systemd service
    SERVICE_SRC="$SCRIPT_DIR/.config/systemd/user/nvidia-display-monitor.service"
    SERVICE_DST="$HOME/.config/systemd/user/nvidia-display-monitor.service"
    
    mkdir -p "$HOME/.config/systemd/user"
    if [ -f "$SERVICE_SRC" ]; then
        cp "$SERVICE_SRC" "$SERVICE_DST"
        echo -e "${GREEN}✓ Installed systemd service${NC}"
    else
        echo -e "${RED}Error: service file not found${NC}"
        exit 1
    fi
    
    # Enable and start service
    systemctl --user daemon-reload
    systemctl --user enable nvidia-display-monitor.service
    systemctl --user start nvidia-display-monitor.service
    
    echo -e "${GREEN}✓ Service enabled and started${NC}"
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Display Monitor installed successfully!          ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "The monitor is now running and will auto-apply layout on display changes."
    echo ""
    echo "Commands:"
    echo "  Status:  systemctl --user status nvidia-display-monitor"
    echo "  Logs:    cat /tmp/nvidia-display-monitor.log"
    echo "  Stop:    systemctl --user stop nvidia-display-monitor"
    echo "  Disable: systemctl --user disable nvidia-display-monitor"
    
elif [ "$choice" = "2" ]; then
    # Install udev rules (needs root)
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: udev installation requires sudo${NC}"
        echo "Usage: sudo $0"
        exit 1
    fi
    
    # Get the actual user
    if [ -n "$SUDO_USER" ]; then
        ACTUAL_USER="$SUDO_USER"
        ACTUAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    else
        echo -e "${RED}Error: Could not determine the actual user${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Installing udev rules...${NC}"
    echo "User: $ACTUAL_USER"
    
    # Install hotplug handler
    HANDLER_SRC="$SCRIPT_DIR/.screenlayout/hotplug-handler.sh"
    HANDLER_DST="$ACTUAL_HOME/.screenlayout/hotplug-handler.sh"
    
    if [ -f "$HANDLER_SRC" ]; then
        cp "$HANDLER_SRC" "$HANDLER_DST"
        chown "$ACTUAL_USER:$ACTUAL_USER" "$HANDLER_DST"
        chmod +x "$HANDLER_DST"
        echo -e "${GREEN}✓ Installed hotplug-handler.sh${NC}"
    else
        echo -e "${RED}Error: hotplug-handler.sh not found${NC}"
        exit 1
    fi
    
    # Install udev rule
    UDEV_SRC="$SCRIPT_DIR/udev/99-nvidia-display-hotplug.rules"
    UDEV_DST="/etc/udev/rules.d/99-nvidia-display-hotplug.rules"
    
    if [ -f "$UDEV_SRC" ]; then
        sed "s/USERNAME/$ACTUAL_USER/g" "$UDEV_SRC" > "$UDEV_DST"
        chmod 644 "$UDEV_DST"
        echo -e "${GREEN}✓ Installed udev rule${NC}"
    else
        echo -e "${RED}Error: udev rule not found${NC}"
        exit 1
    fi
    
    udevadm control --reload-rules
    udevadm trigger
    echo -e "${GREEN}✓ udev rules reloaded${NC}"
    
    echo ""
    echo -e "${YELLOW}⚠ WARNING: udev hotplug often doesn't work with NVIDIA drivers${NC}"
    echo -e "${YELLOW}  If it doesn't work, run this script again and choose option 1${NC}"
    echo ""
    echo "Logs: /tmp/nvidia-hotplug.log"
fi
