#!/bin/bash
# NVIDIA Display Layout Setup Wizard
# Generates personalized MetaMode scripts based on your monitor configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCREENLAYOUT_DIR="$HOME/.screenlayout"
SYSTEMD_DIR="$HOME/.config/systemd/user"
SERVICE_NAME="apply-display-layout.service"

# Arrays to store monitor configuration
declare -a DISPLAY_IDS
declare -a DISPLAY_NAMES
declare -a DISPLAY_RESOLUTIONS
declare -a DISPLAY_POSITIONS
declare -a DISPLAY_ROTATIONS
declare -a DISPLAY_OFFSETS

# Capture card config
CAPTURE_ENABLED=false
CAPTURE_DISPLAY=""
CAPTURE_MIRROR_TARGET=""

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     NVIDIA Display Layout Setup Wizard                       ║"
echo "║     Deterministic MetaMode Configuration                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check requirements
check_requirements() {
    echo -e "${BLUE}Checking requirements...${NC}"
    
    if ! command -v nvidia-settings &> /dev/null; then
        echo -e "${RED}Error: nvidia-settings not found. Please install NVIDIA drivers.${NC}"
        exit 1
    fi
    
    if [ -z "$DISPLAY" ]; then
        export DISPLAY=:0
    fi
    
    if [ -z "$XAUTHORITY" ]; then
        export XAUTHORITY="$HOME/.Xauthority"
    fi
    
    echo -e "${GREEN}✓ nvidia-settings found${NC}"
    echo -e "${GREEN}✓ DISPLAY=$DISPLAY${NC}"
    echo ""
}

