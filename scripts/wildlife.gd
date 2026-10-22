class_name Wildlife
extends Node2D
## Yakalanabilir canlılar. Sunucu canlıları üretir, hareket ettirir ve
## konumlarını istemcilere yollar; istemciler sadece görüntüler.
## Yakalama ve yılanbalığı çarpması sunucuda karar verilir.

const TILE := 16.0
const PER_PLAYER := 7
const MAX_TOTAL := 40
const SPAWN_MIN := 10.0       # hücre
const SPAWN_MAX := 24.0
const NEAR := 30.0            # bu yarıçaptakiler oyuncunun "çevresi" sayılır
const DESPAWN := 46.0
const SYNC_SEC := 0.12
const SHOCK_RANGE := 20.0     # piksel
const SHOCK_COOLDOWN := 2.2
const AGGRO_RANGE := 7.0 * 16.0

var world: Node               # World
var _server := false
var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _spawn_timer := 0.0
var _sync_timer := 0.0

# Sunucu: id -> {sp, pos, vel, t, cool}
var _c := {}
# İstemci görüntüsü: id -> {node, target, sp, t, light, prev}
var _view := {}


func _ready() -> void:
	name = "Wildlife"
	_server = multiplayer.is_server()
	_rng.randomize()
	z_index = -2


func _process(delta: float) -> void:
	if _server and world.loaded:
		_server_tick(delta)
	if not world.dedicated:
		_view_tick(delta)


# --------------------------------------------------------------------------
# Sunucu
# --------------------------------------------------------------------------

