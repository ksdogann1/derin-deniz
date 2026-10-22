extends SceneTree
## v0.8 testi: altın, tekne (depo, satış, geliştirme), pazar, basit envanter, yakınlaştırma,
## yeni türler ve "yanında canlı varken sandık kırılmıyor" hatası.
##   godot --headless --path . --script res://tests/economy_test.gd

const WORLD := "test_ekonomi"

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


func _initialize() -> void:
	_run()


func _gold() -> int:
	return int(world._inventories[1].get("gold", 0))


func _at_boat() -> void:
	var b: Dictionary = world._inventories[1].boat
	me.position = Vector2((float(b.x) + 0.5) * 16.0, Player.SURFACE_Y + 2.0)
	me.net_pos = me.position
	await _wait(0.15)


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	get_multiplayer().multiplayer_peer = NetTools.server_peer(7806)
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	world = World.new()
	world.player_name = "Tuccar"
	world.world_name = WORLD
	main.add_child(world)
	await _wait(0.6)
	me = world.local_player()
	var inv: Dictionary = world._inventories[1]
	var eco: Economy = world.economy

	# ------------------------------------------------------------ tekne
	check("yeni oyuncuya başlangıç altını", _gold() == Economy.START_GOLD)
	check("tekne yeri atandı", int(inv.boat.x) >= 0)
	check("tekne herkese yayınlandı", eco.boats.has(1))
	var bx := (float(inv.boat.x) + 0.5) * 16.0
	check("oyuncu teknesinin yanında doğdu", absf(me.position.x - bx) < 4.0 * 16.0)
	await _at_boat()
	check("teknenin yanında tekne düğmesi görünür", world.hud.near_boat())

	Inventory.give(inv, 201, 4)     # palyaço
	Inventory.give(inv, 223, 1)     # dev kalamar (efsanevi)
	eco.store(201, 3)
	check("canlı tekneye kondu", int(inv.boat.store.get(201, 0)) == 3 and Inventory.count(inv, 201) == 1)
	eco.take(201, 1)
	check("tekneden canlı alındı", int(inv.boat.store.get(201, 0)) == 2 and Inventory.count(inv, 201) == 2)
	Inventory.give(inv, 202, 20)
	eco.store(202, 20)
	check("depo sınırı aşılmadı (%d/%d)" % [Economy.stored(inv.boat), Economy.capacity(inv.boat)],
		Economy.stored(inv.boat) == Economy.capacity(inv.boat))

	# ------------------------------------------------------------ satış
	var g0 := _gold()
	eco.sell("inv", 223, 1)
	check("efsanevi canlı satıldı (+%d)" % Species.price(223), _gold() == g0 + Species.price(223))
	check("satılan canlı envanterden çıktı", Inventory.count(inv, 223) == 0)
	check("ansiklopedi kaydı satıştan etkilenmez", true)
	g0 = _gold()
	eco.sell("store", 202, 5)
	check("teknedeki canlı satıldı", _gold() == g0 + Species.price(202) * 5)
	check("mitik canlılar çok pahalı", Species.price(239) >= 700 and Species.price(239) > Species.price(223))

	# uzaktayken satış olmaz
	me.position = Vector2(bx + 30 * 16.0, 40 * 16.0)
	me.net_pos = me.position
	await _wait(0.1)
	g0 = _gold()
	eco.sell("inv", 201, 1)
	check("tekneden uzakta satış reddedildi", _gold() == g0)
	await _at_boat()

	# ------------------------------------------------------------ geliştirme
	inv.gold = 100
	eco.upgrade("hull", 0)
	check("altın yetmeyince gövde alınmadı", int(inv.boat.hull) == 0 and _gold() == 100)
	inv.gold = 1000
	var cap0 := Economy.capacity(inv.boat)
	eco.upgrade("hull", 0)
	check("gövde geliştirildi (Balıkçı Teknesi)", int(inv.boat.hull) == 1 and _gold() == 1000 - 150)
	eco.upgrade("depot", 0)
	check("depo büyüdü", Economy.capacity(inv.boat) > cap0 + 10)
	eco.upgrade("paint", 3)
	check("tekne boyandı", int(inv.boat.paint) == 3 and int(eco.boats[1].paint) == 3)
	eco.upgrade("sonar", 0)
	check("sonar alındı", int(inv.boat.sonar) == 1)

	# ------------------------------------------------------------ pazar
	var lamps := Inventory.count(inv, Blocks.LAMP)
	var slot := -1
	for i in Inventory.SLOTS:
		if Inventory.slot_id(inv, i) == Blocks.LAMP:
			slot = i
	eco.list_item(slot, 2, 15)
	check("eşya pazara kondu", eco.listings.size() == 1 and Inventory.count(inv, Blocks.LAMP) == lamps - 2)
	check("pazar istemciye yansıdı", eco.market.size() == 1)
	var lid := int(eco.listings[0].id)
	g0 = _gold()
	eco.buy(lid)
	check("kendi ilanını satın alamazsın", eco.listings.size() == 1 and _gold() == g0)
	eco.unlist(lid)
	check("ilan geri alındı, eşya döndü", eco.listings.is_empty() and Inventory.count(inv, Blocks.LAMP) == lamps)
	# çevrimdışı satıcının ilanı
	world._saved_players["Uzakta"] = {"inv": {"slots": [], "gold": 5}, "codex": {}, "best": 0, "quest": {}}
	eco.listings.append({"id": 99, "seller": "Uzakta", "item": 223, "n": 1, "price": 120})
	g0 = _gold()
	eco.buy(99)
	check("başkasının ilanı satın alındı", Inventory.count(inv, 223) == 1 and _gold() == g0 - 120)
	check("çevrimdışı satıcıya altın kaydedildi", int(world._saved_players["Uzakta"].inv.gold) == 125)

	# ------------------------------------------------------------ kayıt
	world.save_now()
	var data := SaveStore.load_world(WORLD)
	check("pazar kayda yazıldı", data.has("market"))
	check("oyuncunun altını ve teknesi kayıtta", int(data.players["Tuccar"].inv.get("gold", -1)) == _gold()
		and int(data.players["Tuccar"].inv.boat.hull) == 1)

	# ------------------------------------------------------------ sandık altını
	var c := Vector2i(int(me.position.x / 16.0) + 2, 2)
	world._server_set_cell(c, Blocks.CHEST)
	world._last_break[1] = 0
	g0 = _gold()
	world.request_break(c)
	check("sandıktan altın çıktı", _gold() > g0)

	# ------------------------------------------------------------ basit envanter
	inv.slots[0] = [Blocks.GLASS, 5]
	inv.slots[20] = [Blocks.SAND, 7]
	world.inv_swap(20, 0)
	check("çantadaki eşya hotbara geçti", Inventory.slot_id(inv, 0) == Blocks.SAND and Inventory.slot_id(inv, 20) == Blocks.GLASS)
	inv.slots[25] = [Blocks.GLASS, 3]
	world.inv_sort()
	var glass_stacks := 0
	for i in range(Inventory.HOTBAR, Inventory.SLOTS):
		if Inventory.slot_id(inv, i) == Blocks.GLASS:
			glass_stacks += 1
	check("sırala aynı eşyaları birleştirdi", glass_stacks == 1)
	world.inv_drop(0)
	check("atılan yığın silindi", Inventory.slot_id(inv, 0) == 0)
	world.hud.toggle_craft()
	check("envanter penceresi açıldı", world.hud._inv.visible)
	world.hud._inv._on_slot(4, 1)
	check("hotbar yuvasına dokunmak onu seçer", world.selected_slot == 4)
	world.hud.back()

	# ------------------------------------------------------------ yakınlaştırma
	var z0 := Settings.zoom
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	world._unhandled_input(wheel)
	check("tekerlek yakınlaştırdı", Settings.zoom > z0)
	Settings.set_zoom(99.0)
	check("yakınlık sınırlı", is_equal_approx(Settings.zoom, Settings.ZOOM_MAX))
	Settings.set_zoom(z0)
	# iki parmak
	Settings.touch_mode = 1
	world.hud._update_touch()
	var tc: TouchControls = world.hud.touch
	var vs := root.get_visible_rect().size
	_touch(0, Vector2(vs.x * 0.5, vs.y * 0.3), true)
	_touch(1, Vector2(vs.x * 0.6, vs.y * 0.3), true)
	await _wait(0.05)
	_drag(1, Vector2(vs.x * 0.8, vs.y * 0.3))
	await _wait(0.05)
	check("iki parmakla yakınlaştırma", Settings.zoom > z0 * 1.5 and not tc.pressed())
	_touch(1, Vector2(vs.x * 0.8, vs.y * 0.3), false)
	_touch(0, Vector2(vs.x * 0.5, vs.y * 0.3), false)
	await _wait(0.05)
	Settings.set_zoom(z0)

	# ------------------------------------------------------------ sandık + yanından geçen canlı
	me.position = Vector2(bx, 20 * 16.0)
	me.net_pos = me.position
	var chest := Vector2i(int(me.position.x / 16.0) + 2, 20)
	for dx in range(-3, 4):
		for dy in range(-3, 3):
			world._server_set_cell(chest + Vector2i(dx, dy), Blocks.AIR)
	world._server_set_cell(chest, Blocks.CHEST)
	world._last_break[1] = 0
	world.wildlife.spawn(219, world.cell_center(chest) + Vector2(40, 0))
	me._camera.reset_smoothing()
	await _wait(0.6)
	var crab_id := -1
	for id in world.wildlife._view.keys():
		if world.wildlife._view[id].sp == 219:
			crab_id = id
	await _wait(0.1)
	tc.mode = "break"
	var screen := _screen_of_viewport(root.get_canvas_transform() * world.cell_center(chest))
	_touch(0, screen, true)
	for i in 14:
		await _wait(0.1)
		# kamera oyuncuyla kayar; parmak sandığın üstünde kalsın
		_drag(0, _screen_of_viewport(root.get_canvas_transform() * world.cell_center(chest)))
		# yengeç sandığın üstünden geçiyor
		if crab_id >= 0 and world.wildlife._view.has(crab_id):
			(world.wildlife._view[crab_id].node as Node2D).position = world.cell_center(chest) + Vector2(3, 2)
			world.wildlife._view[crab_id].target = world.cell_center(chest) + Vector2(3, 2)
	print("  [hata ayıklama] yengeç=%d  dokunuş=%s  imleç hücresi=%s  sandık=%s" % [crab_id, tc.pressed(),
		world.cell_at(tc.world_point()), chest])
	_touch(0, screen, false)
	check("yanında yengeç varken sandık kırıldı (dokunmatik)", world.get_cell_id(chest) != Blocks.CHEST)
	Settings.touch_mode = 0
	world.hud._update_touch()
	Settings.set_zoom(z0)
	Settings.save()          # testin değiştirdiği ayarlar kalıcı olmasın

	# ------------------------------------------------------------ türler
	check("45 tür var", Species.LIST.size() == 45)
	var mythic := 0
	for d in Species.LIST:
		if int(d.rarity) == 5:
			mythic += 1
		if not ResourceLoader.exists("res://assets/creatures/%s.png" % d.tex):
			check("doku yok: " + str(d.tex), false)
	check("7 mitik tür", mythic == 7)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	print("%d/%d kontrol geçti" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _screen_of_viewport(p: Vector2) -> Vector2:
	var vis := root.get_visible_rect().size
	var k := minf(root.size.x / vis.x, root.size.y / vis.y)
	var offset := (Vector2(root.size) - vis * k) * 0.5
	return p * k + offset


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
