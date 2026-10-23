#!/usr/bin/env python3
"""CAPERWORKS audio build: renders every procedural SFX cue and music stem, normalises loudness,
encodes OGG Vorbis deterministically, and writes the Godot cue registry + music track resources.

usage: python3 tools/audiogen/build.py [--only <name|cue.id|group|music>] [--check-determinism] [--jobs N]
                                       [--no-report]
"""
from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
import tempfile
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import analysis  # noqa: E402
import cues  # noqa: E402
import cues_afterhours  # noqa: E402
import cues_ambience  # noqa: E402
import cues_decks  # noqa: E402
import cues_impact  # noqa: E402
import cues_ostrander  # noqa: E402
import cues_rolling_thunder  # noqa: E402
import cues_safehouse  # noqa: E402
import cues_sentry  # noqa: E402
import music_afterhours  # noqa: E402
import music_dockside_burn  # noqa: E402
import music_gallery_night  # noqa: E402
import music_glasshouse  # noqa: E402
import music_last_call  # noqa: E402
import music_long_con  # noqa: E402
import music_night_deposit  # noqa: E402
import music_ostrander_federal  # noqa: E402
import music_rolling_thunder  # noqa: E402
import music_shadow_ledger  # noqa: E402
import music_vault_hymn  # noqa: E402
import registry  # noqa: E402
from synth import loudness, wavio  # noqa: E402
from synth.core import seed_for  # noqa: E402

REPO = HERE.parent.parent
SFX_DIR = Path("game/assets/audio/sfx")
CUE_TRES = Path("game/world/audio/cues.tres")
# every heist music track (D-117): one module per track, all on the music_engine.py parts
TRACKS = {m.TRACK: m for m in (music_glasshouse, music_night_deposit, music_shadow_ledger, music_dockside_burn,
                               music_gallery_night, music_ostrander_federal, music_rolling_thunder,
                               music_vault_hymn, music_long_con, music_last_call, music_afterhours)}


def mus_dir(track: str) -> Path:
    return Path("game/assets/audio/music") / track


def track_tres(track: str) -> Path:
    return Path("game/world/audio/music") / track / f"{track}.tres"


def track_parts(track: str) -> list[str]:
    """Rendered parts of a track: its loop stems then its one-shot stingers."""
    m = TRACKS[track]
    return list(m.STEMS) + list(m.STINGERS)


def stem_aliases(track: str) -> dict[str, str]:
    """MusicTrack stem name -> rendered part. Aliases let a stealth-only track answer every phase."""
    m = TRACKS[track]
    return dict(getattr(m, "STEM_ALIASES", {p: p for p in m.STEMS}))
REPORT_DIR = Path("docs/levels/_audio")
# every SFX cue: the main table plus the grouped tables (impact_fx.md: cue.impact_<surface>; D-117 heist beds)
ALL_CUES: list[cues.CueSpec] = (cues.CUES + cues_impact.CUES + cues_ambience.CUES + cues_ostrander.CUES
                                + cues_rolling_thunder.CUES + cues_safehouse.CUES + cues_sentry.CUES
                                + cues_decks.CUES + cues_afterhours.CUES)

# Loudness classes (style guide §9). ceiling = true-peak dBTP.
TARGETS = {
    # one-shot transients may be peak-limited by up to 12 dB (sub-millisecond click/crack peaks)
    "sfx": {"lufs": -18.0, "mode": "short", "ceiling": -1.0, "limit": 12.0, "quality": wavio.OGG_QUALITY["sfx"]},
    "bed": {"lufs": -18.0, "mode": "integrated", "ceiling": -1.0, "limit": 6.0, "quality": wavio.OGG_QUALITY["sfx"]},
    "voice": {"lufs": -20.0, "mode": "short", "ceiling": -1.0, "limit": 6.0, "quality": wavio.OGG_QUALITY["sfx"]},
    "music": {"lufs": -16.0, "mode": "integrated", "ceiling": -1.0, "limit": 6.0,
              "quality": wavio.OGG_QUALITY["music"]},
}


def sfx_files(spec: cues.CueSpec) -> list[str]:
    if spec.variations == 1:
        return [f"sfx_{spec.name}.ogg"]
    return [f"sfx_{spec.name}_{i + 1}.ogg" for i in range(spec.variations)]


def variant_seed_key(spec: cues.CueSpec, v: int) -> str:
    return f"{spec.cue_id}#{v}"


def normalise(x: np.ndarray, norm: str, loop: bool) -> np.ndarray:
    t = TARGETS[norm]
    if not loop:
        return loudness.normalize(x, t["lufs"], t["mode"], t["ceiling"], t["limit"])
    # loops: limit on a circularly padded copy so the limiter has no start/end state seam
    pad = min(x.shape[0] // 4, 24000)
    ext = np.concatenate([x[-pad:], x, x[:pad]])
    return loudness.normalize(ext, t["lufs"], t["mode"], t["ceiling"], t["limit"])[pad:pad + x.shape[0]]


def _encode(x: np.ndarray, out_ogg: Path, quality: int, serial_key: str) -> None:
    out_ogg.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="audiogen_") as td:
        wav = Path(td) / "render.wav"
        wavio.write_wav24(wav, np.clip(x, -1.0, 1.0))
        wavio.export_ogg(wav, out_ogg, quality, seed_for(serial_key))


