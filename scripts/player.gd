class_name Player
extends CharacterBody2D
## Dalgıç oyuncu. Yerel oyuncu girdiyi okur ve konumunu yayınlar;
## uzaktaki oyuncular sadece ağdan gelen konuma doğru yumuşak ilerler.

const SPEED := 108.0
const ACCEL := 5.0
const SINK := 12.0
const BASE_OXYGEN := 60.0
const OXYGEN_PER_TANK := 30.0
const REACH_CELLS := 5.5
const TILE := 16.0
const SEND_INTERVAL := 0.05
const SURFACE_Y := 7.0          # dalgıç bundan yukarı çıkamaz (yüzeyde süzülür)
const STATION_RADIUS := 3       # oksijen istasyonu etki alanı (hücre)
const FRAME := 24

const SUIT_COLORS: Array[Color] = [
	Color("ff5a46"), Color("ffb42e"), Color("ffe14d"), Color("5ce67a"),
	Color("3ad1ff"), Color("5a7dff"), Color("b56bff"), Color("ff6fc4"),
]

var peer_id := 1
var is_local := false
var oxygen := BASE_OXYGEN
var display_name := "Dalgıç"
var suit_color := Color("3ad1ff")
var world: Node            # World (döngüsel bağımlılığı önlemek için tipsiz)

var net_pos := Vector2.ZERO
var net_vel := Vector2.ZERO

var _suit: Sprite2D
var _base: Sprite2D
var _visual: Node2D
var _light: PointLight2D
var _camera: Camera2D
var _bubbles: CPUParticles2D
var _label: Label
var _bubble_label: Label
var _bubble_time := 0.0
var _send_timer := 0.0
var _anim_t := 0.0
var _warned := false
var near_station := false

var _mine_cell := Vector2i(-9999, -9999)
var _mine_time := 0.0
var _pending_cell := Vector2i(-9999, -9999)
var _pending_timeout := 0.0
var _place_cooldown := 0.0
var _lmb_prev := false
var _rmb_prev := false
var _catch_cooldown := 0.0

static var _tex_base: Texture2D
static var _tex_suit: Texture2D


func setup(p_peer_id: int, p_world: Node, p_name: String, p_color: Color) -> void:
	peer_id = p_peer_id
	world = p_world
	display_name = p_name
	suit_color = p_color
	name = str(peer_id)
	set_multiplayer_authority(peer_id)


func _ready() -> void:
	# multiplayer ancak ağaca eklendikten sonra kullanılabilir
	is_local = peer_id == multiplayer.get_unique_id()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 15)
	shape.shape = rect
	add_child(shape)
	collision_layer = 2 if is_local else 0
	collision_mask = 1 if is_local else 0

	if _tex_base == null:
		_tex_base = load("res://assets/diver_base.png")
		_tex_suit = load("res://assets/diver_suit.png")
	_visual = Node2D.new()
	add_child(_visual)
	_suit = Sprite2D.new()
	_suit.texture = _tex_suit
	_suit.hframes = 8
	_suit.modulate = suit_color
	_visual.add_child(_suit)
	_base = Sprite2D.new()
	_base.texture = _tex_base
	_base.hframes = 8
	_visual.add_child(_base)

	var ls := LabelSettings.new()
	ls.font_size = 7
	ls.outline_size = 3
	ls.outline_color = Color(0, 0, 0, 0.8)
	ls.font_color = suit_color.lightened(0.45)
	_label = Label.new()
	_label.text = display_name
	_label.label_settings = ls
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-40, -27)
	_label.size = Vector2(80, 10)
	_label.z_index = 20
	add_child(_label)

	var bs := LabelSettings.new()
	bs.font_size = 7
	bs.font_color = Color(0.08, 0.1, 0.16)
	_bubble_label = Label.new()
	_bubble_label.label_settings = bs
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.92)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	_bubble_label.add_theme_stylebox_override("normal", sb)
	_bubble_label.z_index = 21
	_bubble_label.visible = false
	add_child(_bubble_label)

	_light = PointLight2D.new()
	_light.texture = Player.make_light_texture()
	_light.texture_scale = 1.7
	_light.energy = 0.8
	_light.color = Color(0.85, 0.95, 1.0)
	add_child(_light)

	_bubbles = CPUParticles2D.new()
	_bubbles.amount = 4
	_bubbles.lifetime = 2.4
	_bubbles.explosiveness = 0.75
	_bubbles.direction = Vector2(0, -1)
	_bubbles.spread = 20.0
	_bubbles.gravity = Vector2(0, -12)
	_bubbles.initial_velocity_min = 8.0
	_bubbles.initial_velocity_max = 16.0
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.1
	_bubbles.color = Color(0.85, 0.97, 1.0, 0.75)
	_bubbles.texture = Player._bubble_texture()
	_bubbles.position = Vector2(4, -10)
	add_child(_bubbles)

	net_pos = position
	if is_local:
		_camera = Camera2D.new()
		_camera.zoom = Vector2(2.5, 2.5)
		_camera.position_smoothing_enabled = true
		_camera.position_smoothing_speed = 8.0
		_camera.limit_left = 0
		_camera.limit_top = -int(Ambience.SKY_HEIGHT)
		_camera.limit_right = WorldGen.W * int(TILE)
		_camera.limit_bottom = WorldGen.H * int(TILE)
		add_child(_camera)
		_camera.make_current()


