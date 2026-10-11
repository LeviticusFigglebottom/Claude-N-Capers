## Colour-vision deficiency simulation and perceptual distance (B5-01). Owner: ENV B.
## simulate(): Machado, Oliveira & Fernandes 2009 matrices (severity 1.0) applied in linear sRGB.
## delta_e76(): CIE76 = Euclidean distance in CIELAB (D65). Used by the palette tests and handy for
## checking new HUD colours.
class_name ColorVision
extends RefCounted

const NORMAL: StringName = &"normal"
const PROTANOPIA: StringName = &"protanopia"
const DEUTERANOPIA: StringName = &"deuteranopia"
const TRITANOPIA: StringName = &"tritanopia"
const KINDS: Array[StringName] = [PROTANOPIA, DEUTERANOPIA, TRITANOPIA]
## Rows of the 3x3 matrices (Machado 2009, severity 1.0).
const MATRICES: Dictionary = {
	&"protanopia": [
		Vector3(0.152286, 1.052583, -0.204868), Vector3(0.114503, 0.786281, 0.099216), Vector3(-0.003882, -0.048116, 1.051998)],
	&"deuteranopia": [
		Vector3(0.367322, 0.860646, -0.227968), Vector3(0.280085, 0.672501, 0.047413), Vector3(-0.011820, 0.042940, 0.968881)],
	&"tritanopia": [
		Vector3(1.255528, -0.076749, -0.178779), Vector3(-0.078411, 0.930809, 0.147602), Vector3(0.004733, 0.691367, 0.303900)],
}
## D65 reference white.
const WHITE: Vector3 = Vector3(0.95047, 1.0, 1.08883)


## `c` as seen with `kind` (NORMAL / unknown = unchanged). Alpha kept.
static func simulate(c: Color, kind: StringName) -> Color:
	if not MATRICES.has(kind):
		return c
	var lin: Vector3 = Vector3(c.srgb_to_linear().r, c.srgb_to_linear().g, c.srgb_to_linear().b)
	var m: Array = MATRICES[kind]
	var out: Vector3 = Vector3((m[0] as Vector3).dot(lin), (m[1] as Vector3).dot(lin), (m[2] as Vector3).dot(lin))
	out = out.clamp(Vector3.ZERO, Vector3.ONE)
	return Color(out.x, out.y, out.z, c.a).linear_to_srgb()


## CIELAB (L, a, b) of an sRGB colour.
static func to_lab(c: Color) -> Vector3:
	var l: Color = c.srgb_to_linear()
	var x: float = 0.4124564 * l.r + 0.3575761 * l.g + 0.1804375 * l.b
	var y: float = 0.2126729 * l.r + 0.7151522 * l.g + 0.0721750 * l.b
	var z: float = 0.0193339 * l.r + 0.1191920 * l.g + 0.9503041 * l.b
	var fx: float = _f(x / WHITE.x)
	var fy: float = _f(y / WHITE.y)
	var fz: float = _f(z / WHITE.z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## CIE76 colour difference (~2.3 = just noticeable; > 20 = clearly different).
static func delta_e76(a: Color, b: Color) -> float:
	return to_lab(a).distance_to(to_lab(b))


## delta_e76 of the two colours as seen with `kind`.
static func delta_e76_as(a: Color, b: Color, kind: StringName) -> float:
	return delta_e76(simulate(a, kind), simulate(b, kind))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 216.0 / 24389.0 else (24389.0 / 27.0 * t + 16.0) / 116.0
