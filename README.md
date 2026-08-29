# NVIDIA X11 Multi-Monitor Toolkit

A complete NVIDIA display management solution for X11 Linux desktops. Handles multi-monitor layouts, mixed refresh rates, HDMI capture card mirroring, and browser performance — all using native NVIDIA MetaModes (no xrandr).

## Features

- **Interactive setup wizard** — detects displays, refresh rates, and generates everything
- **Auto-start on boot** — systemd user services apply your layout at login
- **Hotplug detection** — daemon re-applies layout when monitors connect/disconnect
- **Mixed refresh rate fix** — ForceFullCompositionPipeline eliminates stuttering
- **Capture card support** — optional HDMI capture mirroring with auto-detection and configurable refresh rate
- **PipeWire audio integration** — automatic combined audio sink for streaming/recording setups
- **G-Sync Compatible** — per-display VRR for non-validated monitors
- **Browser tweaks** — hardware acceleration for Floorp/Firefox on NVIDIA
- **Portable** — works on any NVIDIA + X11 setup, not hardcoded to one machine

## Quick Start

```bash
git clone https://github.com/ChiefGyk3D/nvidia-display-layout.git
cd nvidia-display-layout

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
7. Auto-detect capture card refresh rates and let you pick one
8. Generate personalized layout scripts
9. Install and enable systemd services for auto-start + hotplug
10. Apply the layout immediately

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

## How It Works

### Project Structure

```
nvidia-display-layout/
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
│   └── user.js                    # Firefox/Floorp performance settings
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

### Installed Files

The wizard generates scripts tailored to your hardware and installs them to `$HOME`:

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

This reads your current MetaMode and adds FFCP to every display. It also supports:

```bash
./nvidia-display-setup.sh --status  # Show displays, MetaMode, service status
./nvidia-display-setup.sh --setup   # Launch the full setup wizard
```

If the wizard has already been run, `nvidia-display-setup.sh` delegates to `~/.screenlayout/apply-layout.sh` automatically.

## Display Configuration

### Mixed Refresh Rate Fix (ForceFullCompositionPipeline)

If your monitors have different refresh rates (e.g., 144Hz + 75Hz + 60Hz), NVIDIA's compositor tries to sync them together, causing stuttering, frame drops, and jank when moving windows between monitors.

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

### G-Sync Compatible (VRR)

G-Sync Compatible allows Variable Refresh Rate (VRR, also known as FreeSync/Adaptive Sync) on monitors that aren't on NVIDIA's validated G-Sync list. This reduces tearing without the latency cost of traditional VSync.

The wizard adds `AllowGSYNCCompatible=On` to each display's MetaMode options. This is set **per-display**, so you can enable it only on monitors that support it and skip it on those that don't (e.g., capture cards or older monitors).

**Requirements:** NVIDIA driver 550.x+, monitor with FreeSync/Adaptive Sync, DisplayPort connection (HDMI VRR support varies by driver version).

**Verify G-Sync is active:**

```bash
nvidia-settings -q CurrentMetaMode | grep AllowGSYNCCompatible
# Or use the status tool:
./display-status.sh
```

### HDMI Capture Card

The project detects whether your capture card is connected and automatically picks the right layout:

- **Capture card plugged in** → uses `nvidia-capture.sh` (mirrors your chosen display)
- **Capture card unplugged** → uses `nvidia-base.sh` (base layout only)

If your capture card supports the mirror display's native resolution (e.g., Elgato 4K Pro at 1440p), the wizard outputs at that resolution directly — no scaling overhead. If the capture card doesn't support the resolution (e.g., mirroring a 1440p monitor to a 1080p Cam Link 4K), the wizard automatically configures `ViewPortIn`/`ViewPortOut` scaling so the full content is downscaled to fit.

This happens automatically at boot and whenever the hotplug daemon detects a change. No manual switching needed.

#### Capture Card Refresh Rate

The setup wizard auto-detects available refresh rates for your capture card at the chosen mirror resolution and lets you pick one interactively. The selected rate is saved to `nvidia-capture.sh` as a configurable default.