def job_sfx(root: str, name: str, v: int) -> str:
    spec = next(c for c in ALL_CUES if c.name == name)
    from synth.core import rng_for
    x = spec.fn(rng_for(spec.cue_id, str(v)), v)
    x = normalise(x, spec.norm, spec.loop)
    rel = SFX_DIR / spec.folder / sfx_files(spec)[v]
    _encode(x, Path(root) / rel, TARGETS[spec.norm]["quality"], variant_seed_key(spec, v))
    return str(rel)


def job_music(root: str, track: str, part: str) -> str:
    mus = TRACKS[track]
    fn = mus.STEMS.get(part) or mus.STINGERS[part]
    x = normalise(fn(), "music", part in mus.STEMS)
    rel = mus_dir(track) / f"mus_{track}_{part}.ogg"
    _encode(x, Path(root) / rel, TARGETS["music"]["quality"], f"mus_{track}_{part}")
    return str(rel)


def write_sources(root: Path) -> None:
    for spec in ALL_CUES:
        d = root / SFX_DIR / spec.folder
        d.mkdir(parents=True, exist_ok=True)
        t = TARGETS[spec.norm]
        lines = [
            "Generated by tools/audiogen/build.py: CAPERWORKS procedural synthesis (numpy/scipy).",
            "No samples, no recordings, no third-party audio.",
            f"cue id: {spec.cue_id}",
            f"recipe: tools/audiogen/{spec.fn.__module__}.py::{spec.fn.__name__}",
            f"command: python3 tools/audiogen/build.py --only {spec.name}",
            f"loudness: {t['lufs']} LUFS ({t['mode']}), true peak <= {t['ceiling']} dBTP",
            f"encode: ffmpeg libvorbis -q:a {t['quality']} 48 kHz, -fflags +bitexact -flags +bitexact "
            "-map_metadata -1, -serial_offset = seed & 0x7fffffff",
            f"loop: {str(spec.loop).lower()}",
            "files:",
        ]
        for v, f in enumerate(sfx_files(spec)):
            key = variant_seed_key(spec, v)
            lines.append(f"  {f}  seed=zlib.crc32('{key}')={seed_for(key)}")
        (d / "SOURCE.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    for track, mus in TRACKS.items():
        d = root / mus_dir(track)
        d.mkdir(parents=True, exist_ok=True)
        lines = [
            "Generated by tools/audiogen/build.py: CAPERWORKS procedural music (numpy/scipy sequencer + synths).",
            "No samples, no recordings, no third-party audio.",
            f"recipe: tools/audiogen/music_{track}.py ({mus.BPM:g} BPM, {mus.BEATS_PER_BAR}/4, {mus.KEY})",
            "command: python3 tools/audiogen/build.py --only music" if track == "glasshouse"
            else f"command: python3 tools/audiogen/build.py --only mus_{track}",
            "loudness: -16 LUFS integrated, true peak <= -1 dBTP; stems are seamless bar-aligned loops",
            f"encode: ffmpeg libvorbis -q:a {TARGETS['music']['quality']} 48 kHz stereo, bitexact, no metadata",
            "files:",
        ]
        for part in track_parts(track):
            key = f"mus_{track}_{part}"
            bars = f"{mus.BARS[part]} bars loop" if part in mus.BARS else "one-shot stinger"
            lines.append(f"  {key}.ogg  {bars}  seed=zlib.crc32('{key}')={seed_for(key)}")
        aliases = {k: v for k, v in stem_aliases(track).items() if k != v}
        if aliases:
            lines.append("stem aliases (MusicTrack stem -> file part): "
                         + ", ".join(f"{k} -> {v}" for k, v in aliases.items()))
        (d / "SOURCE.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_resources(root: Path) -> None:
    entries = []
    for spec in ALL_CUES:
        entries.append({
            "id": spec.cue_id,
            "streams": [f"res://assets/audio/sfx/{spec.folder}/{f}" for f in sfx_files(spec)],
            "volume_db": spec.volume_db, "bus": spec.bus, "positional": spec.positional,
            "max_distance": spec.max_distance, "pitch_jitter": spec.pitch_jitter,
            "cooldown_s": spec.cooldown_s, "loop": spec.loop,
        })
    registry.write_cue_registry(root / CUE_TRES, entries)
    for track, mus in TRACKS.items():
        res = f"res://assets/audio/music/{track}"
        registry.write_music_track(
            root / track_tres(track), track, mus.BPM, mus.BEATS_PER_BAR,
            {s: f"{res}/mus_{track}_{p}.ogg" for s, p in stem_aliases(track).items()},
            {p: f"{res}/mus_{track}_{p}.ogg" for p in mus.STINGERS},
            mus.STEM_GAIN_DB, {s: mus.BARS[p] for s, p in stem_aliases(track).items()})


def select(only: str | None) -> tuple[list[tuple[str, int]], list[tuple[str, str]]]:
    sfx = [(c.name, v) for c in ALL_CUES for v in range(c.variations)]
    music = [(t, p) for t in TRACKS for p in track_parts(t)]
    if only is None:
        return sfx, music
    key = only.removeprefix("cue.")
    if key == "music":
        return [], music
    if key.removeprefix("mus_") in TRACKS:  # one whole track: mus_<track>
        return [], [(t, p) for t, p in music if t == key.removeprefix("mus_")]
    hit = [(t, p) for t, p in music if key == f"mus_{t}_{p}"]
    if hit:
        return [], hit
    hits = [(n, v) for n, v in sfx if n == key]
    if not hits:  # a group folder, e.g. --only impact
        group = {c.name for c in ALL_CUES if c.subdir == key}
        hits = [(n, v) for n, v in sfx if n in group]
    if not hits:
        raise SystemExit(f"unknown --only target {only!r}")
    return hits, []


def build(root: Path, only: str | None, jobs: int) -> list[str]:
    sfx, music = select(only)
    with ProcessPoolExecutor(max_workers=jobs) as ex:
        futs = [ex.submit(job_music, str(root), t, p) for t, p in music]  # long jobs first
        futs += [ex.submit(job_sfx, str(root), n, v) for n, v in sfx]
        outs = [f.result() for f in futs]
    write_sources(root)
    write_resources(root)
    return sorted(outs)


def all_outputs(root: Path) -> dict[str, str]:
    files = {}
    for base in [root / "game/assets/audio", root / "game/world/audio/cues.tres"] + [root / track_tres(t) for t in TRACKS]:
        paths = [base] if base.is_file() else sorted(p for p in base.rglob("*") if p.is_file() and p.suffix != ".import")
        for p in paths:
            files[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return files


def report(root: Path) -> None:
    rows = []
    sheet_items = []
    music_items = []
    for spec in ALL_CUES:
        for v, f in enumerate(sfx_files(spec)):
            x = wavio.decode(root / SFX_DIR / spec.folder / f)
            m = analysis.metrics(x)
            rows.append((f"{spec.cue_id}[{v + 1}]" if spec.variations > 1 else spec.cue_id, spec, m))
            if v == 0 or spec.name == "glass_break":
                sheet_items.append((f.removesuffix(".ogg"), x, m))
    music_loops: set[str] = set()
    for track, mus in TRACKS.items():
        for part in track_parts(track):
            x = wavio.decode(root / mus_dir(track) / f"mus_{track}_{part}.ogg")
            m = analysis.metrics(x)
            rows.append((f"mus_{track}_{part}", None, m))
            music_items.append((f"mus_{track}_{part}", x, m))
            if part in mus.STEMS:
                music_loops.add(f"mus_{track}_{part}")
    out = REPO / REPORT_DIR
    analysis.contact_sheet(sheet_items, out / "cue_spectrograms.png", cols=5, max_s=3.0,
                           title="CAPERWORKS P1 cues (decoded OGG, up to 3 s each)")
    analysis.contact_sheet(music_items, out / "music_spectrograms.png", cols=4, tile_w=420, max_s=None,
                           title="CAPERWORKS heist music stems (decoded OGG, full length)")
    hdr = "id\tbus\tloop\tduration_s\tch\tlufs_short_max\tlufs_integrated\ttrue_peak_dbtp\tcentroid_hz"
    lines = [hdr]
    for rid, spec, m in rows:
        lines.append("\t".join(str(v) for v in (
            rid, spec.bus if spec else "Music", (spec.loop if spec else rid in music_loops),
            m["duration_s"], m["channels"], m["lufs_short_max"], m["lufs_integrated"], m["true_peak_dbtp"],
            int(m["centroid_hz"]))))
    (out / "cue_metrics.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="cue name (glass_break), cue id (cue.glass_break), group folder (impact), mus_<track>_<part>, mus_<track> or 'music'")
    ap.add_argument("--check-determinism", action="store_true",
                    help="build, then rebuild into a temp tree and require byte-identical outputs")
    ap.add_argument("--jobs", type=int, default=4)
    ap.add_argument("--no-report", action="store_true", help="skip metrics + spectrogram sheets")
    a = ap.parse_args()
    outs = build(REPO, a.only, a.jobs)
    print(f"built {len(outs)} audio files + registry/track resources")
    if not a.no_report and a.only is None:
        report(REPO)
    total = sum(p.stat().st_size for p in (REPO / "game/assets/audio").rglob("*.ogg"))
    print(f"total audio size: {total / 1e6:.2f} MB")
    if a.check_determinism:
        with tempfile.TemporaryDirectory(prefix="audiogen_det_") as td:
            build(Path(td), a.only, a.jobs)
            first = all_outputs(REPO)
            second = all_outputs(Path(td))
            keys = sorted(second)
            bad = [k for k in keys if first.get(k) != second[k]]
            for k in keys:
                print(f"{'OK  ' if k not in bad else 'DIFF'} {second[k][:16]} {k}")
            print(f"determinism: {len(keys) - len(bad)}/{len(keys)} byte-identical")
            shutil.rmtree(td, ignore_errors=True)
            if bad:
                return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
