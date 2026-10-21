class_name World
extends Node2D

signal leave_requested
## Oyun dünyası. Sunucu yetkilidir: blok kırma/koyma, üretim, sohbet ve
## envanter sunucuda doğrulanır, sonuç herkese yayınlanır. İstemciler
## görüntüler ve istek gönderir.

const TILE := 16
const MAX_REACH_CELLS := 7.5        # sunucu toleransı (istemci 5.5 kullanır)
const START_INVENTORY := {Blocks.LAMP: 4, Blocks.GLASS: 8, Blocks.OXYGEN: 1}
const AUTOSAVE_SEC := 60.0
const MAX_LIGHTS := 64        # havuz; kullanılan sayı Ayarlar > Işık sayısı
const CHAT_MAX := 120
const WALL_TINT := Color(0.27, 0.31, 0.4)
const BAG_MAX := 5
const CATCH_RANGE := 4.0           # hücre (istemci)
const SERVER_CATCH_RANGE := 6.0    # hücre (sunucu toleransı)
const MILESTONES := [[60, 3], [140, 6], [230, 10], [290, 15]]   # [satır, inci]

var cells := PackedByteArray()
var walls := PackedByteArray()
var dedicated := false
var player_name := "Dalgıç"
var player_color := Color("3ad1ff")
var world_name := "okyanus"

# Yerel istemci durumu
var inventory: Dictionary = {}
var hover_cell := Vector2i.ZERO
var hover_ok := false
var crack := 0.0
var selected_slot := 0
var loaded := false
var chat_history: Array[String] = []   # son mesajlar (testler için)
var bag: Array = []                    # fileyedeki canlılar (tür id)
var codex: Dictionary = {}             # tür -> toplam yakalanan
var best_depth := 0
var hover_creature := -1
var aquariums: Dictionary = {}         # Vector2i -> tür
var quest: Dictionary = {}             # yerel oyuncunun görev özeti
var host_info: Dictionary = {}         # kurucuysa: IP adresleri, port, UPnP durumu

var hud: Hud
var sfx: Sfx
var wildlife: Wildlife
var trade: Trade
var map: WorldMap
var _aq_nodes := {}                  # Vector2i -> Sprite2D
var _layer: TileMapLayer
var _wall_layer: TileMapLayer
var _overlay: Node2D
var _players: Node2D
var _fx: Node2D
var _canvas_mod: CanvasModulate
var _lit := {}                       # Vector2i -> blok id (ışık saçan hücreler)
var _light_pool: Array[PointLight2D] = []
var _light_timer := 0.0
var _tint_grad: Gradient
var _clear_grad: Gradient
var _is_server := false

# Yalnızca sunucuda
var _inventories := {}               # peer -> Dictionary
var _names := {}                     # peer -> String
var _colors := {}                    # peer -> Color
var _joined := {}                    # peer -> true (dünyayı yüklemiş)
var _last_break := {}                # peer -> msec
var _last_chat := {}                 # peer -> msec
var _saved_players := {}             # ad -> envanter (kayıttan)
var _seed := 0
var _autosave := AUTOSAVE_SEC
var _bags := {}                      # peer -> Array
var _codexes := {}                   # peer -> Dictionary
var _bests := {}                     # peer -> int
var _quests := {}                    # peer -> görev durumu
var _rng := RandomNumberGenerator.new()
var _backup_note := false
var _player_tick := 0.0


func _ready() -> void:
	name = "World"
	_is_server = multiplayer.is_server()
	_make_gradients()

	if not dedicated:
		add_child(Ambience.new())

	var ts := TileAtlas.build_tileset()
	_wall_layer = TileMapLayer.new()
	_wall_layer.name = "Walls"
	_wall_layer.tile_set = ts
	_wall_layer.collision_enabled = false
	_wall_layer.modulate = WALL_TINT
	_wall_layer.z_index = -10
	add_child(_wall_layer)

	if not dedicated:
		var fauna := Fauna.new()
		fauna.world = self
		add_child(fauna)
	wildlife = Wildlife.new()
	wildlife.world = self
	add_child(wildlife)
	trade = Trade.new()
	trade.world = self
	add_child(trade)
	if not dedicated:
		map = WorldMap.new()
		map.world = self
		add_child(map)

	_layer = TileMapLayer.new()
	_layer.name = "Tiles"
	_layer.tile_set = ts
	add_child(_layer)

	_overlay = Node2D.new()
	_overlay.name = "Overlay"
	_overlay.z_index = 30
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)

	_players = Node2D.new()
	_players.name = "Players"
	_players.z_index = 10
	add_child(_players)

	_fx = Node2D.new()
	_fx.name = "Fx"
	_fx.z_index = 20
	add_child(_fx)

	_canvas_mod = CanvasModulate.new()
	add_child(_canvas_mod)

	sfx = Sfx.new()
	sfx.enabled = not dedicated and DisplayServer.get_name() != "headless"
	add_child(sfx)

	if not dedicated:
		for i in MAX_LIGHTS:
			var l := PointLight2D.new()
			l.texture = Player.make_light_texture()
			l.enabled = false
			add_child(l)
			_light_pool.append(l)
		hud = Hud.new()
		hud.name = "Hud"
		hud.world = self
		add_child(hud)

	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if _is_server:
		_load_or_generate()
		_build_tilemap()
		loaded = true
		if not dedicated:
			_register_player(1, player_name, player_color)
			if _backup_note:
				toast("Harita büyüdü! Eski dünyan yedeklendi, yeni büyük dünya oluşturuldu.")
	else:
		client_ready.rpc_id(1, player_name, player_color)


