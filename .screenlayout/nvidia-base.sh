#!/bin/bash
# NVIDIA MetaMode base layout (no capture card)
# Left:   DPY-3
# Center: DPY-5
# Right:  DPY-1 (portrait)

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 1920x1080 +0+580, \
DPY-5: 1920x1080 +1920+580, \
DPY-1: 1920x1080 +3840+0 {Rotation=Right}"
