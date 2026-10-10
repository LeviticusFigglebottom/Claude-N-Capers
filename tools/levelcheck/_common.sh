# Shared helpers for tools/levelcheck/*.sh (sourced). Owner: ENV C.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo /opt/godot/godot)}"
HEISTS_DIR="$ROOT/game/world/heists"

# Heist ids with game/world/heists/<id>/<id>.tscn (or the ids given as arguments).
lc_heists() {
	if [[ $# -gt 0 ]]; then printf '%s\n' "$@"; return; fi
	local d id
	for d in "$HEISTS_DIR"/*/; do
		[[ -d "$d" ]] || continue
		id="$(basename "$d")"
		[[ -f "$d/$id.tscn" ]] && echo "$id"
	done
	return 0
}

# Stage of a heist: game/world/heists/<id>/stage.txt (greybox|final), else a "Stage: final" line in
# docs/design/heists/<id>.md, else greybox.
lc_stage() {
	local id="$1" s=""
	if [[ -f "$HEISTS_DIR/$id/stage.txt" ]]; then
		s="$(tr -d '[:space:]' < "$HEISTS_DIR/$id/stage.txt")"
	elif [[ -f "$ROOT/docs/design/heists/$id.md" ]] && grep -qiE '^Stage:[[:space:]]*final' "$ROOT/docs/design/heists/$id.md"; then
		s="final"
	fi
	case "$s" in final) echo final ;; *) echo greybox ;; esac
}

lc_import() {
	"$GODOT" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
}

# Prints a Godot log file without engine noise, then deletes it.
lc_show() {
	grep -vE "^(ALSA|WARNING:|ERROR: Condition \"status < 0\"|[[:space:]]+at: |This mismatch|The cell (size|height)|This warning)" "$1" \
		| grep -v "^[[:space:]]*$" || true
	rm -f "$1"
}
