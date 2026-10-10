#!/usr/bin/env bash
# Software rendering for headless screenshots (lavapipe Vulkan + xvfb). Owner: LEAD. (QC-2)
# Usage afterwards: xvfb-run -a -s "-screen 0 1920x1080x24" godot --path game --resolution 1920x1080 <scene>
set -euo pipefail
if command -v xvfb-run >/dev/null && ls /usr/share/vulkan/icd.d/lvp_icd*.json >/dev/null 2>&1; then exit 0; fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq mesa-vulkan-drivers xvfb >/dev/null
echo "render deps installed"