func _exit_tree() -> void:
	if _is_server and loaded:
		save_now()


func _process(delta: float) -> void:
	if _is_server and loaded:
		_autosave -= delta
		if _autosave <= 0.0:
			_autosave = AUTOSAVE_SEC
			save_now()
		_player_tick -= delta
		if _player_tick <= 0.0:
			_player_tick = 0.5
			_server_player_tick()
	if dedicated:
		return
	_overlay.queue_redraw()
	var p := local_player()
	var row := p.depth_row() if p != null else 0.0
	var t := clampf(row / float(WorldGen.H), 0.0, 1.0)
	_canvas_mod.color = _tint_grad.sample(t)
	RenderingServer.set_default_clear_color(_clear_grad.sample(t))
	sfx.set_depth(t)
	_light_timer -= delta
	if _light_timer <= 0.0:
		_light_timer = 0.15
		_update_lights()
	_animate_aquariums()


func _make_gradients() -> void:
	_tint_grad = Gradient.new()
	_tint_grad.offsets = PackedFloat32Array([0.0, 0.12, 0.25, 0.5, 0.78, 1.0])
	_tint_grad.colors = PackedColorArray([
		Color(0.95, 1.0, 1.0), Color(0.72, 0.86, 0.97), Color(0.42, 0.58, 0.82),
		Color(0.17, 0.22, 0.42), Color(0.07, 0.07, 0.17), Color(0.04, 0.03, 0.09)])
	_clear_grad = Gradient.new()
	_clear_grad.offsets = PackedFloat32Array([0.0, 0.12, 0.25, 0.5, 0.78, 1.0])
	_clear_grad.colors = PackedColorArray([
		Color(0.25, 0.62, 0.86), Color(0.16, 0.45, 0.72), Color(0.08, 0.26, 0.5),
		Color(0.03, 0.08, 0.22), Color(0.01, 0.02, 0.08), Color(0.0, 0.0, 0.03)])


# --------------------------------------------------------------------------
# Yardımcılar
# --------------------------------------------------------------------------

func local_player() -> Player:
	return _players.get_node_or_null(str(multiplayer.get_unique_id())) as Player


func players() -> Array[Node]:
	return _players.get_children()


func joined_peers() -> Array:
	return _joined.keys()


## Sunucu: [peer, konum] listesi
func server_positions() -> Array:
	var out := []
	for peer in _joined.keys():
		var p := _players.get_node_or_null(str(peer)) as Player
		if p != null:
			out.append([peer, p.server_pos()])
	return out


func has_net() -> bool:
	return Inventory.count(inventory, Blocks.NET) > 0


static func bag_max(inv: Dictionary) -> int:
	return BAG_MAX + 2 * Inventory.level(inv, Blocks.BIG_BAG)


## Yerel oyuncunun envanterinde bir eşyadan kaç tane var
func have(id: int) -> int:
	return Inventory.count(inventory, id)


func request_leave() -> void:
	leave_requested.emit()


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < WorldGen.W and c.y < WorldGen.H


func get_cell_id(c: Vector2i) -> int:
	if not in_bounds(c):
		return Blocks.BEDROCK
	return cells[c.y * WorldGen.W + c.x]


func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


func spawn_pos() -> Vector2:
	return Vector2(cell_center(WorldGen.spawn_cell()).x, Player.SURFACE_Y + 4.0)


## Seçili hotbar yuvasındaki eşya (0 = boş)
func selected_block() -> int:
	return Inventory.slot_id(inventory, selected_slot)


func toast(text: String) -> void:
	if hud != null:
		hud.toast(text)


func play_ui(sound: String) -> void:
	if sfx != null:
		sfx.play_ui(sound)


func player_count() -> int:
	return _players.get_child_count()


func input_locked() -> bool:
	return hud != null and hud.typing()


func pointer_over_ui() -> bool:
	return hud != null and hud.pointer_over_ui()


# --------------------------------------------------------------------------
# Karo haritası ve görseller
# --------------------------------------------------------------------------

func _build_tilemap() -> void:
	for c in _aq_nodes.keys():
		(_aq_nodes[c] as Node).queue_free()
	_aq_nodes.clear()
	for c in aquariums.keys():
		_update_aquarium_view(c)
	_layer.clear()
	_wall_layer.clear()
	_lit.clear()
	for y in WorldGen.H:
		for x in WorldGen.W:
			var c := Vector2i(x, y)
			var w := walls[y * WorldGen.W + x]
			if w != Blocks.AIR:
				_wall_layer.set_cell(c, 0, Vector2i(Blocks.variant_for(w, c) if not Blocks.is_anim(w) else 0, w))
			var id := cells[y * WorldGen.W + x]
			if id != Blocks.AIR:
				_apply_visual(c, id)
	if map != null:
		map.build()


func _atlas_coords(c: Vector2i, id: int) -> Vector2i:
	if Blocks.is_anim(id):
		return Vector2i(0, id)
	if Blocks.has_top(id) and not Blocks.is_solid(get_cell_id(c + Vector2i(0, -1))):
		return Vector2i(TileAtlas.TOP_COL, id)
	return Vector2i(Blocks.variant_for(id, c), id)


func _apply_visual(c: Vector2i, id: int) -> void:
	if id == Blocks.AIR:
		_layer.erase_cell(c)
	else:
		_layer.set_cell(c, 0, _atlas_coords(c, id))
	if Blocks.light_of(id) != null:
		_lit[c] = id
	else:
		_lit.erase(c)


