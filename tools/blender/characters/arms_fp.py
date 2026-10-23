"""``char_arms_fp``: first-person arms ``rig_arms`` + the viewmodel animation sets (D1-03, D-034).

One glb: armature ``rig_arms`` (``_arms``: ``root`` = camera origin, the contract arm/finger bones,
helper bones ``weapon`` and ``magazine``), the skinned ``Arms`` mesh (hands at first-person
density, dark crew-suit sleeves ``char_suit_dark`` with a turned-in cuff, skin ``char_skin_2``) and
the clips of every set in ``_arms_sets.SETS`` (pistol, smg, rifle, shotgun, lmg, sniper, akimbo, revolver; D-055:
break_action, lever, bow, crossbow, launcher, flamethrower, saw, minigun; D-058: shotgun_box; D2-04: a ``bash`` per
gun set and the non-gun sets melee_knife, melee_blunt, melee_blade, throwable, deploy_bag, deploy_small, deploy_sentry) named
``<set>_<clip>``; loops carry the
``-loop`` suffix (Godot strips it and sets LOOP_LINEAR), except ``*_reload_loop``: Godot loops a name ending in
``_loop`` and strips that suffix too unless the stripped name already exists (``<set>_reload`` does, so the
name survives). New hold-to-fire loops are therefore named ``fire_hold`` / ``cut_hold`` (D-055): ``saw_cut_loop``
would import as ``saw_cut``. Godot also
replaces '/' in animation names, so the set is a prefix: the assembly tool puts ``<set>_<clip>`` into
an AnimationLibrary "<set>" as ``<clip>`` (played as "rifle/reload").

Godot (after import): ``<root>/rig_arms/Skeleton3D/Arms``. Place the node at the camera (``root`` =
camera origin, -Z forward). Attach the weapon with a BoneAttachment3D on ``weapon`` (identity child)
and the magazine with a BoneAttachment3D on ``magazine``. Every clip keys the same transforms
(rotations of all bones, positions of the clavicles, ``weapon`` and ``magazine``). Events (frame
numbers at 30 fps) and the moving-part conventions are listed in SOURCE.txt.
"""

import math

import _anim as anim
import _arms as arms
import _arms_clips as clips_mod
import _arms_sets as sets

TRI_BUDGET = 12000
EXPORT = {"embed": False, "animations": True, "skins": True, "morph": False}
ASSET_ID = "char_arms_fp"
PARAMS = {"skin": 2}

