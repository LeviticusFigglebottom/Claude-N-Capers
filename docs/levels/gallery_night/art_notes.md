# Gallery Night: G2 art notes

- **Near-range interior props (lead ruling, round 224).** Gallery Night's interior dressing draws to 30 m, not the
  style guide's 60 m for medium props. The reason is the draw-call budget: at 60 m the worst review cameras reached
  about 3320 draw calls, and the budget is 2500. At 30 m the worst is rc_back_corridor at 2374. The change is
  GN-local and the style guide is unchanged. The generator writes near-range copies of each prop wrapper scene to
  `game/world/heists/gallery_night/art/props_near/`, and GN's dressing uses those copies; the shared prop library
  keeps 60 m.
- Accepted with G2: 12 walkthrough 3x whitelist entries (PlayerPortico1-4 to Locker1/Locker5/StoreStudy1, about
  3.0x because the gala furniture bends the hall walk). StaffDoor and DockCorridorDoor now swing outward, into their rooms.
- Open: the gallery rooms (founders, harbour, benefactors) could use more gala dressing (catering tables,
  glasses, standing signage) once the DB and SL G2 passes are done.