func _set_cell(c: Vector2i, id: int) -> void:
	var old := get_cell_id(c)
	cells[c.y * WorldGen.W + c.x] = id
	_apply_visual(c, id)
	if map != null:
		map.on_cell(c, id)
	var below := c + Vector2i(0, 1)
	var bid := get_cell_id(below)
	if in_bounds(below) and Blocks.has_top(bid):
		_apply_visual(below, bid)
	if dedicated or old == id:
		return
	if id == Blocks.AIR:
		_fx_break(c, old)
		sfx.play_at("break", cell_center(c))
	else:
		_fx_place(c)
		sfx.play_at("place", cell_center(c))


func _update_lights() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var center := cam.get_screen_center_position()
	var half := get_viewport_rect().size / cam.zoom * 0.5 + Vector2(64, 64)
	var cands: Array = []
	for c in _lit.keys():
		var p := cell_center(c)
		if absf(p.x - center.x) < half.x and absf(p.y - center.y) < half.y:
			cands.append([p.distance_squared_to(center), c])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in _light_pool.size():
		var l := _light_pool[i]
		if i < cands.size() and i < Settings.lights:
			var c2: Vector2i = cands[i][1]
			var id: int = _lit[c2]
			l.position = cell_center(c2)
			l.color = Blocks.light_of(id)
			l.texture_scale = Blocks.DEFS[id].get("light_scale", 1.0)
			l.energy = Blocks.DEFS[id].get("light_energy", 1.0)
			l.enabled = true
		else:
			l.enabled = false


func _fx_break(c: Vector2i, id: int) -> void:
	var p := CPUParticles2D.new()
	p.position = cell_center(c)
	p.one_shot = true
	p.emitting = true
	if Settings.particles == 0:
		p.queue_free()
		return
	p.amount = 12 if Settings.particles == 2 else 5
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(6, 6)
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(0, 70)
	p.damping_min = 30.0
	p.damping_max = 50.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.2
	var col := Blocks.color_of(id)
	var grad := Gradient.new()
	grad.colors = PackedColorArray([col.lightened(0.15), Color(col.darkened(0.3), 0.0)])
	p.color_ramp = grad
	p.finished.connect(p.queue_free)
	_fx.add_child(p)


func _fx_place(c: Vector2i) -> void:
	var p := CPUParticles2D.new()
	p.position = cell_center(c)
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.9
	p.explosiveness = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 25.0
	p.gravity = Vector2(0, -20)
	p.texture = Player._bubble_texture()
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color = Color(0.85, 0.97, 1.0, 0.7)
	p.finished.connect(p.queue_free)
	_fx.add_child(p)


func _draw_overlay() -> void:
	if hover_creature >= 0:
		var cp := wildlife.view_pos(hover_creature)
		if cp != Vector2.INF:
			var ok := has_net() and bag.size() < World.bag_max(inventory)
			var col := Color(0.45, 1.0, 0.6, 0.9) if ok else Color(1.0, 0.5, 0.4, 0.9)
			var r := 10.0 + sin(Time.get_ticks_msec() * 0.01) * 1.5
			_overlay.draw_arc(cp, r, 0, TAU, 24, col, 1.2)
			_overlay.draw_string(ThemeDB.fallback_font, cp + Vector2(-60, -16),
				Species.display_name(wildlife.view_species(hover_creature)),
				HORIZONTAL_ALIGNMENT_CENTER, 120, 7, col)
		return
	if not hover_ok:
		return
	var r := Rect2(Vector2(hover_cell) * TILE, Vector2(TILE, TILE))
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
	_overlay.draw_rect(r.grow(0.5), Color(1, 1, 1, 0.85 * pulse), false, 1.0)
	if crack > 0.0:
		_overlay.draw_rect(r, Color(0, 0, 0, crack * 0.45), true)
		var n := int(crack * 5.0) + 1
		var o := r.position
		var segs := [
			[Vector2(8, 8), Vector2(3, 3)], [Vector2(8, 8), Vector2(14, 5)],
			[Vector2(8, 8), Vector2(6, 14)], [Vector2(8, 8), Vector2(13, 13)],
			[Vector2(3, 3), Vector2(1, 9)], [Vector2(14, 5), Vector2(15, 1)]]
		for i in mini(n, segs.size()):
			_overlay.draw_line(o + segs[i][0], o + segs[i][1], Color(0.05, 0.05, 0.08, 0.85), 1.0)


# --------------------------------------------------------------------------
# Girdi (hotbar)
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if dedicated or input_locked():
		return
	var n := Inventory.HOTBAR
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			selected_slot = k - KEY_1
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			selected_slot = (selected_slot + n - 1) % n
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			selected_slot = (selected_slot + 1) % n


# --------------------------------------------------------------------------
# Kayıt (sunucu)
# --------------------------------------------------------------------------

func _load_or_generate() -> void:
	var data := SaveStore.load_world(world_name)
	if data.has("migrate_players"):
		_saved_players = data["migrate_players"]
		data = {}
	if not data.is_empty():
		cells = data["cells"]
		walls = data["walls"]
		_seed = int(data.get("seed", 0))
		_saved_players = data.get("players", {})
		aquariums = data.get("aquariums", {})
		print("[Sunucu] '%s' dünyası yüklendi" % world_name)
		return
	_seed = int(Time.get_ticks_usec() % 1000000)
	if SaveStore.last_backup != "":
		print("[Sunucu] Eski dünya yedeklendi: %s" % SaveStore.last_backup)
		_backup_note = true
	var gen := WorldGen.generate(_seed)
	cells = gen["cells"]
	walls = gen["walls"]
	print("[Sunucu] '%s' için yeni dünya üretildi (seed %d)" % [world_name, _seed])
	save_now()


