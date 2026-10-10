"""Binary glTF (.glb) utilities: canonical re-serialisation and hashing. Pure Python.

``normalise()`` parses the JSON chunk and writes it back with sorted keys, compact separators and a
fixed ``asset.generator`` string, then re-pads both chunks per the spec. Binary buffer bytes are
left untouched. This removes the only sources of byte drift between otherwise identical exports
(dict ordering and the exporter's generator/version text) and makes diffs of the JSON readable.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import struct

_MAGIC = 0x46546C67  # b"glTF"
_JSON = 0x4E4F534A
_BIN = 0x004E4942


def read(path: pathlib.Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, length = struct.unpack_from("<III", data, 0)
    if magic != _MAGIC or version != 2 or length != len(data):
        raise ValueError(f"{path}: not a glTF 2.0 binary")
    off = 12
    doc: dict | None = None
    binary = b""
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == _JSON:
            doc = json.loads(chunk.decode("utf-8"))
        elif ctype == _BIN:
            binary = chunk
        off += 8 + clen
    if doc is None:
        raise ValueError(f"{path}: no JSON chunk")
    return doc, binary


def write(path: pathlib.Path, doc: dict, binary: bytes) -> None:
    js = json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    js += b" " * ((4 - len(js) % 4) % 4)
    out = struct.pack("<II", len(js), _JSON) + js
    if binary:
        binary += b"\0" * ((4 - len(binary) % 4) % 4)
        out += struct.pack("<II", len(binary), _BIN) + binary
    path.write_bytes(struct.pack("<III", _MAGIC, 2, 12 + len(out)) + out)


def normalise(path: pathlib.Path, generator: str) -> None:
    doc, binary = read(path)
    doc.setdefault("asset", {})["generator"] = generator
    doc["asset"].pop("copyright", None)
    write(path, doc, binary)


def sha256(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def node_names(path: pathlib.Path) -> list[str]:
    doc, _ = read(path)
    return [n.get("name", "") for n in doc.get("nodes", [])]


def material_names(path: pathlib.Path) -> list[str]:
    doc, _ = read(path)
    return [m.get("name", "") for m in doc.get("materials", [])]