> **Important:** Not all rates are available at all resolutions. For example, the Elgato 4K Pro supports 100/120/144/240Hz at 1440p but **not** 60Hz at that resolution (60Hz is only available at 4K and 1080p).

**Change the default** by editing the `CAPTURE_REFRESH` line in `~/.screenlayout/nvidia-capture.sh`:

```bash
CAPTURE_REFRESH="${CAPTURE_REFRESH:-120}"  # Change 120 to your desired rate
```

**Override on the fly** without editing any files:

```bash
CAPTURE_REFRESH=144 ~/.screenlayout/apply-layout.sh
```

#### HDMI Deep Color and Bandwidth

Many capture cards (including the Elgato 4K Pro) advertise HDMI deep color support (10/12-bit) in their EDID. The NVIDIA X11 driver auto-negotiates 10bpc (30-bit color), which increases TMDS bandwidth by 25%. At 1440p this means:

| Refresh Rate | Pixel Clock | @10bpc TMDS | @8bpc TMDS | HDMI 2.0 (600 MHz) |
|---|---|---|---|---|
| 100Hz | 407 MHz | 509 MHz ✓ | 407 MHz ✓ | Fits both |
| 120Hz | 498 MHz | **622 MHz ✗** | 498 MHz ✓ | **8bpc only** |
| 144Hz | 596 MHz | **744 MHz ✗** | 596 MHz ✓ | **8bpc only** |

#### Why not HDMI 2.1 FRL?

HDMI 2.1 introduced **FRL (Fixed Rate Link)** which supports up to 48 Gbps — more than enough for 10bpc at any refresh rate. Both the RTX 5070 Ti and Elgato 4K Pro support FRL (up to 40 Gbps per the EDID). However, **NVIDIA's proprietary X11 driver does not negotiate FRL** — it falls back to legacy TMDS signaling, which is capped at 600 MHz (18 Gbps). This is an X11 driver limitation, not a hardware one.