# Detect connected displays
detect_displays() {
    echo -e "${BLUE}Detecting connected displays...${NC}"
    echo ""
    
    # Get display info from nvidia-settings
    local dpys_output
    dpys_output=$(nvidia-settings -q dpys 2>/dev/null) || {
        echo -e "${RED}Error: Could not query displays. Is X11 running?${NC}"
        exit 1
    }
    
    # Parse connected displays
    local count=0
    while IFS= read -r line; do
        if [[ "$line" =~ \[([0-9]+)\].*\'([^\']+)\'.*\((DPY-[0-9]+)\) ]]; then
            local idx="${BASH_REMATCH[1]}"
            local name="${BASH_REMATCH[2]}"
            local dpy="${BASH_REMATCH[3]}"
            
            # Check if connected
            if echo "$dpys_output" | grep -A5 "$dpy" | grep -q "connected"; then
                DISPLAY_IDS+=("$dpy")
                DISPLAY_NAMES+=("$name")
                ((count++))
                echo -e "  ${GREEN}[$count]${NC} $dpy - $name"
            fi
        fi
    done <<< "$dpys_output"
    
    if [ ${#DISPLAY_IDS[@]} -eq 0 ]; then
        echo -e "${RED}No connected displays found!${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${GREEN}Found ${#DISPLAY_IDS[@]} connected display(s)${NC}"
    echo ""
}

# Get available resolutions for a display
get_resolutions() {
    local dpy="$1"
    # Common resolutions - nvidia-settings can be queried for more
    echo "3840x2160"
    echo "2560x1440"
    echo "1920x1080"
    echo "1680x1050"
    echo "1600x900"
    echo "1440x900"
    echo "1366x768"
    echo "1280x1024"
    echo "1280x720"
    echo "custom"
}

# Configure each display
configure_displays() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    DISPLAY CONFIGURATION                       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    local positions=("left" "center" "right" "top" "bottom" "skip")
    local rotations=("normal" "left" "right" "inverted")
    
    for i in "${!DISPLAY_IDS[@]}"; do
        local dpy="${DISPLAY_IDS[$i]}"
        local name="${DISPLAY_NAMES[$i]}"
        
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}Configuring: $dpy ($name)${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        
        # Position
        echo "Select position for this display:"
        for p in "${!positions[@]}"; do
            echo "  [$((p+1))] ${positions[$p]}"
        done
        echo ""
        read -p "Position [1-${#positions[@]}]: " pos_choice
        pos_choice=${pos_choice:-2}  # Default to center
        DISPLAY_POSITIONS[$i]="${positions[$((pos_choice-1))]}"
        
        if [ "${DISPLAY_POSITIONS[$i]}" = "skip" ]; then
            echo -e "${YELLOW}Skipping $dpy${NC}"
            echo ""
            continue
        fi
        
        # Resolution
        echo ""
        echo "Select resolution:"
        local res_options=($(get_resolutions "$dpy"))
        for r in "${!res_options[@]}"; do
            echo "  [$((r+1))] ${res_options[$r]}"
        done
        echo ""
        read -p "Resolution [1-${#res_options[@]}] (default: 3 for 1920x1080): " res_choice
        res_choice=${res_choice:-3}
        
        if [ "${res_options[$((res_choice-1))]}" = "custom" ]; then
            read -p "Enter custom resolution (e.g., 2560x1080): " custom_res
            DISPLAY_RESOLUTIONS[$i]="$custom_res"
        else
            DISPLAY_RESOLUTIONS[$i]="${res_options[$((res_choice-1))]}"
        fi
        
        # Rotation
        echo ""
        echo "Select rotation:"
        for r in "${!rotations[@]}"; do
            echo "  [$((r+1))] ${rotations[$r]}"
        done
        echo ""
        read -p "Rotation [1-${#rotations[@]}] (default: 1 for normal): " rot_choice
        rot_choice=${rot_choice:-1}
        DISPLAY_ROTATIONS[$i]="${rotations[$((rot_choice-1))]}"
        
        echo ""
        echo -e "${GREEN}✓ Configured $dpy: ${DISPLAY_RESOLUTIONS[$i]} @ ${DISPLAY_POSITIONS[$i]} (${DISPLAY_ROTATIONS[$i]})${NC}"
        echo ""
    done
}

# Configure capture card
configure_capture() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                  CAPTURE CARD CONFIGURATION                    ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    read -p "Do you have an HDMI capture card? [y/N]: " has_capture
    
    if [[ "$has_capture" =~ ^[Yy] ]]; then
        CAPTURE_ENABLED=true
        
        echo ""
        echo "Select which display is your capture card:"
        for i in "${!DISPLAY_IDS[@]}"; do
            echo "  [$((i+1))] ${DISPLAY_IDS[$i]} - ${DISPLAY_NAMES[$i]}"
        done
        echo ""
        read -p "Capture card display: " cap_choice
        CAPTURE_DISPLAY="${DISPLAY_IDS[$((cap_choice-1))]}"
        
        echo ""
        echo "Select which display the capture card should mirror:"
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_IDS[$i]}" != "$CAPTURE_DISPLAY" ] && [ "${DISPLAY_POSITIONS[$i]}" != "skip" ]; then
                echo "  [$((i+1))] ${DISPLAY_IDS[$i]} - ${DISPLAY_NAMES[$i]}"
            fi
        done
        echo ""
        read -p "Mirror target display: " mirror_choice
        CAPTURE_MIRROR_TARGET="${DISPLAY_IDS[$((mirror_choice-1))]}"
        
        echo ""
        echo -e "${GREEN}✓ Capture card: $CAPTURE_DISPLAY mirrors $CAPTURE_MIRROR_TARGET${NC}"
    else
        echo -e "${YELLOW}No capture card configured${NC}"
    fi
    echo ""
}

# Calculate offsets based on positions
calculate_offsets() {
    # Sort displays by position and calculate X,Y offsets
    local x_offset=0
    local max_height=0
    
    # First pass: find max height for vertical centering
    for i in "${!DISPLAY_IDS[@]}"; do
        if [ "${DISPLAY_POSITIONS[$i]}" = "skip" ]; then
            continue
        fi
        
        local res="${DISPLAY_RESOLUTIONS[$i]}"
        local rot="${DISPLAY_ROTATIONS[$i]}"
        local width="${res%x*}"
        local height="${res#*x}"
        
        # Swap for rotation
        if [ "$rot" = "left" ] || [ "$rot" = "right" ]; then
            local tmp=$width
            width=$height
            height=$tmp
        fi
        
        if [ "$height" -gt "$max_height" ]; then
            max_height=$height
        fi
    done
    
    # Process left displays first, then center, then right
    local positions_order=("left" "center" "right")
    x_offset=0
    
    for pos in "${positions_order[@]}"; do
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_POSITIONS[$i]}" != "$pos" ]; then
                continue
            fi
            
            local res="${DISPLAY_RESOLUTIONS[$i]}"
            local rot="${DISPLAY_ROTATIONS[$i]}"
            local width="${res%x*}"
            local height="${res#*x}"
            
            # Swap for rotation
            if [ "$rot" = "left" ] || [ "$rot" = "right" ]; then
                local tmp=$width
                width=$height
                height=$tmp
            fi
            
            # Calculate Y offset for vertical centering
            local y_offset=$(( (max_height - height) / 2 ))
            
            DISPLAY_OFFSETS[$i]="+${x_offset}+${y_offset}"
            
            x_offset=$((x_offset + width))
        done
    done
}

