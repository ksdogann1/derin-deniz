class_name UiTheme
extends RefCounted
## Menü ve HUD için ortak görünüm.

const BG := Color(0.035, 0.09, 0.16, 0.86)
const BORDER := Color(0.36, 0.78, 0.96, 0.35)
const ACCENT := Color(0.36, 0.86, 1.0)
const TEXT := Color(0.9, 0.96, 1.0)
const MUTED := Color(0.62, 0.74, 0.84)
const GOOD := Color(0.45, 0.95, 0.6)
const BAD := Color(1.0, 0.45, 0.42)
const GOLD := Color(1.0, 0.86, 0.45)

static var _theme: Theme


static func box(bg: Color, border: Color, radius := 10, border_w := 1, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin * 0.7
	s.content_margin_bottom = margin * 0.7
	s.anti_aliasing = true
	return s


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 15
	t.set_stylebox("panel", "PanelContainer", box(BG, BORDER))
	t.set_stylebox("panel", "Panel", box(BG, BORDER))

	t.set_stylebox("normal", "Button", box(Color(0.07, 0.2, 0.32, 0.95), Color(0.36, 0.78, 0.96, 0.5), 8, 1, 12))
	t.set_stylebox("hover", "Button", box(Color(0.1, 0.3, 0.46, 1.0), ACCENT, 8, 1, 12))
	t.set_stylebox("pressed", "Button", box(Color(0.05, 0.15, 0.25, 1.0), ACCENT, 8, 2, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), Color(0.6, 0.9, 1.0, 0.6), 8, 1, 12))
	t.set_stylebox("disabled", "Button", box(Color(0.08, 0.12, 0.17, 0.8), Color(1, 1, 1, 0.08), 8, 1, 12))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))

	t.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.06, 0.11, 0.9), Color(1, 1, 1, 0.15), 6, 1, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0.02, 0.06, 0.11, 0.95), ACCENT, 6, 1, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", Color(1, 1, 1, 0.35))

	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.55))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_color("font_shadow_color", "RichTextLabel", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "RichTextLabel", 1)
	t.set_constant("shadow_offset_y", "RichTextLabel", 1)

	t.set_stylebox("panel", "TooltipPanel", box(BG, BORDER, 6, 1, 8))
	_theme = t
	return t


## Kenarlara doğru koyulaşan radyal doku (vinyet).
static func vignette_texture(color: Color, inner := 0.55) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, inner, 1.0])
	g.colors = PackedColorArray([Color(color, 0.0), Color(color, 0.0), Color(color, 1.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.08, 0.5)
	return tex


static func label(text: String, size := 15, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
