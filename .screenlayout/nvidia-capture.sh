#!/bin/bash
# NVIDIA MetaMode with HDMI capture enabled (mirrors center display at 1440p)
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups
# Note: Capture card (DPY-0) does NOT need composition pipeline
# Elgato 4K Pro supports 1440p natively — no ViewPort scaling needed

# ── Capture card refresh rate ────────────────────────────────────────
# Elgato 4K Pro supported rates at 1440p: 240, 144, 120, 100
# (60Hz is NOT available at 1440p — only at 4K and 1080p)
# Change this value to switch capture refresh rate
CAPTURE_REFRESH="${CAPTURE_REFRESH:-100}"
# ─────────────────────────────────────────────────────────────────────

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 2560x1440_180 +0+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-5: 2560x1440_180 +2560+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080_75 +5120+0 {Rotation=Right, ForceFullCompositionPipeline=On}, \
DPY-0: 2560x1440_${CAPTURE_REFRESH} +2560+240"
