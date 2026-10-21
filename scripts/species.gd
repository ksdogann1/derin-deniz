class_name Species
extends RefCounted
## Yakalanabilir deniz canlıları. Envanterde id'leri 200'den başlar.
## min/max: görüldüğü derinlik (satır), weight: çıkma olasılığı ağırlığı,
## reward: ilk yakalayışta verilen inci, move: hareket tarzı.

const FIRST := 200

const LIST: Array[Dictionary] = [
	{"id": 200, "name": "Sarı Cerrah", "tex": "sari_cerrah", "fw": 48, "fh": 36, "frames": 4, "row": 0,
		"min": 3, "max": 60, "weight": 10.0, "rarity": 0, "reward": 2, "speed": 30.0, "move": "swim"},
	{"id": 201, "name": "Palyaço Balığı", "tex": "palyaco", "fw": 40, "fh": 26, "frames": 4, "row": 0,
		"min": 3, "max": 50, "weight": 9.0, "rarity": 0, "reward": 2, "speed": 26.0, "move": "swim"},
	{"id": 202, "name": "Mavi Kromis", "tex": "mavi_kromis", "fw": 40, "fh": 24, "frames": 4, "row": 0,
		"min": 20, "max": 110, "weight": 8.0, "rarity": 0, "reward": 3, "speed": 32.0, "move": "swim"},
	{"id": 203, "name": "Gümüş Sardalya", "tex": "sardalya", "fw": 44, "fh": 20, "frames": 4, "row": 0,
		"min": 50, "max": 140, "weight": 8.0, "rarity": 0, "reward": 3, "speed": 38.0, "move": "swim"},
	{"id": 204, "name": "Denizatı", "tex": "denizati", "fw": 24, "fh": 40, "frames": 4, "row": 0,
		"min": 8, "max": 70, "weight": 3.5, "rarity": 1, "reward": 6, "speed": 7.0, "move": "hover"},
	{"id": 205, "name": "Deniz Kaplumbağası", "tex": "kaplumbaga", "fw": 52, "fh": 32, "frames": 4, "row": 0,
		"min": 3, "max": 40, "weight": 2.0, "rarity": 1, "reward": 8, "speed": 15.0, "move": "swim"},
	{"id": 206, "name": "Pembe Denizanası", "tex": "denizanasi", "fw": 32, "fh": 44, "frames": 4, "row": 0,
		"min": 50, "max": 160, "weight": 6.0, "rarity": 0, "reward": 4, "speed": 12.0, "move": "jelly"},
	{"id": 207, "name": "Ahtapot", "tex": "ahtapot", "fw": 40, "fh": 36, "frames": 4, "row": 0,
		"min": 80, "max": 200, "weight": 3.0, "rarity": 1, "reward": 8, "speed": 16.0, "move": "jelly"},
	{"id": 208, "name": "Işıklı Denizanası", "tex": "isikli_denizanasi", "fw": 32, "fh": 44, "frames": 4, "row": 0,
		"min": 140, "max": 318, "weight": 5.0, "rarity": 1, "reward": 7, "speed": 12.0, "move": "jelly", "tint": Color(0.9, 1.0, 1.4), "light": Color(0.55, 0.5, 1.0)},
	{"id": 209, "name": "Fener Balığı", "tex": "fener", "fw": 48, "fh": 40, "frames": 4, "row": 0,
		"min": 150, "max": 318, "weight": 3.0, "rarity": 2, "reward": 12, "speed": 10.0, "move": "swim", "light": Color(0.4, 1.0, 0.85), "light_offset": Vector2(10, -7)},
	{"id": 210, "name": "Hayalet Kalamar", "tex": "kalamar", "fw": 28, "fh": 52, "frames": 4, "row": 0,
		"min": 220, "max": 318, "weight": 2.0, "rarity": 2, "reward": 15, "speed": 18.0, "move": "jelly", "tint": Color(1.1, 1.2, 1.3), "light": Color(0.5, 0.95, 1.0)},
	{"id": 211, "name": "Altın Fener Balığı", "tex": "altin_fener", "fw": 48, "fh": 40, "frames": 4, "row": 0,
		"min": 250, "max": 318, "weight": 0.5, "rarity": 3, "reward": 30, "speed": 12.0, "move": "swim", "light": Color(1.0, 0.75, 0.3), "light_offset": Vector2(10, -7)},
	{"id": 212, "name": "Elektrikli Yılanbalığı", "tex": "yilanbaligi", "fw": 64, "fh": 24, "frames": 4, "row": 0,
		"min": 130, "max": 318, "weight": 3.0, "rarity": 4, "reward": 10, "speed": 22.0, "move": "eel", "hostile": true, "attack": "shock"},
	{"id": 213, "name": "Lüfer", "tex": "lufer", "fw": 60, "fh": 28, "frames": 4, "row": 0,
		"min": 15, "max": 90, "weight": 6.0, "rarity": 0, "reward": 4, "speed": 42.0, "move": "swim"},
	{"id": 214, "name": "Çipura", "tex": "cipura", "fw": 52, "fh": 36, "frames": 4, "row": 0,
		"min": 4, "max": 45, "weight": 7.0, "rarity": 0, "reward": 3, "speed": 24.0, "move": "swim"},
	{"id": 215, "name": "Barbunya", "tex": "barbunya", "fw": 48, "fh": 26, "frames": 4, "row": 0,
		"min": 10, "max": 80, "weight": 6.0, "rarity": 0, "reward": 3, "speed": 18.0, "move": "bottom"},
	{"id": 216, "name": "Orfoz", "tex": "orfoz", "fw": 64, "fh": 40, "frames": 4, "row": 0,
		"min": 25, "max": 120, "weight": 2.5, "rarity": 1, "reward": 9, "speed": 10.0, "move": "bottom"},
	{"id": 217, "name": "Balon Balığı", "tex": "balon", "fw": 40, "fh": 32, "frames": 4, "row": 0,
		"min": 8, "max": 70, "weight": 3.0, "rarity": 1, "reward": 7, "speed": 10.0, "move": "puffer"},
	{"id": 218, "name": "Vatoz", "tex": "vatoz", "fw": 64, "fh": 32, "frames": 4, "row": 0,
		"min": 20, "max": 150, "weight": 2.5, "rarity": 1, "reward": 9, "speed": 14.0, "move": "glide"},
	{"id": 219, "name": "Mavi Yengeç", "tex": "yengec", "fw": 36, "fh": 24, "frames": 4, "row": 0,
		"min": 5, "max": 140, "weight": 5.0, "rarity": 0, "reward": 3, "speed": 12.0, "move": "crawl"},
	{"id": 220, "name": "Mavi Köpekbalığı", "tex": "kopekbaligi", "fw": 96, "fh": 40, "frames": 4, "row": 0,
		"min": 50, "max": 200, "weight": 1.5, "rarity": 4, "reward": 15, "speed": 34.0, "move": "shark", "hostile": true, "attack": "bite"},
	{"id": 221, "name": "Kılıç Balığı", "tex": "kilic", "fw": 96, "fh": 36, "frames": 4, "row": 0,
		"min": 40, "max": 170, "weight": 1.2, "rarity": 2, "reward": 14, "speed": 50.0, "move": "swim"},
	{"id": 222, "name": "Ay Balığı", "tex": "ay_baligi", "fw": 64, "fh": 72, "frames": 4, "row": 0,
		"min": 20, "max": 150, "weight": 0.6, "rarity": 2, "reward": 18, "speed": 6.0, "move": "drift"},
	{"id": 223, "name": "Dev Kalamar", "tex": "dev_kalamar", "fw": 64, "fh": 120, "frames": 4, "row": 0,
		"min": 270, "max": 318, "weight": 0.4, "rarity": 3, "reward": 40, "speed": 14.0, "move": "jelly", "light": Color(1.0, 0.85, 0.4), "light_offset": Vector2(0, 2)},
]

