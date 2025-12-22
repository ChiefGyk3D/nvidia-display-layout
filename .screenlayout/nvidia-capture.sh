#!/bin/bash
# NVIDIA MetaMode with HDMI capture enabled (mirrors center display)

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 1920x1080 +0+580, \
DPY-5: 1920x1080 +1920+580, \
DPY-1: 1920x1080 +3840+0 {Rotation=Right}, \
DPY-0: 1920x1080 +1920+580"
