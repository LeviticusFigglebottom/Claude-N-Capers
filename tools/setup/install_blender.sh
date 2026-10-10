#!/usr/bin/env bash
# Idempotently install pinned Blender LTS to /opt/blender (ENV B/C need it). Owner: LEAD.
set -euo pipefail
VER=4.5.14
DEST=/opt/blender
if [[ -x "$DEST/blender" ]] && "$DEST/blender" --version 2>/dev/null | grep -q "Blender ${VER}"; then exit 0; fi
TMP="$(mktemp -d)"
curl -sSL -o "$TMP/b.tar.xz" "https://download.blender.org/release/Blender4.5/blender-${VER}-linux-x64.tar.xz"
mkdir -p "$DEST"; tar -xJf "$TMP/b.tar.xz" -C "$DEST" --strip-components=1
ln -sf "$DEST/blender" /usr/local/bin/blender 2>/dev/null || true
rm -rf "$TMP"
"$DEST/blender" --version | head -1
