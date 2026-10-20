"""Ostrander Federal purpose variants of shared dressing kits (OF-C2). Imported by _kits.py, which writes every kit
.tres.

docs/design/heists/ostrander_federal.md's room list names shared kits for rooms whose purpose is more specific than
the kit's (validate_level density: a kit's purpose must be its room's): the count room (cash_office), the janitor
closets (janitor), the sally port (warehouse), mail and operations (office) and the teller workroom (banking_hall).
Each variant `<kit>_of` is its base kit with the room's purpose and `seed_id` = the base id, so the placer lays the
rooms out as before. The cart queue (CQ, 3 x 4 m between the cash lift and BB) has no wall run for a packing bench
beside its sealed-bag shelving, trolley and skid: its variant drops the bench (the count room packs the bags).
"""

from __future__ import annotations

import copy

# variant id -> (base kit, room purpose)
VARIANTS = {
    "count_room_of": ("count_room", "cash_office"),
    "janitor_closet_of": ("janitor_closet", "janitor"),
    "sally_port_of": ("sally_port", "warehouse"),
    "copy_room_of": ("copy_room", "office"),
    "teller_line_of": ("teller_line", "banking_hall"),
    "cash_transfer_of": ("cash_transfer", "storage"),
}


def ostrander_kits(kits: dict) -> dict:
    out = {}
    for vid, (base, purpose) in VARIANTS.items():
        k = copy.deepcopy(kits[base])
        k["purpose"] = purpose
        k["seed_id"] = base
        k["notes"] = f"Ostrander Federal ({purpose}), from {base}: " + k.get("notes", "")
        if vid == "cash_transfer_of":
            k["required"] = [r for r in k["required"] if r != "packing_bench"]
            k.get("clutter", {}).pop("bench", None)
            k["notes"] = ("Ostrander Federal CQ cart queue, from cash_transfer without the packing bench (no wall run "
                          "for it beside the shelving, trolley and skid). " + kits[base].get("notes", ""))
        out[vid] = k
    return out
