# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Changed
- **Audio integration no longer restarts PipeWire.** `apply-layout.sh` used to
  run `reset-pipewire` (a full pipewire/wireplumber/pipewire-pulse restart) on
  every display event — HDMI re-handshakes, MetaMode drift, and monitor sleep
  all disconnected every application's audio streams (frozen browser tabs) and
  could race PipeWire 1.0.x into a segfault. The combined sink is now created
  declaratively by PipeWire itself (pipewire_sink v2's `60-combined-sink.conf`)
  and reattaches the HDMI sink automatically; the generated `apply-layout.sh`
  only re-asserts the HDMI card profile and calls the non-disruptive
  `pipewire-ensure-defaults`. Re-run `setup-wizard.sh` (or the pipewire_sink
  installer) to upgrade an existing `~/.screenlayout/apply-layout.sh`.

### Added
- Elgato 4K Pro capture card support — outputs at native 1440p without ViewPort scaling
- Custom EDID override to disable HDMI deep color (10bpc) on the capture card output, enabling 120Hz at 1440p (8bpc stays within TMDS 600 MHz limit)
- systemd path watcher (`patch-xorg-edid.path`) to re-add CustomEDID if system76-power overwrites xorg.conf
- Configurable capture card refresh rate (default 120Hz, evenly divides to 30/60 fps)

### Fixed
- Display monitor now detects MetaMode resets (HDMI renegotiation, compositor, system76-power) — previously only tracked display connect/disconnect, missing mode changes on already-connected displays
- Post-apply verification loop catches HDMI handshake resets that revert the MetaMode after it's applied (up to 3 retry attempts with 5s verification delay)
- Shader pre-caching settings (`gfx.webrender.program-binary-disk-cache`, `gfx.webrender.precache-shaders`) to eliminate frame drops when opening new browser windows
- GPU process stability settings (`layers.gpu-process.force-enabled`, `max_restarts=0`) to prevent frame hitches
- WebRender worker thread tuning (`gfx.webrender.worker-count=4`) for parallel scene building across multiple windows
- Content process pre-launching (`dom.ipc.processPrelaunch`) for faster new window creation
- Profile detection via `profiles.ini` in `install-browser-tweaks.sh` — finds the actual active profile instead of globbing
- User.js installation to **all** browser profiles, not just the first match
- Comprehensive README sections: FAQ, Known Limitations, Uninstall, Update, Backup/Restore, G-Sync Compatible
- CONTRIBUTING.md with bug report templates and code style guidelines
- This CHANGELOG

### Fixed
- `install-browser-tweaks.sh` was installing to a stale profile directory (matched `*.default-release` glob instead of the active profile from `profiles.ini`)

## [2025-02-24] - Browser & Onboarding Improvements

### Added
- Extensive README overhaul for new user onboarding
- Prerequisites section with distro-specific install commands
- Flatpak VA-API troubleshooting in README
- `nvidia-smi pmon` verification tip for hardware decode
- Documented `AllowGSYNCCompatible` and ViewPort options

### Fixed
- VA-API hardware video decode in Flatpak: driver at `/usr/lib/x86_64-linux-gnu/dri/` is blocked by sandbox — now copies `nvidia_drv_video.so` to `~/.local/lib/dri/` automatically
- `install-browser-tweaks.sh` copies VA-API driver to user-accessible path
- Launch scripts (`launch-floorp.sh`, `launch-firefox.sh`) now set `NVD_BACKEND=direct` and `LIBVA_DRIVERS_PATH`
- `media.ffvpx.enabled` set to `true` — disabling it broke the decode pipeline on newer Gecko versions
- Added `media.rdd-process.enabled` and `media.gpu-process-decoder` for proper NVDEC offloading
- `gfx.display.max-frame-rate` bumped from 144 to 180 to match new monitor refresh rate

## [2025-02-24] - G-Sync & 1440p Capture Scaling

### Added
- `AllowGSYNCCompatible=On` explicit persistence in all layout scripts
- G-Sync Compatible per-display prompt in setup wizard
- G-Sync/VRR status section in `display-status.sh`
- 180Hz added to common refresh rate list in wizard
- ASUS TUF Gaming VG27WCS to tested hardware
- `CAPTURE_DISPLAY_NAME` variable in wizard for clarity

### Fixed
- Capture card (DPY-0) was silently dropped because it doesn't support 1440p — added `ViewPortIn=2560x1440, ViewPortOut=1920x1080+0+0` auto-scaling
- `apply-layout.sh` grep pattern changed from `connected.*enabled` to `connected` (detected connected-but-not-yet-enabled capture cards)
- Setup wizard now detects resolution mismatch between source and capture card and generates ViewPort scaling automatically

## [2025-02-23] - Mixed Refresh Rate & Browser Tweaks

### Added
- Browser performance tweaks subsystem (`browser-tweaks/`)
- `user.js` with NVIDIA hardware acceleration, NVDEC decode, mixed refresh rate settings
- `install-browser-tweaks.sh` auto-detection for Floorp/Firefox (Flatpak and native)
- Launcher scripts with NVIDIA environment variables
- Refresh rate auto-detection improvements in setup wizard

## [2025-02-22] - Hotplug & Services

### Added
- Display monitor service (polling-based hotplug detection)
- `install-hotplug.sh` with choice between polling monitor and udev rules
- `remove-hotplug.sh` for clean uninstallation
- `display-status.sh` interactive status and action menu
- systemd user services for auto-start at login

### Fixed
- HDMI detection reliability
- Display monitor startup timing
- Handshake timer for slow-connecting displays

## [2025-02-21] - Initial Release

### Added
- Interactive setup wizard (`setup-wizard.sh`)
- NVIDIA MetaMode-based display layout generation
- ForceFullCompositionPipeline support for mixed refresh rate fix
- HDMI capture card mirroring with auto-detection
- `nvidia-display-setup.sh` quick-apply tool
- Template layout scripts in `.screenlayout/`
- systemd service templates
- udev rules for hotplug (alternative method)