def notes() -> dict:
    """Contract notes copied into SOURCE.txt (see the D-034 / D-050 reports, characters.md)."""
    (lx, ly, lz), lo = anim.grip_offset_godot(arms.skeleton(), "L")
    return {
        "fp.clips": "<set>_<clip>; all sets: idle*, ads_idle*, sprint* (loops), draw, holster, fire, fire_ads, reload, "
                    "reload_empty; shotgun, lever: reload_start, reload_loop, reload_end, reload_end_empty; sniper: bolt, bolt_ads; "
                    "pistol: fire_auto, fire_auto_ads; akimbo: fire_l, fire_ads_l; bow: draw_string, hold*, release, nock; "
                    "flamethrower: fire_start, fire_hold*, fire_end; saw: rev, cut_hold*, cut_end; minigun: spin_up, "
                    "fire_hold*, spin_down; shotgun_box: the common clips only (mag swap reloads); every gun set: bash "
                    "(D2-04 quick melee); non-gun sets (D2-04): melee_knife / melee_blunt / melee_blade / melee_heavy: idle*, sprint*, "
                    "draw, holster, swing, charge_start, charge*, charge_swing; throwable: idle*, sprint*, draw, holster, "
                    "throw, throw_low; deploy_bag / deploy_small / deploy_sentry: idle*, draw, holster, place",
        "fp.camera": "review camera = crew camera: 75 deg vertical FOV (crew_member.tscn), root = eye",
        "fp.fire": "fire/fire_ads start at rest, kick peaks on frame 1; full-auto sets (smg, rifle, lmg) are 3 f "
                   "(<= 1.5 shot intervals) so the game restarts them every shot",
        "fp.shotgun": "pump folded into fire/fire_ads (events pump_back, pump_forward); shell-by-shell = reload_start + "
                      "n x reload_loop (frame 0 == last frame; imports LOOP_LINEAR via Godot's _loop suffix: loop it n x its length) + reload_end (reload_end_empty when the "
                      "tube was empty: adds a pump); reload/reload_empty = the same pieces for 6 rounds (3.4 s / 4.2 s); "
                      "suggested data: reload_start_s 0.4, reload_per_round_s 0.4333, reload_end_s 0.4 (empty 1.2)",
        "fp.sniper": "fire/fire_ads = recoil only (9 f); play bolt (hip) / bolt_ads after each shot (27 f; 9 + 27 = 36 f = "
                     "1.2 s = 50 rpm); during the bolt the right hand leaves the grip and the weapon bone moves "
                     "relative to hand.R (the left hand holds the gun); reload_empty ends with the bolt cycle",
        "fp.lmg": "reload: cover_open, mag_out (box off), mag_in (box on), belt_seat, cover_close; reload_empty adds "
                  "charge (charging handle pulled back by the left hand)",
        "fp.offhand_grip": (f"akimbo left gun: attach the second WeaponVisual to hand.L (BoneAttachment3D + Socket) at "
                            f"basis x=({lx[0]:.4f},{lx[1]:.4f},{lx[2]:.4f}) y=({ly[0]:.4f},{ly[1]:.4f},{ly[2]:.4f}) "
                            f"z=({lz[0]:.4f},{lz[1]:.4f},{lz[2]:.4f}) origin=({lo[0]:.4f},{lo[1]:.4f},{lo[2]:.4f}) "
                            "(hand.L bone space; = _anim.grip_offset L = the X-mirror of the weapon bone's hand.R offset: "
                            "the same gun model, not mirrored; no helper bone)"),
        "fp.akimbo": ("one gun on the weapon bone (right) + the offhand gun on hand.L; fire / fire_ads kick the right gun, "
                      f"fire_l / fire_ads_l the left one ({sets.AKIMBO_FIRE} f, under one shot interval up to 600 rpm: alternate them per "
                      "shot); ads_idle raises both guns closer together (no sight alignment, the crosshair stays between "
                      "them); reload: both guns tilt inward, mag_out_r / mag_out_l drop the magazines, the guns dip below "
                      "the view, mag_in_r / mag_in_l happen off screen, done; reload_empty adds slide_release_r / "
                      "slide_release_l (thumb on the slide stop); the right magazine falls on the magazine bone and is "
                      "re-seated off screen; the left magazine has no bone: hide it (or drop a physics copy) at mag_out_l, "
                      "show it at mag_in_l; lengths from the akimbo weapon data (anim_set akimbo) when present, else "
                      "2.0 s / 2.6 s / equip 0.5 s"),
        "fp.revolver": (f"Crane: pivot on the hinge line parallel to the bore, opens {sets.CRANE_OPEN_DEG:.0f} deg "
                        "(+ about its local Z; the cylinder swings to -X) over crane_open-2..crane_open+1, closes over "
                        f"crane_close-3..crane_close; Cylinder (child of Crane) turns {sets.CYLINDER_STEP_DEG:.0f} deg per "
                        "shot; eject: palm on the ejector rod, muzzle up (rod stroke eject-3..eject, spawn 6 casings at "
                        "eject); Speedloader rides the magazine bone: its weapon-scene pose = loaded against the closed "
                        "cylinder (bone identity), visible loader_show..crane_close, seated on the open cylinder at "
                        "speedloader_in (its rounds move to the cylinder), twisted and released at loader_drop (falls "
                        "away empty), bone back to identity at crane_close; reload_empty = reload (same motion and events); "
                        "fire/fire_ads 9 f, heavier kick than the pistol"),
        "fp.pistol_auto": ("pistol fire_auto / fire_auto_ads: 3 f machine-pistol kick (<= 1.5 shot intervals up to "
                           "900 rpm), restarted every shot; the semi-auto pistol clips are unchanged"),
        "fp.break_action": (f"Breech (barrels + fore-end) pivots at the hinge pin, opens {sets.BREAK_OPEN_DEG:.0f} deg muzzle-down "
                            "(- about its local X) over breech_open-2..breech_open+1 (a small bounce on the stop until "
                            "breech_open+5), closes over breech_close-3..breech_close; the left hand rides the fore-end while "
                            "it moves; eject: spawn the empties, hide the chamber rounds; shell_in_1 / shell_in_2: show round "
                            "1 / 2 in its chamber (the round travels in the left hand from about shell_in_1-13); one barrel per "
                            "fire (alternate barrels per shot); reload_empty = reload (always both chambers); lengths from "
                            "the break_action weapon data when present, else 2.6 s / equip 0.6 s"),
        "fp.launcher": (f"Breech (barrel) pivots at the hinge pin, opens {sets.LAUNCHER_OPEN_DEG:.0f} deg muzzle-down (- about "
                        "local X), same timing rules as fp.break_action; eject: spawn the 40 mm casing; round_in: the round "
                        f"(in the left hand from round_in-16) is seated; fire/fire_ads {sets.LAUNCHER_FIRE} f heavy recoil; "
                        "reload_empty = reload; defaults 3.0 s / equip 0.7 s"),
        "fp.crossbow": (f"string = two halves StringUpper (left) / StringLower (right) (ENV B's Vise), each node's origin "
                        f"= its fixed prod-tip anchor, Godot model ({-sets.STRING_ANCHOR_X:.3f} / {sets.STRING_ANCHOR_X:.3f}, "
                        f"{sets.STRING_LATCHED[2]:.3f}, {-sets.STRING_ANCHOR_Y:.3f}), its ...Cord running to the string "
                        f"CENTRE where they meet; the model RESTS RELEASED (rotation 0: centre "
                        f"{_g(sets.CROSSBOW.markers['string_rest'])}, {sets.STRING_TRAVEL:.3f} m ahead of the nock); "
                        f"latched = the centre on the Magwell, Godot model {_g(sets.CROSSBOW.markers['string_latched'])}. "
                        "Per frame: centre = released + (latched - "
                        "released) x string, string from curve.crossbow_<clip> (1 = latched, 0 = released; clips without "
                        "a curve keep the current state: latched when loaded). ENV A bends each half about its fixed "
                        "anchor: rotate it (about its local X) so its inner end points at the centre and stretch it along "
                        f"that line (local Y) by |centre - anchor| / |released - anchor| (latched: {_latch_swing()}). "
                        "fire/fire_ads string_release@0 (latched -> released over "
                        "frames 0..1); reload: muzzle down, the left fingers hook the centre at cock and pull it back "
                        "to the latch by string_back (string = ((f - cock) / (string_back - cock))^2.4, the hand's own ease, "
                        "so the fingers stay on the centre); the bolt (Magwell) rides the magazine "
                        "bone: hidden after the shot, shown at bolt_show (carried in the left hand), laid on the rail by "
                        "bolt_in (bone identity from bolt_in); reload_empty = reload; defaults 2.0 s / equip 0.55 s"),
        "fp.lever": (f"Lever swings {sets.LEVER_OPEN_DEG:.0f} deg down (+ about its local X: the loop's rear end goes down) "
                     "about its pivot: thrown over lever_open-4..lever_open, back by lever_close (smoothstep); the cycle "
                     "is inside fire/fire_ads (like the pump) and reload_end_empty; the right hand turns "
                     f"{sets.LEVER_HAND_FOLLOW:.2f} x the lever angle with it (the weapon bone moves relative to hand.R "
                     "during the cycle); shell-by-shell through the right-side loading gate (Magwell): reload_start + "
                     "n x reload_loop (round_in, frame 0 == last frame, imports LOOP_LINEAR via the _loop suffix) + "
                     "reload_end / reload_end_empty; reload/reload_empty = the pieces composed for the tube (preview, "
                     "D-053); pieces from reload_start_s / reload_per_round_s / reload_end_s / reload_end_empty_s, else "
                     "0.5 / 0.5 / 0.4 / 1.0 s, tube mag_size else 8"),
        "fp.bow": ("held in the LEFT hand: the weapon bone carries the bow frame (origin = the riser grip, Y = arrow "
                   "direction, Z = up the riser) at hand.L x the fp.offhand_grip offset in every bow clip (it moves relative "
                   "to hand.R); the right hand holds the nocked arrow on the string; Arrow (Magwell) rides the magazine "
                   f"bone: identity = nocked at brace, drawn back {sets.BOW_DRAW:.3f} m x draw along local +Z, carried by "
                   "the right hand in nock from arrow_show, on the string at nocked; hide it at release (spawn the "
                   "projectile); StringUpper / StringLower turn about their cam axles so the string's nock point sits "
                   f"{sets.BOW_BRACE:.3f} + {sets.BOW_DRAW:.3f} x draw m behind the grip (draw per frame: curve.bow_<clip>, "
                   "0 = brace, 1 = full draw, negative = the string's forward overshoot after release); clips: "
                   "draw_string (charge, last frame = hold frame 0, event drawn), hold* (full draw, tremble), release "
                   "(release@0), nock (= reload = reload_empty), fire / fire_ads = release; no sights: ads_idle raises the "
                   "undrawn bow to the centre"),
        "fp.flamethrower": ("hold to fire: fire_start (ignite@2: light the flame; ready at its end) -> fire_hold* (loop it "
                            "while the trigger is held) -> fire_end (extinguish@0); fire / fire_ads are 3 f one-shot "
                            "shudders kept for the generic per-shot path (restart per damage tick); PilotLight: a marker "
                            "only (no motion); the fuel canister rides the magazine bone (mag_out / mag_swap / mag_in, "
                            "dropped on reload_empty); left hand on a raked front grip (vgrip)"),
        "fp.saw": ("hold to cut: rev (rev@0: spin the Blade up; ready at its end) -> cut_hold* (pushed into the cut, "
                   "vibrating) -> cut_end; fire / fire_ads = 3 f shudders (generic per-shot path); Blade spins about "
                   "its local X (ENV A, from rev until cut_end ends) and rides the magazine bone in the blade change: "
                   "nut_off, blade_out (bone slides 0.03 m along -X off the arbor, then the left hand carries it away), "
                   "blade_in (seated: bone identity), nut_on, done; reload_empty = reload; left hand on the side "
                   "handle (vgrip); no sights: ads_idle is a raised hold"),
        "fp.minigun": ("spin_up (spin@0 -> spun@15: Rotor at speed, fire may start) -> fire_hold* -> spin_down "
                       "(stopped@end); Rotor spins about its local Z (ENV A); fire / fire_ads = 3 f shudders; reload / "
                       "reload_empty: the ammo box rides the magazine bone (mag_out, mag_swap, mag_in; dropped when "
                       "empty), belt_seat (the left hand feeds the belt into the chute); sprint* = a 24 f heavy jog; "
                       "left hand on the left side grip (vgrip); no sights: ads_idle is a raised hip hold"),
        "fp.shotgun_box": (f"box / drum-fed self-loading shotguns (anim_set shotgun_box): the rifle hold (left hand on "
                           f"LeftHandIK under the fore-end / shroud) with a shotgun kick; fire / fire_ads "
                           f"{sets.SHOTGUN_BOX.frames('fire')} f (<= 1.5 shot intervals at the data's rpm, restarted every "
                           "shot, semi or auto); reload: mag_out (the drum / box rocks forward off its front lip, "
                           "magazine bone), mag_swap (old one stowed off screen, fresh one in the left hand), mag_in "
                           "(rocked in front lip first: canted forward, hooked, rocked back until it latches; bone identity "
                           "from mag_in), done; reload_empty: the empty drops at mag_out (falls on the magazine bone), then "
                           "the same rock-in and the left hand racks the charging handle on the receiver's left side "
                           f"({sets.SHOTGUN_BOX_CHARGE:.3f} m back) and lets it fly home at bolt_release; lengths from the "
                           "first shotgun_box weapon data (sorted by file name) when present, else 3.6 s / 4.4 s / equip "
                           "0.7 s / 300 rpm"),
        "fp.parts": (f"Pump: slides {sets.PUMP_TRAVEL:.3f} m along local +Z (back) between the pump_back ramp and "
                     f"pump_forward; Bolt: handle lifts {sets.BOLT_LIFT_DEG:.0f} deg about the bore axis "
                     f"(bolt_open), slides {sets.BOLT_TRAVEL:.3f} m along +Z (bolt_back), returns (bolt_forward), "
                     f"locks down (bolt_close); Rampart feed cover: opens {clips_mod.COVER_OPEN_DEG:.0f} deg about its "
                     f"front hinge (cover_open .. cover_close; the weapon scene needs a hinged FeedCover pivot); "
                     f"Slide (pistol): slide_release; smg/rifle bolt_release (cocking-handle slap / bolt catch); shotgun_box "
                     f"bolt_release (charging handle released after a {sets.SHOTGUN_BOX_CHARGE:.3f} m pull)"),
        "fp.bash": ("D2-04 quick melee with the gun out (PD2 weapon bash): <set>/bash in every gun set; the set's idle "
                    "frame 0 moved as one block (wind-up, strike, recover); hit@ = the contact (ENV A deals the melee hit "
                    "there), done@ = the last frame = idle frame 0 (blend back to idle); "
                    + ", ".join(f"{k} {n} f hit@{h}" for k, (n, h) in sets.BASH.items())
                    + " (families: " + ", ".join(f"{k}={v}" for k, v in sorted(sets.BASH_FAMILY.items()))
                    + ", other sets long); akimbo bashes with the right gun only; hands stay on their grips"),
        "fp.vgrip": ("D-118 vertical foregrip mods: <set>_vgrip_hand (" + ", ".join(sorted(_vgrip_wrists()))
                     + ") is a one-frame hip hold with the left hand closed round the grip (palm on the mod's "
                     "LeftHandIK, thumb tucked over it). With a vertical-grip mod equipped, blend the left-hand bones "
                     "(hand.L and its fingers) to it and IK the left wrist to the mod's LeftHandIK + this offset "
                     "(Godot weapon axes, m): "
                     + "; ".join(f"{k} {_g(v)}" for k, v in sorted(_vgrip_wrists().items()))),
        "fp.organic": ("D-116 follow-up: every gun set's reload* / draw / holster carries a secondary-motion "
                       "layer (_arms_organic; akimbo: per gun, before the two are combined): the gun follows its "
                       "keys through a spring "
                       "(anticipation, overshoot, settle), kicked at mag_out / mag_in / shell_in* / round_in* / "
                       "slide_release / bolt_release / bolt_forward / pump_forward / cover_close / belt_seat, with a "
                       "slow drift while the hands work; the hands follow their paths on the gun through springs, the "
                       "fingers re-grip, the wrist rolls into the well before a seat, the firing hand squeezes on a "
                       "release. Clip lengths, key and event frames are unchanged; every clip starts and ends on its "
                       "keyed pose (draw: the raise plays over the first 80 % and settles, ready@ = last frame)"),
        "fp.melee": ("melee_knife / melee_blunt / melee_blade (MeleeDef; proposal: MeleeDef.anim_set): the melee weapon "
                     "hangs identity on the weapon bone, which carries the ITEM frame: Godot origin on the handle axis at "
                     "the grip pivot (20 mm below the top of the fist), handle along +Y (blade / head toward +Y), edge / "
                     "striking face toward -Z; it is the gun grip offset turned 18 deg (the grip rake) about X, so the "
                     "weapon bone is not identity under hand.R in these sets. Tap: swing (hit@ contact, done@ back at "
                     "idle). Hold: charge_start (idle -> the wind-up; length = MeleeDef.charge_time_s, charged@ its end) -> "
                     "charge* (held wind-up, trembling; frame 0 = charge_start's last frame) -> charge_swing on release "
                     "(hit@, done@). draw ready@, holster gone@ (defaults: no equip time in MeleeDef). melee_heavy "
                     "(characters v1.38, MeleeDef.anim_set = melee_heavy: sledgehammer, fire axe) is TWO-HANDED: the same "
                     "clips, events and item frame, the right hand at the origin and the left hand closed round the same "
                     "handle 0.28 m lower (Godot item (0, -0.28, 0)) in every clip; the head about 0.55 m up the handle "
                     "(+Y); overhead strikes down through the centre of the view"),
        "fp.throwable": ("throwable (ThrowableDef kinds frag / concussion / incendiary; proposal: ThrowableDef.anim_set): "
                         "the grenade hangs identity on the weapon bone = its centre (Godot +Y up the fuse, -Z forward) in "
                         "the right fist; draw: pin_pull@ (the left hand pulls the ring on the grenade's left: hide the "
                         "model's Pin), ready@; throw (overhand) / throw_low (underhand): release@ = hide the held model "
                         "and spawn the projectile at the weapon bone with the hand's velocity, done@ = both hands off "
                         "screen (then draw the gun); holster gone@ (no throw)"),
        "fp.deploy": ("deploy_bag (ammo / doctor bag, body bag case, armor bag), deploy_small (ECM, trip mine, FAK), "
                      "deploy_sentry (two side handles 0.36 m apart) (DeployableDef.kind; proposal: DeployableDef.anim_set): "
                      "the weapon bone carries the item's carry handle (proposal: a Handle Marker3D in the deployable "
                      "model; attach the model so Handle sits on the bone; Godot axes X along a top handle bar, +Y up, "
                      "-Z forward); draw ready@, idle*, holster gone@; place = the deploy hold: place@ = "
                      "deploy_time_s x 30 (retime so place@ lands on the hold's end: spawn the prefab and hide the held "
                      "model), done@ = empty hands off screen; lengths from the first DeployableDef of the kind group "
                      "(deploy_time_s), else 2.0 s"),
    }


