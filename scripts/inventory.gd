class_name Inventory
extends RefCounted
## Minecraft tarzı envanter. Durum bir sözlüktür ve ağ üzerinden aynen gönderilir:
##   slots:  36 yuva (0-8 hotbar, 9-35 çanta). Her yuva null ya da [id, adet]
##   grid:   3x3 üretim ızgarası (9 yuva)
##   cursor: fareyle tutulan yığın (null ya da [id, adet])
##   levels: ekipman seviyeleri {TANK_UPGRADE: 2, FINS: 1, ...}
## Bütün işlemler saf fonksiyonlardır: sunucu da istemci de aynı kodu çalıştırır.

const SLOTS := 36
const HOTBAR := 9
const GRID := 9
const MAX_STACK := 99
const SINGLE := [Blocks.NET]          # yığılmayan eşyalar


static func create(start: Dictionary = {}) -> Dictionary:
	var st := {"slots": [], "grid": [], "cursor": null, "levels": {}}
	for i in SLOTS:
		st.slots.append(null)
	for i in GRID:
		st.grid.append(null)
	for id in start:
		give(st, int(id), int(start[id]))
	return st


## Eski (v0.4 ve öncesi) {id: adet} biçimindeki envanteri dönüştürür.
static func from_any(data: Variant, fallback: Dictionary) -> Dictionary:
	if typeof(data) == TYPE_DICTIONARY:
		var d: Dictionary = data
		if d.has("slots"):
			var st: Dictionary = d.duplicate(true)
			_fix_sizes(st)
			return st
		if not d.is_empty():
			return create(d)
	return create(fallback)


static func _fix_sizes(st: Dictionary) -> void:
	for key in ["slots", "grid"]:
		var want := SLOTS if key == "slots" else GRID
		var arr: Array = st.get(key, [])
		while arr.size() < want:
			arr.append(null)
		st[key] = arr
	if not st.has("levels"):
		st["levels"] = {}
	if not st.has("cursor"):
		st["cursor"] = null


static func max_stack(id: int) -> int:
	return 1 if id in SINGLE else MAX_STACK


static func level(st: Dictionary, id: int) -> int:
	return int((st.get("levels", {}) as Dictionary).get(id, 0))


static func count(st: Dictionary, id: int) -> int:
	if Blocks.UPGRADE_MAX.has(id):
		return level(st, id)
	var n := 0
	for s in st.get("slots", []):
		if s != null and int(s[0]) == id:
			n += int(s[1])
	return n


static func free_space(st: Dictionary, id: int) -> int:
	var room := 0
	var mx := max_stack(id)
	for s in st.slots:
		if s == null:
			room += mx
		elif int(s[0]) == id:
			room += mx - int(s[1])
	return room


## Eşya ekle. Sığmayan miktarı döndürür. Ekipmanlar seviye olarak eklenir.
static func give(st: Dictionary, id: int, n: int) -> int:
	if n <= 0:
		return 0
	if Blocks.UPGRADE_MAX.has(id):
		st.levels[id] = mini(level(st, id) + n, int(Blocks.UPGRADE_MAX[id]))
		return 0
	return _add_to(st.slots, id, n, range(SLOTS))


## Önce aynı eşyanın yığınlarına, sonra ilk boş yuvaya (önce hotbar) ekler.
static func _add_to(arr: Array, id: int, n: int, order: Array) -> int:
	var mx := max_stack(id)
	for i in order:
		if n <= 0:
			break
		var s = arr[i]
		if s != null and int(s[0]) == id and int(s[1]) < mx:
			var put := mini(mx - int(s[1]), n)
			arr[i] = [id, int(s[1]) + put]
			n -= put
	for i in order:
		if n <= 0:
			break
		if arr[i] == null:
			var put := mini(mx, n)
			arr[i] = [id, put]
			n -= put
	return n


## Belirli miktarı kaldırır (çantadan başlayarak). Yetmezse hiçbir şeyi değiştirmez.
static func take(st: Dictionary, id: int, n: int) -> bool:
	if count(st, id) < n:
		return false
	for i in range(SLOTS - 1, -1, -1):
		if n <= 0:
			break
		var s = st.slots[i]
		if s != null and int(s[0]) == id:
			var t := mini(int(s[1]), n)
			n -= t
			st.slots[i] = null if int(s[1]) - t <= 0 else [id, int(s[1]) - t]
	return true


