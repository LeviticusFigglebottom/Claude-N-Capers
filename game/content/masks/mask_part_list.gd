## A list of mask parts of one kind (`content/data/masks/parts/<kind>.tres`). Owner: ENV B.
## Has no `id` property on purpose: ContentDB skips it and MaskCatalog reads it. Entry order is the
## UI order.
class_name MaskPartList
extends Resource

@export var entries: Array[MaskPartDef] = []
