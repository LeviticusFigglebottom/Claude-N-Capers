#!/usr/bin/env bash
# SessionStart hook for cloud sessions. Owner: LEAD. Installs pinned tools; never fails the session.
cd "$(dirname "$0")/../.." || exit 0
bash tools/setup/install_godot.sh >/tmp/install_godot.log 2>&1 || echo "godot install failed, see /tmp/install_godot.log"
pip install -q -r tools/requirements.txt >/tmp/pip.log 2>&1 || echo "pip install failed, see /tmp/pip.log"
BR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
bash tools/setup/install_render_deps.sh >/tmp/install_render.log 2>&1 || echo "render deps install failed, see /tmp/install_render.log"
if [[ "$BR" == env/b-* || "$BR" == env/c-* || "$BR" == env/d-* || "${CAPER_NEEDS_BLENDER:-0}" == 1 ]]; then
  bash tools/setup/install_blender.sh >/tmp/install_blender.log 2>&1 || echo "blender install failed, see /tmp/install_blender.log"
fi
(cd game && /opt/godot/godot --headless --import >/dev/null 2>&1) || true
echo "CAPERWORKS env ready on branch $BR"
exit 0
