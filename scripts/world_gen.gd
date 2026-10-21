class_name WorldGen
extends RefCounted
## Sunucuda çalışan dünya üretimi. Dünya W x H hücre, y=0 su yüzeyi.
## Çıktı: {"cells": blok dizisi, "walls": arka duvar dizisi}

const W := 480
const H := 320
const SURFACE_ROWS := 4        # üstte her zaman açık su
const SEABED_BASE := 14        # deniz tabanının ortalama derinliği

# Derinlik katmanları (satır sınırları)
const LAYER_TWILIGHT := 60
const LAYER_MIDNIGHT := 140
const LAYER_ABYSS := 230


static func layer_name(row: int) -> String:
	if row < LAYER_TWILIGHT:
		return "Güneşli Katman"
	if row < LAYER_MIDNIGHT:
		return "Alacakaranlık"
	if row < LAYER_ABYSS:
		return "Gece Katmanı"
	return "Uçurum"


static func layer_color(row: int) -> Color:
	if row < LAYER_TWILIGHT:
		return Color("4cc3ff")
	if row < LAYER_MIDNIGHT:
		return Color("3a6fd8")
	if row < LAYER_ABYSS:
		return Color("4b3aa8")
	return Color("2a1a4a")


static func spawn_cell() -> Vector2i:
	return Vector2i(W / 2, 1)


static func generate(world_seed: int) -> Dictionary:
	var cells := PackedByteArray()
	cells.resize(W * H)
	cells.fill(Blocks.AIR)
	var walls := PackedByteArray()
	walls.resize(W * H)
	walls.fill(Blocks.AIR)

	var terrain := FastNoiseLite.new()
	terrain.seed = world_seed
	terrain.noise_type = FastNoiseLite.TYPE_SIMPLEX
	terrain.frequency = 0.03

	var caves := FastNoiseLite.new()
	caves.seed = world_seed + 1
	caves.noise_type = FastNoiseLite.TYPE_SIMPLEX
	caves.frequency = 0.07
	caves.fractal_octaves = 2

	var ore := FastNoiseLite.new()
	ore.seed = world_seed + 2
	ore.noise_type = FastNoiseLite.TYPE_CELLULAR
	ore.frequency = 0.12

	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed

	var floor_row := PackedInt32Array()
	floor_row.resize(W)
	for x in W:
		floor_row[x] = SEABED_BASE + int(terrain.get_noise_1d(x) * 8.0)

	for x in W:
		for y in H:
			if y < floor_row[x]:
				continue
			var depth := y - floor_row[x]
			var id := Blocks.ROCK
			if depth < 3:
				id = Blocks.SAND
			elif y >= LAYER_ABYSS + int(terrain.get_noise_1d(x * 3 + 500) * 6.0):
				id = Blocks.ABYSS_STONE
			walls[y * W + x] = id
			if depth > 4 and caves.get_noise_2d(x, y) > 0.38:
				id = Blocks.AIR
			elif depth > 10 and ore.get_noise_2d(x, y) > 0.62:
				id = Blocks.PEARL_ORE
			cells[y * W + x] = id

	_place_reef(cells, floor_row, rng)
	_place_wrecks(cells, walls, floor_row, rng)
	_place_cave_life(cells, rng)

	# Kenar duvarları ve taban
	for y in H:
		cells[y * W + 0] = Blocks.BEDROCK
		cells[y * W + (W - 1)] = Blocks.BEDROCK
	for x in W:
		cells[(H - 1) * W + x] = Blocks.BEDROCK
		cells[(H - 2) * W + x] = Blocks.BEDROCK
	for x in range(1, W - 1):
		for y in SURFACE_ROWS:
			cells[y * W + x] = Blocks.AIR

	return {"cells": cells, "walls": walls}


static func _put(cells: PackedByteArray, x: int, y: int, id: int) -> void:
	if x > 0 and x < W - 1 and y >= SURFACE_ROWS and y < H - 2:
		cells[y * W + x] = id


