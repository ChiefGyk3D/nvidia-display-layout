#!/bin/bash
# Quick display detection and status check
# Shows current displays and helps with reconfiguration

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

export DISPLAY=${DISPLAY:-:1}
export XAUTHORITY="$HOME/.Xauthority"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           NVIDIA Display Status & Configuration              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check current displays
echo -e "${YELLOW}═══ Connected Displays ═══${NC}"
echo ""
nvidia-settings -q dpys 2>/dev/null | grep -E "DPY-[0-9]+" | while read -r line; do
    if echo "$line" | grep -q "connected"; then
        echo -e "${GREEN}●${NC} $line"
    else
        echo -e "${RED}○${NC} $line"
    fi
done
echo ""

# Current MetaMode
echo -e "${YELLOW}═══ Current MetaMode ═══${NC}"
echo ""
nvidia-settings -q CurrentMetaMode 2>/dev/null | grep -A1 "Attribute" | tail -1 | sed 's/^[[:space:]]*//'
echo ""

# Check services
echo -e "${YELLOW}═══ Services Status ═══${NC}"
echo ""

if systemctl --user is-active apply-display-layout.service &>/dev/null; then
    echo -e "${GREEN}●${NC} Login layout service: enabled"
else
    echo -e "${YELLOW}○${NC} Login layout service: not active"
fi

if systemctl --user is-active nvidia-display-monitor.service &>/dev/null; then
    echo -e "${GREEN}●${NC} Display monitor: running"
else
    echo -e "${YELLOW}○${NC} Display monitor: not running"
fi

if [ -f /etc/udev/rules.d/99-nvidia-display-hotplug.rules ]; then
    echo -e "${YELLOW}●${NC} udev hotplug: installed (may not work with NVIDIA)"
fi

echo ""

# Check for config
echo -e "${YELLOW}═══ Configuration ═══${NC}"
echo ""
if [ -f "$HOME/.screenlayout/.layout-config" ]; then
    echo "Saved configuration found:"
    grep -E "^DISPLAY_[0-9]+_(ID|RES|POS|ROT)=" "$HOME/.screenlayout/.layout-config" | while read -r line; do
        echo "  $line"
    done
else
    echo "No saved configuration found."
fi
echo ""

# Actions menu
echo -e "${YELLOW}═══ Actions ═══${NC}"
echo ""
echo "  [1] Apply layout now"
echo "  [2] Run full setup wizard (for new/changed monitors)"
echo "  [3] Restart display monitor service"
echo "  [4] View monitor log"
echo "  [5] Exit"
echo ""
read -p "Select action [1-5]: " action

case "$action" in
    1)
        echo ""
        echo "Applying layout..."
        ~/.screenlayout/apply-layout.sh
        echo -e "${GREEN}Done!${NC}"
        ;;
    2)
        echo ""
        if [ -f "$(dirname "$0")/setup-wizard.sh" ]; then
            "$(dirname "$0")/setup-wizard.sh"
        elif [ -f "$HOME/.screenlayout/setup-wizard.sh" ]; then
            "$HOME/.screenlayout/setup-wizard.sh"
        else
            echo -e "${RED}Setup wizard not found. Run it from the repo directory.${NC}"
        fi
        ;;
    3)
        echo ""
        systemctl --user restart nvidia-display-monitor.service
        echo -e "${GREEN}Monitor service restarted${NC}"
        ;;
    4)
        echo ""
        if [ -f /tmp/nvidia-display-monitor.log ]; then
            tail -20 /tmp/nvidia-display-monitor.log
        else
            echo "No log file found"
        fi
        ;;
    5|"")
        echo "Bye!"
        ;;
    *)
        echo "Invalid selection"
        ;;
esac
