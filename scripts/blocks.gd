class_name Blocks
extends RefCounted
## Blok ve eşya türleri, özellikleri ve üretim tarifleri.
## Görseller: assets/tiles.png (satır = blok id, sütun 0-3 varyant/animasyon,
## sütun 4 = üstü açık hali).

const AIR := 0
const SAND := 1
const ROCK := 2
const CORAL := 3
const KELP := 4
const GLASS := 5
const PEARL_ORE := 6
const ABYSS_STONE := 7
const BEDROCK := 8
const LAMP := 9
const OXYGEN := 10
const BRICK := 11
const PLANK := 12
const CHEST := 13
const GLOWSHROOM := 14
const AQUARIUM := 15

const COUNT := 16

# Blok olmayan eşyalar (envanterde tutulur, yere konmaz)
const PEARL := 100
const TANK_UPGRADE := 101      # adedi = oksijen tüpü seviyesi
const NET := 102               # canlı yakalama ağı
const FINS := 103              # Hızlı Palet: adedi = seviye
const HELMET := 104            # Güçlü Fener (kask): adedi = seviye
const BIG_BAG := 105           # Büyük Fileye: adedi = seviye

## Seviyeli ekipmanlar ve en yüksek seviyeleri
const UPGRADE_MAX := {TANK_UPGRADE: 3, FINS: 2, HELMET: 2, BIG_BAG: 2}
const MAX_TANK_LEVEL := 3

# hardness: kırma süresi (sn), -1 kırılamaz
# drop: kırılınca düşen eşya; solid: çarpışma; light: ışık rengi (yoksa ışık yok)
# anim: sütunlar animasyon kareleri; top: üstü açıkken sütun 4 kullanılır
# weights: varyant olasılıkları (anim yoksa)
const DEFS := {
	SAND: {"name": "Kum", "hardness": 0.25, "drop": SAND, "solid": true, "top": true,
		"weights": [24, 1, 1, 1]},
	ROCK: {"name": "Kaya", "hardness": 0.6, "drop": ROCK, "solid": true, "top": true,
		"weights": [45, 1, 1, 1]},
	CORAL: {"name": "Mercan", "hardness": 0.35, "drop": CORAL, "solid": true,
		"weights": [1, 1, 1, 1]},
	KELP: {"name": "Yosun", "hardness": 0.1, "drop": KELP, "solid": false, "anim": true},
	GLASS: {"name": "Cam", "hardness": 0.3, "drop": GLASS, "solid": true,
		"weights": [3, 3, 1, 3]},
	PEARL_ORE: {"name": "İnci Damarı", "hardness": 1.0, "drop": PEARL, "solid": true,
		"weights": [1, 1, 1, 1]},
	ABYSS_STONE: {"name": "Uçurum Taşı", "hardness": 1.4, "drop": ABYSS_STONE, "solid": true, "top": true,
		"weights": [6, 2, 1, 1]},
	BEDROCK: {"name": "Taban", "hardness": -1.0, "drop": AIR, "solid": true,
		"weights": [1, 1, 1, 1]},
	LAMP: {"name": "Deniz Feneri", "hardness": 0.3, "drop": LAMP, "solid": true, "anim": true,
		"light": Color(1.0, 0.86, 0.55), "light_scale": 1.5, "light_energy": 1.05},
	OXYGEN: {"name": "Oksijen İstasyonu", "hardness": 0.5, "drop": OXYGEN, "solid": true, "anim": true,
		"light": Color(0.45, 0.85, 1.0), "light_scale": 0.85, "light_energy": 0.9},
	BRICK: {"name": "Deniz Tuğlası", "hardness": 0.7, "drop": BRICK, "solid": true,
		"weights": [10, 2, 2, 1]},
	PLANK: {"name": "Batık Tahta", "hardness": 0.4, "drop": PLANK, "solid": true,
		"weights": [4, 2, 1, 2]},
	CHEST: {"name": "Hazine Sandığı", "hardness": 0.8, "drop": AIR, "solid": true,
		"weights": [1, 1, 0, 0]},
	GLOWSHROOM: {"name": "Işıl Mantar", "hardness": 0.1, "drop": GLOWSHROOM, "solid": false, "anim": true,
		"light": Color(0.3, 0.95, 1.0), "light_scale": 0.55, "light_energy": 0.75},
	AQUARIUM: {"name": "Akvaryum", "hardness": 0.4, "drop": AQUARIUM, "solid": true,
		"weights": [1, 0, 0, 0]},
}

const ITEM_NAMES := {
	PEARL: "İnci",
	TANK_UPGRADE: "Büyük Tüp",
	NET: "Ağ",
	FINS: "Hızlı Palet",
	HELMET: "Güçlü Fener",
	BIG_BAG: "Büyük Fileye",
}