static func _at(cells: PackedByteArray, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return Blocks.BEDROCK
	return cells[y * W + x]


## Mercan öbekleri ve yosun ormanları
static func _place_reef(cells: PackedByteArray, floor_row: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	var x := 2
	while x < W - 2:
		var roll := rng.randf()
		if roll < 0.12:
			# 2-4 genişliğinde mercan tepeciği
			var width := rng.randi_range(2, 4)
			for k in width:
				var xx := x + k
				if xx >= W - 1:
					break
				var h := rng.randi_range(1, 3) - (1 if k == 0 or k == width - 1 else 0)
				for j in maxi(h, 1):
					_put(cells, xx, floor_row[xx] - 1 - j, Blocks.CORAL)
			x += width + 1
			continue
		elif roll < 0.38:
			var h2 := rng.randi_range(2, 7)
			for j in h2:
				var yy := floor_row[x] - 1 - j
				if yy > SURFACE_ROWS + 1:
					_put(cells, x, yy, Blocks.KELP)
		x += 1


## Batık gemiler: tahta gövde, içinde hazine sandığı, kırık direk
static func _place_wrecks(cells: PackedByteArray, walls: PackedByteArray, floor_row: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	var placed: Array[int] = []
	var attempts := 0
	while placed.size() < 7 and attempts < 120:
		attempts += 1
		var x0 := rng.randi_range(4, W - 20)
		if absi(x0 + 7 - W / 2) < 14:
			continue      # doğma noktasını kapatma
		var clash := false
		for p in placed:
			if absi(p - x0) < 24:
				clash = true
		if clash:
			continue
		placed.append(x0)
		var ground := 0
		for k in 14:
			ground = maxi(ground, floor_row[x0 + k])
		var keel := ground + 1          # omurga satırı (kuma gömülü)
		# satır: (sol girinti, sağ girinti)
		var shape := [[0, 0], [0, 1], [1, 2], [2, 4]]   # güverte -> omurga (sağda sivri pruva)
		for r in shape.size():
			var y: int = keel - 3 + r
			var xa: int = x0 + shape[r][0]
			var xb: int = x0 + 13 - shape[r][1]
			for xx in range(xa, xb + 1):
				var edge: bool = (xx == xa or xx == xb or r == 0 or r == shape.size() - 1)
				if edge:
					# güvertede kırık bir giriş bırak
					if r == 0 and (xx == x0 + 9 or xx == x0 + 10):
						_put(cells, xx, y, Blocks.AIR)
					else:
						_put(cells, xx, y, Blocks.PLANK)
				else:
					_put(cells, xx, y, Blocks.AIR)
				walls[y * W + xx] = Blocks.PLANK
		# lombozlar
		_put(cells, x0, keel - 2, Blocks.GLASS)
		_put(cells, x0 + 12, keel - 2, Blocks.GLASS)
		# hazine sandığı
		_put(cells, x0 + 4, keel - 1, Blocks.CHEST)
		# kırık direk ve yelken direği
		var mast_h := rng.randi_range(3, 6)
		for j in mast_h:
			_put(cells, x0 + 6, keel - 4 - j, Blocks.PLANK)
		if mast_h > 3:
			_put(cells, x0 + 5, keel - 3 - mast_h + 1, Blocks.PLANK)
		# gemiyi kum dolgusu üstüne oturt
		for xx in range(x0, x0 + 14):
			for yy in range(keel + 1, floor_row[xx] + 1):
				if _at(cells, xx, yy) == Blocks.AIR:
					_put(cells, xx, yy, Blocks.SAND)
			for yy in range(keel - 8, keel - 3):
				if _at(cells, xx, yy) == Blocks.KELP or _at(cells, xx, yy) == Blocks.CORAL:
					_put(cells, xx, yy, Blocks.AIR)


## Mağara tabanlarına hazine sandıkları, derinlere ışıl mantarlar, sığ mağaralara yosun
static func _place_cave_life(cells: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var chests := 0
	for y in range(SEABED_BASE + 12, H - 3):
		for x in range(2, W - 2):
			if _at(cells, x, y) != Blocks.AIR:
				continue
			var below := _at(cells, x, y + 1)
			if not Blocks.is_solid(below) or below == Blocks.CHEST:
				continue
			var r := rng.randf()
			var chest_p := 0.004 + float(y) / H * 0.01
			if r < chest_p and chests < 60:
				_put(cells, x, y, Blocks.CHEST)
				chests += 1
			elif y > LAYER_MIDNIGHT - 15 and r < 0.2:
				_put(cells, x, y, Blocks.GLOWSHROOM)
			elif y < LAYER_TWILIGHT and r < 0.08:
				var h := rng.randi_range(1, 3)
				for j in h:
					if _at(cells, x, y - j) == Blocks.AIR:
						_put(cells, x, y - j, Blocks.KELP)
