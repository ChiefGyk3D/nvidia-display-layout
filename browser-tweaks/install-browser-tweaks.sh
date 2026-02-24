#!/bin/bash
# Install Floorp/Firefox browser tweaks for NVIDIA hardware acceleration
# Optimized for mixed refresh rate multi-monitor setups

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Floorp/Firefox NVIDIA Performance Tweaks Installer       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Detect browser
echo -e "${YELLOW}Detecting browser...${NC}"
echo ""

FLOORP_FLATPAK=false
FLOORP_NATIVE=false
FIREFOX_FLATPAK=false
FIREFOX_NATIVE=false

if flatpak list 2>/dev/null | grep -q "one.ablaze.floorp"; then
    FLOORP_FLATPAK=true
    echo -e "${GREEN}✓ Found: Floorp (Flatpak)${NC}"
fi

if [ -d "$HOME/.floorp" ]; then
    FLOORP_NATIVE=true
    echo -e "${GREEN}✓ Found: Floorp (Native)${NC}"
fi

if flatpak list 2>/dev/null | grep -q "org.mozilla.firefox"; then
    FIREFOX_FLATPAK=true
    echo -e "${GREEN}✓ Found: Firefox (Flatpak)${NC}"
fi

if [ -d "$HOME/.mozilla/firefox" ]; then
    FIREFOX_NATIVE=true
    echo -e "${GREEN}✓ Found: Firefox (Native)${NC}"
fi

if [ "$FLOORP_FLATPAK" = false ] && [ "$FLOORP_NATIVE" = false ] && \
   [ "$FIREFOX_FLATPAK" = false ] && [ "$FIREFOX_NATIVE" = false ]; then
    echo -e "${RED}No supported browser found!${NC}"
    echo "Supported: Floorp (Flatpak/Native), Firefox (Flatpak/Native)"
    exit 1
fi

echo ""

# Function to find profile directory
# Uses profiles.ini to find the active profile instead of globbing
find_profile_dir() {
    local base_dir="$1"
    local profile_dir=""
    
    # Use profiles.ini to find the install default (most reliable)
    if [ -f "$base_dir/profiles.ini" ]; then
        # Get the Default= path from the [Install*] section
        local install_default
        install_default=$(awk '/^\[Install/{found=1} found && /^Default=/{print $0; exit}' "$base_dir/profiles.ini" | cut -d= -f2)
        if [ -n "$install_default" ] && [ -d "$base_dir/$install_default" ]; then
            profile_dir="$base_dir/$install_default"
        fi
    fi
    
    # Fallback: look for default-release profile
    if [ -z "$profile_dir" ]; then
        profile_dir=$(find "$base_dir" -maxdepth 1 -type d -name "*.default-release*" 2>/dev/null | head -1)
    fi
    
    # Fallback: any default profile
    if [ -z "$profile_dir" ]; then
        profile_dir=$(find "$base_dir" -maxdepth 1 -type d -name "*.default*" 2>/dev/null | head -1)
    fi
    
    echo "$profile_dir"
}

# Function to find ALL profile directories (for installing to all profiles)
find_all_profile_dirs() {
    local base_dir="$1"
    
    if [ -f "$base_dir/profiles.ini" ]; then
        # Extract all Path= values from profiles.ini
        grep "^Path=" "$base_dir/profiles.ini" | cut -d= -f2 | while read -r rel_path; do
            if [ -d "$base_dir/$rel_path" ]; then
                echo "$base_dir/$rel_path"
            fi
        done
    else
        # Fallback to globbing
        find "$base_dir" -maxdepth 1 -type d -name "*.default*" 2>/dev/null
    fi
}

# Install user.js to a single profile
install_userjs() {
    local profile_dir="$1"
    local browser_name="$2"
    
    if [ -n "$profile_dir" ] && [ -d "$profile_dir" ]; then
        cp "$SCRIPT_DIR/user.js" "$profile_dir/"
        echo -e "${GREEN}✓ Installed user.js to ${browser_name}: $(basename "$profile_dir")${NC}"
        return 0
    fi
    return 1
}

