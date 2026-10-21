class_name Ambience
extends Node2D
## Görsel ortam: gökyüzü, dalgalı su yüzeyi, ışık huzmeleri, deniz karı.
## Sadece istemcide çalışır, ağ ile ilgisi yoktur.

const TILE := 16.0
const SKY_HEIGHT := 140.0

var _rays: Node2D
var _snow: CPUParticles2D
var _time := 0.0


func _ready() -> void:
	z_index = -50
	_rays = Node2D.new()
	_rays.z_index = 60          # blokların önünde, hafif
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_rays.material = mat
	_rays.draw.connect(_draw_rays)
	add_child(_rays)

	_snow = CPUParticles2D.new()
	_snow.z_index = 55
	_snow.local_coords = false
	_snow.amount = 90
	_snow.lifetime = 9.0
	_snow.preprocess = 9.0
	_snow.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_snow.emission_rect_extents = Vector2(300, 170)
	_snow.direction = Vector2(0.2, 1)
	_snow.spread = 40.0
	_snow.gravity = Vector2(0, 2)
	_snow.initial_velocity_min = 2.0
	_snow.initial_velocity_max = 7.0
	_snow.scale_amount_min = 0.6
	_snow.scale_amount_max = 1.2
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0), Color(0.85, 0.95, 1, 0.45),
		Color(0.85, 0.95, 1, 0.45), Color(1, 1, 1, 0)])
	_snow.color_ramp = grad
	add_child(_snow)


func _process(delta: float) -> void:
	_rays.visible = Settings.rays
	_snow.visible = Settings.snow
	_snow.emitting = Settings.snow
	_snow.amount = 90 if Settings.particles == 2 else 40
	_time += delta
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		_snow.global_position = cam.get_screen_center_position()
	queue_redraw()
	_rays.queue_redraw()


func _view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if cam == null:
		return Rect2(Vector2.ZERO, size)
	var s := size / cam.zoom
	return Rect2(cam.get_screen_center_position() - s * 0.5, s)


func _draw() -> void:
	var view := _view_rect()
	if view.position.y > 40.0:
		return       # yüzey görünmüyor
	var x0 := view.position.x - 20.0
	var x1 := view.end.x + 20.0
	# gökyüzü
	var sky_top := Color("8fd3ff")
	var sky_bot := Color("d8f1ff")
	draw_polygon(PackedVector2Array([
		Vector2(x0, -SKY_HEIGHT), Vector2(x1, -SKY_HEIGHT), Vector2(x1, 0), Vector2(x0, 0)]),
		PackedColorArray([sky_top, sky_top, sky_bot, sky_bot]))
	# güneş
	var sun := Vector2(WorldGen.W * TILE * 0.72, -SKY_HEIGHT * 0.55)
	draw_circle(sun, 20.0, Color(1, 0.97, 0.8, 0.35))
	draw_circle(sun, 12.0, Color(1, 0.98, 0.85))
	# bulutlar
	for i in 6:
		var cx := fposmod(i * 340.0 + _time * 4.0, WorldGen.W * TILE + 200.0) - 100.0
		var cy := -SKY_HEIGHT * (0.3 + 0.12 * (i % 3))
		if cx > x0 - 60 and cx < x1 + 60:
			for k in 4:
				draw_circle(Vector2(cx + k * 9.0, cy - (6.0 if k in [1, 2] else 0.0)), 8.0 + (k % 2) * 3.0,
					Color(1, 1, 1, 0.85))
	# su yüzeyi: dalgalı çizgi ve altında parlak bant
	var pts := PackedVector2Array()
	var x := x0
	while x <= x1:
		pts.append(Vector2(x, _wave(x)))
		x += 4.0
	var band := PackedVector2Array(pts)
	var cols := PackedColorArray()
	for i in pts.size():
		cols.append(Color(0.75, 0.95, 1.0, 0.35))
	for i in range(pts.size() - 1, -1, -1):
		band.append(Vector2(pts[i].x, 28.0))
		cols.append(Color(0.75, 0.95, 1.0, 0.0))
	draw_polygon(band, cols)
	# yüzeyin üstündeki su (dalga ile gökyüzü arası)
	var top := PackedVector2Array(pts)
	top.append(Vector2(x1, 4))
	top.append(Vector2(x0, 4))
	draw_polyline(pts, Color(0.95, 1.0, 1.0, 0.9), 1.5)
	for i in pts.size():
		if i % 7 == 0:
			draw_rect(Rect2(pts[i] + Vector2(0, 2), Vector2(2, 1)), Color(1, 1, 1, 0.6))


func _wave(x: float) -> float:
	return sin(x * 0.045 + _time * 1.6) * 1.6 + sin(x * 0.11 - _time * 2.3) * 0.8 - 1.0


func _draw_rays() -> void:
	var view := _view_rect()
	var max_y := 46.0 * TILE
	if view.position.y > max_y:
		return
	var strength := 1.0 - clampf(view.get_center().y / max_y, 0.0, 1.0)
	for i in 9:
		var base_x := i * 230.0 + 60.0 + sin(_time * 0.21 + i * 1.7) * 30.0
		if base_x < view.position.x - 300.0 or base_x > view.end.x + 300.0:
			continue
		var w := 14.0 + (i * 37 % 4) * 8.0
		var lean := 0.38 + (i % 3) * 0.06
		var flick := 0.6 + 0.4 * sin(_time * 0.9 + i * 2.3)
		var a := 0.13 * flick * strength
		var length := 34.0 * TILE
		var p0 := Vector2(base_x, 0)
		var p1 := Vector2(base_x + w, 0)
		var p2 := Vector2(base_x + w * 2.2 + length * lean, length)
		var p3 := Vector2(base_x + length * lean, length)
		_rays.draw_polygon(PackedVector2Array([p0, p1, p2, p3]), PackedColorArray([
			Color(0.75, 0.95, 1.0, a), Color(0.75, 0.95, 1.0, a),
			Color(0.75, 0.95, 1.0, 0.0), Color(0.75, 0.95, 1.0, 0.0)]))