func _player_record(peer: int) -> Dictionary:
	return {"inv": (_inventories[peer] as Dictionary).duplicate(true),
		"codex": (_codexes[peer] as Dictionary).duplicate(), "best": int(_bests[peer]),
		"quest": (_quests[peer] as Dictionary).duplicate(true)}


func save_now() -> void:
	for peer in _joined.keys():
		_saved_players[_names[peer]] = _player_record(peer)
	var ok := SaveStore.save_world(world_name, {
		"seed": _seed, "cells": cells, "walls": walls, "players": _saved_players,
		"aquariums": aquariums})
	if ok:
		print("[Sunucu] Kaydedildi: %s" % SaveStore.path_for(world_name))


# --------------------------------------------------------------------------
# Ağ: katılma
# --------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func client_ready(pname: String, color: Color) -> void:
	if not _is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	if _joined.has(peer):
		return
	receive_world.rpc_id(peer, cells.compress(FileAccess.COMPRESSION_ZSTD),
		walls.compress(FileAccess.COMPRESSION_ZSTD), cells.size(), world_name, aquariums)
	for other in _joined.keys():
		var pl := _players.get_node_or_null(str(other)) as Player
		if pl != null:
			spawn_player.rpc_id(peer, other, _names[other], pl.server_pos(), _colors[other])
	_register_player(peer, pname, color)


func _unique_name(pname: String) -> String:
	var clean := pname.strip_edges().substr(0, 16)
	if clean.is_empty():
		clean = "Dalgıç"
	var taken := _names.values()
	if not taken.has(clean):
		return clean
	var i := 2
	while taken.has("%s %d" % [clean, i]):
		i += 1
	return "%s %d" % [clean, i]


func _register_player(peer: int, pname: String, color: Color) -> void:
	var clean := _unique_name(pname)
	color.a = 1.0
	_names[peer] = clean
	_colors[peer] = color
	var returning := _saved_players.has(clean)
	var rec: Dictionary = _saved_players.get(clean, {})
	if returning and not rec.has("inv"):
		rec = {"inv": rec}          # eski kayıt biçimi
	_inventories[peer] = Inventory.from_any(rec.get("inv", null), START_INVENTORY)
	_codexes[peer] = (rec.get("codex", {}) as Dictionary).duplicate()
	_bests[peer] = int(rec.get("best", 0))
	_quests[peer] = (rec.get("quest", Quests.new_state()) as Dictionary).duplicate(true)
	_bags[peer] = []
	_joined[peer] = true
	print("[Sunucu] %s katıldı (id %d)" % [clean, peer])
	for target in _joined.keys():
		if target != 1:
			spawn_player.rpc_id(target, peer, clean, spawn_pos(), color)
	spawn_player(peer, clean, spawn_pos(), color)
	_send_inventory(peer)
	_send_player_data(peer)
	_ensure_random_quest(peer)
	_send_quest(peer)
	_broadcast_chat("", "%s %s" % [clean, "geri döndü" if returning else "dalışa katıldı"], 0, Color(0.6, 0.9, 1.0))


@rpc("authority", "call_remote", "reliable")
func receive_world(c_cells: PackedByteArray, c_walls: PackedByteArray, size: int, wname: String,
		aq: Dictionary) -> void:
	cells = c_cells.decompress(size, FileAccess.COMPRESSION_ZSTD)
	walls = c_walls.decompress(size, FileAccess.COMPRESSION_ZSTD)
	world_name = wname
	aquariums = aq
	_build_tilemap()
	loaded = true
	if hud != null:
		hud.loading = false


@rpc("authority", "call_remote", "reliable")
func spawn_player(peer: int, pname: String, pos: Vector2, color: Color) -> void:
	if _players.has_node(str(peer)):
		return
	var p := Player.new()
	p.position = pos
	p.setup(peer, self, pname, color)
	_players.add_child(p)


@rpc("authority", "call_remote", "reliable")
func remove_player(peer: int) -> void:
	var p := _players.get_node_or_null(str(peer))
	if p != null:
		p.queue_free()


func _on_peer_disconnected(peer: int) -> void:
	if not _is_server or not _joined.has(peer):
		return
	var pname: String = _names.get(peer, str(peer))
	print("[Sunucu] %s ayrıldı" % pname)
	_saved_players[pname] = _player_record(peer)
	_joined.erase(peer)
	_bags.erase(peer)
	_codexes.erase(peer)
	_bests.erase(peer)
	_quests.erase(peer)
	_names.erase(peer)
	_colors.erase(peer)
	_inventories.erase(peer)
	_last_break.erase(peer)
	_last_chat.erase(peer)
	remove_player(peer)
	for target in _joined.keys():
		if target != 1:
			remove_player.rpc_id(target, peer)
	_broadcast_chat("", "%s ayrıldı" % pname, 0, Color(0.6, 0.9, 1.0))


## Sunucu: bir oyuncunun konumunu, dünyayı yüklemiş diğer oyunculara aktarır.
func relay_state(peer: int, pos: Vector2, vel: Vector2) -> void:
	var node := _players.get_node_or_null(str(peer)) as Player
	if node == null:
		return
	for target in _joined.keys():
		if target != 1 and target != peer:
			node.net_state.rpc_id(target, pos, vel)


