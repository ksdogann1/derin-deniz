extends SceneTree
## Yerel oynanış testi (sunucu + oyuncu tek süreçte). Fare girdisini taklit
## ederek kırma/koyma akışını, üretimi, hazineyi, oksijeni, sohbeti ve
## kayıt/yüklemeyi dener.
##   godot --headless --path . --script res://tests/local_test.gd

const WORLD := "test_yerel"

var world: World
var failures := 0
var checks := 0


func check(label: String, cond: bool) -> void:
	checks += 1
	print("%s  %s" % ["OK  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## Hücrenin ekran konumu (başsız modda pencere 64x64; içerik ölçeğini hesaba kat)
func _screen_of(cell: Vector2i) -> Vector2:
	var content: Vector2 = root.get_canvas_transform() * world.cell_center(cell)
	var vis := root.get_visible_rect().size
	var k := minf(root.size.x / vis.x, root.size.y / vis.y)
	var offset := (Vector2(root.size) - vis * k) * 0.5
	return content * k + offset


func _mouse_to(cell: Vector2i) -> void:
	var screen := _screen_of(cell)
	var ev := InputEventMouseMotion.new()
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)


func _button(index: MouseButton, pressed: bool, cell: Vector2i) -> void:
	var screen := _screen_of(cell)
	var ev := InputEventMouseButton.new()
	ev.button_index = index
	ev.pressed = pressed
	ev.position = screen
	ev.global_position = screen
	Input.parse_input_event(ev)


func _aim_wait(sec: float, cell: Vector2i) -> void:
	var t := 0.0
	while t < sec:
		_mouse_to(cell)
		await _wait(0.04)
		t += 0.04


func _key(k: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


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


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(7803, 4)
	get_multiplayer().multiplayer_peer = peer
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	world = World.new()
	world.player_name = "Yerel"
	world.world_name = WORLD
	main.add_child(world)
	await _wait(0.5)

	var me := world.local_player()
	check("yerel oyuncu doğdu", me != null)
	check("başlangıç envanteri geldi", world.have(Blocks.LAMP) == 4)
	check("dünya diske kaydedildi", SaveStore.exists(WORLD))
	var wall_count := 0
	for w in world.walls:
		if w != Blocks.AIR:
			wall_count += 1
	check("arka duvarlar üretildi (%d)" % wall_count, wall_count > WorldGen.W * 100)
	var chest_count := world.cells.count(Blocks.CHEST)
	check("hazine sandıkları üretildi (%d)" % chest_count, chest_count >= 2)

	var target := _find_open_sand()
	check("kum hücresi bulundu", target.x >= 0)
	me.position = world.cell_center(target) + Vector2(0, -56)
	me.velocity = Vector2.ZERO
	me._camera.reset_smoothing()
	await _wait(1.0)

	# --- Fareyle kırma
	await _aim_wait(0.1, target)
	_button(MOUSE_BUTTON_LEFT, true, target)
	await _aim_wait(0.12, target)
	check("kırma ilerlemesi görünüyor (çatlak %.2f)" % world.crack, world.crack > 0.0)
	await _aim_wait(0.6, target)
	_button(MOUSE_BUTTON_LEFT, false, target)
	check("blok fareyle kırıldı", world.get_cell_id(target) == Blocks.AIR)
	check("kum envantere girdi", world.have(Blocks.SAND) == 1)

	# --- Fareyle koyma (seçili: cam)
	world.selected_slot = _slot_of(Blocks.GLASS)
	await _aim_wait(0.1, target)
	_button(MOUSE_BUTTON_RIGHT, true, target)
	await _aim_wait(0.3, target)
	_button(MOUSE_BUTTON_RIGHT, false, target)
	check("blok fareyle konuldu", world.get_cell_id(target) == Blocks.GLASS)
	check("cam stoğu azaldı", world.have(Blocks.GLASS) == 7)

	# --- Menzil dışı
	var far := Vector2i(target.x, target.y + 12)
	var far_id := world.get_cell_id(far)
	await _aim_wait(0.1, far)
	_button(MOUSE_BUTTON_LEFT, true, far)
	await _aim_wait(1.5, far)
	_button(MOUSE_BUTTON_LEFT, false, far)
	check("menzil dışı hücre kırılmadı", world.get_cell_id(far) == far_id)

	# --- Hotbar tuşları
	_key(KEY_1)
	await _wait(0.1)
	check("1 tuşu ilk yuvadaki feneri seçti", world.selected_block() == Blocks.LAMP)
	_key(KEY_9)
	await _wait(0.1)
	check("9 tuşu son hotbar yuvasını seçti", world.selected_slot == 8)

	# --- Üretim
	var inv: Dictionary = world._inventories[1]
	_setc(inv, Blocks.SAND, 3)
	world.request_craft(0)        # 3 kum -> 2 cam
	await _wait(0.1)
	check("üretim: 3 kum harcandı", world.have(Blocks.SAND) == 0)
	check("üretim: 2 cam eklendi", world.have(Blocks.GLASS) == 9)
	world.request_craft(0)        # kum yok
	await _wait(0.1)
	check("malzeme yokken üretim reddedildi", world.have(Blocks.GLASS) == 9)
	world.request_craft(99)
	check("geçersiz tarif reddedildi", world.have(Blocks.GLASS) == 9)
	_setc(inv, Blocks.PEARL, 100)
	_setc(inv, Blocks.ABYSS_STONE, 100)
	var tank_idx := -1
	for i in Blocks.RECIPES.size():
		if Blocks.RECIPES[i]["out"] == Blocks.TANK_UPGRADE:
			tank_idx = i
	for i in 5:
		world.request_craft(tank_idx)
	await _wait(0.1)
	check("tüp seviyesi en fazla 3", world.have(Blocks.TANK_UPGRADE) == 3)
	check("tüp yükseltmesi oksijeni artırdı", is_equal_approx(me.max_oxygen(), 150.0))
	_setc(inv, Blocks.TANK_UPGRADE, 0)
	_setc(inv, Blocks.PEARL, 0)
	world._send_inventory(1)

	# --- Hazine sandığı
	var chest_cell := target + Vector2i(1, -1)
	world._server_set_cell(chest_cell, Blocks.CHEST)
	world._last_break[1] = 0
	world.request_break(chest_cell)
	await _wait(0.1)
	check("sandık açıldı", world.get_cell_id(chest_cell) == Blocks.AIR)
	check("sandıktan inci çıktı (%d)" % world.have(Blocks.PEARL),
		world.have(Blocks.PEARL) >= 2)

	# --- İnci damarı inci verir
	var ore_cell := target + Vector2i(-1, -1)
	world._server_set_cell(ore_cell, Blocks.PEARL_ORE)
	var pearls := world.have(Blocks.PEARL)
	world._last_break[1] = 0
	world.request_break(ore_cell)
	await _wait(0.1)
	check("inci damarı inci verdi", world.have(Blocks.PEARL) == pearls + 1)

	# --- Oksijen
	var o2_before := me.oxygen
	await _wait(1.0)
	check("derinde oksijen azalıyor", me.oxygen < o2_before)
	var station := target + Vector2i(2, -2)
	world._server_set_cell(station, Blocks.OXYGEN)
	me.oxygen = 10.0
	await _wait(0.8)
	check("oksijen istasyonu yakınında oksijen doluyor", me.oxygen > 10.0 and me.near_station)
	world._server_set_cell(station, Blocks.AIR)
	me.position = world.spawn_pos()
	me.oxygen = 10.0
	await _wait(1.0)
	check("yüzeyde oksijen doluyor", me.oxygen > 10.0)
	check("yüzeyin üstüne çıkılamıyor", me.position.y >= Player.SURFACE_Y)
	me.position = world.cell_center(target) + Vector2(0, -56)
	me.oxygen = 0.05
	await _wait(0.5)
	check("oksijen bitince yüzeyde yeniden doğdu", me.position.y < 3.0 * 16.0 and me.oxygen > 50.0)

	# --- Sohbet (Enter ile aç, yazarken hareket kilitli)
	_key(KEY_ENTER)
	await _wait(0.1)
	check("Enter sohbet kutusunu açtı", world.input_locked())
	world.hud._on_chat_submit("Merhaba [b]deniz[/b]")
	await _wait(0.1)
	check("sohbet kutusu kapandı", not world.input_locked())
	check("mesaj geçmişe düştü", world.chat_history.size() > 0 and world.chat_history[-1].ends_with("Merhaba [b]deniz[/b]"))
	world.send_chat("spam")
	check("hızlı mesaj sınırlandı", not world.chat_history[-1].ends_with("spam"))

	# --- Canlılar ve yakalama
	me.position = world.cell_center(target) + Vector2(0, -56)
	me.velocity = Vector2.ZERO
	me.oxygen = me.max_oxygen()
	await _wait(2.0)
	check("sunucu oyuncu çevresinde canlı üretti (%d)" % world.wildlife.count(), world.wildlife.count() > 0)
	inv = world._inventories[1]
	_setc(inv, Blocks.NET, 0)
	world._send_inventory(1)
	var cid := world.wildlife.spawn(204, me.position + Vector2(18, 0))
	world.request_catch(cid)
	check("ağ olmadan yakalanamadı", world.bag.is_empty())
	_setc(inv, Blocks.NET, 1)
	world._send_inventory(1)
	var far_id2 := world.wildlife.spawn(204, me.position + Vector2(400, 0))
	world.request_catch(far_id2)
	check("uzaktaki canlı yakalanamadı", world.bag.is_empty())
	world.request_catch(cid)
	check("canlı yakalandı ve fileyeye girdi", world.bag == [204])
	world.request_catch(cid)
	check("aynı canlı iki kez yakalanamadı", world.bag.size() == 1)
	for i in 6:
		world.request_catch(world.wildlife.spawn(200, me.position + Vector2(10, 0)))
	check("fileye en fazla %d" % World.BAG_MAX, world.bag.size() == World.bag_max(world.inventory))
	world.report_death()
	check("ölünce fileyedekiler kaçtı", world.bag.is_empty())

	var pearls_before := world.have(Blocks.PEARL)
	world.request_catch(world.wildlife.spawn(204, me.position + Vector2(10, 0)))
	world.request_catch(world.wildlife.spawn(204, me.position + Vector2(10, 0)))
	me.position = world.spawn_pos()
	await _wait(0.8)
	check("yüzeyde fileye koleksiyona aktarıldı", world.bag.is_empty() and world.have(204) == 2)
	check("ansiklopediye işlendi", int(world.codex.get(204, 0)) == 2)
	var reward := int(Species.get_def(204)["reward"])
	check("ilk tür ödülü verildi (+%d inci)" % reward,
		world.have(Blocks.PEARL) == pearls_before + reward)

	# istasyon yanında da aktarılır, ama tekrar ödül yok
	me.position = world.cell_center(target) + Vector2(0, -56)
	await _wait(0.6)
	var st2 := target + Vector2i(2, -2)
	world._server_set_cell(st2, Blocks.OXYGEN)
	var pearls2 := world.have(Blocks.PEARL)
	world.request_catch(world.wildlife.spawn(204, me.position + Vector2(10, 0)))
	await _wait(0.8)
	check("oksijen istasyonunda da aktarıldı", world.bag.is_empty() and world.have(204) == 3)
	check("aynı türe ikinci kez ödül yok", world.have(Blocks.PEARL) == pearls2)
	world._server_set_cell(st2, Blocks.AIR)

	# --- Akvaryum
	var aq := target + Vector2i(-2, -1)
	world._server_set_cell(aq, Blocks.AQUARIUM)
	world.request_aquarium(aq, 204)
	check("akvaryuma canlı kondu", world.aquariums.get(aq, 0) == 204 and world.have(204) == 2)
	check("akvaryum görüntüsü oluştu", world._aq_nodes.has(aq))
	world.request_aquarium(aq, 207)
	check("elde olmayan canlı konamadı", world.aquariums.get(aq, 0) == 204)
	world._last_break[1] = 0
	world.request_break(aq)
	check("akvaryum kırılınca canlı geri geldi", not world.aquariums.has(aq) and world.have(204) == 3)

	# --- Yılanbalığı
	me.oxygen = 50.0
	world.wildlife.spawn(212, me.position)
	await _wait(0.3)
	check("yılanbalığı çarptı (oksijen %.1f)" % me.oxygen, me.oxygen <= 38.5)
	for id in world.wildlife.server_creatures().keys():
		if world.wildlife.server_creatures()[id].sp == 212:
			world.wildlife.server_creatures().erase(id)

	# --- Derinlik rekoru ödülü
	var pearls3 := world.have(Blocks.PEARL)
	world._bests[1] = 50
	me.position = Vector2(me.position.x, 65.0 * 16.0)
	me.oxygen = me.max_oxygen()
	await _wait(0.7)
	check("derinlik rekoru kaydedildi (%d)" % world._bests[1], int(world._bests[1]) >= 60)
	check("katman ödülü verildi", world.have(Blocks.PEARL) == pearls3 + 3)
	me.position = world.cell_center(target) + Vector2(0, -56)

	# --- Kayıt ve yükleme
	_setc(world._inventories[1], Blocks.CORAL, 42)
	world.save_now()
	var data := SaveStore.load_world(WORLD)
	check("kayıt okundu", not data.is_empty())
	check("kayıtta cam bloğu var", (data["cells"] as PackedByteArray)[target.y * WorldGen.W + target.x] == Blocks.GLASS)
	check("kayıtta oyuncu envanteri var", Inventory.count(data["players"]["Yerel"]["inv"], Blocks.CORAL) == 42)
	check("kayıtta ansiklopedi var", int(data["players"]["Yerel"]["codex"].get(204, 0)) == 3)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveStore.path_for(WORLD)))
	print("%d/%d kontrol geçti" % [checks - failures, checks])
	world.loaded = false        # çıkışta tekrar kaydetme
	quit(1 if failures > 0 else 0)


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
