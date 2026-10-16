"""Writers for the Godot resources generated from the audio build (deterministic .tres text).

* game/world/audio/cues.tres                       AudioCueRegistry (Array[AudioCueDef])
* game/world/audio/music/<track>/<track>.tres      MusicTrack
"""
from __future__ import annotations

from pathlib import Path


def _f(x: float) -> str:
    s = repr(float(x))
    return s


def _b(x: bool) -> str:
    return "true" if x else "false"


def write_cue_registry(path: Path, entries: list[dict]) -> None:
    """entries: [{id, streams: [res paths], volume_db, bus, positional, max_distance, pitch_jitter,
    cooldown_s, loop}] in a stable order."""
    lines: list[str] = ['[gd_resource type="Resource" script_class="AudioCueRegistry" format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://world/audio/cue_registry.gd" id="1_reg"]')
    lines.append('[ext_resource type="Script" path="res://world/audio/audio_cue_def.gd" id="2_def"]')
    stream_ids: dict[str, str] = {}
    for e in entries:
        for sp in e["streams"]:
            sid = f"s{len(stream_ids) + 1}"
            stream_ids[sp] = sid
            lines.append(f'[ext_resource type="AudioStream" path="{sp}" id="{sid}"]')
    lines.append("")
    sub_ids: list[str] = []
    for i, e in enumerate(entries):
        sub = f"cue_{i + 1}"
        sub_ids.append(sub)
        streams = ", ".join(f'ExtResource("{stream_ids[sp]}")' for sp in e["streams"])
        lines += [
            f'[sub_resource type="Resource" id="{sub}"]',
            'script = ExtResource("2_def")',
            f'id = &"{e["id"]}"',
            f"streams = Array[AudioStream]([{streams}])",
            f'volume_db = {_f(e["volume_db"])}',
            f'bus = &"{e["bus"]}"',
            f'positional = {_b(e["positional"])}',
            f'max_distance = {_f(e["max_distance"])}',
            f'pitch_jitter = {_f(e["pitch_jitter"])}',
            f'cooldown_s = {_f(e["cooldown_s"])}',
            f'loop = {_b(e["loop"])}',
            "",
        ]
    subs = ", ".join(f'SubResource("{s}")' for s in sub_ids)
    lines += ["[resource]", 'script = ExtResource("1_reg")', f'cues = Array[ExtResource("2_def")]([{subs}])', ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def write_music_track(path: Path, track_id: str, bpm: float, beats_per_bar: int, stems: dict[str, str],
                      stingers: dict[str, str], gains: dict[str, float], bars: dict[str, int]) -> None:
    lines: list[str] = ['[gd_resource type="Resource" script_class="MusicTrack" format=3]', ""]
    lines.append('[ext_resource type="Script" path="res://world/audio/music_track.gd" id="1_trk"]')
    # one ext_resource per file: aliased stems (a stealth-only track reusing a part) share the id
    ids: dict[str, str] = {}
    for name, sp in list(stems.items()) + list(stingers.items()):
        if sp in ids:
            continue
        rid = f"m_{name}"
        ids[sp] = rid
        lines.append(f'[ext_resource type="AudioStream" path="{sp}" id="{rid}"]')

    def dict_res(d: dict[str, str]) -> str:
        return ", ".join(f'&"{k}": ExtResource("{ids[sp]}")' for k, sp in d.items())

    lines += [
        "",
        "[resource]",
        'script = ExtResource("1_trk")',
        f'id = &"{track_id}"',
        f"bpm = {_f(bpm)}",
        f"beats_per_bar = {beats_per_bar}",
        f"stems = Dictionary[StringName, AudioStream]({{{dict_res(stems)}}})",
        f"stingers = Dictionary[StringName, AudioStream]({{{dict_res(stingers)}}})",
        "gain_db = Dictionary[StringName, float]({%s})" % ", ".join(f'&"{k}": {_f(v)}' for k, v in gains.items()),
        "loop_bars = Dictionary[StringName, int]({%s})" % ", ".join(f'&"{k}": {v}' for k, v in bars.items()),
        "",
    ]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")
