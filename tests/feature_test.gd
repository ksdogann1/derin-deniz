extends SceneTree
## v0.4 özellik testi: görevler, ekipman, ayarlar, oyun içi menü, dokunmatik kontroller.
##   godot --headless --path . --script res://tests/feature_test.gd

const WORLD := "test_ozellik"

var world: World
var me: Player
var failures := 0
var checks := 0


func check(label: String, cond: bool) -> void:
	checks += 1
	print("%s  %s" % ["OK  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _screen_of_viewport(p: Vector2) -> Vector2:
	var vis := root.get_visible_rect().size
	var k := minf(root.size.x / vis.x, root.size.y / vis.y)
	var offset := (Vector2(root.size) - vis * k) * 0.5
	return p * k + offset


func _cell_screen(c: Vector2i) -> Vector2:
	return _screen_of_viewport(root.get_canvas_transform() * world.cell_center(c))


func _touch(index: int, pos_window: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = pos_window
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(index: int, pos_window: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = pos_window
	Input.parse_input_event(ev)


func _initialize() -> void:
	_run()


func _find_open_sand() -> Vector2i:
	for x in range(64, 100):
		for y in range(6, WorldGen.H - 1):
			if world.get_cell_id(Vector2i(x, y)) != Blocks.SAND:
				continue
			var free := true
			for k in range(1, 6):
				if world.get_cell_id(Vector2i(x, y - k)) != Blocks.AIR:
					free = false
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _quest_type() -> String:
	return Quests.current(world._quests[1]).get("type", "")


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(7805, 4)
	get_multiplayer().multiplayer_peer = peer
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	world = World.new()
	world.player_name = "Ozellik"
	world.world_name = WORLD
	main.add_child(world)
	await _wait(0.5)
	me = world.local_player()
	var inv: Dictionary = world._inventories[1]

	# ------------------------------------------------------------ görevler
	check("ilk görev gönderildi", world.quest.get("step", 0) == 1 and world.quest.get("type", "") == "depth")
	var target := _find_open_sand()
	var pearls0 := world.have(Blocks.PEARL)
	me.position = Vector2(world.cell_center(target).x, 12.0 * 16.0)
	await _wait(0.7)
	check("derinlik görevi tamamlandı, 2. göreve geçildi", _quest_type() == "collect")
	me.position = world.cell_center(target) + Vector2(0, -56)
	check("görev ödülü verildi (+3)", world.have(Blocks.PEARL) == pearls0 + 3)

	for i in 5:
		var c := target + Vector2i(1 + i % 2, -1 - i / 2)
		world._server_set_cell(c, Blocks.KELP)
		world._last_break[1] = 0
		world.request_break(c)
	await _wait(0.1)
	check("5 yosun görevi tamamlandı", _quest_type() == "craft")
	_setc(inv, Blocks.KELP, 3)
	world.request_craft(_recipe(Blocks.PLANK))
	check("tahta üretme görevi tamamlandı", Quests.current(world._quests[1]).get("arg", 0) == Blocks.NET)
	_setc(inv, Blocks.KELP, 4)
	_setc(inv, Blocks.PLANK, 2)
	world.request_craft(_recipe(Blocks.NET))
	check("ağ üretme görevi tamamlandı", _quest_type() == "bank")
	check("istemci görev özetini aldı", world.quest.get("step", 0) == 5)
	world.request_catch(world.wildlife.spawn(201, me.position + Vector2(10, 0)))
	me.position = world.spawn_pos()
	await _wait(0.7)
	check("canlı yakalama görevi tamamlandı", _quest_type() == "chest")
	me.position = world.cell_center(target) + Vector2(0, -56)
	await _wait(0.3)
	var ch := target + Vector2i(-1, -1)
	world._server_set_cell(ch, Blocks.CHEST)
	world._last_break[1] = 0
	world.request_break(ch)
	check("sandık görevi tamamlandı", _quest_type() == "place")
	var st := target + Vector2i(-2, -3)
	world._server_set_cell(st, Blocks.AIR)       # rastgele dünyada orası kaya olabilir
	world.request_place(st, _slot_of(Blocks.OXYGEN))
	check("istasyon kurma görevi tamamlandı", world.get_cell_id(st) == Blocks.OXYGEN and _quest_type() == "depth")
	world._server_set_cell(st, Blocks.AIR)
	world._bests[1] = 70
	world._quest_event(1, "depth", 0, 70)
	check("daha önce ulaşılmış derinlik görevi anında geçti", _quest_type() == "codex")
	var qs: Dictionary = world._quests[1]
	qs["step"] = Quests.CHAIN.size()
	qs["rnd"] = {}
	world._ensure_random_quest(1)
	world._send_quest(1)
	check("zincir bitince serbest görev üretildi", world.quest.get("free", false) and world.quest.get("text", "") != "")
	world.save_now()
	var data := SaveStore.load_world(WORLD)
	check("görev durumu kaydedildi", int(data["players"]["Ozellik"]["quest"]["step"]) == Quests.CHAIN.size())

	# ------------------------------------------------------------ ekipman
	_setc(inv, Blocks.ROCK, 50)
	_setc(inv, Blocks.KELP, 50)
	_setc(inv, Blocks.PEARL, 100)
	_setc(inv, Blocks.LAMP, 10)
	_setc(inv, Blocks.GLASS, 10)
	_setc(inv, Blocks.PLANK, 10)
	world._send_inventory(1)
	for i in 3:
		world.request_craft(_recipe(Blocks.FINS))
		world.request_craft(_recipe(Blocks.BIG_BAG))
		world.request_craft(_recipe(Blocks.HELMET))
	check("palet en fazla 2 seviye", world.have(Blocks.FINS) == 2)
	check("palet hızı artırdı", is_equal_approx(me.speed_mult(), 1.4))
	check("büyük fileye kapasiteyi artırdı", World.bag_max(world.inventory) == 9)
	check("güçlü fener 2 seviye", world.have(Blocks.HELMET) == 2)
	await _wait(0.1)
	check("fener ışığı büyüdü", me._light.texture_scale > 1.4)

	# ------------------------------------------------------------ ayarlar
	Settings.sfx = 0.3
	Settings.music = 0.0
	Settings.save()
	Settings.sfx = 0.9
	Settings._loaded = false
	Settings.ensure_loaded()
	check("ayarlar kaydedilip okundu", is_equal_approx(Settings.sfx, 0.3))
	check("müzik kanalı kapatıldı", AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.BUS_MUSIC)))
	Settings.sfx = 0.8
	Settings.music = 0.55
	# görüntü ayarları
	var rev := Settings.revision
	Settings.set_quality(0)
	Settings.fps_limit = 30
	Settings.apply()
	check("düşük kalite ışıkları azalttı", Settings.lights == 8 and not Settings.snow)
	check("kare hızı sınırı uygulandı", Engine.max_fps == 30)
	check("ayar değişince revizyon arttı", Settings.revision > rev)
	await _wait(0.2)
	var lit := 0
	for l in world._light_pool:
		if l.enabled:
			lit += 1
	check("ışık havuzu ayara uydu (%d <= 8)" % lit, lit <= 8)
	Settings.set_quality(2)
	Settings.fps_limit = 60
	Settings.save()
	Settings.apply()
	# harita
	await _wait(0.5)
	check("harita oluşturuldu", world.map != null and world.map.map_tex != null)
	check("oyuncu çevresi keşfedildi", world.map.explored_ratio() > 0.0)
	world.hud.toggle_map()
	check("M haritayı açtı", world.hud._map_panel.visible)
	world.hud.back()
	check("geri tuşu haritayı kapattı", not world.hud._map_panel.visible)
	var hc := Vector2i(WorldGen.W / 2 + 3, 40)
	world._set_cell(hc, Blocks.GLASS)
	check("harita blok değişimini işledi", world.map.map_image.get_pixelv(hc).is_equal_approx(Blocks.color_of(Blocks.GLASS)))

	# ------------------------------------------------------------ oyun içi menü
	world.hud.back()
	check("Esc / geri tuşu menüyü açtı", world.hud._pause.visible)
	world.hud.back()
	check("ikinci kez menüyü kapattı", not world.hud._pause.visible)
	var left := [false]
	world.leave_requested.connect(func(): left[0] = true)
	world.request_leave()
	check("ana menüye dön sinyali", left[0])

	# ------------------------------------------------------------ dokunmatik
	Settings.touch_mode = 1
	world.hud._update_touch()
	var tc: TouchControls = world.hud.touch
	check("dokunmatik kontroller açıldı", tc != null and not world.hud._help.visible)
	me.position = world.cell_center(target) + Vector2(0, -56)
	me.velocity = Vector2.ZERO
	me._camera.reset_smoothing()
	await _wait(0.6)
	var pc := world.cell_at(me.position)
	for dx in range(-1, 9):
		for dy in range(-2, 2):
			world._server_set_cell(pc + Vector2i(dx, dy), Blocks.AIR)   # önünü aç: rastgele dünyada tepe olabilir
	var x0 := me.position.x
	var f0 := Engine.get_physics_frames()
	var t0 := Time.get_ticks_msec()
	var jc := _screen_of_viewport(tc.joy_center())
	_touch(0, jc, true)
	_drag(0, _screen_of_viewport(tc.joy_center() + Vector2(80, 0)))
	await _wait(0.5)
	check("joystick oyuncuyu sağa yüzdürdü (%.0f px, hız %.0f)" % [me.position.x - x0, me.velocity.x],
		me.position.x - x0 > 25.0 and me.velocity.x > 60.0)
	check("joystick vektörü", tc.move_vector().x > 0.8)
	_touch(0, jc, false)
	await _wait(0.4)
	check("bırakınca joystick sıfırlandı", tc.move_vector() == Vector2.ZERO)

	me.position = world.cell_center(target) + Vector2(0, -40)
	me.velocity = Vector2.ZERO
	me._camera.reset_smoothing()
	await _wait(0.5)
	var brk := target + Vector2i(1, 0)
	world._server_set_cell(brk, Blocks.SAND)
	world._last_break[1] = 0
	tc.mode = "break"
	# ikinci parmakla dünyaya bas (ilk parmak joystickte değil; index 1 kullan)
	_touch(1, _cell_screen(brk), true)
	for i in 12:
		_drag(1, _cell_screen(brk))
		await _wait(0.05)
	_touch(1, _cell_screen(brk), false)
	check("dokunarak blok kırıldı", world.get_cell_id(brk) == Blocks.AIR)

	var mode_btn: Rect2 = tc._buttons[0].rect
	_touch(2, _screen_of_viewport(mode_btn.get_center()), true)
	_touch(2, _screen_of_viewport(mode_btn.get_center()), false)
	await _wait(0.1)
	check("mod düğmesi KOY moduna geçti", tc.mode == "place")
	world.selected_slot = _slot_of(Blocks.GLASS)
	await _wait(0.2)
	_touch(1, _cell_screen(brk), true)
	await _wait(0.25)
	_touch(1, _cell_screen(brk), false)
	await _wait(0.1)
	check("dokunarak blok kondu", world.get_cell_id(brk) == Blocks.GLASS)

	world.bag.clear()
	world._bags[1].clear()
	var cid := world.wildlife.spawn(204, me.position + Vector2(24, -8))
	await _wait(0.3)
	var cpos := world.wildlife.view_pos(cid)
	_touch(1, _screen_of_viewport(root.get_canvas_transform() * cpos), true)
	await _wait(0.15)
	_touch(1, _screen_of_viewport(root.get_canvas_transform() * cpos), false)
	await _wait(0.1)
	check("canlıya dokunarak yakalandı", world.bag.size() == 1)

	var craft_btn: Rect2 = tc._buttons[1].rect
	_touch(3, _screen_of_viewport(craft_btn.get_center()), true)
	_touch(3, _screen_of_viewport(craft_btn.get_center()), false)
	await _wait(0.1)
	check("Envanter düğmesi pencereyi açtı", world.hud._inv.visible)
	world.hud.back()

	Settings.touch_mode = 0
	world.hud._update_touch()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	world.loaded = false
	print("%d/%d kontrol geçti" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _recipe(out: int) -> int:
	for i in Blocks.RECIPES.size():
		if Blocks.RECIPES[i]["out"] == out:
			return i
	return -1


## Test yardımcısı: envanterde bir eşyanın adedini ayarla
func _setc(inv: Dictionary, id: int, n: int) -> void:
	if Blocks.UPGRADE_MAX.has(id):
		inv.levels[id] = n
		return
	Inventory.take(inv, id, Inventory.count(inv, id))
	Inventory.give(inv, id, n)


## Hotbarda bu eşyanın bulunduğu yuva
func _slot_of(id: int) -> int:
	for i in Inventory.HOTBAR:
		if Inventory.slot_id(world.inventory, i) == id:
			return i
	return 8
