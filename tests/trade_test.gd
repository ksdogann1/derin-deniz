extends SceneTree
## İki istemcili takas testi. Önce sunucuyu başlat:
##   godot --headless --path . -- --server --port 7801 --world takas_test
## sonra iki ayrı süreçte:
##   godot --headless --path . --script res://tests/trade_test.gd -- --role a --port 7801
##   godot --headless --path . --script res://tests/trade_test.gd -- --role b --port 7801
## a: takas ister, eşya koyar, onaylar. b: önce reddeder, sonra kabul eder,
## onaydan sonra teklifi değiştirip onayların sıfırlandığını doğrular.

var world: World
var role := "a"
var port := 7801
var failures := 0
var checks := 0


func check(label: String, cond: bool) -> void:
	checks += 1
	print("[takas-%s] %s  %s" % [role, "OK  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--role" and i + 1 < a.size():
			role = a[i + 1]
		if a[i] == "--port" and i + 1 < a.size():
			port = int(a[i + 1])
	_run()


func _wait(sec: float) -> void:
	await create_timer(sec).timeout


## cond doğru olana kadar bekler (en fazla sec saniye)
func _until(cond: Callable, sec := 8.0) -> bool:
	var n := int(sec / 0.1)
	for i in n:
		if cond.call():
			return true
		await _wait(0.1)
	return cond.call()


func _finish() -> void:
	print("[takas-%s] %d/%d kontrol geçti" % [role, checks - failures, checks])
	quit(1 if failures > 0 else 0)


func _other() -> int:
	for n in world.players():
		var p := n as Player
		if p != null and p.peer_id != multiplayer_id():
			return p.peer_id
	return -1


func multiplayer_id() -> int:
	return get_multiplayer().get_unique_id()


func _count(id: int) -> int:
	return Inventory.count(world.inventory, id)


func _run() -> void:
	var peer := NetTools.client_peer("127.0.0.1", port)
	if peer == null:
		check("istemci oluşturuldu", false)
		_finish()
		return
	get_multiplayer().multiplayer_peer = peer
	var conn := await _until(func(): return peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED, 10.0)
	check("sunucuya bağlandı", conn)
	if not conn:
		_finish()
		return
	var main := Node.new()
	main.name = "Main"
	root.add_child(main)
	world = World.new()
	world.dedicated = true
	world.player_name = "Takasci" + role.to_upper()
	main.add_child(world)
	var ok := await _until(func(): return world.loaded and world.local_player() != null, 15.0)
	check("dünyaya girdi", ok)
	if not ok:
		_finish()
		return
	ok = await _until(func(): return _other() > 0, 15.0)
	check("diğer oyuncu göründü", ok)
	if not ok:
		_finish()
		return
	var tr: Trade = world.trade
	if role == "a":
		await _run_a(tr)
	else:
		await _run_b(tr)
	_finish()


func _run_a(tr: Trade) -> void:
	var other := _other()
	await _wait(1.0)
	# 1) ilk istek reddedilecek
	tr.request(other)
	await _wait(2.0)
	check("reddedilince takas açılmadı", tr.state.is_empty())
	# 2) ikinci istek kabul edilecek
	tr.request(other)
	var ok := await _until(func(): return not tr.state.is_empty())
	check("takas penceresi açıldı", ok)
	if not ok:
		return
	var my_id := Inventory.slot_id(world.inventory, 0)
	var my_n := int(world.inventory.slots[0][1])
	var before_mine := _count(my_id)
	tr.offer_slot(0, 0)          # yığının tamamı
	ok = await _until(func(): return (tr.state.get("mine", []) as Array).size() == 1)
	check("teklifim sunucudan döndü", ok)
	check("teklif miktarı doğru", ok and int(tr.state.mine[0][1]) == my_n)
	# hile: elde olandan fazlası teklif edilemez
	tr.offer_slot(0, 999)
	await _wait(0.8)
	check("elde olandan fazlası eklenmedi", _offered_total(tr.state.mine) <= before_mine)
	my_n = _offered_total(tr.state.mine)
	var gold0 := int(world.inventory.get("gold", 0))
	tr.offer_gold(10)
	ok = await _until(func(): return int(tr.state.get("my_gold", 0)) == 10)
	check("altın teklife kondu", ok)
	ok = await _until(func(): return (tr.state.get("theirs", []) as Array).size() > 0)
	check("karşı teklif göründü", ok)
	tr.set_ready(true)
	ok = await _until(func(): return bool(tr.state.get("my_ok", false)))
	check("onayım göründü", ok)
	# b teklifini değiştirince onayım sıfırlanmalı
	ok = await _until(func(): return not bool(tr.state.get("my_ok", true)) and _offered_total(tr.state.get("theirs", [])) == 2)
	check("teklif değişince onay sıfırlandı", ok)
	var their_id := int(tr.state.theirs[0][0])
	var before_theirs := _count(their_id)
	ok = await _until(func(): return bool(tr.state.get("their_ok", false)))
	check("karşı taraf yeniden onayladı", ok)
	tr.set_ready(true)
	ok = await _until(func(): return tr.state.is_empty())
	check("takas kapandı", ok)
	ok = await _until(func(): return _count(their_id) == before_theirs + 2)
	check("karşı eşyalar envantere geldi (+2)", ok)
	check("verdiğim yığın envanterden düştü", _count(my_id) == before_mine - my_n)
	check("verdiğim 10 altın düştü", int(world.inventory.get("gold", 0)) == gold0 - 10)


func _run_b(tr: Trade) -> void:
	var ok := await _until(func(): return tr.invite_from > 0)
	check("takas isteği geldi", ok)
	tr.answer(tr.invite_from, false)
	ok = await _until(func(): return tr.invite_from > 0)
	check("ikinci istek geldi", ok)
	tr.answer(tr.invite_from, true)
	ok = await _until(func(): return not tr.state.is_empty())
	check("takas penceresi açıldı", ok)
	ok = await _until(func(): return (tr.state.get("theirs", []) as Array).size() > 0)
	check("karşı teklif göründü", ok)
	if not ok:
		return
	var their_id := int(tr.state.theirs[0][0])
	var their_n := int(tr.state.theirs[0][1])
	var gold0 := int(world.inventory.get("gold", 0))
	# A'nın teklifinden farklı bir eşya bul (en az 2 adet)
	var slot := -1
	for i in Inventory.SLOTS:
		var id := Inventory.slot_id(world.inventory, i)
		if id != 0 and id != their_id and int(world.inventory.slots[i][1]) >= 2:
			slot = i
			break
	check("verilecek eşya bulundu", slot >= 0)
	if slot < 0:
		tr.cancel()
		return
	var my_id := Inventory.slot_id(world.inventory, slot)
	var before_mine := _count(my_id)
	var before_theirs := _count(their_id)
	tr.offer_slot(slot, 1)
	ok = await _until(func(): return bool(tr.state.get("their_ok", false)))
	check("karşı tarafın onayı göründü", ok)
	await _wait(1.0)             # a'nın onayını görmesine zaman tanı
	tr.offer_slot(slot, 1)       # onaydan sonra değişiklik
	ok = await _until(func(): return not bool(tr.state.get("their_ok", true)) and _offered_total(tr.state.mine) == 2)
	check("değişiklik karşı onayı sıfırladı", ok)
	tr.set_ready(true)
	ok = await _until(func(): return tr.state.is_empty())
	check("takas tamamlandı", ok)
	ok = await _until(func(): return _count(their_id) == before_theirs + their_n)
	check("gelen yığın envantere girdi", ok)
	check("verdiğim 2 eşya düştü", _count(my_id) == before_mine - 2)
	check("karşı tarafın 10 altını geldi", int(world.inventory.get("gold", 0)) == gold0 + 10)


func _offered_total(list: Array) -> int:
	var n := 0
	for e in list:
		n += int(e[1])
	return n