## Şekilli üretim tarifleri (Minecraft gibi). Desen 3x3 ızgaranın herhangi
## bir yerine konabilir, yatay aynası da kabul edilir. "." boş hücre.
## Harfler: S kum, R kaya, C mercan, K yosun, G cam, P inci, A uçurum taşı,
##          T batık tahta, L deniz feneri
const KEY := {"S": SAND, "R": ROCK, "C": CORAL, "K": KELP, "G": GLASS, "P": PEARL,
	"A": ABYSS_STONE, "T": PLANK, "L": LAMP}

const RECIPES: Array[Dictionary] = [
	{"out": GLASS, "count": 2, "pattern": ["SSS"]},
	{"out": BRICK, "count": 4, "pattern": ["RR", "RR"]},
	{"out": PLANK, "count": 2, "pattern": ["K", "K", "K"]},
	{"out": NET, "count": 1, "pattern": [".KK", ".KK", "T.."]},
	{"out": LAMP, "count": 1, "pattern": ["CPC"]},
	{"out": OXYGEN, "count": 1, "pattern": ["GPG", "GPG", "KPK"]},
	{"out": GLOWSHROOM, "count": 2, "pattern": ["A", "K"]},
	{"out": AQUARIUM, "count": 1, "pattern": ["G.G", "GSG"]},
	{"out": FINS, "count": 1, "pattern": ["KPK", "R.R", "RPR"]},
	{"out": HELMET, "count": 1, "pattern": ["LGL", "P.P"]},
	{"out": BIG_BAG, "count": 1, "pattern": ["KPK", "K.K", "KPK"]},
	{"out": TANK_UPGRADE, "count": 1, "pattern": ["PAP", "A.A", "PAP"]},
]


## Bir tarifin toplam malzemeleri {id: adet}
static func recipe_inputs(r: Dictionary) -> Dictionary:
	var out := {}
	for row in r["pattern"]:
		for ch in row:
			if ch != ".":
				var id: int = KEY[ch]
				out[id] = int(out.get(id, 0)) + 1
	return out


## Tarif açıklamaları (üretim panelinde)
const RECIPE_HINTS := {
	FINS: "Her seviye yüzme hızını %20 artırır",
	HELMET: "Her seviye kafa fenerini %35 güçlendirir",
	BIG_BAG: "Her seviye fileyeye 2 yer ekler",
	TANK_UPGRADE: "Her seviye +30 sn oksijen",
	NET: "Parıldayan canlıları yakalamak için",
	AQUARIUM: "Koleksiyonundaki canlıları sergile",
}

## Yere konabilen bloklar
const PLACEABLE: Array[int] = [
	SAND, ROCK, CORAL, KELP, GLASS, BRICK, PLANK, LAMP, OXYGEN, GLOWSHROOM, AQUARIUM,
]


static func is_block(id: int) -> bool:
	return id > AIR and id < COUNT


static func is_solid(id: int) -> bool:
	if id == AIR:
		return false
	return DEFS.get(id, {}).get("solid", true)


static func is_breakable(id: int) -> bool:
	if id == AIR or not DEFS.has(id):
		return false
	return DEFS[id]["hardness"] >= 0.0


static func is_replaceable(id: int) -> bool:
	return id == AIR or id == KELP or id == GLOWSHROOM


static func item_name(id: int) -> String:
	if Species.is_species(id):
		return Species.display_name(id)
	if ITEM_NAMES.has(id):
		return ITEM_NAMES[id]
	return DEFS.get(id, {}).get("name", "?")


static func drop_of(id: int) -> int:
	return DEFS.get(id, {}).get("drop", AIR)


static func light_of(id: int) -> Variant:
	return DEFS.get(id, {}).get("light", null)


static func has_top(id: int) -> bool:
	return DEFS.get(id, {}).get("top", false)


static func is_anim(id: int) -> bool:
	return DEFS.get(id, {}).get("anim", false)


## Hücre konumuna göre kararlı (her istemcide aynı) varyant seçimi.
static func variant_for(id: int, c: Vector2i) -> int:
	var w: Array = DEFS.get(id, {}).get("weights", [1])
	var total := 0
	for v in w:
		total += int(v)
	if total <= 0:
		return 0
	var h := absi((c.x * 73856093) ^ (c.y * 19349663) ^ (id * 83492791)) % total
	for i in w.size():
		h -= int(w[i])
		if h < 0:
			return i
	return 0


## Basit renk (parçacık efektleri ve mini harita için)
static func color_of(id: int) -> Color:
	match id:
		SAND: return Color("e0c992")
		ROCK: return Color("5a6674")
		CORAL: return Color("e0607e")
		KELP: return Color("3aa05a")
		GLASS: return Color("bfe8f5")
		PEARL_ORE: return Color("c9c2e0")
		ABYSS_STONE: return Color("2a2048")
		BEDROCK: return Color("14111a")
		LAMP: return Color("f2cf5c")
		OXYGEN: return Color("a8b3bd")
		BRICK: return Color("486672")
		PLANK: return Color("8a5a34")
		CHEST: return Color("cf9f2c")
		GLOWSHROOM: return Color("35c6e0")
		AQUARIUM: return Color("8fc8e8")
	return Color.WHITE
