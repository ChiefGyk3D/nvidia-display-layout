#!/bin/bash
# NVIDIA MetaMode base layout (no capture card)
# Left:   DPY-3 (180Hz 1440p)
# Center: DPY-5 (180Hz 1440p)
# Right:  DPY-1 (75Hz portrait 1080p)
#
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 2560x1440_180 +0+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-5: 2560x1440_180 +2560+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080_75 +5120+0 {Rotation=Right, ForceFullCompositionPipeline=On}"
