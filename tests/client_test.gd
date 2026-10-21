extends SceneTree
## Otomatik ağ testi. Önce sunucuyu başlat:
##   godot --headless --path . -- --server --port 7799
## sonra (ayrı süreçlerde):
##   godot --headless --path . --script res://tests/client_test.gd -- --role observer --port 7799
##   godot --headless --path . --script res://tests/client_test.gd -- --role actor    --port 7799
##   godot --headless --path . --script res://tests/client_test.gd -- --role latejoin --port 7799
## Roller: actor (blok kırar/koyar, hileli istekleri dener), observer (başkasının
## değişikliklerini görür), latejoin (sonradan katılana güncel dünya gelir).

var world: World
var role := "actor"
var port := 7799
var failures := 0
var checks := 0


func check(label: String, cond: bool) -> void:
	checks += 1
	if cond:
		print("[%s] OK    %s" % [role, label])
	else:
		failures += 1
		print("[%s] FAIL  %s" % [role, label])


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--role" and i + 1 < a.size():
			role = a[i + 1]
		if a[i] == "--port" and i + 1 < a.size():
			port = int(a[i + 1])
	_run()


## Üstünde 5 boş hücre olan ilk kum hücresi (sütunlar 64..90 taranır).
func _find_floor_cell() -> Vector2i:
	for x in range(WorldGen.W / 2, WorldGen.W / 2 + 27):
		for y in range(6, WorldGen.H - 1):
			if world.get_cell_id(Vector2i(x, y)) != Blocks.SAND:
				continue
			var free := true
			for k in range(1, 6):
				if world.get_cell_id(Vector2i(x, y - k)) != Blocks.AIR:
					free = false
					break
			if free:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Oyuncuların koyduğu ilk cam bloğu (geç katılan testi için).
func _find_glass_cell() -> Vector2i:
	for x in range(WorldGen.W / 2, WorldGen.W / 2 + 27):
		for y in WorldGen.H:
			if world.get_cell_id(Vector2i(x, y)) == Blocks.GLASS:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


