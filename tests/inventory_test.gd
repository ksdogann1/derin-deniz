extends SceneTree
## Envanter mantığı birim testi (ağsız, sahnesiz).
##   godot --headless --path . --script res://tests/inventory_test.gd

var failures := 0
var checks := 0


func check(label: String, cond: bool) -> void:
	checks += 1
	print("%s  %s" % ["OK  " if cond else "FAIL", label])
	if not cond:
		failures += 1


func _grid(st: Dictionary, rows: Array) -> void:
	for i in 9:
		st.grid[i] = null
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row.substr(x, 1)
			if ch != ".":
				st.grid[y * 3 + x] = [Blocks.KEY[ch], 1]


func _initialize() -> void:
	var st := Inventory.create({Blocks.SAND: 150, Blocks.KELP: 5})
	check("150 kum 99+51 olarak yığıldı", st.slots[0] == [Blocks.SAND, 99] and st.slots[1] == [Blocks.SAND, 51])
	check("yosun sonraki yuvada", st.slots[2] == [Blocks.KELP, 5])
	check("sayım", Inventory.count(st, Blocks.SAND) == 150)

	# sol tık: al ve koy
	Inventory.click(st, "inv", 2, 1, false)
	check("sol tık yığını imlece aldı", st.cursor == [Blocks.KELP, 5] and st.slots[2] == null)
	Inventory.click(st, "inv", 20, 1, false)
	check("sol tık boş yuvaya bıraktı", st.slots[20] == [Blocks.KELP, 5] and st.cursor == null)
	# sağ tık: yarısını al, tek tek bırak
	Inventory.click(st, "inv", 20, 2, false)
	check("sağ tık yarısını aldı (3)", st.cursor == [Blocks.KELP, 3] and st.slots[20] == [Blocks.KELP, 2])
	Inventory.click(st, "grid", 0, 2, false)
	Inventory.click(st, "grid", 3, 2, false)
	Inventory.click(st, "grid", 6, 2, false)
	check("sağ tıkla ızgaraya tek tek kondu", st.cursor == null and st.grid[0] == [Blocks.KELP, 1]
		and st.grid[3] == [Blocks.KELP, 1] and st.grid[6] == [Blocks.KELP, 1])
	check("dikine 3 yosun = Batık Tahta tarifi",
		Inventory.match_recipe(st.grid) >= 0 and Blocks.RECIPES[Inventory.match_recipe(st.grid)]["out"] == Blocks.PLANK)
	var res := Inventory.click(st, "out", 0, 1, false)
	check("sonuç alındı: imleçte 2 tahta", st.cursor == [Blocks.PLANK, 2] and res.times == 1)
	check("ızgara harcandı", st.grid[0] == null and st.grid[3] == null and st.grid[6] == null)
	Inventory.click(st, "inv", 8, 1, false)
	check("tahta hotbara kondu", st.slots[8] == [Blocks.PLANK, 2])

	# desen kayması ve ayna
	_grid(st, [".KK", ".KK", "T.."])
	check("ağ deseni eşleşti", Blocks.RECIPES[Inventory.match_recipe(st.grid)]["out"] == Blocks.NET)
	_grid(st, ["KK.", "KK.", "..T"])
	check("ağ deseninin aynası da eşleşti", Blocks.RECIPES[Inventory.match_recipe(st.grid)]["out"] == Blocks.NET)
	_grid(st, ["...", "SSS", "..."])
	check("desen ızgarada kayık olsa da eşleşti", Blocks.RECIPES[Inventory.match_recipe(st.grid)]["out"] == Blocks.GLASS)
	_grid(st, ["SS.", "S..", "..."])
	check("yanlış desen eşleşmedi", Inventory.match_recipe(st.grid) == -1)
	_grid(st, [])

	# shift ile çoklu üretim
	var st2 := Inventory.create({Blocks.SAND: 30})
	Inventory.close(st2)
	for i in 3:
		st2.grid[i] = [Blocks.SAND, 10]
	st2.slots[0] = null
	var r2 := Inventory.click(st2, "out", 0, 1, true)
	check("shift ile 10 kez cam üretildi", r2.times == 10 and Inventory.count(st2, Blocks.GLASS) == 20)
	check("ızgara tamamen harcandı", st2.grid[0] == null and st2.grid[2] == null)

	# shift ile hotbar <-> çanta
	var st3 := Inventory.create({Blocks.ROCK: 10})
	Inventory.click(st3, "inv", 0, 1, true)
	check("shift: hotbardan çantaya taşındı", st3.slots[0] == null and st3.slots[9] == [Blocks.ROCK, 10])
	Inventory.click(st3, "inv", 9, 1, true)
	check("shift: çantadan hotbara döndü", st3.slots[0] == [Blocks.ROCK, 10])

	# tarif kitabı ve ekipman
	var st4 := Inventory.create({Blocks.PEARL: 20, Blocks.ABYSS_STONE: 20})
	var ti := -1
	for i in Blocks.RECIPES.size():
		if Blocks.RECIPES[i]["out"] == Blocks.TANK_UPGRADE:
			ti = i
	check("tarif kitabı: yerleştirilebilir", Inventory.can_fill(st4, ti))
	check("tarif kitabı ızgaraya dizdi", Inventory.autofill(st4, ti) and Inventory.match_recipe(st4.grid) == ti)
	check("malzemeler envanterden düştü", Inventory.count(st4, Blocks.PEARL) == 16)
	Inventory.click(st4, "out", 0, 1, false)
	check("ekipman seviye olarak işlendi", Inventory.level(st4, Blocks.TANK_UPGRADE) == 1 and st4.cursor == null)
	for i in 5:
		Inventory.autofill(st4, ti)
		Inventory.click(st4, "out", 0, 1, false)
	check("ekipman en fazla 3 seviye", Inventory.level(st4, Blocks.TANK_UPGRADE) == 3)
	Inventory.close(st4)
	check("kapatınca ızgara envantere döndü", st4.grid.all(func(s): return s == null))
	check("yetersiz malzemeyle yerleştirilemez", not Inventory.autofill(Inventory.create({}), ti))

	# ağ yığılmaz, çöp
	var st5 := Inventory.create({Blocks.NET: 2})
	check("ağ yığılmaz", st5.slots[0] == [Blocks.NET, 1] and st5.slots[1] == [Blocks.NET, 1])
	Inventory.click(st5, "inv", 0, 1, false)
	Inventory.click(st5, "trash", 0, 1, false)
	check("çöp imleçteki eşyayı sildi", st5.cursor == null and Inventory.count(st5, Blocks.NET) == 1)

	# eski kayıt dönüşümü
	var old := {Blocks.GLASS: 8, Blocks.TANK_UPGRADE: 2, 204: 3}
	var st6 := Inventory.from_any(old, {})
	check("eski kayıt: cam yuvaya geçti", Inventory.count(st6, Blocks.GLASS) == 8)
	check("eski kayıt: tüp seviyesi korundu", Inventory.level(st6, Blocks.TANK_UPGRADE) == 2)
	check("eski kayıt: canlılar korundu", Inventory.count(st6, 204) == 3)

	# dolu envanter
	var st7 := Inventory.create({})
	for i in Inventory.SLOTS:
		st7.slots[i] = [Blocks.ROCK, 99]
	check("dolu envanter fazlayı geri verir", Inventory.give(st7, Blocks.SAND, 5) == 5)
	check("koyma yuvası 1 harcar", Inventory.use_slot(st7, 3) == Blocks.ROCK and st7.slots[3] == [Blocks.ROCK, 98])

	print("%d/%d kontrol geçti" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)
