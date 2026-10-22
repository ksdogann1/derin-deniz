class_name TouchControls
extends CanvasLayer
## Telefon ve tablet kontrolleri: sol altta joystick, sağda Kır/Koy modu,
## yan düğmeler (Üretim, Ansiklopedi, Sohbet, Menü). Dünyaya dokunmak:
## Kır modunda basılı tut = kır, Koy modunda dokun = koy, canlıya dokun = yakala.
## Çoklu dokunuşu doğrudan okur; joystick tutulurken de düğmeler çalışır.

const JOY_R := 84.0
const DEAD := 0.18

var hud: Node       # Hud
var world: Node     # World
var mode := "break"

var _canvas: Control
var _joy_idx := -1
var _joy_vec := Vector2.ZERO
var _world_idx := -1
var _world_pos := Vector2.ZERO
var _world_pressed := false
var _buttons: Array[Dictionary] = []     # {rect, label, action}
var _pressed_btn := -1
# iki parmakla yakınlaştırma (Growtopia gibi)
var _extra_idx := -1                     # dünyaya dokunan ikinci parmak
var _extra_pos := Vector2.ZERO
var _pinch := false
var _pinch_d0 := 1.0
var _pinch_z0 := 1.0


func _ready() -> void:
	layer = 11
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw)
	add_child(_canvas)


func _size() -> Vector2:
	return _canvas.size if _canvas.size.x > 0 else get_viewport().get_visible_rect().size


func joy_center() -> Vector2:
	var s := _size()
	return Vector2(140, s.y - 150)


func _layout() -> void:
	var s := _size()
	_buttons = [
		{"rect": Rect2(s.x - 176, s.y - 214, 132, 132), "label": "mode", "action": _toggle_mode},
		{"rect": Rect2(s.x - 330, 150, 112, 46), "label": "Envanter", "action": func(): hud.toggle_craft()},
		{"rect": Rect2(s.x - 330, 202, 112, 46), "label": "Ansiklopedi", "action": func(): hud.toggle_codex()},
		{"rect": Rect2(s.x - 330, 254, 112, 46), "label": "Harita", "action": func(): hud.toggle_map()},
		{"rect": Rect2(s.x - 330, 306, 112, 46), "label": "Oyuncular", "action": func(): hud.toggle_players()},
		{"rect": Rect2(s.x - 330, 358, 112, 46), "label": "Sohbet", "action": func(): hud.open_chat()},
		{"rect": Rect2(s.x - 330, 410, 112, 46), "label": "Menü", "action": func(): hud.back()},
	]


func _toggle_mode() -> void:
	mode = "place" if mode == "break" else "break"


# --------------------------------------------------------------------------
# Oyuncunun kullandığı API
# --------------------------------------------------------------------------

func move_vector() -> Vector2:
	return _joy_vec if _joy_vec.length() > DEAD else Vector2.ZERO


func pressed() -> bool:
	return _world_pressed


## Dokunulan noktanın dünya koordinatı
func world_point() -> Vector2:
	return get_viewport().get_canvas_transform().affine_inverse() * _world_pos


# --------------------------------------------------------------------------
# Girdi
# --------------------------------------------------------------------------

func _blocked_by_ui(pos: Vector2) -> bool:
	if hud.any_panel_open() or hud.typing():
		return true
	return hud._hotbar.get_global_rect().has_point(pos) or hud.ui_button_at(pos)