# --------------------------------------------------------------------------
# Ağ: sohbet ve bildirimler
# --------------------------------------------------------------------------

func send_chat(text: String) -> void:
	text = text.strip_edges()
	if text.is_empty():
		return
	if _is_server:
		_server_chat(1, text)
	else:
		req_chat.rpc_id(1, text)


@rpc("any_peer", "call_remote", "reliable")
func req_chat(text: String) -> void:
	if _is_server:
		_server_chat(multiplayer.get_remote_sender_id(), text)


func _server_chat(peer: int, text: String) -> void:
	if not _joined.has(peer):
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_chat.get(peer, -10000)) < 400:
		return
	_last_chat[peer] = now
	var clean := text.strip_edges().replace("\n", " ").substr(0, CHAT_MAX)
	if clean.is_empty():
		return
	_broadcast_chat(_names[peer], clean, peer, _colors[peer])


func _broadcast_chat(sender: String, text: String, peer: int, color: Color) -> void:
	for target in _joined.keys():
		if target != 1:
			chat_msg.rpc_id(target, sender, text, peer, color)
	if not dedicated:
		chat_msg(sender, text, peer, color)
	else:
		print("[Sohbet] %s: %s" % [sender if sender != "" else "*", text])


@rpc("authority", "call_remote", "reliable")
func chat_msg(sender: String, text: String, peer: int, color: Color) -> void:
	chat_history.append("%s: %s" % [sender, text])
	if hud != null:
		hud.add_chat(sender, text, color)
	if peer != 0:
		var p := _players.get_node_or_null(str(peer)) as Player
		if p != null:
			p.say(text)
		if sfx != null:
			sfx.play_ui("chat", -10.0)


func _notify(peer: int, text: String, sound: String) -> void:
	if peer == 1:
		if not dedicated:
			notice(text, sound)
	else:
		notice.rpc_id(peer, text, sound)


@rpc("authority", "call_remote", "reliable")
func notice(text: String, sound: String) -> void:
	toast(text)
	if sound != "":
		play_ui(sound)


# --------------------------------------------------------------------------
# Ağ: blok kırma / koyma / üretim (sunucu doğrular)
# --------------------------------------------------------------------------

func request_break(c: Vector2i) -> void:
	if _is_server:
		_server_break(1, c)
	else:
		req_break.rpc_id(1, c)


## Hotbar yuvasındaki bloğu koy
func request_place(c: Vector2i, slot: int) -> void:
	if _is_server:
		_server_place(1, c, slot)
	else:
		req_place.rpc_id(1, c, slot)


## Envanter penceresinde tıklama. İstemci sonucu hemen kendi tarafında gösterir,
## sunucu aynı işlemi doğrulayıp kesin durumu geri yollar.
func inv_click(kind: String, idx: int, button: int, shift: bool) -> void:
	if _is_server:
		_server_inv_click(1, kind, idx, button, shift)
	else:
		Inventory.click(inventory, kind, idx, button, shift)
		req_inv_click.rpc_id(1, kind, idx, button, shift)


func inv_close() -> void:
	if _is_server:
		_server_inv_close(1)
	else:
		Inventory.close(inventory)
		req_inv_close.rpc_id(1)


func inv_autofill(ri: int) -> void:
	if _is_server:
		_server_autofill(1, ri)
	else:
		Inventory.autofill(inventory, ri)
		req_autofill.rpc_id(1, ri)


## Tarifi doğrudan üret (tarif kitabından hızlı üretim ve testler için)
func request_craft(index: int) -> void:
	if _is_server:
		_server_quick_craft(1, index)
	else:
		req_quick_craft.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func req_break(c: Vector2i) -> void:
	if _is_server:
		_server_break(multiplayer.get_remote_sender_id(), c)


@rpc("any_peer", "call_remote", "reliable")
func req_place(c: Vector2i, slot: int) -> void:
	if _is_server:
		_server_place(multiplayer.get_remote_sender_id(), c, slot)


@rpc("any_peer", "call_remote", "reliable")
func req_inv_click(kind: String, idx: int, button: int, shift: bool) -> void:
	if _is_server:
		_server_inv_click(multiplayer.get_remote_sender_id(), kind, idx, button, shift)


