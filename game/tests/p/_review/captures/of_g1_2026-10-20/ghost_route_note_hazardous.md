# OF ghost line on Hazardous, seed 1002: route note (ENV P, 2026-10-21, trunk r263 67260f0b)

For C (design doc §ghost line) and the GPU box's windowed human-input check. Positions are OF world metres
(x, y, z); y is the floor: B -4, G 0, M 5, E 8.6. "BB" = basement corridor (z 7-9), "VC" = vault antechamber
(x 14-34, z 9-13), "VT" = vault (z 13-25), "CQ" = cash transfer room (x 10-13, z 3-7), "GL" = cash lift room
(x 10-13, z 0-3), "SA" = stair A (x 13-16, z 0-7), "LK" = staff lockers (x 0-10, z 0-7), "RC" = records (x 0-14, z 9-25).
Times are heist seconds on seed 1002 Hazardous r263; the harness run that proved each step is named.

## Steps 1-5: proven unseen in one continuous run (haz_zd, plus haz_zc/za for the same lines)

1. Plaza spawn, Tannery Street, Ledger Lane to the dumpsters (t≈33).
2. Dock. Wait for rover_dock's smoke at the Tannery corner (cues at t≈78, 149, 259, 317, 401). rover_hall's loop (b)
   LD check comes every ~88 s (t≈11, 96, 185, 269, 361, 449); if he is heading in at the cue, let that check pass inside
   the same smoke window (≤ 25 s), then mask, ECM #1, lockpick DockPersonnelDoor (8 s). If DockCorridorDoor is not clear,
   wait in the lane beside the dock door at (6, 0, -1.5), not inside LD. Through BC and SA, then **wait on SA's half
   landing (14.5, -2, 2.0)** until BB is clear: no guard in BB west of x 32, in RC's front (x < 14, z < 14), walking in
   VC, or within 6 m of SA's door. The B landing behind SA's door is NOT a wait spot (walkers in BB see it at 2 m).
   Back up to the half landing if a guard is within 10 m at the foot.
3. Keycard (manager on mgr_vault). Wait crouched at **(8.5, -4, 0.5)**, behind WCPartitionLK2. It is the one LK floor point
   hidden from his walk in (LockerDoor → ManagerLKWC (7.25, -4, 2.2)) and from BB. When he stands at his WC stop
   (t≈341), shout from there without stepping out: the all-round shout reaches him by the short navmesh path. He goes
   down blind; then step out, tie him (tie 1), take the card (t≈357). Stepping out to shout fails: within 1.5 m NPCs
   see all round and he fills 1.0 at once.
4. Code. LK → SA in a BB window (as step 2's rule, crouched at the LK hide (1.5, -4, 4) meanwhile); the stair wait for G
   / E is done from the half landing. pc_exec hack 45 s, one interruption; done t≈466.
5. Vault. Down to the half landing, BB rule, then the LK hide. Gate window: the vault guard on loop (b) (RC) and
   rover_basement away. On Hazardous this window is rare: haz_zd waited 300 s twice with none (t 599-1199). Gate,
   cross the sweep (lane x+0.01, 3.35 m/s), code at TL, back across. **Wait out the time lock (270 s) crouched in
   CQ's SE corner (12.5, -4, 3.5)**: no BB point sees it, and CQ's door is 2 m from the gate. Do not wait in RC (the
   vault guard's loop (b) walks it) or walk BB to LK. Vault open t≈1484.

## Step 6: the bags. Each sub-move is proven unseen in debug runs (`--test=ghost6`, a logged SHORTCUT start at CQ)

- After the time lock the vault guard is back on his VC post (25.6, -4, 10.9), 4 m from VT's door. Every VC crossing
  needs him away on loop (b) (RC, west / south) or (c) (east, x > 36, SD). On seed 1002 that is about every 200 s.
- **In** (CQ → VT): from CQ's corner, when the vault guard's current absence is ≤ 15 s old or he is ≥ 25 m from the
  gate by path. No other guard may be in VC, within 12 m of the gate, in BB within 25 m of it, or walking toward it
  within 32 m. Also check where each guard will be ~8 s later.
- The cash cage (CashCageGate, BARRED) opens with the vault code at CashCageKeypad (25.25, -4, 16.6).
- **Out with a bag** (VT → CQ): wait at **(24.5, -4, 20.5)** beside the cash. It is hidden from every VC point. Leave
  on the same window rule (absence ≤ 10 s, or ≥ 25 m by path, projected 12 s ahead). Cross the sweep (2.56 m/s with
  a MEDIUM bag). **Stop just inside the gate at (17, -4, 10.3)**: the VC side, blind from BB except at the gate. Step
  out only when no guard is in BB within 25 m of the gate (or within 8 m anywhere), while the vault guard is still
  ≥ 18 m off. A guard can step out of a side room into BB with no warning; this stop is the only defence.
- Bag into the cash lift: open CashLiftDoorB (11.5, -4, 3), then throw from 3.2 m back inside CQ, looking steeply
  down. A throw from the door hits GL's back wall and rests just outside the car's 2.2 m count box (C content note).
- Two bags per lift cycle (proven: ghost6_j/k/l/m, 176 s and 114 s per bag on good windows).
- Lift up: from CQ / GL, wait crouched in CQ's corner for BB, step to SA and up to the half landing. Climb to G
  **4-40 s after rover_hall's LD check** (proven ghost6_l/m: up 4 s after his t=373 check). Stage both bags by LD's
  personnel door (staged 2/6 at t=398). Leave LD within ~60 s, before his next check (ghost6_l failed waiting 67 s
  for a posted guard 7 m off behind walls). Ghost6_m left at once (6 s) and recalled the lift unseen at t=424.

## Step 7 (not reached by the harness yet): lift cycles 2-3, throw, walk out

- Repeat step 6's cycle for bags 3-6 (cycles 2 and 3). The cycle 2 in-crossing is where ghost6_m/n/o/p/q/r died. Each
  death was a BB guard close to the gate during the gate → CQ dash: rover_basement standing 14 m off facing west, or
  stepping out of a room, or the vault guard coming back down BB. A human should peek BB from inside the gate every
  trip.
- Then ECM #2 in LD and throw the 6 staged bags from the personnel door into the E1 van's zone (4 m MEDIUM throw;
  ~15 s of the 20 s jam), timed when rover_hall is on loop (a) or (c), not (b). Walk out through the dock door
  and the lane. The escape opens on 6 secured.
