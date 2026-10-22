class_name Economy
extends Node
## Altın, kişisel tekneler ve oyuncu pazarı. Sunucu yetkilidir.
##  - Altın ve tekne bilgisi oyuncunun envanter sözlüğünde durur ("gold", "boat"),
##    böylece kaydedilir ve sahibine her değişiklikte gönderilir.
##  - Tekne işlemleri (depo, satış, geliştirme, pazar) yalnızca kendi teknenin yanında yapılır.
##  - Pazar: oyuncu eşyasını fiyatıyla listeler (eşya envanterden alınıp bekletilir),
##    başkası satın alınca altın satıcıya geçer (çevrimdışıysa kaydına eklenir).

const BOAT_RANGE := 6.0          # hücre: teknenin bu kadar yakınında işlem yapılır
const SLOT_SPACING := 14         # tekneler arası hücre
const MAX_LISTINGS := 6
const MAX_PRICE := 999999

const HULLS := [
	{"name": "Sandal", "cap": 0, "cost": 0},
	{"name": "Balıkçı Teknesi", "cap": 10, "cost": 150},
	{"name": "Yat", "cap": 25, "cost": 600},
	{"name": "Araştırma Gemisi", "cap": 45, "cost": 2000},
]
const DEPOT_CAP := [10, 25, 45, 70, 100]
const DEPOT_COST := [0, 80, 250, 600, 1500]
const SONAR_RANGE := [0, 45, 90]
const SONAR_COST := [0, 400, 1200]
const PAINT_COST := 25
const PAINTS := [Color("e8eef2"), Color("e05a4a"), Color("f2b33d"), Color("4fc46a"), Color("3aa6e0"),
	Color("7a5ae0"), Color("e06ab4"), Color("2b3440")]
const PEARL_PRICE := 3
const START_GOLD := 25

var world: Node            # World

# --- sunucu
var listings: Array = []   # [{id, seller, item, n, price}]
var _next_listing := 1

# --- istemci (sunucu da kendi oyuncusu için doldurur)
var boats := {}            # peer -> {x, hull, paint, name}
var market: Array = []
var sonar: Array = []      # [[konum, tür], ...] sonarın gördüğü nadir canlılar
var _sonar_timer := 0.0


func _ready() -> void:
	name = "Economy"


## Sunucu: sonarı olan oyunculara yakındaki nadir canlıları bildir
func _process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server() or world == null:
		return
	_sonar_timer -= delta
	if _sonar_timer > 0.0:
		return
	_sonar_timer = 2.0
	for peer in world._joined.keys():
		var inv := _inv(peer)
		var lvl := int(inv.get("boat", {}).get("sonar", 0))
		if lvl <= 0:
			continue
		var p: Node2D = world._server_player(peer)
		if p == null:
			continue
		var r2: float = pow(float(SONAR_RANGE[lvl]) * 16.0, 2)
		var found: Array = []
		for c in world.wildlife._c.values():
			var rr := int(Species.get_def(int(c.sp)).get("rarity", 0))
			if (rr == 2 or rr == 3 or rr == 5) and (c.pos as Vector2).distance_squared_to(p.server_pos()) <= r2:
				found.append([c.pos, int(c.sp)])
		if peer == 1:
			sonar = found
		else:
			c_sonar.rpc_id(peer, found)


@rpc("authority", "call_remote", "unreliable")
func c_sonar(found: Array) -> void:
	sonar = found


# --------------------------------------------------------------------------
# Ortak yardımcılar
# --------------------------------------------------------------------------

static func default_boat() -> Dictionary:
	return {"hull": 0, "depot": 0, "sonar": 0, "paint": 0, "store": {}, "x": -1}


static func ensure(inv: Dictionary) -> void:
	if not inv.has("gold"):
		inv["gold"] = START_GOLD
	if not inv.has("boat") or typeof(inv["boat"]) != TYPE_DICTIONARY:
		inv["boat"] = default_boat()
	var b: Dictionary = inv["boat"]
	for k in default_boat():
		if not b.has(k):
			b[k] = default_boat()[k]


static func gold(inv: Dictionary) -> int:
	return int(inv.get("gold", 0))


static func capacity(boat: Dictionary) -> int:
	return int(DEPOT_CAP[clampi(int(boat.get("depot", 0)), 0, DEPOT_CAP.size() - 1)]) + \
		int(HULLS[clampi(int(boat.get("hull", 0)), 0, HULLS.size() - 1)]["cap"])


