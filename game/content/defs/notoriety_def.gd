## One Notoriety rank's rewards (pd2_fidelity P10). Owner: ENV B. Lives in NotorietyTable
## (content/data/notoriety/ranks.tres), never as a top-level file. Design: content/docs/notoriety.md.
## Reward ids are mask part ids (`mask_colors.*`, `mask_material.*`, ...) or preset ids (`mask.*`).
class_name NotorietyDef
extends Resource

## 1..NotorietyTweak.max_rank.
@export var rank: int = 1
## Granted on reaching this rank. The rank's unlock id `unlock.notoriety.rank_<n>` is recorded too, and
## it owns every preset whose MaskDef.unlock is that id.
@export var rewards: Array[StringName] = []
## Plain unlock ids granted into PlayerProfile.unlocks on reaching this rank (D-062), e.g.
## `unlock.music.<track_id>`: the owner of that unlock (ENV C's music table) reads the profile's unlocks.
@export var unlocks: Array[StringName] = []
## Optional reward choice (PD2's infamy tree): the player picks ONE option they do not own yet. Ranks
## may list the same pool, so each pick narrows the next choice.
@export var choices: Array[StringName] = []
