"""WAV 48 kHz / 24-bit writer (deterministic, no extra chunks) and OGG Vorbis export via ffmpeg."""
from __future__ import annotations

import shutil
import struct
import subprocess
from pathlib import Path

import numpy as np

from .core import SR

OGG_QUALITY = {"sfx": 6, "music": 5}


def to_int24_bytes(x: np.ndarray) -> bytes:
    x2 = x[:, None] if x.ndim == 1 else x
    q = np.clip(np.round(x2 * 8388607.0), -8388608, 8388607).astype("<i4")
    b = q.reshape(-1).view(np.uint8).reshape(-1, 4)[:, :3]  # little-endian low 3 bytes
    return b.tobytes()


def write_wav24(path: Path, x: np.ndarray, sr: int = SR) -> None:
    ch = 1 if x.ndim == 1 else x.shape[1]
    data = to_int24_bytes(x)
    block = ch * 3
    hdr = b"RIFF" + struct.pack("<I", 36 + len(data)) + b"WAVE"
    hdr += b"fmt " + struct.pack("<IHHIIHH", 16, 1, ch, sr, sr * block, block, 24)
    hdr += b"data" + struct.pack("<I", len(data))
    path.write_bytes(hdr + data)


def ffmpeg_bin() -> str:
    exe = shutil.which("ffmpeg")
    if exe is None:
        raise RuntimeError("ffmpeg (with libvorbis) is required for OGG export")
    return exe


def export_ogg(wav: Path, ogg: Path, quality: int, serial: int) -> None:
    """Byte-deterministic Vorbis export: bitexact muxer/codec flags, no metadata, fixed serial."""
    cmd = [ffmpeg_bin(), "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
           "-i", str(wav), "-map_metadata", "-1", "-c:a", "libvorbis", "-q:a", str(quality),
           "-fflags", "+bitexact", "-flags", "+bitexact", "-serial_offset", str(serial & 0x7FFFFFFF),
           str(ogg)]
    subprocess.run(cmd, check=True)


def decode(path: Path) -> np.ndarray:
    """Decode any audio file to float32 (n, ch) at 48 kHz for verification."""
    probe = subprocess.run([ffmpeg_bin(), "-nostdin", "-hide_banner", "-loglevel", "error", "-i", str(path),
                            "-f", "f32le", "-acodec", "pcm_f32le", "-ar", str(SR), "-"],
                           check=True, capture_output=True)
    raw = np.frombuffer(probe.stdout, dtype="<f4")
    ch = channels_of(path)
    return raw.reshape(-1, ch).astype(np.float64)


def channels_of(path: Path) -> int:
    r = subprocess.run([ffmpeg_bin(), "-hide_banner", "-i", str(path)], capture_output=True, text=True)
    return 2 if "stereo" in r.stderr else 1