def _vgrip_wrists() -> dict:
    """{set: the left wrist of ``<set>_vgrip_hand`` minus the set's ``vgrip_ik`` marker} (Blender weapon space)."""
    sk = arms.skeleton()
    out = {}
    for name, s in sets.SETS.items():
        m = s.markers.get("vgrip_ik")
        if m is not None:
            w = clips_mod.left_vgrip(sk, m, s.pole_l).wrist - m
            out[name] = w
    return out


def export_name(name: str, table: dict) -> str:
    """Loops get Godot's ``-loop`` suffix (stripped on import), except names already ending in ``_loop``,
    which Godot loops by that suffix while keeping the name (``shotgun_reload_loop`` precedent)."""
    return f"{name}-loop" if table[name]["loop"] and not name.endswith("_loop") else name


def _latch_swing() -> str:
    """The latched swing / stretch of a string half from the markers (ENV B's SOURCE: +/-18.74 deg, x1.3049)."""
    m = sets.CROSSBOW.markers
    rx, ry = m["string_rest"][0] - sets.STRING_ANCHOR_X, m["string_rest"][1] - sets.STRING_ANCHOR_Y
    lx, ly = m["string_latched"][0] - sets.STRING_ANCHOR_X, m["string_latched"][1] - sets.STRING_ANCHOR_Y
    ang = math.degrees(abs(math.atan2(ly, lx) - math.atan2(ry, rx)))
    return f"-/+{ang:.2f} deg, x{math.hypot(lx, ly) / math.hypot(rx, ry):.4f}"


