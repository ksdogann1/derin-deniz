class_name MenuBackground
extends Control
## Ana menünün hareketli su altı arka planı.

var _t := 0.0
const MENU_FISH := [200, 201, 213, 214, 202, 203, 215, 205]
var _jelly_tex: Texture2D
var _fish: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_jelly_tex = load("res://assets/creatures/denizanasi.png")
	for i in 14:
		_fish.append({"x": _rng.randf(), "y": _rng.randf_range(0.15, 0.85), "v": _rng.randf_range(0.02, 0.05),
			"variant": _rng.randi_range(0, 7), "dir": 1.0 if _rng.randf() < 0.5 else -1.0,
			"s": _rng.randf_range(3.0, 5.0)})
	for i in 40:
		_bubbles.append({"x": _rng.randf(), "y": _rng.randf(), "v": _rng.randf_range(0.03, 0.09),
			"r": _rng.randf_range(1.5, 4.0)})


func _process(delta: float) -> void:
	_t += delta
	for f in _fish:
		f.x += f.v * f.dir * delta
		if f.x > 1.1:
			f.x = -0.1
		elif f.x < -0.1:
			f.x = 1.1
	for b in _bubbles:
		b.y -= b.v * delta
		if b.y < -0.05:
			b.y = 1.05
			b.x = _rng.randf()
	queue_redraw()


func _draw() -> void:
	var sz := size
	var top := Color("1b6fa8")
	var bot := Color("030b1c")
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)]),
		PackedColorArray([top, top, bot, bot]))
	# ışık huzmeleri
	for i in 7:
		var x := sz.x * (0.08 + i * 0.15) + sin(_t * 0.25 + i) * 30.0
		var w := 40.0 + (i % 3) * 25.0
		var a := 0.07 + 0.04 * sin(_t * 0.7 + i * 1.9)
		draw_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + w, 0),
			Vector2(x + w * 2.5 + 260, sz.y * 0.9), Vector2(x + 260, sz.y * 0.9)]),
			PackedColorArray([Color(0.7, 0.95, 1, a), Color(0.7, 0.95, 1, a),
				Color(0.7, 0.95, 1, 0), Color(0.7, 0.95, 1, 0)]))
	# uzak kayalık silueti
	var pts := PackedVector2Array()
	pts.append(Vector2(0, sz.y))
	var x2 := 0.0
	while x2 <= sz.x + 20:
		var h := sz.y * (0.82 - 0.06 * sin(x2 * 0.006) - 0.04 * sin(x2 * 0.019 + 1.0))
		pts.append(Vector2(x2, h))
		x2 += 20.0
	pts.append(Vector2(sz.x, sz.y))
	draw_colored_polygon(pts, Color(0.01, 0.04, 0.09, 0.9))
	# balıklar
	for f in _fish:
		var sp: int = MENU_FISH[int(f.variant) % MENU_FISH.size()]
		var d := Species.get_def(sp)
		var fw := int(d["fw"])
		var fh := int(d["fh"])
		var frame := int(_t * 6.0 + f.x * 20.0) % 4
		var src := Rect2(frame * fw, 0, fw, fh)
		var s: float = f.s * 0.5
		var pos := Vector2(f.x * sz.x, f.y * sz.y + sin(_t + f.x * 10.0) * 6.0)
		var dst := Rect2(pos, Vector2(fw * s * f.dir, fh * s))
		draw_texture_rect_region(Species.texture(sp), dst, src, Color(0.75, 0.88, 1.0, 0.85))
	# denizanası
	var jf := int(_t * 3.0) % 4
	draw_texture_rect_region(_jelly_tex, Rect2(sz.x * 0.82, sz.y * 0.35 + sin(_t * 0.8) * 20.0, 32 * 2.4, 44 * 2.4),
		Rect2(jf * 32, 0, 32, 44), Color(1, 1, 1, 0.8))
	# kabarcıklar
	for b in _bubbles:
		draw_arc(Vector2(b.x * sz.x + sin(_t * 2.0 + b.y * 9.0) * 4.0, b.y * sz.y), b.r, 0, TAU, 12,
			Color(0.85, 0.97, 1, 0.5), 1.2)
