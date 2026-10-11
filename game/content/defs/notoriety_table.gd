## Every Notoriety rank's rewards (content/data/notoriety/ranks.tres). Owner: ENV B.
## Has no `id` on purpose: ContentDB skips it and Notoriety reads it. A rank without an entry has no
## item reward (badge and XP bonus only).
class_name NotorietyTable
extends Resource

@export var ranks: Array[NotorietyDef] = []