def _g(p) -> str:
    """A Blender weapon-space point as Godot model coordinates (x, y up, -z muzzle)."""
    return f"({p[0]:.3f}, {p[2]:.3f}, {-p[1]:.3f})"


def crossbow_curves(sk) -> dict:
    """``{clip: [string per frame]}`` for the crossbow clips that move the string (1 = latched, 0 = released)."""
    s = sets.SETS["crossbow"]
    fns = clips_mod.state_fns(sk, s)
    out = {}
    for c in sorted(s.clips):
        vals = [fns[c](f).extra.get("string") for f in range(s.frames(c) + 1)]
        if any(v is not None for v in vals):
            out[c] = [1.0 if v is None else float(v) for v in vals]
    return out


def bow_curves(sk) -> dict:
    """``{clip: [draw per frame]}`` for the bow clips (string draw 0 = brace, 1 = full draw)."""
    s = sets.SETS["bow"]
    fns = clips_mod.state_fns(sk, s)
    return {c: [float(fns[c](f).extra.get("draw", 0.0)) for f in range(s.frames(c) + 1)] for c in sorted(s.clips)}


def build(ctx) -> None:
    import bpy  # noqa: PLC0415

    table = sets.clip_table()
    arm = arms.build_arms_rig()
    mesh = arms.build_arms_mesh(ctx, arm, {"skin": int(ctx.param("skin", 2))})
    sk = arms.skeleton()
    solver = anim.Solver(sk)
    bpy.context.scene.render.fps = anim.FPS
    clips = {}
    for s in arms.SETS.values():
        clips.update(arms.fp_clips(sk, s))
    if sorted(clips) != sorted(table):
        raise AssertionError(f"clip table out of date: {sorted(set(clips) ^ set(table))}")
    for name in sorted(clips):
        baked = anim.bake(solver, clips[name])
        c = baked.checks
        if c["max_reach_err_m"] > 0.010:
            raise AssertionError(f"{name}: IK reach error {c['max_reach_err_m'] * 1000:.1f} mm")
        anim.write_action(arm, baked, export_name(name, table))
        ctx.source_extra[f"check.{name}"] = (f"reach_err={c['max_reach_err_m'] * 1000:.1f}mm "
                                             f"step={c['max_joint_step_deg']:.1f}deg")
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    (rx, ry, rz), (ox, oy, oz) = anim.grip_offset_godot(sk, "R")
    eye = arms.eye_point()
    ctx.source_extra["tris"] = mesh["tris"]
    ctx.source_extra["root"] = (f"camera origin = rig_humanoid eye midpoint ({eye[0]:.4f},{eye[1]:.4f},{eye[2]:.4f}) "
                                "m Blender")
    ctx.source_extra["weapon_bone"] = (
        f"child of hand.R at the HandR grip offset: basis x=({rx[0]:.4f},{rx[1]:.4f},{rx[2]:.4f}) "
        f"y=({ry[0]:.4f},{ry[1]:.4f},{ry[2]:.4f}) z=({rz[0]:.4f},{rz[1]:.4f},{rz[2]:.4f}) "
        f"origin=({ox:.4f},{oy:.4f},{oz:.4f}); "
        f"identity relative to hand.R except in sniper_bolt, sniper_bolt_ads and sniper_reload_empty, the lever cycle "
        f"(lever_fire*, lever_reload_end_empty and the composed lever_reload_empty), every bow clip (the bow is in hand.L) "
        f"and every clip of the non-gun sets (melee_*, throwable, deploy_*: the bone carries the item frame, fp.melee / "
        f"fp.throwable / fp.deploy)")
    for clip, vals in bow_curves(sk).items():
        ctx.source_extra[f"curve.bow_{clip}"] = "draw=" + ",".join(f"{v:.3f}" for v in vals)
    for clip, vals in crossbow_curves(sk).items():
        ctx.source_extra[f"curve.crossbow_{clip}"] = "string=" + ",".join(f"{v:.3f}" for v in vals)
    ctx.source_extra["loops"] = ",".join(sorted(n for n, r in table.items() if r["loop"]))
    ctx.source_extra["sets"] = ",".join(arms.SETS)
    for k, v in notes().items():
        ctx.source_extra[k] = v
    for name in sorted(table):
        row = table[name]
        extra = f"{row['frames']}f loop={row['loop']}"
        if row.get("events"):
            evs = sorted(row["events"].items(), key=lambda kv: (kv[1], kv[0]))
            extra += " events=" + ",".join(f"{k}@{v}" for k, v in evs)
        ctx.source_extra[f"clip.{name}"] = extra
