#!/bin/bash
# NVIDIA MetaMode with HDMI capture enabled (mirrors center display at 1440p)
# ForceFullCompositionPipeline=On fixes stuttering on mixed refresh rate setups
# Note: Capture card (DPY-0) does NOT need composition pipeline
# Elgato 4K Pro supports 1440p natively — no ViewPort scaling needed

export DISPLAY=:1
export XAUTHORITY="$HOME/.Xauthority"

nvidia-settings --assign "CurrentMetaMode=\
DPY-3: 2560x1440_180 +0+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-5: 2560x1440_180 +2560+240 {AllowGSYNCCompatible=On, ForceFullCompositionPipeline=On}, \
DPY-1: 1920x1080_75 +5120+0 {Rotation=Right, ForceFullCompositionPipeline=On}, \
DPY-0: 2560x1440 +2560+240"