func _server_tick(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 0.8
		_maintain()
	var players: Array = world.server_positions()
	for id in _c.keys():
		_step(_c[id], delta, players)
	_shock_check(delta, players)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = SYNC_SEC
		_sync()


func _blocked(p: Vector2) -> bool:
	var id: int = world.get_cell_id(Vector2i(floori(p.x / TILE), floori(p.y / TILE)))
	return Blocks.is_solid(id) or p.y < 20.0


func _maintain() -> void:
	var players: Array = world.server_positions()
	# uzaktakileri sil
	for id in _c.keys():
		var pos: Vector2 = _c[id].pos
		var near := false
		for pl in players:
			if (pl[1] as Vector2).distance_to(pos) < DESPAWN * TILE:
				near = true
				break
		if not near:
			_c.erase(id)
	# her oyuncunun çevresini doldur
	for pl in players:
		if _c.size() >= MAX_TOTAL:
			return
		var ppos: Vector2 = pl[1]
		var count := 0
		for id in _c.keys():
			if (_c[id].pos as Vector2).distance_to(ppos) < NEAR * TILE:
				count += 1
		if count < PER_PLAYER:
			_try_spawn(ppos)


func _try_spawn(around: Vector2) -> void:
	for attempt in 8:
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(SPAWN_MIN, SPAWN_MAX) * TILE
		var p := around + Vector2(cos(ang), sin(ang)) * dist
		var cell := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
		if not world.in_bounds(cell) or cell.y < 2:
			continue
		if world.get_cell_id(cell) != Blocks.AIR:
			continue
		var sp := Species.pick_for_row(cell.y, _rng)
		if sp < 0:
			continue
		spawn(sp, world.cell_center(cell))
		return


## Sunucu: belirli bir canlı üret (testler de kullanır). id döner.
func spawn(sp: int, pos: Vector2) -> int:
	var id := _next_id
	_next_id += 1
	var d := Species.get_def(sp)
	var dir := -1.0 if _rng.randf() < 0.5 else 1.0
	_c[id] = {"sp": sp, "pos": pos, "vel": Vector2(dir * float(d["speed"]), 0), "t": _rng.randf() * 10.0,
		"cool": 0.0}
	return id


func _nearest_player(pos: Vector2, players: Array) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for pl in players:
		var d := (pl[1] as Vector2).distance_to(pos)
		if d < bd:
			bd = d
			best = pl[1]
	return best


func _step(c: Dictionary, delta: float, players: Array) -> void:
	var d := Species.get_def(c.sp)
	var speed: float = d["speed"]
	c.t += delta
	var vel: Vector2 = c.vel
	match d["move"]:
		"swim":
			var dir := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
			vel.x = lerpf(vel.x, dir * speed, delta * 2.0)
			vel.y = sin(c.t * 1.3) * speed * 0.25
			if int(d["rarity"]) >= 2:
				var np := _nearest_player(c.pos, players)
				if np != Vector2.INF and np.distance_to(c.pos) < 40.0:
					vel = vel.lerp((c.pos - np).normalized() * speed * 2.0, 0.2)   # nadirler kaçar
		"hover":
			vel = Vector2(sin(c.t * 0.5) * speed, sin(c.t * 0.9) * speed * 0.7)
		"jelly":
			var phase := fmod(c.t, 2.4)
			vel.x = lerpf(vel.x, sin(c.t * 0.3) * speed * 0.4, delta)
			vel.y = -speed * 1.4 if phase < 0.5 else lerpf(vel.y, speed * 0.3, delta * 1.5)
		"bottom", "glide":
			# dibe yakın yüz: altında zemin yoksa yavaşça in
			var dir3 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
			vel.x = lerpf(vel.x, dir3 * speed, delta * 2.0)
			var floor_near := _blocked(c.pos + Vector2(0, 24)) or _blocked(c.pos + Vector2(0, 40))
			var wave := sin(c.t * (1.6 if d["move"] == "glide" else 1.0)) * speed * 0.2
			vel.y = wave + (0.0 if floor_near else speed * 0.6)
		"crawl":
			# zeminde yürü; zemin yoksa düş, önü uçurumsa dön
			var dir4 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
			if not _blocked(c.pos + Vector2(0, 10)):
				vel = Vector2(vel.x * 0.5, 50.0)
			else:
				if not _blocked(c.pos + Vector2(dir4 * 10.0, 12)):
					dir4 = -dir4
				vel = Vector2(dir4 * speed, 0.0)
				if fmod(c.t, 6.0) < 1.5:
					vel.x = 0.0          # ara sıra dur
		"puffer", "drift":
			var dir5 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
			vel.x = lerpf(vel.x, dir5 * speed, delta)
			vel.y = sin(c.t * 0.5) * speed * 0.5
		"shark":
			var np3 := _nearest_player(c.pos, players)
			if np3 != Vector2.INF and np3.distance_to(c.pos) < AGGRO_RANGE * 1.3 and fmod(c.t, 9.0) < 6.0:
				vel = vel.lerp((np3 - c.pos).normalized() * speed * 1.2, delta * 2.0)
			else:
				var dir6 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
				vel.x = lerpf(vel.x, dir6 * speed * 0.6, delta)
				vel.y = sin(c.t * 0.4) * speed * 0.15
		"ribbon":
			# uzun gövdeli, saldırmayan dalgalı yüzüş
			var dir7 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
			vel.x = lerpf(vel.x, dir7 * speed, delta * 1.5)
			vel.y = sin(c.t * 0.6) * speed * 0.35
		"eel":
			var np2 := _nearest_player(c.pos, players)
			if np2 != Vector2.INF and np2.distance_to(c.pos) < AGGRO_RANGE:
				vel = vel.lerp((np2 - c.pos).normalized() * speed * 1.3, delta * 3.0)
			else:
				var dir2 := signf(vel.x) if absf(vel.x) > 0.1 else 1.0
				vel.x = lerpf(vel.x, dir2 * speed, delta * 2.0)
				vel.y = sin(c.t * 0.9) * speed * 0.3
	var next: Vector2 = c.pos + vel * delta
	if _blocked(next + Vector2(signf(vel.x) * 6.0, 0)) or _blocked(next):
		vel = Vector2(-vel.x, -vel.y * 0.6)
		if _blocked(c.pos):
			vel.y = -speed      # içine blok konduysa yukarı kaç
			next = c.pos + Vector2(0, -16.0 * delta * 4.0)
		else:
			next = c.pos
	c.vel = vel
	c.pos = next
	c.cool = maxf(0.0, c.cool - delta)


func _shock_check(_delta: float, players: Array) -> void:
	for id in _c.keys():
		var c: Dictionary = _c[id]
		if not Species.get_def(c.sp).get("hostile", false) or c.cool > 0.0:
			continue
		for pl in players:
			var rng_: float = SHOCK_RANGE * (1.6 if c.sp == 220 else 1.0)
			if (pl[1] as Vector2).distance_to(c.pos) < rng_:
				c.cool = SHOCK_COOLDOWN
				world.server_shock(pl[0], c.pos, Species.get_def(c.sp).get("attack", "shock"))
				break


func _sync() -> void:
	var ids := PackedInt32Array()
	var sps := PackedInt32Array()
	var poss := PackedVector2Array()
	for id in _c.keys():
		ids.append(id)
		sps.append(_c[id].sp)
		poss.append(_c[id].pos)
	for peer in world.joined_peers():
		if peer != 1:
			wl_state.rpc_id(peer, ids, sps, poss)
	if not world.dedicated:
		_apply_state(ids, sps, poss)


## Sunucu: yakalama denemesi. Başarılıysa tür id'si, değilse -1.
func try_catch(id: int, from: Vector2, max_dist: float) -> int:
	if not _c.has(id):
		return -1
	var c: Dictionary = _c[id]
	if (c.pos as Vector2).distance_to(from) > max_dist:
		return -1
	_c.erase(id)
	return c.sp


func count() -> int:
	return _c.size() if _server else _view.size()


func server_creatures() -> Dictionary:
	return _c


# --------------------------------------------------------------------------
# İstemci görüntüsü
# --------------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func wl_state(ids: PackedInt32Array, sps: PackedInt32Array, poss: PackedVector2Array) -> void:
	_apply_state(ids, sps, poss)


func _apply_state(ids: PackedInt32Array, sps: PackedInt32Array, poss: PackedVector2Array) -> void:
	var seen := {}
	for i in ids.size():
		var id := ids[i]
		seen[id] = true
		if not _view.has(id):
			_view[id] = _make_view(sps[i], poss[i])
		_view[id].target = poss[i]
	for id in _view.keys():
		if not seen.has(id):
			(_view[id].node as Node).queue_free()
			_view.erase(id)


func _make_view(sp: int, pos: Vector2) -> Dictionary:
	var d := Species.get_def(sp)
	var s := Sprite2D.new()
	s.texture = Species.texture(sp)
	s.hframes = int(d["frames"])
	s.vframes = maxi(1, int(s.texture.get_height() / int(d["fh"])))
	s.frame = int(d["row"]) * int(d["frames"])
	s.modulate = Species.tint(sp)
	s.position = pos
	s.scale = Vector2(Species.DRAW_SCALE, Species.DRAW_SCALE)
	add_child(s)
	var inv_s := 1.0 / Species.DRAW_SCALE     # çocuk düğümler ölçeği telafi eder
	var light: PointLight2D = null
	if d.has("light"):
		light = PointLight2D.new()
		light.texture = Player.make_light_texture()
		light.texture_scale = (0.55 if sp == 223 else 0.32) * inv_s
		light.energy = 1.1
		light.color = d["light"]
		light.position = d.get("light_offset", Vector2.ZERO) * inv_s
		s.add_child(light)
	if not world.dedicated and DisplayServer.get_name() != "headless" and Settings.particles > 0:
		var sparkle := CPUParticles2D.new()
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # karanlıkta da görünsün
		sparkle.material = mat
		sparkle.amount = 4
		sparkle.lifetime = 1.4
		sparkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		sparkle.emission_sphere_radius = 7.0 * inv_s
		sparkle.gravity = Vector2(0, -6)
		sparkle.initial_velocity_min = 0.0
		sparkle.initial_velocity_max = 3.0
		sparkle.scale_amount_min = 1.0 * inv_s
		sparkle.scale_amount_max = 1.6 * inv_s
		sparkle.gravity = Vector2(0, -6) * inv_s
		sparkle.initial_velocity_max = 3.0 * inv_s
		var hostile: bool = d.get("hostile", false)
		var g := Gradient.new()
		var col := Color(1.0, 0.95, 0.45) if not hostile else Color(1.0, 0.95, 0.2)
		if int(d.get("rarity", 0)) == 5:
			col = Color(0.95, 0.55, 1.0)       # mitik: mor parıltı
			sparkle.amount = 10
		g.colors = PackedColorArray([Color(col, 0.0), Color(col, 0.9), Color(col, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		sparkle.color_ramp = g
		s.add_child(sparkle)
	return {"node": s, "target": pos, "sp": sp, "t": randf() * 10.0, "light": light}


func _view_tick(delta: float) -> void:
	for id in _view.keys():
		var v: Dictionary = _view[id]
		var s: Sprite2D = v.node
		var d := Species.get_def(v.sp)
		v.t += delta
		var before := s.position
		s.position = s.position.lerp(v.target, 1.0 - exp(-10.0 * delta))
		var dx := s.position.x - before.x
		if absf(dx) > 0.05:
			s.flip_h = dx < 0.0
			if v.light != null and d.has("light_offset"):
				var ox: float = absf(d["light_offset"].x) / Species.DRAW_SCALE
				(v.light as PointLight2D).position.x = -ox if s.flip_h else ox
		var frames := int(d["frames"])
		var fps := 3.0 if d["move"] in ["jelly", "drift"] else (4.0 if d["move"] in ["crawl", "glide"] else 6.0)
		var f := int(v.t * fps) % frames
		if d["move"] == "puffer":
			# yakında oyuncu varsa şişer (son iki kare)
			var near := false
			for pl in world.players():
				if (pl as Node2D).position.distance_to(s.position) < 50.0:
					near = true
			f = (2 if near else 0) + int(v.t * 3.0) % 2
		s.frame = int(d["row"]) * frames + f
		if int(d.get("rarity", 0)) == 5:
			# mitik: renkten renge geçen parıltı
			s.modulate = Color.from_hsv(fmod(v.t * 0.15, 1.0), 0.12, 1.2)
		elif d.get("attack", "") == "shock":
			# elektrik titremesi
			s.modulate = Color(1, 1, 1) if int(v.t * 10.0) % 7 != 0 else Color(1.8, 1.8, 0.6)


## İstemci: fare konumundaki canlı (id) ya da -1.
func creature_at(p: Vector2, radius := 11.0) -> int:
	var best := -1
	var bd := radius
	for id in _view.keys():
		var d := (_view[id].node as Node2D).position.distance_to(p)
		if d < bd:
			bd = d
			best = id
	return best


func view_pos(id: int) -> Vector2:
	if _view.has(id):
		return (_view[id].node as Node2D).position
	return Vector2.INF


func view_species(id: int) -> int:
	return _view[id].sp if _view.has(id) else -1
