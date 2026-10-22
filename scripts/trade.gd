class_name Trade
extends Node
## Oyuncular arası takas. Sunucu yetkilidir:
##  - Teklifler eşyaları envanterden almaz, sadece "ayırır"; sayılar her an doğrulanır.
##  - Teklif değişince iki tarafın onayı da sıfırlanır (son anda değiştirme hilesine karşı).
##  - İki taraf onaylayınca sunucu, iki envanterin kopyası üzerinde değiş tokuşu dener;
##    eşya eksikse ya da yer yoksa hiçbir şey değişmez. Başarılıysa tek seferde uygulanır.
## Ekipman seviyeleri takas edilemez; yuvadaki her eşya (canlılar dahil) edilebilir.

const MAX_OFFER := 9
const INVITE_MS := 20000

var world: Node            # World

# --- sunucu
var _invites := {}         # hedef peer -> {from, t}
var _trades := {}          # trade id -> {a, b, offer: {a: [], b: []}, ok: {a, b}}
var _of := {}              # peer -> trade id
var _next := 1

# --- istemci
var invite_from := -1
var invite_name := ""
var state: Dictionary = {}   # açık takasın özeti (boşsa takas yok)


func _ready() -> void:
	name = "Trade"
	multiplayer.peer_disconnected.connect(func(peer):
		if multiplayer.is_server():
			_cancel_for(peer, "Karşı taraf oyundan ayrıldı."))


# --------------------------------------------------------------------------
# İstemci API
# --------------------------------------------------------------------------

func request(target: int) -> void:
	_call("_s_request", [target])


func answer(from_peer: int, accept: bool) -> void:
	invite_from = -1
	_call("_s_answer", [from_peer, accept])


func offer_slot(slot: int, amount: int) -> void:
	_call("_s_offer", [slot, amount])


func offer_gold(amount: int) -> void:
	_call("_s_gold", [amount])


func remove_offer(index: int) -> void:
	_call("_s_remove", [index])


func set_ready(on: bool) -> void:
	_call("_s_ready", [on])


func cancel() -> void:
	_call("_s_cancel", [])


func _call(method: String, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, [1] + args)
	else:
		rpc_id(1, "_rpc_" + method.substr(3), args)


