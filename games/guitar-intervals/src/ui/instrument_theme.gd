extends RefCounted
## Shared colors and surfaces for the instrument faceplate and display.

const DESK := Color("d1d2c9")
const CASE := Color("eeeee6")
const INK := Color("242821")
const MUTED := Color("666c61")
const LINE := Color("bfc3b7")
const KEY := Color("fafaf2")
const SHADOW := Color("afb4a7")
const SCREEN := Color("171e1b")
const SCREEN_GRID := Color("3c4940")
const SCREEN_MUTED := Color("8f9f91")
const SCREEN_INK := Color("eef1df")
const ROOT := Color("f07845")
const TARGET := Color("83b7dc")
const FIFTH := Color("b3ca85")
const SUCCESS := Color("276a48")
const ERROR := Color("ae3b32")
const INFO := Color("3d657c")


static func panel(fill: Color, border: Color, radius: int = 5, margin: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func key(fill: Color, pressed: bool = false) -> StyleBoxFlat:
	var style := panel(fill, INK if pressed else LINE, 4, 10)
	style.border_width_bottom = 1 if pressed else 3
	style.shadow_color = Color(0.1, 0.15, 0.08, 0.12)
	style.shadow_size = 1 if pressed else 2
	style.shadow_offset = Vector2(0, 1 if pressed else 2)
	return style