# Generate MetaMode string
generate_metamode() {
    local include_capture="$1"
    local metamode=""
    local first=true
    
    for i in "${!DISPLAY_IDS[@]}"; do
        local dpy="${DISPLAY_IDS[$i]}"
        local pos="${DISPLAY_POSITIONS[$i]}"
        local res="${DISPLAY_RESOLUTIONS[$i]}"
        local rot="${DISPLAY_ROTATIONS[$i]}"
        local offset="${DISPLAY_OFFSETS[$i]}"
        
        # Skip if position is skip
        if [ "$pos" = "skip" ]; then
            continue
        fi
        
        # Skip capture card in base mode
        if [ "$dpy" = "$CAPTURE_DISPLAY" ] && [ "$include_capture" = "false" ]; then
            continue
        fi
        
        if [ "$first" = true ]; then
            first=false
        else
            metamode+=", \\"$'\n'
        fi
        
        # Build display config
        local config="$dpy: $res $offset"
        
        # Add rotation if not normal
        if [ "$rot" != "normal" ]; then
            local rot_value
            case "$rot" in
                left) rot_value="Left" ;;
                right) rot_value="Right" ;;
                inverted) rot_value="Inverted" ;;
            esac
            config+=" {Rotation=$rot_value}"
        fi
        
        metamode+="$config"
    done
    
    # Add capture card mirroring if enabled
    if [ "$include_capture" = "true" ] && [ "$CAPTURE_ENABLED" = true ]; then
        # Find the mirror target's offset
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_IDS[$i]}" = "$CAPTURE_MIRROR_TARGET" ]; then
                local mirror_res="${DISPLAY_RESOLUTIONS[$i]}"
                local mirror_offset="${DISPLAY_OFFSETS[$i]}"
                metamode+=", \\"$'\n'
                metamode+="$CAPTURE_DISPLAY: $mirror_res $mirror_offset"
                break
            fi
        done
    fi
    
    echo "$metamode"
}

# Get X display number
get_display_number() {
    if [ -n "$DISPLAY" ]; then
        echo "$DISPLAY"
    else
        echo ":0"
    fi
}

# Generate scripts
generate_scripts() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                    GENERATING SCRIPTS                          ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Calculate offsets
    calculate_offsets
    
    # Create directories
    mkdir -p "$SCREENLAYOUT_DIR"
    mkdir -p "$SYSTEMD_DIR"
    
    local display_num=$(get_display_number)
    
    # Generate nvidia-base.sh
    echo -e "${BLUE}Generating nvidia-base.sh...${NC}"
    local base_metamode=$(generate_metamode "false")
    
    cat > "$SCREENLAYOUT_DIR/nvidia-base.sh" << EOF
#!/bin/bash
# NVIDIA MetaMode base layout
# Generated by setup-wizard.sh on $(date)

export DISPLAY=$display_num
export XAUTHORITY="\$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\\
$base_metamode"
EOF
    chmod +x "$SCREENLAYOUT_DIR/nvidia-base.sh"
    echo -e "${GREEN}✓ Created $SCREENLAYOUT_DIR/nvidia-base.sh${NC}"
    
    # Generate nvidia-capture.sh if capture is enabled
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo -e "${BLUE}Generating nvidia-capture.sh...${NC}"
        local capture_metamode=$(generate_metamode "true")
        
        cat > "$SCREENLAYOUT_DIR/nvidia-capture.sh" << EOF
#!/bin/bash
# NVIDIA MetaMode with capture card enabled
# Generated by setup-wizard.sh on $(date)

export DISPLAY=$display_num
export XAUTHORITY="\$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\\
$capture_metamode"
EOF
        chmod +x "$SCREENLAYOUT_DIR/nvidia-capture.sh"
        echo -e "${GREEN}✓ Created $SCREENLAYOUT_DIR/nvidia-capture.sh${NC}"
    fi
    
    # Generate apply-layout.sh
    echo -e "${BLUE}Generating apply-layout.sh...${NC}"
    
    if [ "$CAPTURE_ENABLED" = true ]; then
        # Get the capture card's display name for detection
        local capture_name=""
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_IDS[$i]}" = "$CAPTURE_DISPLAY" ]; then
                capture_name="${DISPLAY_NAMES[$i]}"
                break
            fi
        done
        
        cat > "$SCREENLAYOUT_DIR/apply-layout.sh" << EOF
#!/bin/bash
# Apply correct NVIDIA MetaMode depending on capture card presence
# Generated by setup-wizard.sh on $(date)

export DISPLAY=$display_num
export XAUTHORITY="\$HOME/.Xauthority"

if nvidia-settings -q dpys | grep -q "${capture_name}.*connected.*enabled"; then
    ~/.screenlayout/nvidia-capture.sh