## Çizimler 2 kat çözünürlükte; oyunda bu ölçekle gösterilir
const DRAW_SCALE := 0.5

const RARITY_NAMES := ["Yaygın", "Nadir", "Çok Nadir", "Efsanevi", "Tehlikeli"]
const RARITY_COLORS := [Color("b8c7d3"), Color("5ce67a"), Color("5ab4ff"), Color("ffcc33"), Color("ff6a5a")]

static var _by_id := {}
static var _tex := {}
static var _icons := {}


static func is_species(id: int) -> bool:
	return id >= FIRST and id < FIRST + LIST.size()


static func get_def(id: int) -> Dictionary:
	if _by_id.is_empty():
		for d in LIST:
			_by_id[d["id"]] = d
	return _by_id.get(id, {})


static func display_name(id: int) -> String:
	return get_def(id).get("name", "?")


static func texture(id: int) -> Texture2D:
	var d := get_def(id)
	var n: String = d.get("tex", "fish")
	if not _tex.has(n):
		_tex[n] = load("res://assets/creatures/%s.png" % n)
	return _tex[n]


## İlk karenin simgesi (HUD için).
static func icon(id: int) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var d := get_def(id)
	var at := AtlasTexture.new()
	at.atlas = texture(id)
	at.region = Rect2(0, int(d["row"]) * int(d["fh"]), int(d["fw"]), int(d["fh"]))
	_icons[id] = at
	return at


static func tint(id: int) -> Color:
	return get_def(id).get("tint", Color.WHITE)


## Derinliğe göre ağırlıklı rastgele tür (yoksa -1).
static func pick_for_row(row: int, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for d in LIST:
		if row >= int(d["min"]) and row <= int(d["max"]):
			total += float(d["weight"])
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	for d in LIST:
		if row >= int(d["min"]) and row <= int(d["max"]):
			r -= float(d["weight"])
			if r <= 0.0:
				return int(d["id"])
	return -1


static func depth_text(id: int) -> String:
	var d := get_def(id)
	return "%d-%d m" % [int(d["min"]), int(d["max"])]