func _input(event: InputEvent) -> void:
	_layout()
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		var up := t.position / Settings.ui_scale      # arayüz koordinatı (ölçekli katman)
		if t.pressed:
			# yan düğmeler (bir pencere açıkken gizli ve dokunulmaz: pencereyle çakışmasın)
			var panel_open: bool = hud.any_panel_open()
			for i in _buttons.size():
				if panel_open:
					break
				if (_buttons[i].rect as Rect2).has_point(up):
					_pressed_btn = i
					(_buttons[i].action as Callable).call()
					get_viewport().set_input_as_handled()
					return
			# hotbar (ikinci parmakla dokunulursa fare taklidi çalışmaz, burada seç)
			if t.index != 0 and hud._hotbar.get_global_rect().has_point(up):
				var local: Vector2 = up - hud._hotbar.get_global_rect().position
				world.selected_slot = clampi(int(local.x / (Hud.SLOT + Hud.SLOT_GAP)), 0, Inventory.HOTBAR - 1)
				return
			if _joy_idx == -1 and up.distance_to(joy_center()) < JOY_R * 1.7 and not hud.any_panel_open():
				_joy_idx = t.index
				_update_joy(up)
				return
			if _world_idx == -1 and not _blocked_by_ui(up):
				_world_idx = t.index
				_world_pos = t.position
				_world_pressed = true
			elif _world_idx != -1 and _extra_idx == -1 and not _blocked_by_ui(up):
				# ikinci parmak: kırma/koyma iptal, yakınlaştırma başlar
				_extra_idx = t.index
				_extra_pos = t.position
				_pinch = true
				_world_pressed = false
				_pinch_d0 = maxf(20.0, _world_pos.distance_to(_extra_pos))
				_pinch_z0 = Settings.zoom
		else:
			if t.index == _joy_idx:
				_joy_idx = -1
				_joy_vec = Vector2.ZERO
			if t.index == _world_idx or t.index == _extra_idx:
				if _pinch:
					# yakınlaştırma bitti; iki parmak da kalkana dek kırma başlamasın
					if t.index == _world_idx:
						_world_idx = _extra_idx
						_world_pos = _extra_pos
					_extra_idx = -1
					_pinch = false
					_world_pressed = false
				else:
					_world_idx = -1
					_world_pressed = false
			_pressed_btn = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_idx:
			_update_joy(d.position / Settings.ui_scale)
		elif d.index == _world_idx or d.index == _extra_idx:
			if d.index == _world_idx:
				_world_pos = d.position
			else:
				_extra_pos = d.position
			if _pinch:
				Settings.set_zoom(_pinch_z0 * _world_pos.distance_to(_extra_pos) / _pinch_d0)


func _update_joy(pos: Vector2) -> void:
	var v := (pos - joy_center()) / JOY_R
	_joy_vec = v.limit_length(1.0)


func _process(_delta: float) -> void:
	var s := Settings.ui_scale
	scale = Vector2(s, s)
	var want := get_viewport().get_visible_rect().size / s
	if _canvas.size != want:
		_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_canvas.position = Vector2.ZERO
		_canvas.size = want
	_canvas.queue_redraw()


# --------------------------------------------------------------------------
# Çizim
# --------------------------------------------------------------------------

func _draw() -> void:
	_layout()
	if hud.any_panel_open():
		return
	var c := joy_center()
	_canvas.draw_circle(c, JOY_R + 6, Color(0.02, 0.06, 0.12, 0.35))
	_canvas.draw_arc(c, JOY_R, 0, TAU, 48, Color(0.6, 0.9, 1.0, 0.45), 2.0)
	var knob := c + _joy_vec * JOY_R
	_canvas.draw_circle(knob, 34, Color(0.6, 0.9, 1.0, 0.35 if _joy_idx == -1 else 0.6))
	_canvas.draw_arc(knob, 34, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	var font := ThemeDB.fallback_font
	for i in _buttons.size():
		var b: Dictionary = _buttons[i]
		var r: Rect2 = b.rect
		var down := i == _pressed_btn
		if b.label == "mode":
			var center := r.get_center()
			var col := Color(1.0, 0.55, 0.35) if mode == "break" else Color(0.4, 0.95, 0.6)
			_canvas.draw_circle(center, r.size.x * 0.5, Color(col, 0.28 if not down else 0.5))
			_canvas.draw_arc(center, r.size.x * 0.5, 0, TAU, 48, Color(col, 0.9), 3.0)
			var title := "KIR" if mode == "break" else "KOY"
			_canvas.draw_string_outline(font, center + Vector2(-60, 8), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 26, 5,
				Color(0, 0, 0, 0.6))
			_canvas.draw_string(font, center + Vector2(-60, 8), title, HORIZONTAL_ALIGNMENT_CENTER, 120, 26, Color.WHITE)
			var hint := "dokun: değiştir"
			_canvas.draw_string(font, center + Vector2(-60, 34), hint, HORIZONTAL_ALIGNMENT_CENTER, 120, 11,
				Color(1, 1, 1, 0.6))
			var id: int = world.selected_block()
			if mode == "place" and id != 0:
				_canvas.draw_texture_rect(TileAtlas.icon(id), Rect2(center + Vector2(-12, -44), Vector2(24, 24)), false)
		else:
			_canvas.draw_style_box(UiTheme.box(Color(0.04, 0.12, 0.2, 0.7 if not down else 0.9),
				Color(0.36, 0.78, 0.96, 0.5), 10, 1, 0), r)
			_canvas.draw_string(font, r.position + Vector2(0, r.size.y * 0.5 + 6), b.label,
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, UiTheme.TEXT)
	if _world_pressed:
		_canvas.draw_arc(_world_pos / Settings.ui_scale, 22, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
