#!/bin/bash
# NVIDIA MetaMode with HDMI capture enabled (mirrors center display)
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups
# Note: Capture card (DPY-0) does NOT need composition pipeline

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 1920x1080 +0+580 {ForceFullCompositionPipeline=On}, \
DPY-5: 1920x1080 +1920+580 {ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080 +3840+0 {Rotation=Right, ForceFullCompositionPipeline=On}, \
DPY-0: 1920x1080 +1920+580"
