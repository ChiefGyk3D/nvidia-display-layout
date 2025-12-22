#!/bin/bash
# Apply correct NVIDIA MetaMode depending on HDMI capture presence

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

if nvidia-settings -q dpys | grep -q "HDMI-0) (connected, enabled)"; then
    ~/.screenlayout/nvidia-capture.sh
else
    ~/.screenlayout/nvidia-base.sh
fi