@rpc("any_peer", "call_remote", "reliable")
func req_inv_close() -> void:
	if _is_server:
		_server_inv_close(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func req_autofill(ri: int) -> void:
	if _is_server:
		_server_autofill(multiplayer.get_remote_sender_id(), ri)


@rpc("any_peer", "call_remote", "reliable")
func req_quick_craft(index: int) -> void:
	if _is_server:
		_server_quick_craft(multiplayer.get_remote_sender_id(), index)


func _server_player(peer: int) -> Player:
	if not _joined.has(peer):
		return null
	return _players.get_node_or_null(str(peer)) as Player


func _within_reach(p: Player, c: Vector2i) -> bool:
	return cell_center(c).distance_to(p.server_pos()) <= MAX_REACH_CELLS * TILE


func _give(peer: int, id: int, n: int) -> void:
	var left := Inventory.give(_inventories[peer], id, n)
	if left > 0:
		_notify(peer, "Envanter dolu! %d %s sığmadı" % [left, Blocks.item_name(id)], "warn")


func _server_break(peer: int, c: Vector2i) -> void:
	var p := _server_player(peer)
	if p == null or not in_bounds(c) or not _within_reach(p, c):
		return
	var id := get_cell_id(c)
	if not Blocks.is_breakable(id):
		return
	var now := Time.get_ticks_msec()
	var need_ms := int(Blocks.DEFS[id]["hardness"] * 1000.0 * 0.5)
	if now - int(_last_break.get(peer, 0)) < maxi(need_ms, 40):
		return    # çok hızlı kırma isteği (hile / bozuk istemci)
	_last_break[peer] = now
	_server_set_cell(c, Blocks.AIR)
	if id == Blocks.AQUARIUM and aquariums.has(c):
		_give(peer, int(aquariums[c]), 1)
		_server_set_aquarium(c, 0)
	if id == Blocks.CHEST:
		_open_chest(peer, c)
	else:
		var drop := Blocks.drop_of(id)
		if drop != Blocks.AIR:
			_give(peer, drop, 1)
			_quest_event(peer, "collect", drop, 1)
			if drop == Blocks.PEARL:
				_notify(peer, "+1 İnci", "pickup")
	_send_inventory(peer)


func _open_chest(peer: int, c: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	var pearls := 2 + c.y / 45 + rng.randi_range(0, 3)
	_give(peer, Blocks.PEARL, pearls)
	_quest_event(peer, "chest", 0, 1)
	var parts := ["+%d İnci" % pearls]
	var roll := rng.randf()
	var bonus := Blocks.AIR
	var count := 0
	if roll < 0.35:
		bonus = Blocks.LAMP
		count = rng.randi_range(1, 3)
	elif roll < 0.55:
		bonus = Blocks.GLOWSHROOM
		count = rng.randi_range(2, 4)
	elif roll < 0.7 and c.y > WorldGen.LAYER_TWILIGHT:
		bonus = Blocks.OXYGEN
		count = 1
	if bonus != Blocks.AIR:
		_give(peer, bonus, count)
		parts.append("+%d %s" % [count, Blocks.item_name(bonus)])
	_notify(peer, "Hazine bulundu!  " + ", ".join(parts), "treasure")


func _server_place(peer: int, c: Vector2i, slot: int) -> void:
	var p := _server_player(peer)
	if p == null or not in_bounds(c) or not _within_reach(p, c):
		return
	var inv: Dictionary = _inventories[peer]
	var id := Inventory.slot_id(inv, slot)
	if slot >= Inventory.HOTBAR or not Blocks.PLACEABLE.has(id):
		return
	var existing := get_cell_id(c)
	if not Blocks.is_replaceable(existing) or existing == id:
		return
	if Blocks.is_solid(id):
		# Hiçbir oyuncunun gövdesinin içine katı blok konmaz
		var cell_rect := Rect2(Vector2(c) * TILE, Vector2(TILE, TILE))
		for other in _players.get_children():
			var o := other as Player
			if o != null and cell_rect.intersects(Rect2(o.server_pos() - Vector2(6, 8), Vector2(12, 16))):
				return
	Inventory.use_slot(inv, slot)
	_server_set_cell(c, id)
	_send_inventory(peer)
	_quest_event(peer, "place", id, 1)


func _server_inv_click(peer: int, kind: String, idx: int, button: int, shift: bool) -> void:
	if not _joined.has(peer):
		return
	var inv: Dictionary = _inventories[peer]
	var res := Inventory.click(inv, kind, idx, button, shift)
	_send_inventory(peer)
	if int(res.crafted) >= 0:
		_after_craft(peer, int(res.crafted), int(res.times))


func _server_inv_close(peer: int) -> void:
	if not _joined.has(peer):
		return
	Inventory.close(_inventories[peer])
	_send_inventory(peer)


func _server_autofill(peer: int, ri: int) -> void:
	if not _joined.has(peer):
		return
	Inventory.autofill(_inventories[peer], ri)
	_send_inventory(peer)


func _server_quick_craft(peer: int, index: int) -> void:
	if not _joined.has(peer):
		return
	var inv: Dictionary = _inventories[peer]
	if not Inventory.autofill(inv, index):
		Inventory.close(inv)
		_send_inventory(peer)
		return
	var res := Inventory.click(inv, "out", 0, 1, false)
	Inventory.close(inv)
	_send_inventory(peer)
	if int(res.crafted) >= 0:
		_after_craft(peer, int(res.crafted), int(res.times))


func _after_craft(peer: int, ri: int, times: int) -> void:
	var r: Dictionary = Blocks.RECIPES[ri]
	var out: int = r["out"]
	if Blocks.UPGRADE_MAX.has(out):
		var inv: Dictionary = _inventories[peer]
		_notify(peer, "%s yükseltildi! (Seviye %d/%d)" % [Blocks.item_name(out), Inventory.level(inv, out),
			int(Blocks.UPGRADE_MAX[out])], "craft")
		_quest_event(peer, "upgrade", 0, 1)
	else:
		_notify(peer, "", "craft")
	for i in times:
		_quest_event(peer, "craft", out, 1)


func _server_set_cell(c: Vector2i, id: int) -> void:
	_set_cell(c, id)
	for target in _joined.keys():
		if target != 1:
			apply_cell.rpc_id(target, c, id)


@rpc("authority", "call_remote", "reliable")
func apply_cell(c: Vector2i, id: int) -> void:
	if not in_bounds(c):
		return
	_set_cell(c, id)


func _send_inventory(peer: int) -> void:
	var inv: Dictionary = _inventories.get(peer, {})
	if peer == 1:
		if not dedicated:
			inventory = inv.duplicate(true)
	else:
		set_inventory.rpc_id(peer, inv)


@rpc("authority", "call_remote", "reliable")
func set_inventory(inv: Dictionary) -> void:
	inventory = inv


# --------------------------------------------------------------------------
# Canlılar: yakalama, fileye, ansiklopedi, rekorlar
# --------------------------------------------------------------------------

func request_catch(id: int) -> void:
	if _is_server:
		_server_catch(1, id)
	else:
		req_catch.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func req_catch(id: int) -> void:
	if _is_server:
		_server_catch(multiplayer.get_remote_sender_id(), id)


func _server_catch(peer: int, id: int) -> void:
	var p := _server_player(peer)
	if p == null:
		return
	if Inventory.count(_inventories[peer], Blocks.NET) <= 0:
		_notify(peer, "Yakalamak için önce Ağ üret (C)", "")
		return
	var b: Array = _bags[peer]
	if b.size() >= World.bag_max(_inventories[peer]):
		_notify(peer, "Fileyen dolu! Yüzeye ya da bir oksijen istasyonuna dön.", "warn")
		return
	var sp := wildlife.try_catch(id, p.server_pos(), SERVER_CATCH_RANGE * TILE)
	if sp < 0:
		return
	b.append(sp)
	_send_player_data(peer)
	var first := int((_codexes[peer] as Dictionary).get(sp, 0)) == 0
	_notify(peer, "Yakalandı: %s%s  (fileye %d/%d)" % [Species.display_name(sp),
		"  · yeni tür!" if first else "", b.size(), World.bag_max(_inventories[peer])], "catch")


## Sunucu: tehlikeli bir canlı saldırdı (shock: yılanbalığı, bite: köpekbalığı)
func server_shock(peer: int, from: Vector2, kind := "shock") -> void:
	if peer == 1:
		if not dedicated:
			shocked(from, kind)
	else:
		shocked.rpc_id(peer, from, kind)


@rpc("authority", "call_remote", "reliable")
func shocked(from: Vector2, kind: String) -> void:
	var p := local_player()
	if p != null:
		p.shock(from, kind)


func report_death() -> void:
	if _is_server:
		_server_died(1)
	else:
		req_died.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func req_died() -> void:
	if _is_server:
		_server_died(multiplayer.get_remote_sender_id())


func _server_died(peer: int) -> void:
	if not _bags.has(peer):
		return
	var b: Array = _bags[peer]
	if b.size() > 0:
		_notify(peer, "Fileyendeki %d canlı kaçtı..." % b.size(), "warn")
		b.clear()
		_send_player_data(peer)


func _near_station(pos: Vector2) -> bool:
	var c := cell_at(pos)
	for dy in range(-Player.STATION_RADIUS, Player.STATION_RADIUS + 1):
		for dx in range(-Player.STATION_RADIUS, Player.STATION_RADIUS + 1):
			if get_cell_id(c + Vector2i(dx, dy)) == Blocks.OXYGEN:
				return true
	return false


func _server_player_tick() -> void:
	for pl in server_positions():
		var peer: int = pl[0]
		var pos: Vector2 = pl[1]
		var row := int(pos.y / TILE)
		# derinlik rekoru
		var old: int = _bests[peer]
		if row > old:
			_bests[peer] = row
			for m in MILESTONES:
				if old < int(m[0]) and row >= int(m[0]):
					_give(peer, Blocks.PEARL, int(m[1]))
					_send_inventory(peer)
					_notify(peer, "Yeni derinlik: %s!  +%d İnci" % [WorldGen.layer_name(int(m[0])), int(m[1])],
						"treasure")
			if row / 10 != old / 10:
				_send_player_data(peer)
			_quest_event(peer, "depth", 0, row)
		# fileyeyi güvenli noktada koleksiyona aktar
		var b: Array = _bags[peer]
		if b.size() > 0 and (pos.y < 2.0 * TILE or _near_station(pos)):
			_bank(peer)


func _bank(peer: int) -> void:
	var b: Array = _bags[peer]
	var cdx: Dictionary = _codexes[peer]
	var news: Array[String] = []
	var reward := 0
	for sp in b:
		_give(peer, sp, 1)
		_quest_event(peer, "bank", sp, 1)
		if int(cdx.get(sp, 0)) == 0:
			news.append(Species.display_name(sp))
			reward += int(Species.get_def(sp)["reward"])
		cdx[sp] = int(cdx.get(sp, 0)) + 1
	var n := b.size()
	b.clear()
	if reward > 0:
		_give(peer, Blocks.PEARL, reward)
	_send_inventory(peer)
	_send_player_data(peer)
	var msg := "%d canlı koleksiyona eklendi" % n
	if news.size() > 0:
		msg += "  ·  Yeni tür: %s  +%d İnci" % [", ".join(news), reward]
	_notify(peer, msg, "treasure" if news.size() > 0 else "pickup")
	_quest_event(peer, "codex", 0, cdx.size())


func _send_player_data(peer: int) -> void:
	if peer == 1:
		if not dedicated:
			set_player_data(_bags[peer], _codexes[peer], _bests[peer])
	else:
		set_player_data.rpc_id(peer, _bags[peer], _codexes[peer], _bests[peer])


@rpc("authority", "call_remote", "reliable")
func set_player_data(p_bag: Array, p_codex: Dictionary, p_best: int) -> void:
	bag = p_bag.duplicate()
	codex = p_codex.duplicate()
	best_depth = p_best


# --------------------------------------------------------------------------
# Akvaryum
# --------------------------------------------------------------------------

## Akvaryuma canlı koy (sp = 0: boşalt)
func request_aquarium(c: Vector2i, sp: int) -> void:
	if _is_server:
		_server_aquarium(1, c, sp)
	else:
		req_aquarium.rpc_id(1, c, sp)


@rpc("any_peer", "call_remote", "reliable")
func req_aquarium(c: Vector2i, sp: int) -> void:
	if _is_server:
		_server_aquarium(multiplayer.get_remote_sender_id(), c, sp)


func _server_aquarium(peer: int, c: Vector2i, sp: int) -> void:
	var p := _server_player(peer)
	if p == null or get_cell_id(c) != Blocks.AQUARIUM or not _within_reach(p, c):
		return
	if sp != 0 and not Species.is_species(sp):
		return
	var inv: Dictionary = _inventories[peer]
	if sp != 0 and Inventory.count(inv, sp) <= 0:
		return
	if aquariums.has(c):
		_give(peer, int(aquariums[c]), 1)
	if sp != 0:
		Inventory.take(inv, sp, 1)
	_server_set_aquarium(c, sp)
	_send_inventory(peer)
	if sp != 0:
		_quest_event(peer, "aquarium", 0, 1)


func _server_set_aquarium(c: Vector2i, sp: int) -> void:
	apply_aquarium(c, sp)
	for target in _joined.keys():
		if target != 1:
			apply_aquarium.rpc_id(target, c, sp)


@rpc("authority", "call_remote", "reliable")
func apply_aquarium(c: Vector2i, sp: int) -> void:
	if sp == 0:
		aquariums.erase(c)
	else:
		aquariums[c] = sp
	_update_aquarium_view(c)


func _update_aquarium_view(c: Vector2i) -> void:
	if dedicated:
		return
	if _aq_nodes.has(c):
		(_aq_nodes[c] as Node).queue_free()
		_aq_nodes.erase(c)
	if not aquariums.has(c):
		return
	var sp: int = aquariums[c]
	var d := Species.get_def(sp)
	var s := Sprite2D.new()
	s.texture = Species.texture(sp)
	s.hframes = int(d["frames"])
	s.vframes = maxi(1, int(s.texture.get_height() / int(d["fh"])))
	s.frame = int(d["row"]) * int(d["frames"])
	s.modulate = Species.tint(sp)
	var k := minf(11.0 / float(d["fw"]), 9.0 / float(d["fh"]))
	s.scale = Vector2(k, k)
	s.position = cell_center(c) + Vector2(0, -1)
	s.z_index = 1
	_fx.add_child(s)
	_aq_nodes[c] = s


func _animate_aquariums() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for c in _aq_nodes.keys():
		var s: Sprite2D = _aq_nodes[c]
		var sp: int = aquariums.get(c, 0)
		if sp == 0:
			continue
		var d := Species.get_def(sp)
		var ph: float = t * 0.8 + c.x * 1.3
		s.position = cell_center(c) + Vector2(sin(ph) * 2.5, -1.5 + sin(ph * 1.7) * 1.0)
		s.flip_h = cos(ph) < 0.0
		var frames := int(d["frames"])
		s.frame = int(d["row"]) * frames + int(t * 4.0 + c.y) % frames


# --------------------------------------------------------------------------
# Görevler (sunucu)
# --------------------------------------------------------------------------

func _ensure_random_quest(peer: int) -> void:
	var st: Dictionary = _quests[peer]
	if int(st.get("step", 0)) >= Quests.CHAIN.size() and (st.get("rnd", {}) as Dictionary).is_empty():
		st["rnd"] = Quests.random_quest(int(_bests[peer]), _rng)


func _quest_event(peer: int, type: String, arg: int, amount: int) -> void:
	if not _quests.has(peer):
		return
	var st: Dictionary = _quests[peer]
	var q := Quests.current(st)
	if q.is_empty() or q.get("type", "") != type:
		return
	var want := int(q.get("arg", 0))
	if want != 0 and type not in Quests.STATE_TYPES and arg != want:
		return
	if type in Quests.STATE_TYPES:
		st["prog"] = maxi(int(st.get("prog", 0)), amount)
	else:
		st["prog"] = int(st.get("prog", 0)) + amount
	if int(st["prog"]) >= int(q["need"]):
		_complete_quest(peer)
	else:
		_send_quest(peer)


func _complete_quest(peer: int) -> void:
	var st: Dictionary = _quests[peer]
	var q := Quests.current(st)
	var reward := int(q.get("reward", 0))
	_give(peer, Blocks.PEARL, reward)
	_send_inventory(peer)
	_notify(peer, "Görev tamamlandı: %s  ·  +%d İnci" % [q.get("text", ""), reward], "treasure")
	st["step"] = int(st.get("step", 0)) + 1
	st["prog"] = 0
	st["rnd"] = {}
	_ensure_random_quest(peer)
	# yeni görev zaten sağlanmışsa (ör. daha önce o derinliğe inilmişse) hemen ilerlet
	var nq := Quests.current(st)
	match nq.get("type", ""):
		"depth":
			_quest_event(peer, "depth", 0, int(_bests[peer]))
		"codex":
			_quest_event(peer, "codex", 0, (_codexes[peer] as Dictionary).size())
		_:
			_send_quest(peer)


func _send_quest(peer: int) -> void:
	if not _quests.has(peer):
		return
	var sm := Quests.summary(_quests[peer])
	if peer == 1:
		if not dedicated:
			set_quest(sm)
	else:
		set_quest.rpc_id(peer, sm)


@rpc("authority", "call_remote", "reliable")
func set_quest(sm: Dictionary) -> void:
	quest = sm