# Ağ girişleri (istemci -> sunucu). Tek bir RPC ile hepsini yönlendirmek yerine
# her işlem ayrı tutuldu ki yanlış biçimli istekler kolayca reddedilsin.
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 1:
		_s_request(multiplayer.get_remote_sender_id(), int(args[0]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_answer(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 2:
		_s_answer(multiplayer.get_remote_sender_id(), int(args[0]), bool(args[1]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_offer(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 2:
		_s_offer(multiplayer.get_remote_sender_id(), int(args[0]), int(args[1]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_gold(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 1:
		_s_gold(multiplayer.get_remote_sender_id(), int(args[0]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_remove(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 1:
		_s_remove(multiplayer.get_remote_sender_id(), int(args[0]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ready(args: Array) -> void:
	if multiplayer.is_server() and args.size() == 1:
		_s_ready(multiplayer.get_remote_sender_id(), bool(args[0]))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_cancel(args: Array) -> void:
	if multiplayer.is_server():
		_s_cancel(multiplayer.get_remote_sender_id())


# Sunucu -> istemci
@rpc("authority", "call_remote", "reliable")
func c_invite(from_peer: int, from_name: String) -> void:
	invite_from = from_peer
	invite_name = from_name
	world.play_ui("chat")
	if world.hud != null:
		world.hud.show_trade_invite(from_peer, from_name)


@rpc("authority", "call_remote", "reliable")
func c_state(st: Dictionary) -> void:
	state = st
	if world.hud != null:
		world.hud.show_trade(st)


@rpc("authority", "call_remote", "reliable")
func c_closed(msg: String, ok: bool) -> void:
	state = {}
	if world.hud != null:
		world.hud.close_trade()
	world.toast(msg)
	world.play_ui("treasure" if ok else "warn")


func _to(peer: int, method: String, args: Array) -> void:
	if peer == 1:
		if not world.dedicated:
			callv(method, args)
	else:
		callv("rpc_id", [peer, method] + args)


# --------------------------------------------------------------------------
# Sunucu
# --------------------------------------------------------------------------

func _valid_peer(p: int) -> bool:
	return world._joined.has(p)


func _s_request(peer: int, target: int) -> void:
	if target == peer or not _valid_peer(peer) or not _valid_peer(target):
		return
	if _of.has(peer) or _of.has(target):
		world._notify(peer, "Bu oyuncu şu an başka bir takasta.", "warn")
		return
	_invites[target] = {"from": peer, "t": Time.get_ticks_msec()}
	_to(target, "c_invite", [peer, world._names[peer]])
	world._notify(peer, "Takas isteği gönderildi: %s" % world._names[target], "")


func _s_answer(peer: int, from_peer: int, accept: bool) -> void:
	var inv: Dictionary = _invites.get(peer, {})
	if inv.is_empty() or int(inv.from) != from_peer:
		return
	_invites.erase(peer)
	if Time.get_ticks_msec() - int(inv.t) > INVITE_MS:
		world._notify(peer, "Takas isteğinin süresi doldu.", "warn")
		return
	if not accept:
		if _valid_peer(from_peer):
			world._notify(from_peer, "%s takas isteğini reddetti." % world._names[peer], "warn")
		return
	if not _valid_peer(from_peer) or _of.has(peer) or _of.has(from_peer):
		return
	var id := _next
	_next += 1
	_trades[id] = {"a": from_peer, "b": peer, "offer": {"a": [], "b": []}, "ok": {"a": false, "b": false},
		"gold": {"a": 0, "b": 0}}
	_of[from_peer] = id
	_of[peer] = id
	_broadcast(id)


func _side(t: Dictionary, peer: int) -> String:
	return "a" if int(t.a) == peer else "b"


func _offered(list: Array, id: int) -> int:
	var n := 0
	for e in list:
		if int(e[0]) == id:
			n += int(e[1])
	return n


func _s_offer(peer: int, slot: int, amount: int) -> void:
	if not _of.has(peer):
		return
	var t: Dictionary = _trades[_of[peer]]
	var inv: Dictionary = world._inventories[peer]
	var id := Inventory.slot_id(inv, slot)
	if id == 0:
		return
	var list: Array = t.offer[_side(t, peer)]
	var free := Inventory.count(inv, id) - _offered(list, id)
	var n := mini(free, int(inv.slots[slot][1]) if amount <= 0 else amount)
	if n <= 0:
		return
	var merged := false
	for e in list:
		if int(e[0]) == id and int(e[1]) + n <= Inventory.max_stack(id):
			e[1] = int(e[1]) + n
			merged = true
			break
	if not merged:
		if list.size() >= MAX_OFFER:
			world._notify(peer, "Teklife en fazla %d yığın konabilir." % MAX_OFFER, "warn")
			return
		list.append([id, n])
	_changed(_of[peer])


func _s_gold(peer: int, amount: int) -> void:
	if not _of.has(peer):
		return
	var t: Dictionary = _trades[_of[peer]]
	var have := int((world._inventories[peer] as Dictionary).get("gold", 0))
	t.gold[_side(t, peer)] = clampi(amount, 0, have)
	_changed(_of[peer])


func _s_remove(peer: int, index: int) -> void:
	if not _of.has(peer):
		return
	var t: Dictionary = _trades[_of[peer]]
	var list: Array = t.offer[_side(t, peer)]
	if index < 0 or index >= list.size():
		return
	list.remove_at(index)
	_changed(_of[peer])


## Teklif değişti: iki onayı da sıfırla
func _changed(id: int) -> void:
	var t: Dictionary = _trades[id]
	t.ok.a = false
	t.ok.b = false
	_broadcast(id)


func _s_ready(peer: int, on: bool) -> void:
	if not _of.has(peer):
		return
	var id: int = _of[peer]
	var t: Dictionary = _trades[id]
	t.ok[_side(t, peer)] = on
	if t.ok.a and t.ok.b:
		_finish(id)
	else:
		_broadcast(id)


func _s_cancel(peer: int) -> void:
	_cancel_for(peer, "%s takası iptal etti." % world._names.get(peer, "Oyuncu"))


func _cancel_for(peer: int, msg: String) -> void:
	_invites.erase(peer)
	if not _of.has(peer):
		return
	var id: int = _of[peer]
	var t: Dictionary = _trades[id]
	_close(id)
	for p in [int(t.a), int(t.b)]:
		if _valid_peer(p):
			_to(p, "c_closed", [msg, false])


func _close(id: int) -> void:
	var t: Dictionary = _trades.get(id, {})
	if t.is_empty():
		return
	_of.erase(int(t.a))
	_of.erase(int(t.b))
	_trades.erase(id)


func _finish(id: int) -> void:
	var t: Dictionary = _trades[id]
	var a := int(t.a)
	var b := int(t.b)
	var inv_a: Dictionary = (world._inventories[a] as Dictionary).duplicate(true)
	var inv_b: Dictionary = (world._inventories[b] as Dictionary).duplicate(true)
	var ok := true
	var why := ""
	# önce iki taraftan da teklif edilenleri düş
	for e in t.offer.a:
		if not Inventory.take(inv_a, int(e[0]), int(e[1])):
			ok = false
			why = "%s teklif ettiği eşyaya artık sahip değil." % world._names[a]
	for e in t.offer.b:
		if not Inventory.take(inv_b, int(e[0]), int(e[1])):
			ok = false
			why = "%s teklif ettiği eşyaya artık sahip değil." % world._names[b]
	# altın
	var ga := int(t.gold.a)
	var gb := int(t.gold.b)
	if ok and (int(inv_a.get("gold", 0)) < ga or int(inv_b.get("gold", 0)) < gb):
		ok = false
		why = "teklif edilen altın artık yok."
	if ok:
		inv_a["gold"] = int(inv_a.get("gold", 0)) - ga + gb
		inv_b["gold"] = int(inv_b.get("gold", 0)) - gb + ga
	# sonra karşı tarafın teklifini ekle; sığmazsa iptal
	if ok:
		for e in t.offer.b:
			if Inventory.give(inv_a, int(e[0]), int(e[1])) > 0:
				ok = false
				why = "%s envanterinde yer yok." % world._names[a]
		for e in t.offer.a:
			if Inventory.give(inv_b, int(e[0]), int(e[1])) > 0:
				ok = false
				why = "%s envanterinde yer yok." % world._names[b]
	if not ok:
		t.ok.a = false
		t.ok.b = false
		world._notify(a, "Takas yapılamadı: " + why, "warn")
		world._notify(b, "Takas yapılamadı: " + why, "warn")
		_broadcast(id)
		return
	world._inventories[a] = inv_a
	world._inventories[b] = inv_b
	world._send_inventory(a)
	world._send_inventory(b)
	print("[Sunucu] Takas: %s <-> %s" % [world._names[a], world._names[b]])
	_close(id)
	_to(a, "c_closed", ["Takas tamamlandı!", true])
	_to(b, "c_closed", ["Takas tamamlandı!", true])


func _broadcast(id: int) -> void:
	var t: Dictionary = _trades[id]
	for side in ["a", "b"]:
		var me := int(t[side])
		var other_side := "b" if side == "a" else "a"
		var other := int(t[other_side])
		_to(me, "c_state", [{"id": id, "other": other, "other_name": world._names.get(other, "?"),
			"mine": (t.offer[side] as Array).duplicate(true), "theirs": (t.offer[other_side] as Array).duplicate(true),
			"my_ok": t.ok[side], "their_ok": t.ok[other_side],
			"my_gold": int(t.gold[side]), "their_gold": int(t.gold[other_side])}])


func in_trade(peer: int) -> bool:
	return _of.has(peer)
