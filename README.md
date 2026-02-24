# NVIDIA X11 Multi-Monitor Toolkit

A complete NVIDIA display management solution for X11 Linux desktops. Handles multi-monitor layouts, mixed refresh rates, HDMI capture card mirroring, and browser performance — all using native NVIDIA MetaModes (no xrandr).

## Features

- **Interactive setup wizard** — detects displays, refresh rates, and generates everything
- **Auto-start on boot** — systemd user services apply your layout at login
- **Hotplug detection** — daemon re-applies layout when monitors connect/disconnect
- **Mixed refresh rate fix** — ForceFullCompositionPipeline eliminates stuttering
- **Capture card support** — optional HDMI capture mirroring with auto-detection
- **Browser tweaks** — hardware acceleration for Floorp/Firefox on NVIDIA
- **Portable** — works on any NVIDIA + X11 setup, not hardcoded to one machine

## Requirements

- NVIDIA proprietary driver (tested with 550.x+)
- X11 (not Wayland)
- `nvidia-settings`
- Bash 4.0+
- `nvidia-vaapi-driver` (for browser hardware video decoding)

### Install Prerequisites

```bash
# Ubuntu/Debian
sudo apt install nvidia-settings nvidia-vaapi-driver

# Fedora
sudo dnf install nvidia-settings nvidia-vaapi-driver

# Arch
sudo pacman -S nvidia-settings libva-nvidia-driver
```

Verify VA-API is working:

```bash
vainfo
# Should show: "VA-API NVDEC driver" with supported codecs
```

## Tested Hardware

- **ASUS TUF Gaming VG27WCS** (2560x1440 @ 180Hz) — primary monitors
- **Elgato Cam Link 4K** — HDMI capture card (1080p/4K input)
- NVIDIA GeForce RTX series GPUs

## Quick Start

```bash
git clone https://github.com/ChiefGyk3D/nvidia-capture-card.git
cd nvidia-capture-card

# 1. Configure display layout
./setup-wizard.sh

# 2. Install browser performance tweaks (optional but recommended)
cd browser-tweaks
./install-browser-tweaks.sh
```

The wizard will:

1. Detect all connected displays
2. Auto-detect available refresh rates for each
3. Configure position, resolution, refresh rate, and rotation per display
4. Ask whether to enable ForceFullCompositionPipeline (fixes mixed Hz stuttering)
5. Ask whether to enable G-Sync Compatible (VRR on non-validated monitors)
6. Optionally set up HDMI capture card mirroring (with auto-scaling if resolutions don't match)
7. Generate personalized layout scripts
8. Install and enable systemd services for auto-start + hotplug
9. Apply the layout immediately

The browser tweaks installer will:

1. Auto-detect Floorp/Firefox (Flatpak or native)
2. Install optimized `user.js` settings for NVIDIA hardware acceleration
3. Copy the NVIDIA VA-API driver to a Flatpak-accessible path (Flatpak sandboxes block `/usr`)
4. Set Flatpak environment overrides for hardware video decoding
5. Restart your browser to apply

## How It Works

### Display Layout

The wizard generates MetaMode scripts tailored to your hardware:

```
$HOME/.screenlayout/
├── nvidia-base.sh       # Layout without capture card
├── nvidia-capture.sh    # Layout with capture card mirroring (if configured)
├── apply-layout.sh      # Smart selector — detects capture card, picks correct layout
├── display-monitor.sh   # Hotplug daemon — polls for display changes
└── .layout-config       # Saved configuration
```

### Auto-Start Services

Two systemd user services handle automation:

| Service | What it does | Type |
|---------|-------------|------|
| `apply-display-layout.service` | Applies layout at login | Runs once |
| `nvidia-display-monitor.service` | Watches for display changes | Runs continuously |

```bash
# Check status
systemctl --user status apply-display-layout.service
systemctl --user status nvidia-display-monitor.service

# Manual control
systemctl --user enable apply-display-layout.service    # Enable auto-start
systemctl --user disable nvidia-display-monitor.service  # Disable hotplug
systemctl --user restart nvidia-display-monitor.service   # Restart monitor
```

The monitor daemon polls every 3 seconds and automatically re-applies your layout when displays are connected or disconnected — including capture cards that may not always be on.

### Quick Apply (No Wizard)

For a one-shot application of ForceFullCompositionPipeline without running the wizard:

```bash
./nvidia-display-setup.sh
```

This reads your current MetaMode and adds FFCP to every display. Useful for quick fixes or testing. It also supports:

```bash
./nvidia-display-setup.sh --status  # Show displays, MetaMode, service status
./nvidia-display-setup.sh --setup   # Launch the full setup wizard
```

If the wizard has already been run, `nvidia-display-setup.sh` delegates to the installed `~/.screenlayout/apply-layout.sh` automatically.

## Mixed Refresh Rate Monitors

If your monitors have different refresh rates (e.g., 144Hz + 75Hz + 60Hz), NVIDIA's compositor tries to sync them together, causing stuttering, frame drops, and jank when moving windows between monitors.

### The Fix: ForceFullCompositionPipeline

The setup wizard adds `{ForceFullCompositionPipeline=On}` to each display's MetaMode and pins the exact refresh rate:

```bash
nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 2560x1440_180 +0+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-5: 2560x1440_180 +2560+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080_75 +5120+0 {Rotation=Right, ForceFullCompositionPipeline=On}"
```

The wizard auto-detects refresh rates via `nvidia-settings` and `xrandr`, or lets you pick from common rates (60/75/120/144/165/180/240Hz) or enter a custom value. FFCP and G-Sync Compatible are enabled per-display so you can skip them on monitors where you don't need them.

| Benefit | Trade-off |
|---------|-----------|
| Eliminates mixed refresh rate stuttering | ~1 frame of input latency |
| Smooth scrolling in browsers | Slightly higher GPU usage |
| No more frame drops between monitors | |

Capture cards don't need FFCP since they just receive a mirror signal.

## HDMI Capture Card

The project detects whether your capture card is connected and automatically picks the right layout:

- **Capture card plugged in** → uses `nvidia-capture.sh` (mirrors your chosen display)
- **Capture card unplugged** → uses `nvidia-base.sh` (base layout only)

If the capture card doesn't support the mirror display's native resolution (e.g., mirroring a 1440p monitor to a 1080p capture card), the wizard automatically configures `ViewPortIn`/`ViewPortOut` scaling so the full content is downscaled to fit.

This happens automatically at boot and whenever the hotplug daemon detects a change. No manual switching needed.

## Browser Performance Tweaks (Floorp/Firefox)

Browsers on NVIDIA + Linux often have frame drops, especially with mixed refresh rates. This project includes optimized settings.

### Install

```bash
cd browser-tweaks
./install-browser-tweaks.sh
```

This automatically detects your browser (Floorp/Firefox, Flatpak/Native) and installs:

#### user.js Settings

| Category | What it does |
|----------|-------------|
| Hardware Acceleration | Forces WebRender, GPU compositing, hardware video decode |
| NVIDIA NVDEC | Offloads H.264/HEVC/VP9/AV1 decoding to GPU |
| Mixed Refresh Rate | Auto-detects refresh rate, caps at highest monitor |
| Smooth Scrolling | Physics-based scrolling for less jank |
| Memory Cache | Larger cache reduces repainting |

#### Flatpak Environment Variables

| Variable | Purpose |
|----------|---------|
| `MOZ_X11_EGL=1` | EGL backend (better for modern NVIDIA) |
| `MOZ_DISABLE_RDD_SANDBOX=1` | Enable hardware video decoding |
| `LIBVA_DRIVER_NAME=nvidia` | nvidia-vaapi-driver for VA-API |
| `MOZ_WEBRENDER=1` | Force WebRender compositor |
| `__GL_SYNC_TO_VBLANK=0` | Disable global VSync (fixes mixed refresh) |
| `__GL_YIELD=USLEEP` | Better multi-monitor frame pacing |
| `MOZ_USE_XINPUT2=1` | Improved input handling |

### Browser Launchers

Dedicated launcher scripts set all NVIDIA environment variables before launching the browser. Use these as custom launchers instead of the default desktop shortcuts:

```bash
browser-tweaks/launch-floorp.sh    # Floorp (Flatpak)
browser-tweaks/launch-firefox.sh   # Firefox (Flatpak)
```

For native (non-Flatpak) installs, the `user.js` tweaks handle everything — no launcher needed.

### Verify Hardware Acceleration

1. Open `about:support` → **Graphics** section
2. Check: **Compositing: WebRender**, **WebRender: force-enabled**
3. Play a YouTube video → right-click → **Stats for nerds** → dropped frames should stay very low

### Manual In-Browser Setup (about:config)

The `user.js` file handles everything automatically on startup. However, if you prefer to set things manually, or need to verify/adjust settings in a running browser, open `about:config` and search for these keys:

#### Required for Hardware Acceleration

| Setting | Value | What it does |
|---------|-------|-------------|
| `gfx.webrender.all` | `true` | Enable WebRender on all pages |
| `gfx.webrender.enabled` | `true` | Enable WebRender compositor |
| `gfx.canvas.accelerated` | `true` | GPU-accelerated canvas |
| `layers.acceleration.force-enabled` | `true` | Force GPU compositing layers |
| `layers.gpu-process.enabled` | `true` | Separate GPU process |
| `layers.gpu-process.force-enabled` | `true` | Force GPU process even if unstable |
| `gfx.x11-egl.force-enabled` | `true` | Use EGL instead of GLX (NVIDIA) |
| `widget.dmabuf.force-enabled` | `true` | DMA-BUF for zero-copy texture sharing |

#### Required for NVIDIA Video Decoding (NVDEC)

| Setting | Value | What it does |
|---------|-------|-------------|
| `media.hardware-video-decoding.enabled` | `true` | Enable hardware video decode |
| `media.hardware-video-decoding.force-enabled` | `true` | Force it even if not auto-detected |
| `media.ffmpeg.vaapi.enabled` | `true` | VA-API via nvidia-vaapi-driver |
| `media.ffvpx.enabled` | `true` | Keep enabled — needed for decode pipeline negotiation |
| `media.rdd-ffmpeg.enabled` | `true` | FFmpeg in RDD process |
| `media.rdd-vpx.enabled` | `true` | VP9 in RDD process |
| `media.av1.enabled` | `true` | Enable AV1 codec |
| `media.mediasource.vp9.enabled` | `true` | VP9 via MediaSource |

**Prerequisite:** Install `nvidia-vaapi-driver` for VA-API support:

```bash
# Fedora
sudo dnf install nvidia-vaapi-driver

# Ubuntu/Debian
sudo apt install nvidia-vaapi-driver

# Arch
sudo pacman -S libva-nvidia-driver
```

Verify it's working: `vainfo` should show NVIDIA as the driver.

#### Mixed Refresh Rate / Multi-Monitor

| Setting | Value | What it does |
|---------|-------|-------------|
| `layout.frame_rate` | `-1` | Auto-detect refresh rate (critical for mixed Hz) |
| `gfx.display.max-frame-rate` | `180` | Cap at your highest monitor's Hz (adjust to match yours) |
| `gfx.webrender.compositor` | `true` | WebRender compositor |
| `gfx.webrender.compositor.force-enabled` | `true` | Force compositor |
| `widget.wayland.vsync.enabled` | `false` | Disable Wayland vsync (X11 setups) |
| `gfx.webrender.all.async-scene-builder` | `true` | Async scene building for multi-monitor |

> **Note:** Change `gfx.display.max-frame-rate` to match your highest refresh rate monitor. If your fastest monitor is 165Hz, set it to `165`.

#### Smooth Scrolling

| Setting | Value | What it does |
|---------|-------|-------------|
| `general.smoothScroll` | `true` | Enable smooth scrolling |
| `general.smoothScroll.msdPhysics.enabled` | `true` | Physics-based scrolling |
| `apz.frame_delay.enabled` | `false` | Reduce input-to-paint delay |

#### Performance Tuning

| Setting | Value | What it does |
|---------|-------|-------------|
| `dom.ipc.processCount` | `8` | Content processes (8 for 16GB+ RAM, lower for less) |
| `browser.cache.memory.capacity` | `524288` | 512MB memory cache |
| `nglayout.initialpaint.delay` | `0` | No delay before first paint |
| `browser.sessionstore.interval` | `30000` | Save session every 30s instead of 15s |
| `toolkit.telemetry.enabled` | `false` | Disable telemetry (reduces background CPU) |

### Additional Browser Steps

After installing the tweaks (`user.js` or manual `about:config`), you may also need to:

1. **Restart the browser completely** — close all windows, not just reload
2. **Check `about:support` → Graphics** — verify WebRender is active
3. **Enable hardware acceleration in settings** (if disabled):
   - Firefox: Settings → General → Performance → uncheck "Use recommended performance settings" → check "Use hardware acceleration when available"
   - Floorp: Same location, same settings
4. **For Flatpak installs**, the launcher scripts or `install-browser-tweaks.sh` set the needed environment variables. If you launched from the desktop shortcut instead, the env vars won't be set — use the launcher scripts or run `install-browser-tweaks.sh` which applies Flatpak overrides permanently.

## Project Structure

```
nvidia-capture-card/
├── setup-wizard.sh              # Interactive configuration wizard
├── nvidia-display-setup.sh      # Quick apply / status / setup launcher
├── display-status.sh            # Status checker and action menu
├── install-hotplug.sh           # Install hotplug detection (monitor or udev)
├── remove-hotplug.sh            # Uninstall hotplug detection
├── README.md
│
├── browser-tweaks/
│   ├── install-browser-tweaks.sh  # Auto-detect and install browser tweaks
│   ├── launch-floorp.sh           # Floorp launcher with NVIDIA env vars
│   ├── launch-firefox.sh          # Firefox launcher with NVIDIA env vars
│   └── user.js                    # Firefox/Floorp performance settings (same file works for both)
│
├── .screenlayout/                 # Example/template layout scripts
│   ├── apply-layout.sh            # Smart selector (capture card detection)
│   ├── display-monitor.sh         # Hotplug polling daemon
│   ├── hotplug-handler.sh         # udev event handler
│   ├── nvidia-base.sh             # Base layout example
│   └── nvidia-capture.sh          # Capture card layout example
│
├── .config/systemd/user/
│   ├── apply-display-layout.service     # Login layout service
│   └── nvidia-display-monitor.service   # Hotplug monitor service
│
└── udev/
    └── 99-nvidia-display-hotplug.rules  # udev rules (alternative to monitor)
```

## Reconfiguring

When you change your monitor setup, just re-run the wizard:

```bash
./setup-wizard.sh
```

Or use the status tool for a quick overview and actions:

```bash
./display-status.sh
```

Your previous configuration is preserved in `~/.screenlayout/.layout-config` until the wizard overwrites it.

## MetaMode Reference

### Syntax

```
DPY-X: WIDTHxHEIGHT_REFRESHRATE +X_OFFSET+Y_OFFSET {Options}
```

The refresh rate suffix (e.g., `_144`) is optional. If omitted, the driver picks the default.

### Options

| Option | Description |
|--------|-------------|
| `Rotation=Left\|Right\|Inverted` | Rotate display |
| `ForceFullCompositionPipeline=On` | Fix mixed refresh rate stuttering |
| `AllowGSYNCCompatible=On` | Enable VRR/FreeSync on non-validated monitors |
| `ViewPortIn=WxH` | Input viewport size (for scaling) |
| `ViewPortOut=WxH+X+Y` | Output viewport size (for scaling) |

### Example Layouts

**Dual monitor (side by side):**
```
[Left: 1920x1080] [Right: 1920x1080]
```

**Triple with portrait:**
```
[Left: 1920x1080 @ 144Hz] [Center: 2560x1440 @ 165Hz] [Right: 1080x1920 @ 75Hz Portrait]
```

**Mixed refresh rate + capture card:**
```
[Left: 1920x1080 @ 144Hz] [Center: 1920x1080 @ 144Hz] [Right: 1920x1080 @ 75Hz Portrait]
                                    + HDMI Capture Card @ 60Hz (mirrors center)
```

## Troubleshooting

### Layout resets after sleep/wake

```bash
~/.screenlayout/apply-layout.sh
```

Or restart the monitor service which will re-apply automatically.

### MetaMode shows `source=RandR`

Something is overwriting NVIDIA settings. Check for GNOME display configuration or other display management tools conflicting.

### Hotplug not detecting changes

Check the monitor daemon log:

```bash
cat /tmp/nvidia-display-monitor.log
```

The polling-based monitor service (recommended) is more reliable than udev rules with NVIDIA proprietary drivers.

### Browser still dropping frames

1. Verify FFCP: `nvidia-settings -q CurrentMetaMode | grep ForceFullCompositionPipeline`
2. Check `about:support` → Graphics → Compositing should say WebRender
3. Verify VA-API: `vainfo` (requires `nvidia-vaapi-driver`)
4. Check GPU decode is active: `nvidia-smi pmon -c 5` — the `dec` column should show usage during video playback
5. Restart browser after installing tweaks
6. **Flatpak users:** Run `install-browser-tweaks.sh` — it copies the VA-API driver to `~/.local/lib/dri/` because Flatpak blocks `/usr` paths inside the sandbox. Without this, hardware video decode silently falls back to software.

## Design Principles

| Principle | Why |
|-----------|-----|
| NVIDIA MetaModes only | Native driver control, no xrandr conflicts |
| No GNOME Displays | Avoids config state conflicts |
| Deterministic | Same result every boot |
| User services | No root needed for daily operation |
| Portable | Works on any NVIDIA + X11 machine |

## License

MIT
