class_name Quests
extends RefCounted
## Görevler: önce yeni başlayanı yönlendiren bir zincir, sonra sürekli
## yenilenen rastgele görevler. İlerleme sunucuda tutulur.
##
## type: depth (derinliğe in), collect (kırarak topla), craft (üret),
##       bank (canlıyı koleksiyona kat), chest (sandık aç), place (blok koy),
##       codex (ansiklopedide N tür), aquarium (akvaryuma canlı koy),
##       upgrade (ekipman yükselt)
## arg: belirli blok/tür (0 = herhangi biri)

const CHAIN: Array[Dictionary] = [
	{"text": "İlk dalış: deniz tabanına in (10 m)", "type": "depth", "arg": 0, "need": 10, "reward": 3},
	{"text": "5 Yosun topla", "type": "collect", "arg": Blocks.KELP, "need": 5, "reward": 2},
	{"text": "Yosundan Batık Tahta üret (C)", "type": "craft", "arg": Blocks.PLANK, "need": 1, "reward": 2},
	{"text": "Bir Ağ üret", "type": "craft", "arg": Blocks.NET, "need": 1, "reward": 3},
	{"text": "Parıldayan bir canlı yakala ve yüzeye getir", "type": "bank", "arg": 0, "need": 1, "reward": 3},
	{"text": "Bir hazine sandığı aç", "type": "chest", "arg": 0, "need": 1, "reward": 4},
	{"text": "Bir Oksijen İstasyonu kur", "type": "place", "arg": Blocks.OXYGEN, "need": 1, "reward": 4},
	{"text": "Alacakaranlık katmanına in (60 m)", "type": "depth", "arg": 0, "need": 60, "reward": 3},
	{"text": "Ansiklopedide 5 tür keşfet (K)", "type": "codex", "arg": 0, "need": 5, "reward": 6},
	{"text": "Bir akvaryuma canlı koy", "type": "aquarium", "arg": 0, "need": 1, "reward": 4},
	{"text": "Bir ekipmanını yükselt (Palet, Fener, Fileye ya da Tüp)", "type": "upgrade", "arg": 0, "need": 1, "reward": 5},
	{"text": "Gece Katmanına in (140 m)", "type": "depth", "arg": 0, "need": 140, "reward": 5},
	{"text": "Bir Fener Balığı yakala", "type": "bank", "arg": 209, "need": 1, "reward": 8},
	{"text": "Uçuruma in (230 m)", "type": "depth", "arg": 0, "need": 230, "reward": 8},
	{"text": "Efsanevi Altın Fener Balığını bul", "type": "bank", "arg": 211, "need": 1, "reward": 25},
]

## Değeri biriken değil, "en az şu kadar" olan türler
const STATE_TYPES := ["depth", "codex"]


static func new_state() -> Dictionary:
	return {"step": 0, "prog": 0, "rnd": {}}


static func current(state: Dictionary) -> Dictionary:
	var step := int(state.get("step", 0))
	if step < CHAIN.size():
		return CHAIN[step]
	return state.get("rnd", {})


## Zincir bittikten sonra oyuncunun derinliğine uygun rastgele görev.
static func random_quest(best_depth: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.55:
		var pool: Array[int] = []
		for d in Species.LIST:
			if int(d["min"]) <= best_depth + 15 and int(d["rarity"]) < 3:
				pool.append(int(d["id"]))
		if not pool.is_empty():
			var sp: int = pool[rng.randi_range(0, pool.size() - 1)]
			var need := rng.randi_range(1, 3) if int(Species.get_def(sp)["rarity"]) == 0 else 1
			var reward := 2 + int(Species.get_def(sp)["reward"]) * need / 2
			return {"text": "%d %s yakala ve koleksiyona getir" % [need, Species.display_name(sp)],
				"type": "bank", "arg": sp, "need": need, "reward": reward}
	if roll < 0.8:
		var opts := [[Blocks.SAND, "Kum"], [Blocks.ROCK, "Kaya"], [Blocks.CORAL, "Mercan"], [Blocks.KELP, "Yosun"]]
		if best_depth > WorldGen.LAYER_ABYSS:
			opts.append([Blocks.ABYSS_STONE, "Uçurum Taşı"])
		var o: Array = opts[rng.randi_range(0, opts.size() - 1)]
		var need2 := rng.randi_range(10, 25)
		return {"text": "%d %s topla" % [need2, o[1]], "type": "collect", "arg": o[0], "need": need2,
			"reward": 2 + need2 / 6}
	var need3 := rng.randi_range(1, 2)
	return {"text": "%d hazine sandığı aç" % need3, "type": "chest", "arg": 0, "need": need3, "reward": 4 * need3}


## İstemciye gönderilen özet
static func summary(state: Dictionary) -> Dictionary:
	var q := current(state)
	var step := int(state.get("step", 0))
	return {"text": q.get("text", ""), "prog": int(state.get("prog", 0)), "need": int(q.get("need", 1)),
		"reward": int(q.get("reward", 0)), "step": step + 1, "total": CHAIN.size(),
		"free": step >= CHAIN.size(), "type": q.get("type", "")}