On Wayland, the DRM/KMS path handles HDMI link negotiation directly and supports FRL. See [Roadmap](#roadmap) for planned Wayland support.

#### 8bpc vs 10bpc for Streaming

For streaming and recording through a capture card, **8bpc has zero visual impact**:

- **Twitch** encodes at 8-bit regardless of input — 10bpc is downsampled before transmission
- **YouTube** accepts 10-bit VP9/AV1 uploads but OBS x264/NVENC typically outputs 8-bit; even if you encode 10-bit, YouTube re-encodes to 8-bit for most viewers
- **OBS recording** in x264/NVENC uses 8-bit by default; 10-bit recording requires explicit HEVC/AV1 10-bit profile configuration and increases file size ~20% with no visible difference at typical streaming bitrates
- **The capture card itself** converts the HDMI input to USB/PCIe video frames — your OBS source is the capture device, not the raw HDMI signal

The only scenario where 10bpc matters is HDR content viewed directly on a monitor. For a capture card feeding OBS at 1080p output, the extra 2 bits per channel are discarded before they reach your audience.

#### Custom EDID Override

To run 120Hz+ at 1440p on X11, deep color must be disabled on the capture card output. This project includes a **custom EDID** with deep color flags stripped, applied via `CustomEDID` in xorg.conf targeting only the capture card (`DFP-0`). All other displays are unaffected.

**Files involved:**
- `/etc/X11/edid/elgato-4k-pro-no-deepcolor.bin` — modified EDID (deep color flags removed)
- `/etc/X11/edid/elgato-4k-pro-original.bin` — backup of original EDID
- `/etc/X11/xorg.conf` — `CustomEDID` option in Device section
- `patch-xorg-edid.path` / `patch-xorg-edid.service` — systemd watcher that re-adds the option if system76-power overwrites xorg.conf

**To revert** (go back to 10bpc, max 100Hz at 1440p): remove the `CustomEDID` line from `/etc/X11/xorg.conf` and restart X.

| Capture Card | 1440p Rates | 4K Rates | 1080p Rates |
|-------------|------------|---------|------------|
| Elgato 4K Pro | 240, 144, 120, 100 | 144, 120, 100, 60 | 240, 120, 60 |
| Elgato Cam Link 4K | N/A (use ViewPort) | 30 | 60 |

### PipeWire Combined Audio Sink (Optional)

If you use a capture card for streaming or recording (e.g., a 2PC setup), you likely want audio to play through **both** your local speakers/headphones **and** the HDMI output to the capture card simultaneously. The [PipeWire Combined Audio Output](https://github.com/ChiefGyk3D/pipewire_sink) project handles exactly this.

The combined sink itself is created **declaratively by PipeWire** (pipewire_sink v2 installs `~/.config/pipewire/pipewire.conf.d/60-combined-sink.conf`), so it exists from the moment PipeWire starts and reattaches the capture card's HDMI sink automatically whenever it disappears and returns. Display events never restart the audio stack.

When `apply-layout.sh` detects your capture card is connected, it automatically:

1. Applies the NVIDIA display layout with the capture card mirror
2. Waits for the HDMI audio handshake to complete
3. Forces the NVIDIA HDMI audio profile active
4. Calls `pipewire-ensure-defaults` to re-assert the default sink/source and volumes (non-disruptive — running audio streams are untouched)

When the capture card is **not** connected, none of the audio integration runs — your audio stays on its normal default output.

> **Upgrading from an older install?** Earlier versions called `reset-pipewire` here, which fully restarted PipeWire on every display event — disconnecting every application's audio (frozen browser tabs) and occasionally crashing PipeWire. Re-run `setup-wizard.sh` (or pipewire_sink's `install.sh`) to regenerate `apply-layout.sh` with the non-disruptive integration.

**Setup:**

```bash
git clone https://github.com/ChiefGyk3D/pipewire_sink.git
cd pipewire_sink
./install.sh
```

That's it — `apply-layout.sh` automatically detects `~/.local/bin/pipewire-ensure-defaults` and calls it when a capture card is found.

**Disable audio integration** if you have pipewire_sink installed but don't want it:

```bash
PIPEWIRE_ENSURE_DEFAULTS=none ~/.screenlayout/apply-layout.sh
```

Or set `PIPEWIRE_ENSURE_DEFAULTS="none"` in `~/.screenlayout/apply-layout.sh`.

**Logs:** Check `/tmp/nvidia-display-monitor.log` — lines prefixed with `[pipewire]` are from the audio defaults pass.

## Browser Performance Tweaks (Floorp/Firefox)

Browsers on NVIDIA + Linux often have frame drops, especially with mixed refresh rates. This project includes optimized settings.

### Install

```bash
cd browser-tweaks
./install-browser-tweaks.sh
```

This automatically detects your browser (Floorp/Firefox, Flatpak/Native) and installs:

1. Optimized `user.js` settings for NVIDIA hardware acceleration
2. VA-API driver copy for Flatpak sandboxes (Flatpak blocks `/usr/lib`)
3. Flatpak environment overrides for hardware video decoding
4. Restarts your browser to apply

#### What It Configures

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

Dedicated launcher scripts set all NVIDIA environment variables before launching the browser:

```bash
browser-tweaks/launch-floorp.sh    # Floorp (Flatpak)
browser-tweaks/launch-firefox.sh   # Firefox (Flatpak)
```

For native (non-Flatpak) installs, the `user.js` tweaks handle everything — no launcher needed.

### Verify Hardware Acceleration

1. Open `about:support` → **Graphics** section
2. Check: **Compositing: WebRender**, **WebRender: force-enabled**
3. Play a YouTube video → right-click → **Stats for nerds** → dropped frames should stay very low

### Manual about:config Reference

The `user.js` file handles everything automatically. If you need to verify or adjust settings manually, expand the sections below.

<details>
<summary><strong>Hardware Acceleration Settings</strong></summary>

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

</details>

<details>
<summary><strong>NVIDIA Video Decoding (NVDEC) Settings</strong></summary>

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

**Prerequisite:** `nvidia-vaapi-driver` — see [Install Prerequisites](#install-prerequisites).

</details>

<details>
<summary><strong>Mixed Refresh Rate / Multi-Monitor Settings</strong></summary>

| Setting | Value | What it does |
|---------|-------|-------------|
| `layout.frame_rate` | `-1` | Auto-detect refresh rate (critical for mixed Hz) |
| `gfx.display.max-frame-rate` | `180` | Cap at your highest monitor's Hz (adjust to match yours) |
| `gfx.webrender.compositor` | `true` | WebRender compositor |
| `gfx.webrender.compositor.force-enabled` | `true` | Force compositor |
| `widget.wayland.vsync.enabled` | `false` | Disable Wayland vsync (X11 setups) |
| `gfx.webrender.all.async-scene-builder` | `true` | Async scene building for multi-monitor |

> **Note:** Change `gfx.display.max-frame-rate` to match your highest refresh rate monitor.

</details>

<details>
<summary><strong>Smooth Scrolling &amp; Performance Settings</strong></summary>

| Setting | Value | What it does |
|---------|-------|-------------|
| `general.smoothScroll` | `true` | Enable smooth scrolling |
| `general.smoothScroll.msdPhysics.enabled` | `true` | Physics-based scrolling |
| `apz.frame_delay.enabled` | `false` | Reduce input-to-paint delay |
| `dom.ipc.processCount` | `8` | Content processes (8 for 16GB+ RAM, lower for less) |
| `browser.cache.memory.capacity` | `524288` | 512MB memory cache |
| `nglayout.initialpaint.delay` | `0` | No delay before first paint |
| `browser.sessionstore.interval` | `30000` | Save session every 30s instead of 15s |
| `toolkit.telemetry.enabled` | `false` | Disable telemetry (reduces background CPU) |

</details>

### Additional Browser Steps

After installing tweaks, you may also need to:

1. **Restart the browser completely** — close all windows, not just reload
2. **Check `about:support` → Graphics** — verify WebRender is active
3. **Enable hardware acceleration in settings** (if disabled): Settings → General → Performance → uncheck "Use recommended performance settings" → check "Use hardware acceleration when available"
4. **Flatpak users:** Use the launcher scripts or run `install-browser-tweaks.sh` which applies Flatpak overrides permanently

## Maintenance

### Reconfiguring

When you change your monitor setup, re-run the wizard:

```bash
./setup-wizard.sh
```

Or use the status tool for a quick overview and actions:

```bash
./display-status.sh
```

Your previous configuration is preserved in `~/.screenlayout/.layout-config` until the wizard overwrites it.

### Updating

```bash
cd nvidia-display-layout
git pull

# Re-run if scripts changed
./setup-wizard.sh

# Re-install browser tweaks if user.js changed
cd browser-tweaks
./install-browser-tweaks.sh
```

Your display configuration (`~/.screenlayout/.layout-config`) is separate from the repo, so `git pull` won't overwrite your settings.

### Backup & Restore

```bash
# Backup
cp -r ~/.screenlayout ~/.screenlayout.backup
cp -r ~/.config/systemd/user/apply-display-layout.service ~/.config/systemd/user/apply-display-layout.service.backup
cp -r ~/.config/systemd/user/nvidia-display-monitor.service ~/.config/systemd/user/nvidia-display-monitor.service.backup

# Restore
cp -r ~/.screenlayout.backup/* ~/.screenlayout/
cp ~/.config/systemd/user/apply-display-layout.service.backup ~/.config/systemd/user/apply-display-layout.service
cp ~/.config/systemd/user/nvidia-display-monitor.service.backup ~/.config/systemd/user/nvidia-display-monitor.service
systemctl --user daemon-reload
~/.screenlayout/apply-layout.sh
```

### Uninstalling

```bash
# 1. Stop and disable services
systemctl --user stop apply-display-layout.service nvidia-display-monitor.service
systemctl --user disable apply-display-layout.service nvidia-display-monitor.service

# 2. Remove installed files
rm -rf ~/.screenlayout
rm -f ~/.config/systemd/user/apply-display-layout.service
rm -f ~/.config/systemd/user/nvidia-display-monitor.service
systemctl --user daemon-reload

# 3. Remove hotplug (if installed)
./remove-hotplug.sh

# 4. Remove browser tweaks (optional)
rm -f ~/.var/app/one.ablaze.floorp/.floorp/*/user.js
rm -f ~/.var/app/org.mozilla.firefox/.mozilla/firefox/*/user.js
rm -f ~/.mozilla/firefox/*/user.js
flatpak override --user --reset one.ablaze.floorp 2>/dev/null
flatpak override --user --reset org.mozilla.firefox 2>/dev/null
rm -f ~/.local/lib/dri/nvidia_drv_video.so

# 5. Remove the repo
cd .. && rm -rf nvidia-display-layout
```

After uninstalling, NVIDIA reverts to its default display behavior. FFCP and G-Sync Compatible settings don't persist in the driver permanently.

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
[Left: 2560x1440 @ 180Hz] [Center: 2560x1440 @ 180Hz] [Right: 1080x1920 @ 75Hz Portrait]
                                    + HDMI Capture Card @ 100Hz (mirrors center at 1440p)
```

## Tested Hardware

### Monitors

| Monitor | Resolution | Refresh Rate | Notes |
|---------|-----------|-------------|-------|
| ASUS TUF Gaming VG27WCS | 2560x1440 | 180Hz | G-Sync Compatible, primary development monitors |

### Capture Cards

| Device | Supported Input | Notes |
|--------|----------------|-------|
| Elgato 4K Pro | 1080p, 1440p, 4K | Supports 1440p natively — no ViewPort scaling needed |
| Elgato Cam Link 4K | 1080p, 4K | Does **not** support 1440p — use ViewPort scaling |

### GPUs

| GPU | Driver | Status |
|-----|--------|--------|
| NVIDIA GeForce RTX 5070 Ti | 590.x+ | Fully tested |
| NVIDIA GeForce RTX series (general) | 550.x+ | Expected to work |

### Distros

| Distribution | Status | Notes |
|-------------|--------|-------|
| Ubuntu 24.04+ | Tested | `apt install nvidia-settings nvidia-vaapi-driver` |
| Fedora 39+ | Expected | `dnf install nvidia-settings nvidia-vaapi-driver` |
| Arch Linux | Expected | `pacman -S nvidia-settings libva-nvidia-driver` |

> **Contributions welcome!** If you test on hardware not listed here, please [open an issue](https://github.com/ChiefGyk3D/nvidia-display-layout/issues) or submit a PR to update this table.

## Troubleshooting

### Layout resets after sleep/wake

Run `~/.screenlayout/apply-layout.sh` or restart the monitor service which will re-apply automatically.

### MetaMode shows `source=RandR`

Something is overwriting NVIDIA settings. Check for GNOME display configuration or other display management tools conflicting.

### Hotplug not detecting changes

Check `/tmp/nvidia-display-monitor.log`. The polling-based monitor service (recommended) is more reliable than udev rules with NVIDIA proprietary drivers.

### Capture card silently not working

Capture cards that don't support the source display's resolution are silently dropped by the NVIDIA driver. Signs:

- `nvidia-settings -q dpys` shows the capture card as connected but `nvidia-settings -q CurrentMetaMode` doesn't include it
- The capture card shows no signal or a black screen

The setup wizard detects this automatically. For manual configuration, see [HDMI Capture Card](#hdmi-capture-card).

### Browser still dropping frames

1. Verify FFCP: `nvidia-settings -q CurrentMetaMode | grep ForceFullCompositionPipeline`
2. Check `about:support` → Graphics → Compositing should say WebRender
3. Verify VA-API: `vainfo` (requires `nvidia-vaapi-driver`)
4. Check GPU decode: `nvidia-smi pmon -c 5` — the `dec` column should show usage during video playback
5. Restart browser after installing tweaks
6. **Flatpak users:** Run `install-browser-tweaks.sh` to copy the VA-API driver to `~/.local/lib/dri/`

### VA-API not working after driver update

Re-run `install-browser-tweaks.sh` to refresh the driver copy, then verify with `vainfo`.

### Frames drop when opening new browser windows

1. Verify shader pre-caching in `about:config`: `gfx.webrender.program-binary-disk-cache` and `gfx.webrender.precache-shaders` = `true`
2. Check GPU process stability: `layers.gpu-process.max_restarts` = `0`
3. Re-run `install-browser-tweaks.sh` — the latest `user.js` includes these fixes

### VRR not activating

- Make sure you're on DisplayPort, not HDMI. Some HDMI connections don't support VRR with NVIDIA drivers.
- Desktop compositors (Picom, Compton) may interfere. KWin and Mutter generally work fine.
- Flickering at low frame rates is a monitor limitation, not a driver bug.

## FAQ

### Does this work on Wayland?

Not yet. The current version is X11-only (MetaModes, `nvidia-settings`, `ForceFullCompositionPipeline`). Wayland support using COSMIC/`cosmic-randr` is planned for the Pop!_OS 26.04 upgrade — see [Roadmap](#roadmap). On Wayland, HDMI 2.1 FRL should work out of the box, eliminating the need for the custom EDID deep color workaround.

### Does this work with AMD or Intel GPUs?

No. Everything here is NVIDIA-specific: MetaModes, NVDEC, nvidia-vaapi-driver, ForceFullCompositionPipeline.

### Do I need to re-run the wizard after every reboot?

No. The systemd user services apply your layout automatically on login and watch for display changes. Re-run the wizard only when you physically change your monitor setup.

### Can I use this with a desktop environment's display settings?

Not recommended. GNOME Display Settings, KDE Display Configuration, and similar tools use xrandr or Wayland APIs which conflict with NVIDIA MetaModes. Let this toolkit handle display configuration exclusively.

### Why not just use xrandr?

NVIDIA MetaModes offer features xrandr can't: ForceFullCompositionPipeline, AllowGSYNCCompatible, ViewPortIn/ViewPortOut scaling, and reliably pinned refresh rates. Using xrandr alongside MetaModes can cause conflicts.

## Known Limitations

| Limitation | Details |
|-----------|--------|
| **X11 only (Wayland planned)** | NVIDIA MetaModes and `nvidia-settings` are X11-specific. Wayland support via COSMIC is on the [Roadmap](#roadmap). |
| **NVIDIA proprietary driver only** | Nouveau doesn't support MetaModes, FFCP, or NVDEC. |
| **No per-window refresh rate** | X11 + NVIDIA applies one composition rate globally. FFCP mitigates this. |
| **Capture card resolution limits** | Some capture cards don't support all resolutions — the wizard auto-detects and applies ViewPort scaling when needed. |
| **udev hotplug unreliable** | NVIDIA drivers often don't emit kernel hotplug events. Use the polling monitor service instead (the default). |
| **~1 frame input latency** | FFCP adds ~1 frame of latency. Disable per-display in the wizard for competitive gaming. |
| **Flatpak VA-API workaround** | Flatpak sandboxes block `/usr/lib`. Run `install-browser-tweaks.sh` to copy `nvidia_drv_video.so` to `~/.local/lib/dri/`. Re-run after driver updates. |

## Roadmap

### Wayland / COSMIC Support (Pop!_OS 26.04)

The project will add a **Wayland backend** alongside the existing X11 backend when upgrading to Pop!_OS 26.04 (COSMIC desktop). Both will live in the same repository:

| Feature | X11 (current) | Wayland (planned) |
|---|---|---|
| Display layout | `nvidia-settings` MetaModes | `cosmic-randr` / COSMIC settings API |
| Mixed refresh rate fix | `ForceFullCompositionPipeline` | Native compositor support |
| G-Sync / VRR | `AllowGSYNCCompatible` in MetaMode | DRM/KMS properties |
| Custom EDID | `CustomEDID` in xorg.conf | `drm.edid_firmware=` kernel param (or not needed — FRL fixes bandwidth) |
| Hotplug detection | Polling via `nvidia-settings` | Native DRM hotplug events |
| HDMI deep color | 8bpc EDID workaround (TMDS limit) | Not needed — HDMI 2.1 FRL supports 10bpc at 120Hz+ natively |
| PipeWire audio | Declarative combined sink + `pipewire-ensure-defaults` | Same (no changes needed) |

**What carries over unchanged:** PipeWire combined audio sink, capture card auto-detection logic, setup wizard UX flow, systemd service architecture.

**What gets rewritten:** Display layout scripts, configuration backend, refresh rate detection, display property queries.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

If you test on hardware not listed in the compatibility tables, please open an issue or PR with your results.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a history of changes.

## License

MIT
