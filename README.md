# NVIDIA X11 Persistent Multi-Monitor Layout

A deterministic, NVIDIA-native display layout solution for X11 that avoids xrandr, GNOME display settings, and hotplug race conditions. Includes browser performance tweaks for Floorp/Firefox.

## Features

- ✅ **Interactive setup wizard** - configure any monitor setup
- ✅ Persistent layout across reboot
- ✅ Portrait/landscape monitor support (no squish)
- ✅ Optional HDMI capture card mirroring
- ✅ **Mixed refresh rate support** - ForceFullCompositionPipeline eliminates stuttering
- ✅ No display reordering
- ✅ Manual toggle + auto-apply on login
- ✅ Uses only NVIDIA MetaModes
- ✅ **Browser performance tweaks** - Hardware acceleration for Floorp/Firefox

## Requirements

- NVIDIA proprietary driver (tested with 580.x)
- X11 (not Wayland)
- \`nvidia-settings\`
- Bash 4.0+

## Quick Start (Recommended)

Run the interactive setup wizard:

\`\`\`bash
./setup-wizard.sh
\`\`\`

The wizard will:
1. Detect your connected displays
2. Let you configure position, resolution, and rotation for each
3. Optionally set up HDMI capture card mirroring
4. Generate personalized scripts
5. Enable the systemd service
6. Apply the layout immediately

## Directory Structure

After running the wizard, files are installed to:

\`\`\`
\$HOME/
├── .screenlayout/
│   ├── apply-layout.sh      # Smart selector script
│   ├── display-monitor.sh   # Hotplug monitor daemon
│   ├── nvidia-base.sh       # Base layout (auto-generated)
│   ├── nvidia-capture.sh    # Layout with HDMI capture (if configured)
│   └── .layout-config       # Saved configuration
│
└── .config/systemd/user/
    ├── apply-display-layout.service   # Runs once at login
    └── nvidia-display-monitor.service # Continuous hotplug monitor
\`\`\`

## Mixed Refresh Rate Monitors

If you have monitors with different refresh rates (e.g., 144Hz + 75Hz + 60Hz), you'll experience stuttering and frame drops without proper configuration.

### The Problem

NVIDIA's compositor tries to sync all monitors together, causing:
- 144Hz monitors stuttering down to match slower displays
- Frame drops in browsers, games, and video playback
- Jank when moving windows between monitors

### The Solution: ForceFullCompositionPipeline

Add \`{ForceFullCompositionPipeline=On}\` to each display in your MetaMode:

\`\`\`bash
nvidia-settings --assign "CurrentMetaMode=\\
DPY-3: 1920x1080 +0+580 {ForceFullCompositionPipeline=On}, \\
DPY-5: 1920x1080 +1920+580 {ForceFullCompositionPipeline=On}, \\
DPY-1: 1920x1080 +3840+0 {Rotation=Right, ForceFullCompositionPipeline=On}"
\`\`\`

**Note:** Capture cards (like HDMI capture for streaming) don't need this setting since they just receive a mirror signal.

### Trade-offs

| Benefit | Cost |
|---------|------|
| Eliminates mixed refresh rate stuttering | ~1 frame of input latency |
| Smooth scrolling in browsers | Slightly higher GPU usage |
| No more frame drops | |

For most users, the smoothness improvement far outweighs the minimal latency increase.

## Browser Performance Tweaks (Floorp/Firefox)

Browsers often have frame drop issues on NVIDIA + Linux, especially with mixed refresh rate monitors. This project includes optimized settings for Floorp and Firefox.

### Quick Install

\`\`\`bash
cd browser-tweaks
./install-browser-tweaks.sh
\`\`\`

This automatically:
- Detects your browser (Floorp/Firefox, Flatpak/Native)
- Installs \`user.js\` with hardware acceleration settings
- Configures Flatpak environment variables

### What's Included

#### user.js Settings

| Category | What it does |
|----------|--------------|
| **Hardware Acceleration** | Forces WebRender, GPU compositing, hardware video decode |
| **NVIDIA NVDEC** | Offloads H.264/HEVC/VP9/AV1 decoding to GPU |
| **Mixed Refresh Rate** | Auto-detects refresh rate, caps at highest monitor |
| **Smooth Scrolling** | Physics-based scrolling for less jank |
| **Memory Cache** | Larger cache reduces repainting |

#### Flatpak Environment Variables

| Variable | Purpose |
|----------|---------|
| \`MOZ_X11_EGL=1\` | Use EGL instead of GLX (better for modern NVIDIA) |
| \`MOZ_DISABLE_RDD_SANDBOX=1\` | Enable hardware video decoding |
| \`LIBVA_DRIVER_NAME=nvidia\` | Use nvidia-vaapi-driver for VA-API |
| \`MOZ_WEBRENDER=1\` | Force WebRender compositor |
| \`__GL_SYNC_TO_VBLANK=0\` | Disable global VSync (fixes mixed refresh) |
| \`__GL_YIELD=USLEEP\` | Better multi-monitor frame pacing |
| \`MOZ_USE_XINPUT2=1\` | Improved input handling |

### Manual Installation

If you prefer to install manually:

#### For Flatpak browsers:

\`\`\`bash
# Floorp
flatpak override --user \\
    --env=MOZ_X11_EGL=1 \\
    --env=MOZ_DISABLE_RDD_SANDBOX=1 \\
    --env=LIBVA_DRIVER_NAME=nvidia \\
    --env=MOZ_WEBRENDER=1 \\
    --env=__GL_SYNC_TO_VBLANK=0 \\
    --env=__GL_YIELD=USLEEP \\
    --env=MOZ_USE_XINPUT2=1 \\
    one.ablaze.floorp

# Firefox
flatpak override --user \\
    --env=MOZ_X11_EGL=1 \\
    --env=MOZ_DISABLE_RDD_SANDBOX=1 \\
    --env=LIBVA_DRIVER_NAME=nvidia \\
    --env=MOZ_WEBRENDER=1 \\
    --env=__GL_SYNC_TO_VBLANK=0 \\
    --env=__GL_YIELD=USLEEP \\
    --env=MOZ_USE_XINPUT2=1 \\
    org.mozilla.firefox
\`\`\`

#### Copy user.js to your profile:

\`\`\`bash
# Floorp Flatpak
cp browser-tweaks/user.js ~/.var/app/one.ablaze.floorp/.floorp/*.default-release/

# Floorp Native
cp browser-tweaks/user.js ~/.floorp/*.default-release/

# Firefox Flatpak
cp browser-tweaks/user.js ~/.var/app/org.mozilla.firefox/.mozilla/firefox/*.default-release/

# Firefox Native
cp browser-tweaks/user.js ~/.mozilla/firefox/*.default-release/
\`\`\`

### Verifying Hardware Acceleration

1. Open \`about:support\` in your browser
2. Scroll to **Graphics** section
3. Check for:
   - **Compositing:** WebRender
   - **WebRender:** force-enabled by user (or similar)

### Verifying Video Hardware Decoding

1. Install \`nvidia-vaapi-driver\` if not already installed
2. Check VA-API is working: \`vainfo\`
3. Play a YouTube video
4. Right-click → **Stats for nerds**
5. **Dropped frames** should stay very low

## Manual Installation

If you prefer to configure manually or customize the example scripts:

### 1. Copy the screenlayout scripts

\`\`\`bash
mkdir -p ~/.screenlayout
cp .screenlayout/* ~/.screenlayout/
chmod +x ~/.screenlayout/*.sh
\`\`\`

### 2. Copy the systemd service

\`\`\`bash
mkdir -p ~/.config/systemd/user
cp .config/systemd/user/apply-display-layout.service ~/.config/systemd/user/
\`\`\`

### 3. Enable the service

\`\`\`bash
systemctl --user daemon-reload
systemctl --user enable apply-display-layout.service
\`\`\`

### 4. Set up a keyboard shortcut

Bind this command in your desktop settings (e.g., **Pop!_OS → Keyboard → Custom Shortcuts**):

\`\`\`
/home/YOUR_USERNAME/.screenlayout/apply-layout.sh
\`\`\`

**Recommended keys:**
- \`Super + F12\`
- \`Ctrl + Alt + D\`

### 5. (Optional) Enable Hotplug/Auto-Detection

For automatic layout application when displays are connected/disconnected:

\`\`\`bash
./install-hotplug.sh
\`\`\`

You'll be prompted to choose:

| Option | Description | Reliability |
|--------|-------------|-------------|
| **Display Monitor (recommended)** | Polls every 3 seconds for changes | ✅ Works with NVIDIA |
| udev Rules | Kernel-triggered events | ❌ Often fails with NVIDIA |

The display monitor runs as a lightweight user service and reliably detects hotplug.

## Services

This project uses two systemd services that work together:

| Service | Purpose | Runs |
|---------|---------|------|
| \`apply-display-layout.service\` | Apply layout at login | Once at login |
| \`nvidia-display-monitor.service\` | Detect hotplug changes | Continuously |

**They don't conflict** - both are safe to have enabled. The login service ensures your layout is correct immediately at login, while the monitor handles any changes during your session.

## Scripts

### 🟢 nvidia-base.sh

Applies your base display layout (without capture card). Generated by the wizard or manually configured. Includes \`ForceFullCompositionPipeline=On\` for mixed refresh rate support.

### 🔵 nvidia-capture.sh

Applies the layout with HDMI capture card enabled (mirrors your chosen display). Only created if you configure a capture card.

### 🟣 apply-layout.sh

Smart selector that detects whether the capture device is connected and applies the correct MetaMode automatically.

### 🧙 setup-wizard.sh

Interactive configuration wizard. Run this to:
- Detect all connected displays
- Configure position (left/center/right)
- Set resolution per display
- Configure rotation (normal/left/right/inverted)
- Set up HDMI capture card mirroring
- Generate all scripts automatically

### 📊 display-status.sh

Quick status checker and action menu:
- View connected displays
- Check current MetaMode
- View service status
- Apply layout or restart services
- Launch wizard for reconfiguration

### 🌐 browser-tweaks/install-browser-tweaks.sh

Installs Floorp/Firefox performance tweaks:
- Hardware acceleration via WebRender
- NVIDIA NVDEC video decoding
- Mixed refresh rate optimizations

## Usage

1. Plug/unplug HDMI capture card
2. If using the display monitor, layout applies automatically
3. Or press your hotkey to apply manually

The layout is also automatically applied on login via the systemd service.

## Replacing or Adding Monitors

When you change your monitor setup:

\`\`\`bash
# Option 1: Run the full wizard
./setup-wizard.sh

# Option 2: Quick status check and reconfigure
./display-status.sh
\`\`\`

The wizard will:
1. Detect your new displays automatically
2. Let you configure each one
3. Regenerate all scripts
4. Restart services with new configuration

**Your old configuration is preserved** in \`~/.screenlayout/.layout-config\` until you run the wizard again.

## Verification

Check the current MetaMode:

\`\`\`bash
nvidia-settings -q CurrentMetaMode
\`\`\`

✔ Must **NOT** say \`source=RandR\`  
✔ Should show \`ForceFullCompositionPipeline=On\` for each display

Check display connections:

\`\`\`bash
nvidia-settings -q dpys
\`\`\`

✔ HDMI shows \`connected\` when plugged  
✔ DPY mappings remain stable

## Core Design Philosophy

| Principle | Description |
|-----------|-------------|
| **No xrandr** | NVIDIA MetaModes only |
| **No GNOME Displays** | Avoids config conflicts |
| **No timers** | Deterministic execution |
| **Only NVIDIA MetaModes** | Native driver control |
| **Deterministic** | Same result every time |
| **Manual toggle + auto-apply** | User-controlled with login automation |
| **Optional hotplug** | Available but with intentional delays |

## What is Intentionally NOT Included

| Excluded | Reason |
|----------|--------|
| ❌ xrandr | Conflicts with NVIDIA MetaModes |
| ❌ GNOME Displays | Creates inconsistent state |
| ❌ NVIDIA "Save X Config" | Overwrites with RandR settings |
| ❌ systemd timers | Unnecessary polling |
| ❌ ViewPortIn / ViewPortOut | Not needed for this layout |
| ❌ Panning | Causes display artifacts |

## Customization

### Using the Wizard (Recommended)

Simply run \`./setup-wizard.sh\` again to reconfigure. Your previous settings are saved in \`~/.screenlayout/.layout-config\`.

### Manual Configuration

To manually edit the MetaMode strings:

1. Run \`nvidia-settings -q dpys\` to identify your display names (DPY-0, DPY-1, etc.)
2. Update the MetaMode strings in \`nvidia-base.sh\` and \`nvidia-capture.sh\`
3. Adjust position offsets (\`+X+Y\`) to match your physical layout
4. Update the detection string in \`apply-layout.sh\` if needed

### MetaMode Syntax

\`\`\`
DPY-X: WIDTHxHEIGHT +X_OFFSET+Y_OFFSET {Options}
\`\`\`

Available options:
- \`Rotation=Left|Right|Inverted\` - Rotate display
- \`ForceFullCompositionPipeline=On\` - Fix mixed refresh rate stuttering

Example for a 3-monitor setup with mixed refresh rates:

\`\`\`bash
nvidia-settings --assign "CurrentMetaMode=\\
DPY-3: 1920x1080 +0+0 {ForceFullCompositionPipeline=On}, \\
DPY-5: 1920x1080 +1920+0 {ForceFullCompositionPipeline=On}, \\
DPY-1: 1920x1080 +3840+0 {Rotation=Right, ForceFullCompositionPipeline=On}"
\`\`\`

## Troubleshooting

### Layout resets after sleep/wake

Re-run the apply script:

\`\`\`bash
~/.screenlayout/apply-layout.sh
\`\`\`

### MetaMode shows source=RandR

Something is overwriting NVIDIA settings. Check for:
- GNOME display configuration
- Other display management tools
- Conflicting autostart scripts

### Wrong display detected as HDMI

Update the grep pattern in \`apply-layout.sh\` to match your capture card's identifier.

### Hotplug not working

1. Check the log file:
   \`\`\`bash
   cat /tmp/nvidia-hotplug.log
   \`\`\`

2. Verify udev rule is installed:
   \`\`\`bash
   cat /etc/udev/rules.d/99-nvidia-display-hotplug.rules
   \`\`\`

3. Test udev is triggering:
   \`\`\`bash
   udevadm monitor --property
   # Then plug/unplug a display
   \`\`\`

4. If still not working, use the keyboard shortcut instead (more reliable).

### Browser still dropping frames

1. Verify ForceFullCompositionPipeline is active:
   \`\`\`bash
   nvidia-settings -q CurrentMetaMode | grep ForceFullCompositionPipeline
   \`\`\`

2. Check browser hardware acceleration in \`about:support\`

3. Verify VA-API is working:
   \`\`\`bash
   vainfo
   \`\`\`

4. Make sure you restarted the browser after installing tweaks

### Reconfiguring after hardware changes

Run the wizard again:

\`\`\`bash
./setup-wizard.sh
\`\`\`

## Example Configurations

### Dual Monitor (Side by Side)

\`\`\`
[Left: 1920x1080] [Right: 1920x1080]
\`\`\`

### Triple Monitor with Portrait

\`\`\`
[Left: 1920x1080] [Center: 2560x1440] [Right: 1080x1920 Portrait]
\`\`\`

### Mixed Refresh Rate Setup

\`\`\`
[Left: 1920x1080 @ 144Hz] [Center: 1920x1080 @ 144Hz] [Right: 1920x1080 @ 75Hz Portrait]
                                    + HDMI Capture Card @ 60Hz
\`\`\`

### Ultrawide + Secondary

\`\`\`
[Ultrawide: 3440x1440] [Side: 1920x1080]
\`\`\`

### With Capture Card

\`\`\`
[Left] [Center + Capture Mirror] [Right Portrait]
\`\`\`

## License

MIT
