# Music selection (B5-03, D-062)

Owner: ENV B. Players pick the music a heist plays, and they can listen to tracks in the safehouse.
ENV C owns the tracks, the registry and playback. ENV A replicates the launch options. B owns the
catalog view, the picker, the jukebox UI, the strings and the unlocks.

## Catalog: `MusicCatalog` (`content/audio/music_catalog.gd`, static)

A read-only view over ENV C's track registry.

| Source, in order | When |
|---|---|
| `MusicCatalog.table_override` | Tests only. Any Object with `all() -> Array`. |
| ENV C's `MusicTrackTable` at `MusicCatalogTweak.table_path` (`res://world/audio/music/tracks.tres`) | When the resource exists AND the global class `MusicTrackTable` exists. Read as `MusicTrackTable.load_default().all()`. |
| B stub list `content/data/tweak/music.tres` (`MusicCatalogTweak.tracks`, `MusicStubTrack`) | While C's table is missing. **C's table replaces the stub.** |

- The class is looked up by name (`UiNav.global_class`), so B compiles before C ships it.
- Entries are duck-typed with `get(&"id")`, `get(&"unlock")` and `get(&"default_for_heists")`. They can
  be Resources or Dictionaries.
- Entries without an id are skipped. When an id repeats, the first entry wins.
- The table path is kept in data, because B scripts may not hard-code a path into `world/`.

The stub lists six tracks:
- `glasshouse`, `night_deposit` and `shadow_ledger` are the `HeistDef.music_track` values, and each is
  the default for its own heist. Only `glasshouse` has stems on disk today.
- `vault_hymn`, `long_con` and `last_call` are placeholders that unlock with Notoriety. Their `unlock`
  ids are `unlock.music.<id>`.

The stub's `stems` paths follow C's `res://world/audio/music/<id>/<id>.tres` convention. B never reads them.

### API

| Function | Returns |
|---|---|
| `tracks() -> Array[Dictionary]` | `{id: StringName, unlock: StringName, default_for_heists: Array[StringName]}`, in stable id order (`ContentDB.sort_ids`) |
| `ids()`, `track(id)` (`{}` when unknown), `has(id)` | Lookups |
| `is_unlocked(profile, id)` | True when `unlock == &""` or `profile.unlocks` has it. An unknown id is locked. |
| `available(profile)` | The unlocked ids, sorted |
| `display_key(id)` | `music.<id>.name`. `&""` gives `ui.music.heist_default`. |
| `unlock_rank(id)` | The Notoriety rank whose `NotorietyDef.unlocks` lists the track's unlock. 0 means none. |
| `default_for(heist_id)` | The first track that lists the heist in `default_for_heists`, else `&""` |
| `resolve_choice(profile)` | `profile.music_choice` while it is a known, unlocked track, else `&""` |
| `table_path()`, `has_table()`, `is_stub()` | Source checks |

## Picking a track

`profile.music_choice: StringName` (save v6). `&""` means the heist default.

- **`MusicPicker`** (`ui/common/music_picker.gd`) shows a "Music" row:
  - The first item is "Heist default", which names the heist's own track when the catalog knows it.
  - Every track is listed after it. Locked tracks are disabled and labelled "(Notoriety VII)", or
    "(locked)" when no rank grants them.
  - `choose(id)` writes `music_choice`, saves to `profile_slot` and emits `music_changed`.
  - `set_read_only(id)` shows a fixed pick as text instead of the list.
- **Pre-planning** shows the picker in its bottom bar for solo play and for the host
  (`PreplanningScreen.music_picker`). MenuFlow sets `music_enabled = false` on co-op clients.
- **Lobby** (`LobbyScreen.music_picker`):
  - The host gets an editable picker. A change re-sends the host's profile summary.
  - Clients see the host's pick read-only. `LobbyState.host_music()` reads the `music` field of the
    host's `lobby.profile_summary`.
  - The `music` field holds `resolve_choice` of the sender. `""` means the heist default. A missing or
    non-String value reads as `""`.

## Launch option

`MenuFlow.build_launch_options(..., music)` and `build_coop_launch_options(..., music)` always set
`options["music_track"]: StringName`.

- MenuFlow passes `MusicCatalog.resolve_choice(profile)`. In co-op it uses the **host's** profile, so the
  host wins.
- A pick that no longer exists or is locked again becomes `&""`.
- ENV A replicates `HeistRuntime.launch_options` to every peer.
- ENV C's MusicDirector plays `music_track` when it is non-empty, else `HeistDef.music_track`.

## Jukebox

The hub station `jukebox` (`data/ui/hub_stations.tres`, target `jukebox`) opens `JukeboxScreen`
(`ui/jukebox/`) through `MenuFlow.open_station(&"jukebox")`.

- Each track has a row: its name, "Unlocked" or "Locked: Notoriety VII", and Play. A Stop button sits
  below the list.
- B never plays stems. The screen instances one `MusicDirector` as a child only when the global class
  exists and has `preview`. It then calls `preview(track_id)` and `stop_preview()` via `call()`, which
  plays on the Music bus. `listen_to_event_bus` is set to false when the property exists.
- If that API is missing (true on today's tree), every Play is disabled and a notice says previews
  arrive with the music update.
- Back, Esc / gamepad B, hiding the screen and freeing it all stop the preview.

## Unlocks

Notoriety ranks grant plain unlock ids into `PlayerProfile.unlocks` (`NotorietyDef.unlocks`, B5-02):

| Rank | Unlock id |
|---|---|
| VII | `unlock.music.vault_hymn` |
| XIII | `unlock.music.long_con` |
| XXI | `unlock.music.last_call` |

A track is unlocked when its `unlock` id is in the profile. C's table must use these same unlock ids.

## Strings

- `music.<id>.name` for every track:
  - Glass Ceiling
  - Night Shift
  - Off the Books
  - Vault Hymn
  - The Long Con
  - Last Call
- `ui.music.*` for the picker.
- `ui.jukebox.*` for the jukebox screen.
- `ui.hub.station.jukebox(.desc)` for the hub station.