# Install user.js to ALL profiles found in a base directory
install_userjs_all_profiles() {
    local base_dir="$1"
    local browser_name="$2"
    local count=0
    
    while IFS= read -r profile_dir; do
        if install_userjs "$profile_dir" "$browser_name"; then
            ((count++))
        fi
    done < <(find_all_profile_dirs "$base_dir")
    
    if [ "$count" -eq 0 ]; then
        # Fallback to single profile detection
        local single_profile
        single_profile=$(find_profile_dir "$base_dir")
        install_userjs "$single_profile" "$browser_name"
    fi
}

# Install Flatpak environment overrides
install_flatpak_env() {
    local app_id="$1"
    local browser_name="$2"
    
    # Flatpak reserves /usr — we can't share host /usr paths into the sandbox.
    # Copy the NVIDIA VA-API driver to a user-accessible location instead.
    local host_vaapi_path="/usr/lib/x86_64-linux-gnu/dri"
    if [ -f "/usr/lib64/dri/nvidia_drv_video.so" ]; then
        host_vaapi_path="/usr/lib64/dri"  # Fedora/RHEL
    fi
    
    local user_vaapi_path="$HOME/.local/lib/dri"
    mkdir -p "$user_vaapi_path"
    
    if [ -f "${host_vaapi_path}/nvidia_drv_video.so" ]; then
        cp "${host_vaapi_path}/nvidia_drv_video.so" "$user_vaapi_path/"
        echo -e "${GREEN}✓ Copied nvidia_drv_video.so to ${user_vaapi_path}${NC}"
    else
        echo -e "${YELLOW}⚠ nvidia_drv_video.so not found at ${host_vaapi_path}${NC}"
        echo -e "${YELLOW}  Hardware video decode may not work. Install nvidia-vaapi-driver.${NC}"
    fi

    flatpak override --user \
        --device=dri \
        --filesystem="${user_vaapi_path}:ro" \
        --env=MOZ_X11_EGL=1 \
        --env=MOZ_DISABLE_RDD_SANDBOX=1 \
        --env=LIBVA_DRIVER_NAME=nvidia \
        --env=LIBVA_DRIVERS_PATH="${user_vaapi_path}" \
        --env=NVD_BACKEND=direct \
        --env=MOZ_WEBRENDER=1 \
        --env=__GL_SYNC_TO_VBLANK=0 \
        --env=__GL_YIELD=USLEEP \
        --env=MOZ_USE_XINPUT2=1 \
        "$app_id"
    
    echo -e "${GREEN}✓ Set Flatpak environment variables for $browser_name${NC}"
    echo -e "  VA-API driver path: ${user_vaapi_path}"
}

echo -e "${YELLOW}Installing tweaks...${NC}"
echo ""

# Floorp Flatpak
if [ "$FLOORP_FLATPAK" = true ]; then
    PROFILE_BASE="$HOME/.var/app/one.ablaze.floorp/.floorp"
    install_userjs_all_profiles "$PROFILE_BASE" "Floorp (Flatpak)"
    install_flatpak_env "one.ablaze.floorp" "Floorp"
fi

# Floorp Native
if [ "$FLOORP_NATIVE" = true ]; then
    install_userjs_all_profiles "$HOME/.floorp" "Floorp (Native)"
fi

# Firefox Flatpak
if [ "$FIREFOX_FLATPAK" = true ]; then
    PROFILE_BASE="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
    install_userjs_all_profiles "$PROFILE_BASE" "Firefox (Flatpak)"
    install_flatpak_env "org.mozilla.firefox" "Firefox"
fi

# Firefox Native
if [ "$FIREFOX_NATIVE" = true ]; then
    install_userjs_all_profiles "$HOME/.mozilla/firefox" "Firefox (Native)"
fi

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Installation complete!                   ${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "What was installed:"
echo "  • user.js with NVIDIA hardware acceleration settings"
echo "  • Flatpak environment variables (for Flatpak installs)"
echo ""
echo -e "${YELLOW}IMPORTANT: Restart your browser for changes to take effect!${NC}"
echo ""
echo "To verify hardware acceleration is working:"
echo "  1. Open about:support in your browser"
echo "  2. Check 'Graphics' section"
echo "  3. Look for: Compositing = WebRender"
echo ""
echo "To verify video hardware decoding:"
echo "  1. Play a YouTube video"
echo "  2. Right-click → Stats for nerds"
echo "  3. Dropped frames should stay low"
