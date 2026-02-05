#!/bin/bash
# NVIDIA MetaMode base layout (no capture card)
# Left:   DPY-3 (144Hz)
# Center: DPY-5 (144Hz)
# Right:  DPY-1 (75Hz portrait)
#
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 1920x1080 +0+580 {ForceFullCompositionPipeline=On}, \
DPY-5: 1920x1080 +1920+580 {ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080 +3840+0 {Rotation=Right, ForceFullCompositionPipeline=On}"
