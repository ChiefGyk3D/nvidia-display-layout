#!/bin/bash
# Apply correct NVIDIA MetaMode depending on HDMI capture presence
# Optionally resets PipeWire combined audio sink when capture card is detected
# (requires pipewire_sink project: https://github.com/ChiefGyk3D/pipewire_sink)
# Part of: https://github.com/ChiefGyk3D/nvidia-display-layout

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

NVIDIA_AUDIO_CARD="alsa_card.pci-0000_08_00.1"
HDMI_PROFILE="output:hdmi-stereo"

# Optional: Path to reset-pipewire script (installed by pipewire_sink project)
# Set to empty string or "none" to disable audio integration
RESET_PIPEWIRE_BIN="${RESET_PIPEWIRE_BIN:-$HOME/.local/bin/reset-pipewire}"

# Check if HDMI-0 is connected (with or without enabled)
if nvidia-settings -q dpys | grep -q "HDMI-0) (connected"; then
    ~/.screenlayout/nvidia-capture.sh

    # Wait for HDMI audio handshake after MetaMode change
    sleep 2

    # Force NVIDIA HDMI audio profile active — fixes race condition where
    # PipeWire sees the sink as unavailable during HDMI re-handshake
    if command -v pactl &>/dev/null; then
        pactl set-card-profile "$NVIDIA_AUDIO_CARD" "$HDMI_PROFILE" 2>/dev/null
    fi

    # Reset PipeWire and create combined audio sink (speakers + HDMI capture)
    # This ensures audio routes to both the local output and capture card
    if [ -n "$RESET_PIPEWIRE_BIN" ] && [ "$RESET_PIPEWIRE_BIN" != "none" ] && [ -x "$RESET_PIPEWIRE_BIN" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Capture card detected, resetting PipeWire combined sink..."
        # Additional delay for HDMI audio device to fully register with PipeWire
        sleep 3
        "$RESET_PIPEWIRE_BIN" 2>&1 | while IFS= read -r line; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [pipewire] $line"
        done
    fi
else
    ~/.screenlayout/nvidia-base.sh
fi
