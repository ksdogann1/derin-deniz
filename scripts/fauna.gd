class_name Fauna
extends Node2D
## Kamera çevresinde yüzen süs canlıları (balık sürüleri, denizanası,
## fener balığı, kaplumbağa). Her istemci kendi canlılarını üretir,
## ağ üzerinden eşitlenmez; oyunu etkilemezler.

const TILE := 16.0
const MAX_FISH := 26
const MAX_JELLY := 6
const MAX_ANGLER := 3
const MAX_TURTLE := 1

var world: Node      # World
var _tex := {}
var _list: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0


func _ready() -> void:
	_rng.randomize()
	z_index = -1


func _view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	if cam == null:
		return Rect2(Vector2.ZERO, size)
	var s := size / cam.zoom
	return Rect2(cam.get_screen_center_position() - s * 0.5, s)


func _count(kind: String) -> int:
	var n := 0
	for c in _list:
		if c.kind == kind:
			n += 1
	return n


func _free_cell_near(view: Rect2, min_row: int, max_row: int) -> Vector2:
	# Ekranın biraz dışında boş bir su hücresi bul
	for i in 12:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var x := view.get_center().x + side * (view.size.x * 0.5 + _rng.randf_range(20, 90))
		var y := _rng.randf_range(view.position.y, view.end.y)
		var c := Vector2i(int(x / TILE), int(y / TILE))
		if c.y < max(min_row, 1) or c.y > max_row:
			continue
		if world.get_cell_id(c) == Blocks.AIR and world.get_cell_id(c + Vector2i(1, 0)) == Blocks.AIR:
			return Vector2(x, y)
	return Vector2.INF


func _process(delta: float) -> void:
	var view := _view_rect()
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.6
		_try_spawn(view)
	var keep := view.grow(view.size.x * 0.9)
	for i in range(_list.size() - 1, -1, -1):
		var c: Dictionary = _list[i]
		if not keep.has_point(c.node.position):
			c.node.queue_free()
			_list.remove_at(i)
			continue
		_step(c, delta)


func _try_spawn(view: Rect2) -> void:
	var row := int(view.get_center().y / TILE)
	if row < WorldGen.LAYER_MIDNIGHT and _count("fish") < int(MAX_FISH * Settings.fauna):
		var p := _free_cell_near(view, 2, WorldGen.LAYER_MIDNIGHT)
		if p != Vector2.INF:
			# süs sürüleri yakalanabilir türlerin çizimlerini kullanır (parıltısız)
			var pool := [200, 201, 202, 203, 213, 214]
			if row > WorldGen.LAYER_TWILIGHT:
				pool = [202, 203]
			var variant: int = pool[_rng.randi_range(0, pool.size() - 1)]
			var school := _rng.randi_range(3, 7)
			var dir := 1.0 if p.x < view.get_center().x else -1.0
			for k in school:
				_add_fish(p + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-10, 10)), variant, dir)


func _sprite(tex_name: String, hframes: int, vframes := 1) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _tex[tex_name]
	s.hframes = hframes
	s.vframes = vframes
	add_child(s)
	return s


func _light(parent: Node2D, color: Color, scale_: float, energy: float, offset := Vector2.ZERO) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = Player.make_light_texture()
	l.texture_scale = scale_
	l.color = color
	l.energy = energy
	l.position = offset
	parent.add_child(l)
	return l


func _add_fish(pos: Vector2, sp: int, dir: float) -> void:
	var s := Sprite2D.new()
	s.texture = Species.texture(sp)
	s.hframes = 4
	s.scale = Vector2(Species.DRAW_SCALE, Species.DRAW_SCALE) * 0.8     # sürü balıkları biraz küçük
	s.modulate = Color(0.85, 0.9, 0.95)
	add_child(s)
	s.position = pos
	_list.append({"kind": "fish", "node": s, "vel": Vector2(dir * _rng.randf_range(22, 34), 0),
		"base": 0, "t": _rng.randf() * 10.0, "speed": _rng.randf_range(22, 34)})


func _add_jelly(pos: Vector2) -> void:
	var s := _sprite("jelly", 4)
	s.position = pos
	var deep := pos.y / TILE > WorldGen.LAYER_MIDNIGHT
	if deep:
		s.modulate = Color(0.7, 0.9, 1.6)
		_light(s, Color(0.6, 0.5, 1.0), 0.32, 0.8)
	_list.append({"kind": "jelly", "node": s, "vel": Vector2(_rng.randf_range(-4, 4), -6),
		"t": _rng.randf() * 10.0})


func _add_angler(pos: Vector2) -> void:
	var s := _sprite("angler", 2)
	s.position = pos
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	var lure := _light(s, Color(0.4, 1.0, 0.85), 0.28, 1.4, Vector2(7, -4))
	_list.append({"kind": "angler", "node": s, "vel": Vector2(dir * 9.0, 0), "t": 0.0, "lure": lure})


func _add_turtle(pos: Vector2, dir: float) -> void:
	var s := _sprite("turtle", 2)
	s.position = pos
	_list.append({"kind": "turtle", "node": s, "vel": Vector2(dir * 14.0, 0), "t": 0.0})


func _blocked(p: Vector2) -> bool:
	var id: int = world.get_cell_id(Vector2i(floori(p.x / TILE), floori(p.y / TILE)))
	return Blocks.is_solid(id) or p.y < 10.0


func _step(c: Dictionary, delta: float) -> void:
	var s: Sprite2D = c.node
	c.t += delta
	var vel: Vector2 = c.vel
	match c.kind:
		"fish":
			vel.y = sin(c.t * 1.7) * 6.0
			s.frame = int(c.t * 8.0) % 4
			var player: Node2D = world.local_player()
			if player != null and player.position.distance_to(s.position) < 34.0:
				var away: Vector2 = (s.position - player.position).normalized()
				vel = vel.lerp(away * 80.0, 0.15)     # dalgıçtan kaç
			else:
				var cruise := Vector2(signf(vel.x if absf(vel.x) > 1 else 1.0) * c.speed, vel.y)
				vel = vel.lerp(cruise, 0.03)
		"jelly":
			var phase := fmod(c.t, 2.4)
			s.frame = clampi(int(phase / 0.3), 0, 3) if phase < 1.2 else 0
			vel.y = -14.0 if phase < 0.5 else lerpf(vel.y, 5.0, delta * 1.2)
		"angler":
			s.frame = int(c.t * 2.0) % 2
			vel.y = sin(c.t * 0.6) * 4.0
			(c.lure as PointLight2D).energy = 1.2 + 0.5 * sin(c.t * 3.0)
		"turtle":
			s.frame = int(c.t * 2.5) % 2
			vel.y = sin(c.t * 0.5) * 5.0
	var ahead := s.position + Vector2(signf(vel.x) * 10.0, vel.y * 0.3)
	if _blocked(ahead):
		vel.x = -vel.x
		vel.y = -vel.y * 0.5
		if _blocked(s.position + vel * delta * 4.0):
			vel = Vector2(-vel.x, -10.0)
	c.vel = vel
	s.position += vel * delta
	if absf(vel.x) > 0.5:
		var left := vel.x < 0.0
		s.flip_h = left
		if c.kind == "angler" and c.has("lure"):
			(c.lure as PointLight2D).position.x = -7.0 if left else 7.0