func _finish() -> void:
	print("[%s] %d/%d kontrol geçti" % [role, checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _run() -> void:
	var peer := NetTools.client_peer("127.0.0.1", port)
	if peer == null:
		print("[%s] FAIL  istemci oluşturulamadı" % role)
		quit(1)
		return
	get_multiplayer().multiplayer_peer = peer

	var ok := false
	for i in 100:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			ok = true
			break
		await _wait(0.1)
	check("sunucuya bağlandı", ok)
	if not ok:
		_finish()
		return

	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	world = World.new()
	world.dedicated = true
	world.player_name = role
	main.add_child(world)

	var ready := false
	for i in 150:
		if world.loaded and world.local_player() != null:
			ready = true
			break
		await _wait(0.1)
	check("dünya yüklendi ve oyuncu doğdu", ready)
	if not ready:
		_finish()
		return
	check("dünya boyutu doğru", world.cells.size() == WorldGen.W * WorldGen.H)

	var target := _find_floor_cell()
	check("kum zemini bulundu", target.x >= 0)
	var above := target + Vector2i(0, -1)

	match role:
		"actor":
			await _run_actor(target, above)
		"observer":
			await _run_observer(target, above)
		"latejoin":
			var g := _find_glass_cell()
			check("geç katılana güncel dünya: cam bloğu", g.x >= 0)
			check("geç katılana güncel dünya: fener", g.x >= 0 and world.get_cell_id(g + Vector2i(0, -1)) == Blocks.LAMP)
	_finish()


func _run_actor(target: Vector2i, above: Vector2i) -> void:
	await _wait(1.5)     # observer'ın bizi görmesine zaman tanı
	var me := world.local_player()
	me.position = world.cell_center(target) + Vector2(0, -72)
	me.velocity = Vector2.ZERO
	await _wait(0.4)     # konum sunucuya ulaşsın

	var before_sand := world.have(Blocks.SAND)
	world.request_break(target)
	await _wait(0.6)
	check("kum kırıldı", world.get_cell_id(target) == Blocks.AIR)
	check("envantere kum eklendi", world.have(Blocks.SAND) == before_sand + 1)

	world.request_place(target, _slot_of(Blocks.GLASS))
	await _wait(0.6)
	check("cam konuldu", world.get_cell_id(target) == Blocks.GLASS)
	check("cam stoğu düştü", world.have(Blocks.GLASS) == 7)

	world.request_craft(0)                     # 3 kum gerekir, 1 var
	await _wait(0.5)
	check("ağ: malzemesiz üretim reddedildi", world.have(Blocks.SAND) == before_sand + 1
		and world.have(Blocks.GLASS) == 7)

	# envanter: camı hotbardan çantaya taşı (sol tık al, sol tık bırak)
	var gs := _slot_of(Blocks.GLASS)
	world.inv_click("inv", gs, 1, false)
	world.inv_click("inv", 30, 1, false)
	check("ağ: envanter tıklaması anında göründü", Inventory.slot_id(world.inventory, 30) == Blocks.GLASS)
	world.inventory = Inventory.create({})      # yerel kopyayı boz: sunucunun kesin durumu gelmeli
	world.inv_click("trash", 0, 1, false)       # imleç boşken çöp: etkisiz, sunucu durumu yollar
	await _wait(0.5)
	check("ağ: sunucu envanter tıklamasını uyguladı", Inventory.slot_id(world.inventory, 30) == Blocks.GLASS
		and world.have(Blocks.GLASS) == 7)
	world.inv_click("inv", 30, 1, true)         # shift: geri hotbara
	await _wait(0.4)
	check("ağ: shift ile hotbara döndü", _slot_of(Blocks.GLASS) < Inventory.HOTBAR and _slot_of(Blocks.GLASS) != 8)

	world.send_chat("selam deniz")
	world.send_chat("spam")                    # hız sınırına takılmalı
	await _wait(0.5)
	check("ağ: kendi mesajım sunucudan döndü", world.chat_history.has("actor: selam deniz"))
	check("ağ: art arda mesaj sınırlandı", not world.chat_history.has("actor: spam"))

	var seen_wild := false
	for i in 40:
		if world.wildlife.count() > 0:
			seen_wild = true
			break
		await _wait(0.1)
	check("ağ: sunucudaki canlılar istemciye eşitlendi", seen_wild)
	if seen_wild:
		var wid: int = world.wildlife._view.keys()[0]
		world.request_catch(wid)
		await _wait(0.4)
		check("ağ: ağsız yakalama reddedildi", world.bag.is_empty())
	me.position = world.cell_center(target) + Vector2(0, -72)   # beklerken battı, yerine al
	me.velocity = Vector2.ZERO
	await _wait(0.4)

	world.request_place(above, 8)   # boş yuva: koyacak blok yok
	await _wait(0.6)
	check("stoğu olmayan blok konamadı", world.get_cell_id(above) == Blocks.AIR)

	world.request_place(above, _slot_of(Blocks.LAMP))
	await _wait(0.6)
	check("fener konuldu", world.get_cell_id(above) == Blocks.LAMP)

	world.request_place(target, _slot_of(Blocks.LAMP))  # dolu hücreye koyma
	await _wait(0.6)
	check("dolu hücreye blok konamadı", world.get_cell_id(target) == Blocks.GLASS)

	# Menzil dışı kırma: en az 20 hücre uzakta katı bir hücre bul
	var far := Vector2i(-1, -1)
	for y in range(target.y + 20, WorldGen.H - 4):
		if Blocks.is_breakable(world.get_cell_id(Vector2i(target.x, y))):
			far = Vector2i(target.x, y)
			break
	check("uzak hücre bulundu", far.x >= 0)
	var far_id := world.get_cell_id(far)
	world.request_break(far)
	await _wait(0.6)
	check("menzil dışı kırma reddedildi", world.get_cell_id(far) == far_id)

	# Kırılmaz taban
	world.request_break(Vector2i(0, 50))
	world.request_break(Vector2i(WorldGen.W / 2, WorldGen.H - 1))
	await _wait(0.6)
	check("taban kırılamadı", world.get_cell_id(Vector2i(0, 50)) == Blocks.BEDROCK)

	# Hız sınırı: peş peşe istekler
	var neighbors: Array[Vector2i] = []
	for dx in [-1, 1, -2, 2]:
		var c := Vector2i(target.x + dx, target.y)
		if world.get_cell_id(c) == Blocks.SAND:
			neighbors.append(c)
	if neighbors.size() >= 3:
		for c in neighbors:
			world.request_break(c)
		await _wait(0.8)
		var broken := 0
		for c in neighbors:
			if world.get_cell_id(c) == Blocks.AIR:
				broken += 1
		check("aynı anda gelen kırma istekleri sınırlandı (%d/%d)" % [broken, neighbors.size()], broken < neighbors.size())
	else:
		print("[actor] (hız sınırı testi atlandı: yeterli komşu kum yok)")

	await _wait(3.0)     # observer değişiklikleri görsün


func _run_observer(target: Vector2i, above: Vector2i) -> void:
	var saw_actor := false
	for i in 200:
		if world.player_count() >= 2:
			saw_actor = true
			break
		await _wait(0.1)
	check("diğer oyuncu göründü", saw_actor)
	var actor_node: Player = null
	for p in world.get_node("Players").get_children():
		if p is Player and not p.is_local:
			actor_node = p

	# Actor'ın değişikliklerini bekle (en fazla 25 sn)
	var changed := false
	for i in 250:
		if world.get_cell_id(target) == Blocks.GLASS and world.get_cell_id(above) == Blocks.LAMP:
			changed = true
			break
		await _wait(0.1)
	check("cam bloğu ve fener başkasının değişikliğinden geldi", changed)
	check("başkasının sohbet mesajı geldi", world.chat_history.has("actor: selam deniz"))
	check("katılma bildirimi geldi", world.chat_history.has(": actor dalışa katıldı"))
	if actor_node != null and is_instance_valid(actor_node):
		var dist := actor_node.position.distance_to(world.cell_center(target) + Vector2(0, -72))
		check("diğer oyuncunun konumu eşitlendi (%.0f px)" % dist, dist < 130.0)

	# Actor ayrılınca düğümü silinmeli (en fazla 20 sn)
	var gone := false
	for i in 200:
		if world.player_count() == 1:
			gone = true
			break
		await _wait(0.1)
	check("oyuncu ayrılınca silindi", gone)


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