## Bir yuvadan 1 adet harca (blok koyarken). Yuvadaki eşya id'sini döndürür, yoksa 0.
static func use_slot(st: Dictionary, slot: int) -> int:
	if slot < 0 or slot >= SLOTS or st.slots[slot] == null:
		return 0
	var s: Array = st.slots[slot]
	var id := int(s[0])
	st.slots[slot] = null if int(s[1]) <= 1 else [id, int(s[1]) - 1]
	return id


static func slot_id(st: Dictionary, slot: int) -> int:
	if slot < 0 or slot >= SLOTS or st.slots[slot] == null:
		return 0
	return int(st.slots[slot][0])


# --------------------------------------------------------------------------
# Üretim
# --------------------------------------------------------------------------

## Izgara deseni bir tarifle eşleşiyor mu? Eşleşen tarifin indeksi ya da -1.
static func match_recipe(grid: Array) -> int:
	var cells := _trim(grid)
	if cells.is_empty():
		return -1
	for i in Blocks.RECIPES.size():
		var pat := _pattern_ids(Blocks.RECIPES[i])
		if _same(cells, pat) or _same(cells, _mirror(pat)):
			return i
	return -1


## Izgarayı en küçük dikdörtgene kırpar: satır dizisi (her biri id dizisi, 0 = boş)
static func _trim(grid: Array) -> Array:
	var x0 := 3
	var y0 := 3
	var x1 := -1
	var y1 := -1
	for y in 3:
		for x in 3:
			if grid[y * 3 + x] != null:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return []
	var rows := []
	for y in range(y0, y1 + 1):
		var row := []
		for x in range(x0, x1 + 1):
			var s = grid[y * 3 + x]
			row.append(0 if s == null else int(s[0]))
		rows.append(row)
	return rows


static func _pattern_ids(r: Dictionary) -> Array:
	var pat: Array = r["pattern"]
	var w := 0
	for row in pat:
		w = maxi(w, (row as String).length())
	var rows := []
	for row in pat:
		var ids := []
		for x in w:
			var ch := (row as String).substr(x, 1)
			ids.append(0 if ch == "" or ch == "." else int(Blocks.KEY[ch]))
		rows.append(ids)
	return _trim_rows(rows)


static func _trim_rows(rows: Array) -> Array:
	# desenin kenarlarındaki boş satır/sütunları at
	var g := []
	for y in 3:
		for x in 3:
			var v := 0
			if y < rows.size() and x < (rows[y] as Array).size():
				v = int(rows[y][x])
			g.append(null if v == 0 else [v, 1])
	return _trim(g)


static func _mirror(rows: Array) -> Array:
	var out := []
	for row in rows:
		var r: Array = (row as Array).duplicate()
		r.reverse()
		out.append(r)
	return out


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for y in a.size():
		if (a[y] as Array) != (b[y] as Array):
			return false
	return true


## Izgaradan her dolu hücreden 1 adet harca.
static func _consume_grid(st: Dictionary) -> void:
	for i in GRID:
		var s = st.grid[i]
		if s != null:
			st.grid[i] = null if int(s[1]) <= 1 else [int(s[0]), int(s[1]) - 1]


## Ekipman tarifi şu an üretilebilir mi (seviye sınırı)?
static func upgrade_ok(st: Dictionary, out: int) -> bool:
	return not Blocks.UPGRADE_MAX.has(out) or level(st, out) < int(Blocks.UPGRADE_MAX[out])


# --------------------------------------------------------------------------
# Tıklama (Minecraft kuralları)
# --------------------------------------------------------------------------

## kind: "inv", "grid", "out", "trash". button: 1 sol, 2 sağ. shift: hızlı taşı.
## Sonuç: {"crafted": tarif indeksi ya da -1, "times": kaç kez}
static func click(st: Dictionary, kind: String, idx: int, button: int, shift: bool) -> Dictionary:
	var res := {"crafted": -1, "times": 0}
	match kind:
		"out":
			_click_out(st, shift, res)
		"trash":
			st.cursor = null
		"inv", "grid":
			var arr: Array = st.slots if kind == "inv" else st.grid
			if idx < 0 or idx >= arr.size():
				return res
			if shift:
				_quick_move(st, kind, idx)
			elif button == 2:
				_right(arr, idx, st)
			else:
				_left(arr, idx, st)
	return res


static func _left(arr: Array, i: int, st: Dictionary) -> void:
	var s = arr[i]
	var c = st.cursor
	if c == null:
		arr[i] = null
		st.cursor = s
	elif s == null:
		arr[i] = c
		st.cursor = null
	elif int(s[0]) == int(c[0]):
		var mx := max_stack(int(s[0]))
		var put := mini(mx - int(s[1]), int(c[1]))
		arr[i] = [int(s[0]), int(s[1]) + put]
		st.cursor = null if int(c[1]) - put <= 0 else [int(c[0]), int(c[1]) - put]
	else:
		arr[i] = c
		st.cursor = s


