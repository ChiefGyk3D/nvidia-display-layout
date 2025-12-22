# NVIDIA X11 Persistent Multi-Monitor Layout (with HDMI Capture)

A deterministic, NVIDIA-native display layout solution for X11 that avoids xrandr, GNOME display settings, and hotplug race conditions.

## Features

- ✅ Persistent layout across reboot
- ✅ Portrait monitor support (no squish)
- ✅ HDMI capture card mirrors center display
- ✅ No display reordering
- ✅ Manual toggle + auto-apply on login
- ✅ Uses only NVIDIA MetaModes

## Requirements

- NVIDIA proprietary driver
- X11 (not Wayland)
- `nvidia-settings`

## Directory Structure

```
$HOME/
├── .screenlayout/
│   ├── apply-layout.sh      # Smart selector script
│   ├── nvidia-base.sh       # Base layout (no capture)
│   └── nvidia-capture.sh    # Layout with HDMI capture
│
└── .config/systemd/user/
    └── apply-display-layout.service
```

## Installation

### 1. Copy the screenlayout scripts

```bash
mkdir -p ~/.screenlayout
cp .screenlayout/* ~/.screenlayout/
chmod +x ~/.screenlayout/*.sh
```

### 2. Copy the systemd service

```bash
mkdir -p ~/.config/systemd/user
cp .config/systemd/user/apply-display-layout.service ~/.config/systemd/user/
```

### 3. Enable the service

```bash
systemctl --user daemon-reload
systemctl --user enable apply-display-layout.service
```

### 4. Set up a keyboard shortcut

Bind this command in **Pop!_OS → Keyboard → Custom Shortcuts**:

```
/home/YOUR_USERNAME/.screenlayout/apply-layout.sh
```

**Recommended keys:**
- `Super + F12`
- `Ctrl + Alt + D`

## Scripts

### 🟢 nvidia-base.sh

Apply the base layout when HDMI capture is **NOT** in use.

| Position | Display | Resolution | Notes |
|----------|---------|------------|-------|
| Left | DPY-3 | 1920x1080 | Landscape |
| Center | DPY-5 | 1920x1080 | Landscape |
| Right | DPY-1 | 1920x1080 | Portrait (rotated right) |

### 🔵 nvidia-capture.sh

Enable HDMI capture (DPY-0) mirroring the center monitor without disturbing anything else.

| Position | Display | Resolution | Notes |
|----------|---------|------------|-------|
| Left | DPY-3 | 1920x1080 | Landscape |
| Center | DPY-5 | 1920x1080 | Landscape |
| Right | DPY-1 | 1920x1080 | Portrait (rotated right) |
| Mirror | DPY-0 | 1920x1080 | HDMI capture (mirrors center) |

### 🟣 apply-layout.sh

Smart selector that detects whether HDMI capture is connected and applies the correct MetaMode automatically.

## Usage

1. Plug/unplug HDMI capture card
2. Press your hotkey to apply the correct layout

The layout is also automatically applied on login via the systemd service.

## Verification

Check the current MetaMode:

```bash
nvidia-settings -q CurrentMetaMode
```

✔ Must **NOT** say `source=RandR`

Check display connections:

```bash
nvidia-settings -q dpys
```

✔ HDMI shows `connected` when plugged  
✔ DPY mappings remain stable

## Core Design Philosophy

| Principle | Description |
|-----------|-------------|
| **No xrandr** | NVIDIA MetaModes only |
| **No GNOME Displays** | Avoids config conflicts |
| **No udev hotplug** | No race conditions |
| **No timers** | Deterministic execution |
| **Only NVIDIA MetaModes** | Native driver control |
| **Deterministic** | Same result every time |
| **Manual toggle + auto-apply** | User-controlled with login automation |

## What is Intentionally NOT Included

| Excluded | Reason |
|----------|--------|
| ❌ xrandr | Conflicts with NVIDIA MetaModes |
| ❌ GNOME Displays | Creates inconsistent state |
| ❌ NVIDIA "Save X Config" | Overwrites with RandR settings |
| ❌ udev rules | Race conditions with display init |
| ❌ systemd timers | Unnecessary polling |
| ❌ Auto-hotplug hacks | Unreliable detection |
| ❌ ViewPortIn / ViewPortOut | Not needed for this layout |
| ❌ Panning | Causes display artifacts |

## Customization

To adapt for your setup:

1. Run `nvidia-settings -q dpys` to identify your display names (DPY-0, DPY-1, etc.)
2. Update the MetaMode strings in `nvidia-base.sh` and `nvidia-capture.sh`
3. Adjust position offsets (`+X+Y`) to match your physical layout
4. Update the HDMI detection string in `apply-layout.sh` if needed

## Troubleshooting

### Layout resets after sleep/wake

Re-run the apply script:

```bash
~/.screenlayout/apply-layout.sh
```

### MetaMode shows source=RandR

Something is overwriting NVIDIA settings. Check for:
- GNOME display configuration
- Other display management tools
- Conflicting autostart scripts

### Wrong display detected as HDMI

Update the grep pattern in `apply-layout.sh` to match your capture card's identifier.

## License

MIT
