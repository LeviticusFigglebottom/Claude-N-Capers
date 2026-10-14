"""Impact-cue mix check (impact_fx §4): effective loudness of every registry cue = momentary-max LUFS of its
samples (averaged over variants, decoded with ffmpeg) + its volume_db, listed by bus, with per-family medians.
Usage, from the clone root: python3 tools/audiogen/ui/mix_check.py .  (numpy + ffmpeg). Owner: ENV B."""
import re, subprocess, sys
from pathlib import Path
import numpy as np
root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools/audiogen"))
from synth import loudness
from synth.core import SR

txt = (root / "game/world/audio/cues.tres").read_text()
ext = dict(re.findall(r'\[ext_resource type="AudioStream" path="res://([^"]+)" id="([^"]+)"\]', txt) and
           [(i, p) for p, i in re.findall(r'\[ext_resource type="AudioStream" path="res://([^"]+)" id="([^"]+)"\]', txt)])
rows = []
for block in re.split(r'\n\[sub_resource', txt)[1:]:
    m = re.search(r'id = &"([^"]+)"', block)
    if not m:
        continue
    cid = m.group(1)
    vol = float(re.search(r'volume_db = ([-\d.]+)', block).group(1)) if 'volume_db' in block else 0.0
    bus = re.search(r'bus = &"([^"]+)"', block).group(1) if 'bus =' in block else "Master"
    ids = re.findall(r'ExtResource\("([^"]+)"\)', block.split("streams =")[1].split("\n")[0]) if "streams =" in block else []
    vals = []
    for i in ids:
        f = root / "game" / ext[i]
        pcm = subprocess.run(["ffmpeg", "-v", "quiet", "-i", str(f), "-f", "f32le", "-ac", "1", "-ar", str(SR), "-"],
                             capture_output=True).stdout
        x = np.frombuffer(pcm, dtype=np.float32).astype(np.float64)
        if x.size:
            vals.append(loudness.momentary_max(x))
    if vals:
        rows.append((cid, bus, vol, float(np.mean(vals)), float(np.mean(vals)) + vol))

def fam(c):
    if c.startswith("cue.impact_"): return "impact"
    if c in ("cue.hud_hit", "cue.hud_headshot", "cue.hud_kill"): return "hit marker"
    return None

print("%-34s %-8s %6s %8s %8s" % ("cue", "bus", "vol", "LUFS_m", "eff"))
for r in sorted(rows, key=lambda r: (r[1], -r[4])):
    print("%-34s %-8s %6.1f %8.1f %8.1f" % r)
print()
by = {}
for c, b, v, l, e in rows:
    by.setdefault(fam(c) or b, []).append(e)
for k, v in sorted(by.items()):
    print("%-12s n=%3d  eff median %6.1f  min %6.1f  max %6.1f" % (k, len(v), np.median(v), min(v), max(v)))