static func _right(arr: Array, i: int, st: Dictionary) -> void:
	var s = arr[i]
	var c = st.cursor
	if c == null:
		if s == null:
			return
		var half := int(ceil(int(s[1]) / 2.0))
		st.cursor = [int(s[0]), half]
		arr[i] = null if int(s[1]) - half <= 0 else [int(s[0]), int(s[1]) - half]
	elif s == null or (int(s[0]) == int(c[0]) and int(s[1]) < max_stack(int(s[0]))):
		var cur := 0 if s == null else int(s[1])
		arr[i] = [int(c[0]), cur + 1]
		st.cursor = null if int(c[1]) <= 1 else [int(c[0]), int(c[1]) - 1]
	else:
		_left(arr, i, st)


static func _quick_move(st: Dictionary, kind: String, i: int) -> void:
	var arr: Array = st.slots if kind == "inv" else st.grid
	var s = arr[i]
	if s == null:
		return
	var id := int(s[0])
	var order: Array
	if kind == "grid":
		order = range(SLOTS)
	elif i < HOTBAR:
		order = range(HOTBAR, SLOTS)
	else:
		order = range(HOTBAR)
	arr[i] = null
	var left := _add_to(st.slots, id, int(s[1]), order)
	if left > 0:
		arr[i] = [id, left]


static func _click_out(st: Dictionary, shift: bool, res: Dictionary) -> void:
	var times := 0
	while true:
		var ri := match_recipe(st.grid)
		if ri < 0:
			break
		var r: Dictionary = Blocks.RECIPES[ri]
		var out: int = r["out"]
		var n: int = r["count"]
		if Blocks.UPGRADE_MAX.has(out):
			if not upgrade_ok(st, out):
				break
			st.levels[out] = level(st, out) + 1
		elif shift:
			if free_space(st, out) < n:
				break
			_add_to(st.slots, out, n, range(SLOTS))
		else:
			var c = st.cursor
			if c == null:
				st.cursor = [out, n]
			elif int(c[0]) == out and int(c[1]) + n <= max_stack(out):
				st.cursor = [out, int(c[1]) + n]
			else:
				break
		_consume_grid(st)
		res.crafted = ri
		times += 1
		if not shift or Blocks.UPGRADE_MAX.has(out):
			break
	res.times = times


## Izgaradaki ve imleçteki eşyaları envantere geri koy (pencere kapanınca).
static func close(st: Dictionary) -> void:
	for i in GRID:
		var s = st.grid[i]
		if s != null:
			var left := _add_to(st.slots, int(s[0]), int(s[1]), range(SLOTS))
			st.grid[i] = null if left <= 0 else [int(s[0]), left]
	var c = st.cursor
	if c != null:
		var left2 := _add_to(st.slots, int(c[0]), int(c[1]), range(SLOTS))
		st.cursor = null if left2 <= 0 else [int(c[0]), left2]


## Tarif kitabı: ızgarayı boşaltıp tarifi envanterden yerleştir. Başarılıysa true.
static func autofill(st: Dictionary, ri: int) -> bool:
	if ri < 0 or ri >= Blocks.RECIPES.size():
		return false
	close(st)
	var r: Dictionary = Blocks.RECIPES[ri]
	var need := Blocks.recipe_inputs(r)
	for id in need:
		if count(st, int(id)) < int(need[id]):
			return false
	var pat: Array = r["pattern"]
	for y in pat.size():
		var row: String = pat[y]
		for x in row.length():
			var ch := row.substr(x, 1)
			if ch == ".":
				continue
			var id2: int = Blocks.KEY[ch]
			take(st, id2, 1)
			st.grid[y * 3 + x] = [id2, 1]
	return true


## Tarif kitabında "yerleştirilebilir" mi (ızgaradakiler de sayılır)
static func can_fill(st: Dictionary, ri: int) -> bool:
	var r: Dictionary = Blocks.RECIPES[ri]
	if not upgrade_ok(st, r["out"]):
		return false
	var need := Blocks.recipe_inputs(r)
	for id in need:
		var have := count(st, int(id))
		for s in st.grid:
			if s != null and int(s[0]) == int(id):
				have += int(s[1])
		if have < int(need[id]):
			return false
	return true
