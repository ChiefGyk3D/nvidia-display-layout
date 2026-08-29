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
declare -a DISPLAY_REFRESH_RATES
declare -a DISPLAY_POSITIONS
declare -a DISPLAY_ROTATIONS
declare -a DISPLAY_OFFSETS
declare -a DISPLAY_COMPOSITION_PIPELINE
declare -a DISPLAY_GSYNC_COMPATIBLE

# Capture card config
CAPTURE_ENABLED=false
CAPTURE_DISPLAY=""
CAPTURE_DISPLAY_NAME=""
CAPTURE_MIRROR_TARGET=""
CAPTURE_REFRESH_RATE=""

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

# Detect available refresh rates for a display at a given resolution
detect_refresh_rates() {
    local dpy="$1"
    local resolution="$2"
    local rates=()
    
    # Query nvidia-settings for available modes
    local mode_output
    mode_output=$(nvidia-settings -q "${dpy}/Modes" 2>/dev/null || true)
    
    # Parse refresh rates for the given resolution
    if [ -n "$mode_output" ]; then
        while IFS= read -r line; do
            if [[ "$line" =~ ${resolution}.*@[[:space:]]*([0-9]+\.?[0-9]*)Hz ]]; then
                local rate="${BASH_REMATCH[1]}"
                # Remove decimal if .0
                rate=$(echo "$rate" | sed 's/\.0$//')
                rates+=("$rate")
            fi
        done <<< "$mode_output"
    fi
    
    # Also try xrandr as a fallback for mode detection
    if [ ${#rates[@]} -eq 0 ] && command -v xrandr &>/dev/null; then
        local xrandr_output
        xrandr_output=$(xrandr 2>/dev/null || true)
        
        # Find the output name associated with this DPY
        # nvidia-settings DPY names map to xrandr outputs
        local in_display=false
        local found_res=false
        while IFS= read -r line; do
            if [[ "$line" =~ ^[A-Z] ]] && [[ "$line" =~ " connected" ]]; then
                in_display=true
                found_res=false
            elif [[ "$line" =~ ^[A-Z] ]]; then
                in_display=false
                found_res=false
            elif [ "$in_display" = true ]; then
                if [[ "$line" =~ ^[[:space:]]+${resolution}[[:space:]]+(.*) ]]; then
                    found_res=true
                    local rate_string="${BASH_REMATCH[1]}"
                    # Extract all refresh rates from the line
                    while [[ "$rate_string" =~ ([0-9]+\.[0-9]+) ]]; do
                        local r="${BASH_REMATCH[1]}"
                        r=$(echo "$r" | sed 's/\.00$//')
                        r=$(echo "$r" | sed 's/\.0$//')
                        # Round to integer for common rates
                        local r_int=$(printf "%.0f" "$r")
                        rates+=("$r_int")
                        rate_string="${rate_string#*${BASH_REMATCH[1]}}"
                    done
                fi
            fi
        done <<< "$xrandr_output"
    fi
    
    # Deduplicate and sort descending
    if [ ${#rates[@]} -gt 0 ]; then
        printf '%s\n' "${rates[@]}" | sort -rn -u
    fi
}

# Detect the current/preferred refresh rate for a display
detect_current_refresh_rate() {
    local dpy="$1"
    
    # Try nvidia-settings first
    local refresh
    refresh=$(nvidia-settings -t -q "${dpy}/RefreshRate" 2>/dev/null | head -1)
    if [ -n "$refresh" ]; then
        # Round to nearest common rate
        local rate_int=$(printf "%.0f" "$refresh" 2>/dev/null || echo "")
        if [ -n "$rate_int" ] && [ "$rate_int" -gt 0 ] 2>/dev/null; then
            echo "$rate_int"
            return 0
        fi
    fi
    
    # Fallback: try parsing current MetaMode
    local metamode
    metamode=$(nvidia-settings -q CurrentMetaMode 2>/dev/null || true)
    if [[ "$metamode" =~ ${dpy}:.*_([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
        return 0
    fi
    
    echo ""
    return 1
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
        
        # Refresh Rate
        echo ""
        local chosen_res="${DISPLAY_RESOLUTIONS[$i]}"
        echo -e "${BLUE}Detecting available refresh rates for $dpy at $chosen_res...${NC}"
        local detected_rates
        detected_rates=$(detect_refresh_rates "$dpy" "$chosen_res")
        local current_rate
        current_rate=$(detect_current_refresh_rate "$dpy")
        
        if [ -n "$detected_rates" ]; then
            echo ""
            echo "Detected refresh rates:"
            local rate_idx=1
            local rate_arr=()
            while IFS= read -r rate; do
                local marker=""
                if [ "$rate" = "$current_rate" ]; then
                    marker=" ${GREEN}(current)${NC}"
                fi
                echo -e "  [$rate_idx] ${rate}Hz${marker}"
                rate_arr+=("$rate")
                ((rate_idx++))
            done <<< "$detected_rates"
            echo "  [$rate_idx] Enter custom rate"
            echo "  [$((rate_idx+1))] Auto (let driver decide)"
            echo ""
            read -p "Refresh rate [1-$((rate_idx+1))] (default: 1): " rate_choice
            rate_choice=${rate_choice:-1}
            
            if [ "$rate_choice" = "$((rate_idx+1))" ]; then
                DISPLAY_REFRESH_RATES[$i]=""
                echo -e "${YELLOW}Using auto refresh rate${NC}"
            elif [ "$rate_choice" = "$rate_idx" ]; then
                read -p "Enter refresh rate (e.g., 165): " custom_rate
                DISPLAY_REFRESH_RATES[$i]="$custom_rate"
            else
                DISPLAY_REFRESH_RATES[$i]="${rate_arr[$((rate_choice-1))]}"
            fi
        else
            echo -e "${YELLOW}Could not auto-detect refresh rates.${NC}"
            echo ""
            echo "Common refresh rates:"
            echo "  [1] 60Hz"
            echo "  [2] 75Hz"
            echo "  [3] 120Hz"
            echo "  [4] 144Hz"
            echo "  [5] 165Hz"
            echo "  [6] 180Hz"
            echo "  [7] 240Hz"
            echo "  [8] Enter custom rate"
            echo "  [9] Auto (let driver decide)"
            echo ""
            local common_rates=(60 75 120 144 165 180 240)
            read -p "Refresh rate [1-9] (default: 9): " rate_choice
            rate_choice=${rate_choice:-9}
            
            if [ "$rate_choice" = "9" ]; then
                DISPLAY_REFRESH_RATES[$i]=""
            elif [ "$rate_choice" = "8" ]; then
                read -p "Enter refresh rate (e.g., 165): " custom_rate
                DISPLAY_REFRESH_RATES[$i]="$custom_rate"
            else
                DISPLAY_REFRESH_RATES[$i]="${common_rates[$((rate_choice-1))]}"
            fi
        fi
        
        # ForceFullCompositionPipeline
        echo ""
        echo -e "${YELLOW}ForceFullCompositionPipeline${NC} eliminates stuttering on mixed"
        echo "refresh rate setups (~1 frame of input latency trade-off)."
        echo ""
        read -p "Enable ForceFullCompositionPipeline for $dpy? [Y/n]: " ffcp_choice
        if [[ "$ffcp_choice" =~ ^[Nn] ]]; then
            DISPLAY_COMPOSITION_PIPELINE[$i]="Off"
        else
            DISPLAY_COMPOSITION_PIPELINE[$i]="On"
        fi
        
        # G-Sync Compatible
        echo ""
        echo -e "${YELLOW}AllowGSYNCCompatible${NC} enables variable refresh rate (VRR)"
        echo "for monitors not officially validated as G-Sync Compatible."
        echo "Reduces tearing and improves smoothness if your monitor supports FreeSync/VRR."
        echo ""
        read -p "Enable G-Sync Compatible for $dpy? [Y/n]: " gsync_choice
        if [[ "$gsync_choice" =~ ^[Nn] ]]; then
            DISPLAY_GSYNC_COMPATIBLE[$i]="Off"
        else
            DISPLAY_GSYNC_COMPATIBLE[$i]="On"
        fi
        
        local rate_str=""
        if [ -n "${DISPLAY_REFRESH_RATES[$i]}" ]; then
            rate_str=" @ ${DISPLAY_REFRESH_RATES[$i]}Hz"
        fi
        local ffcp_str=""
        if [ "${DISPLAY_COMPOSITION_PIPELINE[$i]}" = "On" ]; then
            ffcp_str=" [FFCP]"
        fi
        local gsync_str=""
        if [ "${DISPLAY_GSYNC_COMPATIBLE[$i]}" = "On" ]; then
            gsync_str=" [G-Sync]"
        fi
        echo ""
        echo -e "${GREEN}✓ Configured $dpy: ${DISPLAY_RESOLUTIONS[$i]}${rate_str} @ ${DISPLAY_POSITIONS[$i]} (${DISPLAY_ROTATIONS[$i]})${ffcp_str}${gsync_str}${NC}"
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
        CAPTURE_DISPLAY_NAME="${DISPLAY_NAMES[$((cap_choice-1))]}"
        
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
        
        # Detect available refresh rates for the capture card at the mirror resolution
        local mirror_res=""
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_IDS[$i]}" = "$CAPTURE_MIRROR_TARGET" ]; then
                mirror_res="${DISPLAY_RESOLUTIONS[$i]}"
                break
            fi
        done
        
        echo ""
        echo -e "${BLUE}Detecting capture card refresh rates at ${mirror_res}...${NC}"
        local cap_rates=()
        local cap_output
        cap_output=$(xrandr 2>/dev/null | sed -n "/^${CAPTURE_DISPLAY_NAME} connected/,/^[A-Z]/p" | head -20)
        
        if [ -n "$cap_output" ] && [ -n "$mirror_res" ]; then
            local rate_line
            rate_line=$(echo "$cap_output" | grep "^[[:space:]]*${mirror_res}" | head -1)
            if [ -n "$rate_line" ]; then
                while [[ "$rate_line" =~ ([0-9]+)\.[0-9]+ ]]; do
                    cap_rates+=("${BASH_REMATCH[1]}")
                    rate_line="${rate_line#*${BASH_REMATCH[0]}}"
                done
            fi
        fi
        
        # Deduplicate and sort descending
        if [ ${#cap_rates[@]} -gt 0 ]; then
            mapfile -t cap_rates < <(printf '%s\n' "${cap_rates[@]}" | sort -rn -u)
        fi
        
        if [ ${#cap_rates[@]} -gt 0 ]; then
            echo ""
            echo -e "${YELLOW}Capture card refresh rate${NC}"
            echo "Available rates for ${CAPTURE_DISPLAY_NAME} at ${mirror_res}:"
            local rate_idx=1
            for rate in "${cap_rates[@]}"; do
                local default_marker=""
                if [ "$rate" = "100" ]; then
                    default_marker=" ${GREEN}(recommended)${NC}"
                fi
                echo -e "  [$rate_idx] ${rate}Hz${default_marker}"
                ((rate_idx++))
            done
            echo "  [$rate_idx] Enter custom rate"
            echo ""
            
            # Find index of 100Hz for default
            local default_idx=1
            for ri in "${!cap_rates[@]}"; do
                if [ "${cap_rates[$ri]}" = "100" ]; then
                    default_idx=$((ri + 1))
                    break
                fi
            done
            
            read -p "Capture refresh rate [1-${rate_idx}] (default: $default_idx for ${cap_rates[$((default_idx-1))]}Hz): " cap_rate_choice
            cap_rate_choice=${cap_rate_choice:-$default_idx}
            
            if [ "$cap_rate_choice" = "$rate_idx" ]; then
                read -p "Enter refresh rate (e.g., 120): " custom_cap_rate
                CAPTURE_REFRESH_RATE="$custom_cap_rate"
            else
                CAPTURE_REFRESH_RATE="${cap_rates[$((cap_rate_choice-1))]}"
            fi
        else
            echo ""
            echo -e "${YELLOW}Could not auto-detect capture card refresh rates at ${mirror_res}.${NC}"
            echo "Common capture card rates:"
            echo "  [1] 60Hz"
            echo "  [2] 100Hz"
            echo "  [3] 120Hz"
            echo "  [4] 144Hz"
            echo "  [5] 240Hz"
            echo "  [6] Enter custom rate"
            echo ""
            local fallback_rates=(60 100 120 144 240)
            read -p "Capture refresh rate [1-6] (default: 2 for 100Hz): " cap_rate_choice
            cap_rate_choice=${cap_rate_choice:-2}
            
            if [ "$cap_rate_choice" = "6" ]; then
                read -p "Enter refresh rate (e.g., 120): " custom_cap_rate
                CAPTURE_REFRESH_RATE="$custom_cap_rate"
            else
                CAPTURE_REFRESH_RATE="${fallback_rates[$((cap_rate_choice-1))]}"
            fi
        fi
        
        echo ""
        echo -e "${GREEN}✓ Capture card: $CAPTURE_DISPLAY mirrors $CAPTURE_MIRROR_TARGET @ ${CAPTURE_REFRESH_RATE}Hz${NC}"
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
        local refresh="${DISPLAY_REFRESH_RATES[$i]}"
        local ffcp="${DISPLAY_COMPOSITION_PIPELINE[$i]}"
        
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
        
        # Build resolution string with refresh rate
        local res_str="$res"
        if [ -n "$refresh" ]; then
            res_str="${res}_${refresh}"
        fi
        
        # Build display config
        local config="$dpy: $res_str $offset"
        
        # Build options block
        local options=()
        
        # Add rotation if not normal
        if [ "$rot" != "normal" ]; then
            local rot_value
            case "$rot" in
                left) rot_value="Left" ;;
                right) rot_value="Right" ;;
                inverted) rot_value="Inverted" ;;
            esac
            options+=("Rotation=$rot_value")
        fi
        
        # Add ForceFullCompositionPipeline if enabled (not for capture card)
        if [ "$ffcp" = "On" ] && [ "$dpy" != "$CAPTURE_DISPLAY" ]; then
            options+=("ForceFullCompositionPipeline=On")
        fi
        
        # Add AllowGSYNCCompatible if enabled (not for capture card)
        local gsync="${DISPLAY_GSYNC_COMPATIBLE[$i]}"
        if [ "$gsync" = "On" ] && [ "$dpy" != "$CAPTURE_DISPLAY" ]; then
            options+=("AllowGSYNCCompatible=On")
        fi
        
        # Append options block if any
        if [ ${#options[@]} -gt 0 ]; then
            local opts_str
            opts_str=$(IFS=', '; echo "${options[*]}")
            config+=" {$opts_str}"
        fi
        
        metamode+="$config"
    done
    
    # Add capture card mirroring if enabled
    if [ "$include_capture" = "true" ] && [ "$CAPTURE_ENABLED" = true ]; then
        # Find the mirror target's resolution and offset
        for i in "${!DISPLAY_IDS[@]}"; do
            if [ "${DISPLAY_IDS[$i]}" = "$CAPTURE_MIRROR_TARGET" ]; then
                local mirror_res="${DISPLAY_RESOLUTIONS[$i]}"
                local mirror_offset="${DISPLAY_OFFSETS[$i]}"
                metamode+=", \\"$'\n'
                
                # Detect capture card's supported resolutions
                local capture_modes
                capture_modes=$(xrandr 2>/dev/null | grep -A1 "^${CAPTURE_DISPLAY_NAME} connected" | tail -1 | grep -oP '\d+x\d+' | head -1)
                
                # Check if capture card supports the mirror resolution natively
                local capture_supports_res=false
                if [ -n "$capture_modes" ]; then
                    local cap_output
                    cap_output=$(xrandr 2>/dev/null | sed -n "/^${CAPTURE_DISPLAY_NAME} connected/,/^[A-Z]/p" | head -20)
                    if echo "$cap_output" | grep -q "^[[:space:]]*${mirror_res}"; then
                        capture_supports_res=true
                    fi
                fi
                
                if [ "$capture_supports_res" = true ]; then
                    # Capture card supports the resolution natively
                    local cap_res_str="$mirror_res"
                    if [ -n "$CAPTURE_REFRESH_RATE" ]; then
                        cap_res_str="${mirror_res}_${CAPTURE_REFRESH_RATE}"
                    fi
                    metamode+="$CAPTURE_DISPLAY: $cap_res_str $mirror_offset"
                else
                    # Capture card can't do the mirror resolution — find best fallback
                    # Try common resolutions the capture card supports
                    local fallback_res=""
                    for try_res in "$mirror_res" "1920x1080" "1280x720"; do
                        if [ -n "$cap_output" ] && echo "$cap_output" | grep -q "^[[:space:]]*${try_res}"; then
                            fallback_res="$try_res"
                            break
                        fi
                    done
                    fallback_res="${fallback_res:-1920x1080}"
                    
                    if [ "$fallback_res" != "$mirror_res" ]; then
                        # Use ViewPortIn/ViewPortOut to scale
                        metamode+="$CAPTURE_DISPLAY: $fallback_res $mirror_offset {ViewPortIn=$mirror_res, ViewPortOut=${fallback_res}+0+0}"
                    else
                        metamode+="$CAPTURE_DISPLAY: $mirror_res $mirror_offset"
                    fi
                fi
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
    
    # Build display info comments
    local display_comments=""
    for i in "${!DISPLAY_IDS[@]}"; do
        if [ "${DISPLAY_POSITIONS[$i]}" != "skip" ] && [ "${DISPLAY_IDS[$i]}" != "$CAPTURE_DISPLAY" ]; then
            local rate_info=""
            if [ -n "${DISPLAY_REFRESH_RATES[$i]}" ]; then
                rate_info=" @ ${DISPLAY_REFRESH_RATES[$i]}Hz"
            fi
            local ffcp_info=""
            if [ "${DISPLAY_COMPOSITION_PIPELINE[$i]}" = "On" ]; then
                ffcp_info=" [FFCP]"
            fi
            display_comments+="# ${DISPLAY_POSITIONS[$i]^}: ${DISPLAY_IDS[$i]} (${DISPLAY_NAMES[$i]}) ${DISPLAY_RESOLUTIONS[$i]}${rate_info}${ffcp_info}\n"
        fi
    done
    
    cat > "$SCREENLAYOUT_DIR/nvidia-base.sh" << EOF
#!/bin/bash
# NVIDIA MetaMode base layout
# Generated by setup-wizard.sh on $(date)
#
$(echo -e "$display_comments")#
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups

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
# Generated by setup-wizard.sh on $(date)#
# Capture card refresh rate is configurable via CAPTURE_REFRESH env var.
# Supported rates depend on your capture card and resolution.
# Override: CAPTURE_REFRESH=120 ~/.screenlayout/apply-layout.sh

# ── Capture card refresh rate ────────────────────────────────────────
CAPTURE_REFRESH="\${CAPTURE_REFRESH:-${CAPTURE_REFRESH_RATE}}"
# ─────────────────────────────────────────────────────────────────────
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
        
        # Determine NVIDIA audio card for HDMI handshake fix
        local nvidia_audio_card
        nvidia_audio_card=$(pactl list short cards 2>/dev/null | grep -i "pci.*nvidia\|nvidia.*pci\|pci.*hdmi" | head -1 | awk '{print $2}')
        nvidia_audio_card="${nvidia_audio_card:-alsa_card.pci-0000_08_00.1}"
        
        cat > "$SCREENLAYOUT_DIR/apply-layout.sh" << EOF
#!/bin/bash
# Apply correct NVIDIA MetaMode depending on capture card presence
# Optionally resets PipeWire combined audio sink when capture card is detected
# (requires pipewire_sink project: https://github.com/ChiefGyk3D/pipewire_sink)
# Part of: https://github.com/ChiefGyk3D/nvidia-display-layout
# Generated by setup-wizard.sh on $(date)

export DISPLAY=$display_num
export XAUTHORITY="\$HOME/.Xauthority"

NVIDIA_AUDIO_CARD="${nvidia_audio_card}"
HDMI_PROFILE="output:hdmi-stereo"

# Path to pipewire-ensure-defaults (installed by pipewire_sink project).
# Set to empty string or "none" to disable audio integration.
#
# NOTE: earlier versions called reset-pipewire here, restarting the entire
# audio stack on EVERY display event (HDMI handshake, MetaMode drift, monitor
# sleep). That killed all app audio streams and could crash PipeWire. The
# combined sink is now created declaratively by PipeWire itself
# (~/.config/pipewire/pipewire.conf.d/60-combined-sink.conf) and reattaches
# the HDMI sink automatically — no restart is ever needed from here.
PIPEWIRE_ENSURE_DEFAULTS="\${PIPEWIRE_ENSURE_DEFAULTS:-\$HOME/.local/bin/pipewire-ensure-defaults}"

# Check if capture card is connected (with or without enabled)
if nvidia-settings -q dpys | grep -q "${capture_name}) (connected"; then
    ~/.screenlayout/nvidia-capture.sh

    # Wait for HDMI audio handshake after MetaMode change
    sleep 2

    # Force NVIDIA HDMI audio profile active — fixes race condition where
    # PipeWire sees the sink as unavailable during HDMI re-handshake
    if command -v pactl &>/dev/null; then
        pactl set-card-profile "\$NVIDIA_AUDIO_CARD" "\$HDMI_PROFILE" 2>/dev/null
    fi

    # Re-assert audio defaults (combined sink is declarative — NO restart)
    if [ -n "\$PIPEWIRE_ENSURE_DEFAULTS" ] && [ "\$PIPEWIRE_ENSURE_DEFAULTS" != "none" ] && [ -x "\$PIPEWIRE_ENSURE_DEFAULTS" ]; then
        "\$PIPEWIRE_ENSURE_DEFAULTS" 2>&1 | while IFS= read -r line; do
            echo "\$(date '+%Y-%m-%d %H:%M:%S') - [pipewire] \$line"
        done
    fi
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
    
    # Generate systemd service (login apply)
    echo -e "${BLUE}Generating systemd services...${NC}"
    cat > "$SYSTEMD_DIR/$SERVICE_NAME" << 'SVCEOF'
[Unit]
Description=Apply NVIDIA display layout after login
After=graphical-session.target

[Service]
Type=oneshot
ExecStartPre=/bin/sleep 2
ExecStart=%h/.screenlayout/apply-layout.sh

[Install]
WantedBy=default.target
SVCEOF
    echo -e "${GREEN}✓ Created $SYSTEMD_DIR/$SERVICE_NAME${NC}"
    
    # Generate display monitor service (hotplug detection)
    local MONITOR_SERVICE="nvidia-display-monitor.service"
    cat > "$SYSTEMD_DIR/$MONITOR_SERVICE" << 'SVCEOF'
[Unit]
Description=NVIDIA Display Monitor - Auto-apply layout on display changes
After=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.screenlayout/display-monitor.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
SVCEOF
    echo -e "${GREEN}✓ Created $SYSTEMD_DIR/$MONITOR_SERVICE${NC}"
    
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
        echo "DISPLAY_${i}_REFRESH=${DISPLAY_REFRESH_RATES[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_POS=${DISPLAY_POSITIONS[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_ROT=${DISPLAY_ROTATIONS[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_FFCP=${DISPLAY_COMPOSITION_PIPELINE[$i]}" >> "$config_file"
        echo "DISPLAY_${i}_GSYNC=${DISPLAY_GSYNC_COMPATIBLE[$i]}" >> "$config_file"
        echo "" >> "$config_file"
    done
    
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo "CAPTURE_ENABLED=true" >> "$config_file"
        echo "CAPTURE_DISPLAY=$CAPTURE_DISPLAY" >> "$config_file"
        echo "CAPTURE_MIRROR=$CAPTURE_MIRROR_TARGET" >> "$config_file"
        echo "CAPTURE_REFRESH=$CAPTURE_REFRESH_RATE" >> "$config_file"
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
    echo "  • $SYSTEMD_DIR/nvidia-display-monitor.service"
    echo ""
    
    echo -e "${YELLOW}Display layout:${NC}"
    for i in "${!DISPLAY_IDS[@]}"; do
        if [ "${DISPLAY_POSITIONS[$i]}" != "skip" ]; then
            local rate_info=""
            if [ -n "${DISPLAY_REFRESH_RATES[$i]}" ]; then
                rate_info=" @ ${DISPLAY_REFRESH_RATES[$i]}Hz"
            fi
            local ffcp_info=""
            if [ "${DISPLAY_COMPOSITION_PIPELINE[$i]}" = "On" ]; then
                ffcp_info=" [FFCP]"
            fi
            local gsync_info=""
            if [ "${DISPLAY_GSYNC_COMPATIBLE[$i]}" = "On" ]; then
                gsync_info=" [G-Sync]"
            fi
            echo "  • ${DISPLAY_IDS[$i]}: ${DISPLAY_RESOLUTIONS[$i]}${rate_info} @ ${DISPLAY_POSITIONS[$i]} (${DISPLAY_ROTATIONS[$i]})${ffcp_info}${gsync_info}"
        fi
    done
    echo ""
    
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo -e "${YELLOW}Capture card:${NC}"
        echo "  • $CAPTURE_DISPLAY mirrors $CAPTURE_MIRROR_TARGET @ ${CAPTURE_REFRESH_RATE}Hz"
        echo ""
    fi
    
    read -p "Enable systemd services for auto-apply on login and hotplug? [Y/n]: " enable_service
    if [[ ! "$enable_service" =~ ^[Nn] ]]; then
        # Also install the display monitor script
        local monitor_src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.screenlayout/display-monitor.sh"
        if [ -f "$monitor_src" ] && [ ! -f "$SCREENLAYOUT_DIR/display-monitor.sh" ]; then
            cp "$monitor_src" "$SCREENLAYOUT_DIR/display-monitor.sh"
            chmod +x "$SCREENLAYOUT_DIR/display-monitor.sh"
            echo -e "${GREEN}✓ Installed display-monitor.sh${NC}"
        elif [ -f "$SCREENLAYOUT_DIR/display-monitor.sh" ]; then
            echo -e "${GREEN}✓ display-monitor.sh already installed${NC}"
        fi
        
        systemctl --user daemon-reload
        systemctl --user enable "$SERVICE_NAME"
        systemctl --user enable "nvidia-display-monitor.service"
        echo -e "${GREEN}✓ Login layout service enabled${NC}"
        echo -e "${GREEN}✓ Display monitor service enabled (detects hotplug)${NC}"
    fi
    
    echo ""
    read -p "Apply layout now? [Y/n]: " apply_now
    if [[ ! "$apply_now" =~ ^[Nn] ]]; then
        "$SCREENLAYOUT_DIR/apply-layout.sh"
        echo -e "${GREEN}✓ Layout applied${NC}"
    fi
    
    # Offer PipeWire combined audio sink integration if capture card is enabled
    if [ "$CAPTURE_ENABLED" = true ]; then
        echo ""
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}           PipeWire Combined Audio Sink Integration             ${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "When a capture card is detected, you can automatically create a"
        echo "PipeWire combined audio sink that sends audio to both your local"
        echo "output (speakers/headphones) and the HDMI capture card."
        echo ""
        echo "This requires the PipeWire Combined Sink project."
        echo "  https://github.com/ChiefGyk3D/pipewire_sink"
        echo ""
        
        if [ -x "$HOME/.local/bin/pipewire-ensure-defaults" ]; then
            echo -e "${GREEN}✓ pipewire-ensure-defaults is installed at ~/.local/bin/pipewire-ensure-defaults${NC}"
            echo "  Audio integration is enabled automatically — no action needed."
        elif [ -x "$HOME/.local/bin/reset-pipewire" ]; then
            echo -e "${YELLOW}⚠ Old pipewire_sink install detected (reset-pipewire only).${NC}"
            echo "  Re-run pipewire_sink's install.sh to get the non-disruptive"
            echo "  integration (pipewire-ensure-defaults + declarative combined sink)."
        else
            read -p "Install PipeWire combined sink project now? [Y/n]: " install_pipewire
            if [[ ! "$install_pipewire" =~ ^[Nn] ]]; then
                local pipewire_tmp
                pipewire_tmp=$(mktemp -d)
                echo ""
                echo -e "${BLUE}Cloning pipewire_sink...${NC}"
                if git clone https://github.com/ChiefGyk3D/pipewire_sink.git "$pipewire_tmp" 2>/dev/null; then
                    echo -e "${GREEN}✓ Cloned pipewire_sink${NC}"
                    echo ""
                    echo "Launching PipeWire installer..."
                    echo ""
                    (cd "$pipewire_tmp" && ./install.sh)
                    rm -rf "$pipewire_tmp"
                    
                    if [ -x "$HOME/.local/bin/pipewire-ensure-defaults" ]; then
                        echo ""
                        echo -e "${GREEN}✓ PipeWire integration is now active${NC}"
                        echo "  The combined sink is created by PipeWire itself and reattaches"
                        echo "  the capture card automatically — no audio restarts on hotplug."
                    fi
                else
                    echo -e "${RED}✗ Failed to clone pipewire_sink — install it manually later${NC}"
                    rm -rf "$pipewire_tmp"
                fi
            else
                echo -e "${YELLOW}ℹ Skipped. You can install it later:${NC}"
                echo "  git clone https://github.com/ChiefGyk3D/pipewire_sink.git"
                echo "  cd pipewire_sink && ./install.sh"
            fi
        fi
        echo ""
        echo "To disable audio integration, edit ~/.screenlayout/apply-layout.sh and set:"
        echo "  PIPEWIRE_ENSURE_DEFAULTS=\"none\""
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