static func stored(boat: Dictionary) -> int:
	var n := 0
	for k in (boat.get("store", {}) as Dictionary):
		n += int(boat.store[k])
	return n


## Bir eşyanın teknedeki satış fiyatı (0 = satılmaz)
static func price(id: int) -> int:
	if id == Blocks.PEARL:
		return PEARL_PRICE
	if Species.is_species(id):
		return Species.price(id)
	return 0


static func boat_center_x(boat: Dictionary) -> float:
	return (float(boat.get("x", WorldGen.W / 2)) + 0.5) * 16.0


# --------------------------------------------------------------------------
# İstemci API
# --------------------------------------------------------------------------

func store(sp: int, n: int) -> void:
	_call("_s_store", [sp, n])


func take(sp: int, n: int) -> void:
	_call("_s_take", [sp, n])


## source: "inv" ya da "store"
func sell(source: String, id: int, n: int) -> void:
	_call("_s_sell", [source, id, n])


## kind: "hull", "depot", "sonar", "paint" (paint için value = renk)
func upgrade(kind: String, value: int) -> void:
	_call("_s_upgrade", [kind, value])


func list_item(slot: int, n: int, price_each: int) -> void:
	_call("_s_list", [slot, n, price_each])


func buy(listing_id: int) -> void:
	_call("_s_buy", [listing_id])


func unlist(listing_id: int) -> void:
	_call("_s_unlist", [listing_id])


func _call(method: String, args: Array) -> void:
	if multiplayer.is_server():
		callv(method, [1] + args)
	else:
		rpc_id(1, "_rpc", method.substr(3), args)


@rpc("any_peer", "call_remote", "reliable")
func _rpc(op: String, args: Array) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	var want := {"store": 2, "take": 2, "sell": 3, "upgrade": 2, "list": 3, "buy": 1, "unlist": 1}
	if not want.has(op) or args.size() != int(want[op]):
		return
	callv("_s_" + op, [peer] + args)


# Sunucu -> istemci
@rpc("authority", "call_remote", "reliable")
func c_boats(b: Dictionary) -> void:
	boats = b


@rpc("authority", "call_remote", "reliable")
func c_market(m: Array) -> void:
	market = m


# --------------------------------------------------------------------------
# Sunucu
# --------------------------------------------------------------------------

func _inv(peer: int) -> Dictionary:
	var inv: Dictionary = world._inventories.get(peer, {})
	if not inv.is_empty():
		ensure(inv)
	return inv


## Oyuncu kendi teknesinin yanında mı?
func near_boat(peer: int) -> bool:
	var p: Node2D = world._server_player(peer)
	var inv := _inv(peer)
	if p == null or inv.is_empty():
		return false
	var pos: Vector2 = p.server_pos()
	var bx := boat_center_x(inv.boat)
	return absf(pos.x - bx) <= BOAT_RANGE * 16.0 and pos.y <= 3.0 * 16.0


func _ok(peer: int) -> bool:
	if not world._joined.has(peer):
		return false
	if world.trade != null and world.trade.in_trade(peer):
		world._notify(peer, "Takas sürerken tekne kullanılamaz.", "warn")
		return false
	if not near_boat(peer):
		world._notify(peer, "Bunun için teknenin yanında olmalısın.", "warn")
		return false
	return true


## Oyuncu katılınca: tekne yeri ata, herkese tekneleri ve pazarı gönder
func on_join(peer: int) -> void:
	var inv := _inv(peer)
	if int(inv.boat.x) < 0:
		inv.boat.x = _free_slot()
	broadcast_boats()
	_send_market(peer)


func on_leave(_peer: int) -> void:
	broadcast_boats()


func _free_slot() -> int:
	var used := {}
	for pl in world._saved_players.values():
		var b = (pl.get("inv", {}) as Dictionary).get("boat", null) if typeof(pl) == TYPE_DICTIONARY else null
		if typeof(b) == TYPE_DICTIONARY and int(b.get("x", -1)) >= 0:
			used[int(b.x)] = true
	for inv in world._inventories.values():
		var b2 = (inv as Dictionary).get("boat", null)
		if typeof(b2) == TYPE_DICTIONARY and int(b2.get("x", -1)) >= 0:
			used[int(b2.x)] = true
	var base: int = WorldGen.spawn_cell().x
	for k in range(0, 80):
		var off := (k + 1) / 2 * (1 if k % 2 == 1 else -1)
		var x := base + 3 + off * SLOT_SPACING
		if x < 4 or x > WorldGen.W - 5:
			continue
		if not used.has(x):
			return x
	return base