func server_pos() -> Vector2:
	return position if is_local else net_pos


func depth_row() -> float:
	return position.y / TILE


func speed_mult() -> float:
	return 1.0 + 0.2 * Inventory.level(world.inventory, Blocks.FINS) if is_local else 1.0


func max_oxygen() -> float:
	var lvl: int = Inventory.level(world.inventory, Blocks.TANK_UPGRADE) if is_local else 0
	return BASE_OXYGEN + OXYGEN_PER_TANK * lvl


func say(text: String) -> void:
	if not Settings.show_bubbles:
		return
	const MAX_W := 120.0
	var font := ThemeDB.fallback_font
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x + 8.0
	_bubble_label.text = text
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if tw > MAX_W else TextServer.AUTOWRAP_OFF
	var w := minf(tw, MAX_W)
	_bubble_label.custom_minimum_size = Vector2(w, 0)
	_bubble_label.size = Vector2(w, 0)
	_bubble_label.visible = true
	_bubble_time = 5.0


# --------------------------------------------------------------------------
# Ağ
# --------------------------------------------------------------------------

## Sahip konumunu sunucuya yollar; sunucu doğrulayıp diğerlerine aktarır.
## İstemciler yalnızca sunucudan (id 1) gelen durumu kabul eder.
@rpc("any_peer", "call_remote", "unreliable_ordered")
func net_state(pos: Vector2, vel: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		if sender != peer_id:
			return   # başkasının adına konum gönderilemez
		net_pos = pos
		net_vel = vel
		world.relay_state(peer_id, pos, vel)
	elif sender == 1:
		net_pos = pos
		net_vel = vel


# --------------------------------------------------------------------------
# Hareket ve etkileşim
# --------------------------------------------------------------------------

func _key(k: Key) -> bool:
	return Input.is_physical_key_pressed(k)


func _physics_process(delta: float) -> void:
	if not is_local:
		return
	var dir := Vector2.ZERO
	if not world.input_locked():
		dir = Vector2(
			float(_key(KEY_D) or _key(KEY_RIGHT)) - float(_key(KEY_A) or _key(KEY_LEFT)),
			float(_key(KEY_S) or _key(KEY_DOWN)) - float(_key(KEY_W) or _key(KEY_UP) or _key(KEY_SPACE)))
	var tc := _touch()
	if tc != null and not world.input_locked():
		dir += tc.move_vector()
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * SPEED * speed_mult()
	if dir == Vector2.ZERO:
		# yüzeye yakınken suyun üstüne süzül, derinde yavaşça bat
		target.y = -18.0 if position.y < 1.8 * TILE else SINK
	velocity = velocity.lerp(target, 1.0 - exp(-ACCEL * delta))
	move_and_slide()
	if position.y < SURFACE_Y:
		position.y = SURFACE_Y
		velocity.y = maxf(velocity.y, 0.0)

	_send_timer += delta
	if _send_timer >= SEND_INTERVAL:
		_send_timer = 0.0
		if multiplayer.is_server():
			world.relay_state(peer_id, position, velocity)
		else:
			net_state.rpc_id(1, position, velocity)


func _process(delta: float) -> void:
	_label.visible = Settings.show_names
	if is_local and _camera != null and not is_equal_approx(_camera.zoom.x, Settings.zoom):
		# yumuşak yakınlaştırma
		var z := lerpf(_camera.zoom.x, Settings.zoom, minf(1.0, delta * 14.0))
		if absf(z - Settings.zoom) < 0.005:
			z = Settings.zoom
		_camera.zoom = Vector2(z, z)
	if _bubble_time > 0.0:
		var bs := _bubble_label.get_combined_minimum_size()
		_bubble_label.size = bs
		_bubble_label.position = Vector2(-bs.x * 0.5, -29.0 - bs.y)
		_bubble_time -= delta
		_bubble_label.modulate.a = clampf(_bubble_time, 0.0, 1.0)
		if _bubble_time <= 0.0:
			_bubble_label.visible = false

	if not is_local:
		position = position.lerp(net_pos, 1.0 - exp(-14.0 * delta))
		_animate(net_vel, delta)
		_bubbles.emitting = net_pos.y / TILE > 1.5 and Settings.particles > 0
		return

	_animate(velocity, delta)
	_update_oxygen(delta)
	_update_light()
	if world.input_locked() or world.pointer_over_ui():
		_reset_mining()
		world.hover_ok = false
	else:
		_update_interaction(delta)


func _animate(vel: Vector2, delta: float) -> void:
	var speed := vel.length()
	var horizontal := absf(vel.x) > 40.0 and absf(vel.x) > absf(vel.y) * 0.8
	if absf(vel.x) > 5.0:
		var left := vel.x < 0.0
		_suit.flip_h = left
		_base.flip_h = left
	_anim_t += delta * (2.0 + speed / 14.0)
	var f := int(_anim_t) % 4
	var frame := (4 + f) if horizontal else (f if speed > 12.0 else (int(_anim_t * 0.4) % 2) * 2)
	_suit.frame = frame
	_base.frame = frame
	var target_rot := 0.0
	if horizontal:
		_visual.position = Vector2(0, 2)
		var tilt := clampf(vel.y / maxf(absf(vel.x), 1.0), -0.6, 0.6)
		target_rot = tilt if vel.x > 0 else -tilt
	else:
		_visual.position = Vector2(0, -4)
		target_rot = clampf(vel.x / SPEED * 0.25, -0.25, 0.25)
	_visual.rotation = lerp_angle(_visual.rotation, target_rot, 1.0 - exp(-10.0 * delta))
	_bubbles.position.x = -4.0 if _suit.flip_h else 4.0


func _update_oxygen(delta: float) -> void:
	var row := depth_row()
	var maxo := max_oxygen()
	near_station = _station_nearby()
	if row < 1.5 or near_station:
		oxygen = minf(maxo, oxygen + 25.0 * delta)
		_warned = false
	else:
		oxygen -= delta * (1.0 + row / 100.0)
	_bubbles.emitting = row > 1.5 and Settings.particles > 0
	if oxygen < maxo * 0.25 and not _warned:
		_warned = true
		world.play_ui("warn")
	if oxygen <= 0.0:
		respawn("Nefesin tükendi! Yüzeye döndün.")


func _station_nearby() -> bool:
	var c: Vector2i = world.cell_at(position)
	for dy in range(-STATION_RADIUS, STATION_RADIUS + 1):
		for dx in range(-STATION_RADIUS, STATION_RADIUS + 1):
			if world.get_cell_id(c + Vector2i(dx, dy)) == Blocks.OXYGEN:
				return true
	return false


func respawn(message: String) -> void:
	world.report_death()
	position = world.spawn_pos()
	velocity = Vector2.ZERO
	net_pos = position
	oxygen = max_oxygen()
	_camera.reset_smoothing()
	world.toast(message)


## Yılanbalığı çarptı: oksijen kaybı ve geri itilme
func shock(from: Vector2, kind := "shock") -> void:
	if Settings.vibration and Settings.is_mobile():
		Input.vibrate_handheld(220)
	var bite := kind == "bite"
	oxygen = maxf(0.5, oxygen - (16.0 if bite else 12.0))
	var away := (position - from)
	if away.length() < 0.1:
		away = Vector2.UP
	velocity += away.normalized() * (220.0 if bite else 170.0)
	world.play_ui("shock" if not bite else "break")
	if world.hud != null:
		world.hud.flash(Color(1.0, 0.95, 0.4) if not bite else Color(1.0, 0.15, 0.1))
		world.toast("Köpekbalığı ısırdı!  -16 sn oksijen" if bite else "Elektrik çarptı!  -12 sn oksijen")


func _update_light() -> void:
	var t := clampf(depth_row() / float(WorldGen.LAYER_ABYSS), 0.0, 1.0)
	var lvl := Inventory.level(world.inventory, Blocks.HELMET)
	_light.energy = lerpf(0.3, 1.1, t) + 0.15 * lvl
	_light.texture_scale = lerpf(0.9, 1.35, t) * (1.0 + 0.35 * lvl)


func _reach_ok(cell: Vector2i) -> bool:
	var c: Vector2 = world.cell_center(cell)
	return c.distance_to(position) <= REACH_CELLS * TILE


func _update_interaction(delta: float) -> void:
	_place_cooldown = maxf(0.0, _place_cooldown - delta)
	if _pending_timeout > 0.0:
		_pending_timeout -= delta
		if _pending_timeout <= 0.0:
			_pending_cell = Vector2i(-9999, -9999)

	_catch_cooldown = maxf(0.0, _catch_cooldown - delta)
	var mouse := get_global_mouse_position()
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var tc := _touch()
	if tc != null:
		# dokunmatik: dokunulan nokta işaretçi; moda göre kır ya da koy, canlıya dokunmak yakalar
		mouse = tc.world_point()
		var on_creature: bool = tc.pressed() and world.wildlife.creature_at(mouse, 14.0) >= 0
		lmb = tc.pressed() and (tc.mode == "break" or on_creature)
		rmb = tc.pressed() and tc.mode == "place" and not on_creature
		if not tc.pressed():
			world.hover_ok = false
			world.hover_creature = -1
	var lmb_down := lmb and not _lmb_prev
	var rmb_down := rmb and not _rmb_prev
	_lmb_prev = lmb
	_rmb_prev = rmb

	# Canlı yakalama: fare bir canlının üstündeyse tıklama yakalama denemesidir.
	# Basış bir bloğun üstünde başladıysa, yanından canlı geçse bile kırma sürer
	# (yoksa mağara tabanındaki yengeçler sandık kırmayı sürekli sıfırlıyordu).
	var cid: int = world.wildlife.creature_at(mouse, 14.0 if tc != null else 11.0)
	var creature_ok: bool = cid >= 0 and world.wildlife.view_pos(cid).distance_to(position) <= world.CATCH_RANGE * TILE
	if lmb_down:
		_press_on_creature = creature_ok
	if lmb and not _press_on_creature and not lmb_down:
		creature_ok = false
	if creature_ok:
		world.hover_creature = cid
		world.hover_ok = false
		_reset_mining()
		if lmb_down and _catch_cooldown <= 0.0:
			_catch_cooldown = 0.35
			if not world.has_net():
				world.toast("Yakalamak için önce Ağ üret (C)")
			else:
				world.request_catch(cid)
		return
	world.hover_creature = -1

	var cell: Vector2i = world.cell_at(mouse)
	world.hover_cell = cell
	var in_reach: bool = world.in_bounds(cell) and _reach_ok(cell)
	world.hover_ok = in_reach and (tc == null or tc.pressed())

	# Akvaryuma sağ tık: içine canlı koyma penceresi
	if rmb_down and in_reach and world.get_cell_id(cell) == Blocks.AQUARIUM and world.hud != null:
		world.hud.open_aquarium(cell)
		return

	# Kırma
	var breaking := lmb
	if breaking and in_reach:
		var id: int = world.get_cell_id(cell)
		if Blocks.is_breakable(id) and cell != _pending_cell:
			if cell != _mine_cell:
				_mine_cell = cell
				_mine_time = 0.0
			_mine_time += delta
			var need: float = Blocks.DEFS[id]["hardness"]
			world.crack = clampf(_mine_time / need, 0.0, 1.0)
			if _mine_time >= need:
				world.request_break(cell)
				_pending_cell = cell
				_pending_timeout = 0.4
				_mine_cell = Vector2i(-9999, -9999)
				world.crack = 0.0
		else:
			_reset_mining()
	else:
		_reset_mining()

	# Koyma
	if rmb and in_reach and _place_cooldown <= 0.0:
		var existing: int = world.get_cell_id(cell)
		var item: int = world.selected_block()
		if Blocks.PLACEABLE.has(item) and Blocks.is_replaceable(existing) and existing != item \
				and (not Blocks.is_solid(item) or not _overlaps_self(cell)):
			world.request_place(cell, world.selected_slot)
			_place_cooldown = 0.12


var _press_on_creature := false


func _touch() -> TouchControls:
	if world.hud == null:
		return null
	return world.hud.touch


func _reset_mining() -> void:
	_mine_cell = Vector2i(-9999, -9999)
	_mine_time = 0.0
	world.crack = 0.0


func _overlaps_self(cell: Vector2i) -> bool:
	var cell_rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	var body := Rect2(position - Vector2(5, 7.5), Vector2(10, 15))
	return cell_rect.intersects(body)


# --------------------------------------------------------------------------
# Yardımcı dokular
# --------------------------------------------------------------------------

static var _light_tex: Texture2D
static var _bub_tex: Texture2D


static func make_light_texture() -> Texture2D:
	if _light_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.22, 0.6, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.72, 0.72, 0.72, 1),
			Color(0.2, 0.2, 0.2, 1), Color(0, 0, 0, 1)])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.width = 256
		tex.height = 256
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		_light_tex = tex
	return _light_tex


static func _bubble_texture() -> Texture2D:
	if _bub_tex == null:
		var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var ring := Color(1, 1, 1, 0.9)
		for p in [Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(0, 1), Vector2i(4, 1),
				Vector2i(0, 2), Vector2i(4, 2), Vector2i(0, 3), Vector2i(4, 3),
				Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4)]:
			img.set_pixelv(p, ring)
		img.set_pixel(1, 1, Color(1, 1, 1, 1))
		_bub_tex = ImageTexture.create_from_image(img)
	return _bub_tex
