#!/usr/bin/env bash
# Idempotently install the pinned Godot to /opt/godot/godot (+ symlink /usr/local/bin/godot). Owner: LEAD.
set -euo pipefail
VER="$(cat "$(dirname "$0")/godot_version.txt")"
DEST=/opt/godot
if [[ -x "$DEST/godot" ]] && "$DEST/godot" --headless --version 2>/dev/null | grep -q "${VER%-stable}.stable"; then
  exit 0
fi
mkdir -p "$DEST"; TMP="$(mktemp -d)"
curl -sSL -o "$TMP/g.zip" "https://github.com/godotengine/godot/releases/download/${VER}/Godot_v${VER}_linux.x86_64.zip"
unzip -q -o "$TMP/g.zip" -d "$TMP"
mv "$TMP/Godot_v${VER}_linux.x86_64" "$DEST/godot"; chmod +x "$DEST/godot"
ln -sf "$DEST/godot" /usr/local/bin/godot 2>/dev/null || true
rm -rf "$TMP"
"$DEST/godot" --headless --version