func broadcast_boats() -> void:
	var out := {}
	for peer in world._joined.keys():
		var inv := _inv(peer)
		if inv.is_empty():
			continue
		out[peer] = {"x": int(inv.boat.x), "hull": int(inv.boat.hull), "paint": int(inv.boat.paint),
			"name": world._names.get(peer, "?")}
	boats = out
	for peer in world._joined.keys():
		if peer != 1:
			c_boats.rpc_id(peer, out)


func _send_market(peer: int) -> void:
	if peer == 1:
		market = listings.duplicate(true)
	else:
		c_market.rpc_id(peer, listings)


func _broadcast_market() -> void:
	market = listings.duplicate(true)
	for peer in world._joined.keys():
		if peer != 1:
			c_market.rpc_id(peer, listings)


func _done(peer: int, msg: String, sound: String) -> void:
	world._send_inventory(peer)
	if msg != "":
		world._notify(peer, msg, sound)


func _s_store(peer: int, sp: int, n: int) -> void:
	if not _ok(peer) or not Species.is_species(sp):
		return
	var inv := _inv(peer)
	var room := capacity(inv.boat) - stored(inv.boat)
	n = mini(mini(n, Inventory.count(inv, sp)), room)
	if n <= 0:
		_done(peer, "Tekne deposu dolu! Geliştir menüsünden büyüt." if room <= 0 else "", "warn")
		return
	Inventory.take(inv, sp, n)
	inv.boat.store[sp] = int(inv.boat.store.get(sp, 0)) + n
	_done(peer, "%d %s tekneye kondu" % [n, Species.display_name(sp)], "pickup")


func _s_take(peer: int, sp: int, n: int) -> void:
	if not _ok(peer):
		return
	var inv := _inv(peer)
	var have := int(inv.boat.store.get(sp, 0))
	n = mini(mini(n, have), Inventory.free_space(inv, sp))
	if n <= 0:
		_done(peer, "Envanterde yer yok." if have > 0 else "", "warn")
		return
	Inventory.give(inv, sp, n)
	_dec_store(inv.boat, sp, n)
	_done(peer, "", "pickup")


func _dec_store(boat: Dictionary, sp: int, n: int) -> void:
	var left := int(boat.store.get(sp, 0)) - n
	if left <= 0:
		boat.store.erase(sp)
	else:
		boat.store[sp] = left


func _s_sell(peer: int, source: String, id: int, n: int) -> void:
	if not _ok(peer):
		return
	var each := price(id)
	if each <= 0 or n <= 0:
		return
	var inv := _inv(peer)
	if source == "store":
		n = mini(n, int(inv.boat.store.get(id, 0)))
		if n <= 0:
			return
		_dec_store(inv.boat, id, n)
	else:
		n = mini(n, Inventory.count(inv, id))
		if n <= 0 or not Inventory.take(inv, id, n):
			return
	inv.gold = gold(inv) + each * n
	world._quest_event(peer, "sell", id, n)
	_done(peer, "%d %s satıldı  +%d Altın" % [n, Blocks.item_name(id), each * n], "treasure")


func _s_upgrade(peer: int, kind: String, value: int) -> void:
	if not _ok(peer):
		return
	var inv := _inv(peer)
	var b: Dictionary = inv.boat
	var cost := 0
	var label := ""
	match kind:
		"hull":
			var nx := int(b.hull) + 1
			if nx >= HULLS.size():
				return
			cost = int(HULLS[nx]["cost"])
			label = HULLS[nx]["name"]
		"depot":
			var nd := int(b.depot) + 1
			if nd >= DEPOT_COST.size():
				return
			cost = int(DEPOT_COST[nd])
			label = "Depo %d" % (nd + 1)
		"sonar":
			var ns := int(b.sonar) + 1
			if ns >= SONAR_COST.size():
				return
			cost = int(SONAR_COST[ns])
			label = "Sonar %d" % ns
		"paint":
			if value < 0 or value >= PAINTS.size() or value == int(b.paint):
				return
			cost = PAINT_COST
			label = "Yeni boya"
		_:
			return
	if gold(inv) < cost:
		world._notify(peer, "Yeterli altının yok (%d gerekli)." % cost, "warn")
		return
	inv.gold = gold(inv) - cost
	match kind:
		"hull": b.hull = int(b.hull) + 1
		"depot": b.depot = int(b.depot) + 1
		"sonar": b.sonar = int(b.sonar) + 1
		"paint": b.paint = value
	_done(peer, "%s alındı!  -%d Altın" % [label, cost], "craft")
	broadcast_boats()