else
    ~/.screenlayout/nvidia-base.sh
fi
EOF
    else
        cat > "$SCREENLAYOUT_DIR/apply-layout.sh" << EOF
#!/bin/bash
# Apply NVIDIA MetaMode layout
# Generated by setup-wizard.sh on $(date)

export DISPLAY=$display_num
export XAUTHORITY="\$HOME/.Xauthority"

~/.screenlayout/nvidia-base.sh
EOF
    fi
    chmod +x "$SCREENLAYOUT_DIR/apply-layout.sh"
    echo -e "${GREEN}✓ Created $SCREENLAYOUT_DIR/apply-layout.sh${NC}"
    
    # Generate systemd service
    echo -e "${BLUE}Generating systemd service...${NC}"
    cat > "$SYSTEMD_DIR/$SERVICE_NAME" << EOF
[Unit]
Description=Apply NVIDIA display layout after login
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=$SCREENLAYOUT_DIR/apply-layout.sh

[Install]
WantedBy=default.target
EOF
    echo -e "${GREEN}✓ Created $SYSTEMD_DIR/$SERVICE_NAME${NC}"
    
    echo ""
}

# Save configuration for future reference
save_config() {
    local config_file="$SCREENLAYOUT_DIR/.layout-config"
    
    echo "# Layout configuration - generated $(date)" > "$config_file"
    echo "# Run setup-wizard.sh again to reconfigure" >> "$config_file"
    echo "" >> "$config_file"
    
    for i in "${!DISPLAY_IDS[@]}"; do
        echo "DISPLAY_${i}_ID=${DISPLAY_IDS[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_NAME=${DISPLAY_NAMES[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_RES=${DISPLAY_RESOLUTIONS[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_POS=${DISPLAY_POSITIONS[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_ROT=${DISPLAY_ROTATIONS[$i]}" >> "$config_file"
        echo "" >> "$config_file"
    done
    
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo "CAPTURE_ENABLED=true" >> "$config_file"
        echo "CAPTURE_DISPLAY=$CAPTURE_DISPLAY" >> "$config_file"
        echo "CAPTURE_MIRROR=$CAPTURE_MIRROR_TARGET" >> "$config_file"
    fi
    
    echo -e "${GREEN}✓ Configuration saved to $config_file${NC}"
}

# Show summary and enable service
finalize() {
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}                         SUMMARY                                ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${GREEN}Generated files:${NC}"
    echo "  • $SCREENLAYOUT_DIR/nvidia-base.sh"
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo "  • $SCREENLAYOUT_DIR/nvidia-capture.sh"
    fi
    echo "  • $SCREENLAYOUT_DIR/apply-layout.sh"
    echo "  • $SYSTEMD_DIR/$SERVICE_NAME"
    echo ""
    
    echo -e "${YELLOW}Display layout:${NC}"
    for i in "${!DISPLAY_IDS[@]}"; do
        if [ "${DISPLAY_POSITIONS[$i]}" != "skip" ]; then
            echo "  • ${DISPLAY_IDS[$i]}: ${DISPLAY_RESOLUTIONS[$i]} @ ${DISPLAY_POSITIONS[$i]} (${DISPLAY_ROTATIONS[$i]})"
        fi
    done
    echo ""
    
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo -e "${YELLOW}Capture card:${NC}"
        echo "  • $CAPTURE_DISPLAY mirrors $CAPTURE_MIRROR_TARGET"
        echo ""
    fi
    
    read -p "Enable systemd service for auto-apply on login? [Y/n]: " enable_service
    if [[ ! "$enable_service" =~ ^[Nn] ]]; then
        systemctl --user daemon-reload
        systemctl --user enable "$SERVICE_NAME"
        echo -e "${GREEN}✓ Service enabled${NC}"
    fi
    
    echo ""
    read -p "Apply layout now? [Y/n]: " apply_now
    if [[ ! "$apply_now" =~ ^[Nn] ]]; then
        "$SCREENLAYOUT_DIR/apply-layout.sh"
        echo -e "${GREEN}✓ Layout applied${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    SETUP COMPLETE!                            ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Set up a keyboard shortcut to: $SCREENLAYOUT_DIR/apply-layout.sh"
    echo "  2. Recommended keys: Super+F12 or Ctrl+Alt+D"
    echo ""
    echo "To reconfigure, run this wizard again."
    echo "To verify: nvidia-settings -q CurrentMetaMode"
    echo ""
}

# Main execution
main() {
    check_requirements
    detect_displays
    configure_displays
    configure_capture
    generate_scripts
    save_config
    finalize
}

main "$@"
