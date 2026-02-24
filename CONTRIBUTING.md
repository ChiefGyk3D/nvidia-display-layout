# Contributing to NVIDIA X11 Multi-Monitor Toolkit

Thanks for your interest in contributing! This project aims to make NVIDIA multi-monitor setups on Linux painless. Contributions of all kinds are welcome.

## Ways to Contribute

### Report Hardware Compatibility

The most valuable contribution is testing on hardware we haven't tried yet. If you set up the toolkit on your system, please open an issue or PR with:

- **GPU model** and driver version (`nvidia-smi`)
- **Monitor model(s)**, resolution(s), and refresh rate(s)
- **Capture card** (if applicable) and supported resolutions
- **Linux distribution** and version
- What worked, what didn't, and any workarounds you found

### Bug Reports

When filing a bug, include:

```bash
# Run these and paste the output:
nvidia-smi --query-gpu=name,driver_version --format=csv,noheader
nvidia-settings -q CurrentMetaMode
cat ~/.screenlayout/.layout-config
systemctl --user status apply-display-layout.service
systemctl --user status nvidia-display-monitor.service
echo $XDG_SESSION_TYPE   # should be x11
```

For browser-related issues, also include:

- Browser name and version (e.g., Floorp 147.0.3 Flatpak)
- Output of `vainfo`
- Screenshot of `about:support` → Graphics section
- `nvidia-smi pmon -c 5` output during video playback (shows if GPU decode is active)

### Code Contributions

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make your changes
4. Test on your setup
5. Submit a pull request

## Code Style

- **Shell scripts:** Bash 4.0+, use `set -e`, quote variables (`"$var"`), use `[[ ]]` for conditionals
- **Comments:** Explain *why*, not just *what* — especially for NVIDIA-specific workarounds
- **User-facing output:** Use the color variables (`$GREEN`, `$RED`, `$YELLOW`, `$CYAN`, `$NC`) for consistency
- **Error handling:** Always check if files/commands exist before using them

## Project Structure

| Directory | Purpose |
|-----------|---------|
| Root scripts | User-facing tools (wizard, status, hotplug) |
| `browser-tweaks/` | Browser performance optimization |
| `.screenlayout/` | Template layout scripts (installed to `~/.screenlayout/`) |
| `.config/systemd/user/` | Template systemd services |
| `udev/` | udev rules (alternative to polling monitor) |

## Testing

Before submitting changes:

1. **Run the wizard** on your setup and verify it generates correct scripts
2. **Test hotplug** — unplug and replug a monitor, verify auto-detection
3. **Test browser tweaks** — verify `install-browser-tweaks.sh` finds the correct profile
4. **Test uninstall** — verify `remove-hotplug.sh` cleanly removes everything

There's no automated test suite (yet). Manual testing on real hardware is the primary validation.

## Commit Messages

Use clear, descriptive commit messages:

```
Good: Fix capture card detection when HDMI-0 is connected but not enabled
Good: Add ViewPortIn/ViewPortOut scaling for 1440p-to-1080p capture cards
Bad:  fix stuff
Bad:  update
```

## Questions?

Open an issue on GitHub. There's no mailing list or chat — issues are the primary communication channel.
