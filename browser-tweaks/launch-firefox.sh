#!/bin/bash
# Firefox launcher with NVIDIA optimizations
# Same env vars as launch-floorp.sh — they share the same engine
# Works with: https://github.com/ChiefGyk3D/nvidia-capture-card
# Run this instead of the regular Firefox launcher for best performance

# === NVIDIA + X11 Environment Variables ===
# Force EGL backend (better than GLX for modern NVIDIA)
export MOZ_X11_EGL=1

# Enable hardware video acceleration via VA-API/NVDEC
export MOZ_DISABLE_RDD_SANDBOX=1
export LIBVA_DRIVER_NAME=nvidia

# Enable WebRender compositor
export MOZ_WEBRENDER=1

# === MIXED REFRESH RATE MULTI-MONITOR ===
# Allow independent flipping per monitor - CRITICAL for mixed refresh rates
export __GL_SYNC_TO_VBLANK=0
export __GL_AllowFlipDelayedAfterMoveResize=0

# Use NVIDIA's "Allow Flipping" for better multi-monitor sync
export __GL_YIELD="USLEEP"

# Reduce input latency
export MOZ_USE_XINPUT2=1

# Ensure display layout is applied (uses your nvidia-display-layout scripts)
if [ -x "$HOME/.screenlayout/apply-layout.sh" ]; then
    "$HOME/.screenlayout/apply-layout.sh" &>/dev/null &
fi

# Launch Firefox (Flatpak version)
flatpak run org.mozilla.firefox "$@"