func _s_list(peer: int, slot: int, n: int, each: int) -> void:
	if not _ok(peer):
		return
	var inv := _inv(peer)
	var id := Inventory.slot_id(inv, slot)
	if id == 0 or Blocks.UPGRADE_MAX.has(id) or each <= 0 or each > MAX_PRICE:
		return
	var mine := 0
	var pname: String = world._names[peer]
	for l in listings:
		if str(l.seller) == pname:
			mine += 1
	if mine >= MAX_LISTINGS:
		world._notify(peer, "Pazarda en fazla %d ilanın olabilir." % MAX_LISTINGS, "warn")
		return
	n = mini(n, int(inv.slots[slot][1]))
	if n <= 0:
		return
	var s: Array = inv.slots[slot]
	inv.slots[slot] = null if int(s[1]) - n <= 0 else [id, int(s[1]) - n]
	listings.append({"id": _next_listing, "seller": pname, "item": id, "n": n, "price": each})
	_next_listing += 1
	_done(peer, "Pazara kondu: %d %s, tanesi %d Altın" % [n, Blocks.item_name(id), each], "place")
	_broadcast_market()


func _find(listing_id: int) -> int:
	for i in listings.size():
		if int(listings[i].id) == listing_id:
			return i
	return -1


func _s_buy(peer: int, listing_id: int) -> void:
	if not _ok(peer):
		return
	var i := _find(listing_id)
	if i < 0:
		world._notify(peer, "Bu ilan artık yok.", "warn")
		_send_market(peer)
		return
	var l: Dictionary = listings[i]
	var pname: String = world._names[peer]
	if str(l.seller) == pname:
		return
	var inv := _inv(peer)
	var total := int(l.price) * int(l.n)
	if gold(inv) < total:
		world._notify(peer, "Yeterli altının yok (%d gerekli)." % total, "warn")
		return
	if Inventory.free_space(inv, int(l.item)) < int(l.n):
		world._notify(peer, "Envanterinde yer yok.", "warn")
		return
	inv.gold = gold(inv) - total
	Inventory.give(inv, int(l.item), int(l.n))
	listings.remove_at(i)
	_pay(str(l.seller), total, "%s, %d %s ilanını aldı  +%d Altın" % [pname, int(l.n),
		Blocks.item_name(int(l.item)), total])
	_done(peer, "Satın alındı: %d %s  -%d Altın" % [int(l.n), Blocks.item_name(int(l.item)), total], "treasure")
	_broadcast_market()


## Satıcıya altını ver (çevrimiçiyse envanterine, değilse kaydına)
func _pay(seller: String, amount: int, msg: String) -> void:
	for peer in world._joined.keys():
		if world._names.get(peer, "") == seller:
			var inv := _inv(peer)
			inv.gold = gold(inv) + amount
			_done(peer, msg, "treasure")
			return
	var rec = world._saved_players.get(seller, null)
	if typeof(rec) == TYPE_DICTIONARY and rec.has("inv"):
		var sinv: Dictionary = rec.inv
		sinv["gold"] = int(sinv.get("gold", 0)) + amount


func _s_unlist(peer: int, listing_id: int) -> void:
	if not world._joined.has(peer):
		return
	var i := _find(listing_id)
	if i < 0:
		return
	var l: Dictionary = listings[i]
	if str(l.seller) != str(world._names[peer]):
		return
	var inv := _inv(peer)
	if Inventory.free_space(inv, int(l.item)) < int(l.n):
		world._notify(peer, "Geri almak için envanterde yer aç.", "warn")
		return
	Inventory.give(inv, int(l.item), int(l.n))
	listings.remove_at(i)
	_done(peer, "İlan kaldırıldı, eşya geri geldi.", "pickup")
	_broadcast_market()


func save_data() -> Dictionary:
	return {"listings": listings.duplicate(true), "next": _next_listing}


func load_data(d: Dictionary) -> void:
	listings = (d.get("listings", []) as Array).duplicate(true)
	_next_listing = int(d.get("next", 1))
	market = listings.duplicate(true)
