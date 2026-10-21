class_name Settings
extends RefCounted
## Oyuncu ayarları. user://settings.cfg dosyasına kaydedilir.
## Değişince `revision` artar; ilgili düğümler bunu izleyip kendini günceller.

const PATH := "user://settings.cfg"
const BUS_SFX := "Efekt"
const BUS_MUSIC := "Muzik"
const BUS_AMB := "Ortam"

const QUALITY_NAMES := ["Düşük", "Orta", "Yüksek", "Ultra", "Özel"]
const FPS_OPTIONS := [30, 60, 90, 120, 144, 0]          # 0 = sınırsız
const WINDOW_NAMES := ["Pencere", "Tam ekran", "Kenarlıksız tam ekran"]
const PARTICLE_NAMES := ["Kapalı", "Az", "Tam"]

## Kalite ön ayarları: ışık sayısı, parçacık, huzme, deniz karı, canlı yoğunluğu, vinyet
const PRESETS := [
	{"lights": 8, "particles": 1, "rays": false, "snow": false, "fauna": 0.4, "vignette": false},
	{"lights": 16, "particles": 1, "rays": true, "snow": false, "fauna": 0.7, "vignette": true},
	{"lights": 32, "particles": 2, "rays": true, "snow": true, "fauna": 1.0, "vignette": true},
	{"lights": 48, "particles": 2, "rays": true, "snow": true, "fauna": 1.4, "vignette": true},
]

# Ses
static var master := 1.0
static var sfx := 0.8
static var music := 0.55
static var ambience := 0.7
# Görüntü
static var quality := 2
static var fps_limit := 60
static var vsync := true
static var window_mode := 0
static var lights := 32
static var particles := 2
static var rays := true
static var snow := true
static var fauna := 1.0
static var vignette := true
static var zoom := 2.5
static var ui_scale := 1.0
static var show_fps := false
# Oyun
static var touch_mode := 0          # 0 otomatik, 1 açık, 2 kapalı
static var show_names := true
static var show_bubbles := true
static var vibration := true
static var minimap := true

static var revision := 0
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_ensure_buses()
	if is_mobile():
		quality = 1
		ui_scale = 1.15
		zoom = 2.8
		set_quality(1)
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		master = float(cf.get_value("ses", "ana", master))
		sfx = float(cf.get_value("ses", "efekt", sfx))
		music = float(cf.get_value("ses", "muzik", music))
		ambience = float(cf.get_value("ses", "ortam", ambience))
		quality = int(cf.get_value("goruntu", "kalite", quality))
		fps_limit = int(cf.get_value("goruntu", "fps", fps_limit))
		vsync = bool(cf.get_value("goruntu", "vsync", vsync))
		# eski sürümlerdeki "tam_ekran" ayarı
		window_mode = int(cf.get_value("goruntu", "pencere",
			1 if bool(cf.get_value("ekran", "tam_ekran", false)) else window_mode))
		lights = int(cf.get_value("goruntu", "isik", lights))
		particles = int(cf.get_value("goruntu", "parcacik", particles))
		rays = bool(cf.get_value("goruntu", "huzme", rays))
		snow = bool(cf.get_value("goruntu", "deniz_kari", snow))
		fauna = float(cf.get_value("goruntu", "canli", fauna))
		vignette = bool(cf.get_value("goruntu", "vinyet", vignette))
		zoom = float(cf.get_value("goruntu", "yakinlik", zoom))
		ui_scale = float(cf.get_value("goruntu", "arayuz", ui_scale))
		show_fps = bool(cf.get_value("goruntu", "fps_goster", show_fps))
		touch_mode = int(cf.get_value("kontrol", "dokunmatik", touch_mode))
		show_names = bool(cf.get_value("oyun", "adlar", show_names))
		show_bubbles = bool(cf.get_value("oyun", "baloncuk", show_bubbles))
		vibration = bool(cf.get_value("oyun", "titresim", vibration))
		minimap = bool(cf.get_value("oyun", "mini_harita", minimap))
	apply()


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("ses", "ana", master)
	cf.set_value("ses", "efekt", sfx)
	cf.set_value("ses", "muzik", music)
	cf.set_value("ses", "ortam", ambience)
	cf.set_value("goruntu", "kalite", quality)
	cf.set_value("goruntu", "fps", fps_limit)
	cf.set_value("goruntu", "vsync", vsync)
	cf.set_value("goruntu", "pencere", window_mode)
	cf.set_value("goruntu", "isik", lights)
	cf.set_value("goruntu", "parcacik", particles)
	cf.set_value("goruntu", "huzme", rays)
	cf.set_value("goruntu", "deniz_kari", snow)
	cf.set_value("goruntu", "canli", fauna)
	cf.set_value("goruntu", "vinyet", vignette)
	cf.set_value("goruntu", "yakinlik", zoom)
	cf.set_value("goruntu", "arayuz", ui_scale)
	cf.set_value("goruntu", "fps_goster", show_fps)
	cf.set_value("kontrol", "dokunmatik", touch_mode)
	cf.set_value("oyun", "adlar", show_names)
	cf.set_value("oyun", "baloncuk", show_bubbles)
	cf.set_value("oyun", "titresim", vibration)
	cf.set_value("oyun", "mini_harita", minimap)
	cf.save(PATH)


## Kalite ön ayarını uygula (4 = Özel: dokunma)
static func set_quality(q: int) -> void:
	quality = q
	if q < 0 or q >= PRESETS.size():
		return
	var p: Dictionary = PRESETS[q]
	lights = p.lights
	particles = p.particles
	rays = p.rays
	snow = p.snow
	fauna = p.fauna
	vignette = p.vignette


static func is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") \
		or OS.has_feature("web_ios")


static func touch_enabled() -> bool:
	if touch_mode == 1:
		return true
	if touch_mode == 2:
		return false
	return is_mobile()


static func _ensure_buses() -> void:
	for n in [BUS_SFX, BUS_MUSIC, BUS_AMB]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")


static func _set_bus(n: String, v: float) -> void:
	var i := AudioServer.get_bus_index(n)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


static func apply() -> void:
	_set_bus("Master", master)
	_set_bus(BUS_SFX, sfx)
	_set_bus(BUS_MUSIC, music)
	_set_bus(BUS_AMB, ambience)
	Engine.max_fps = fps_limit
	var headless := DisplayServer.get_name() == "headless"
	if not headless:
		DisplayServer.window_set_vsync_mode(
			DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
		if not is_mobile():
			var want := DisplayServer.WINDOW_MODE_WINDOWED
			if window_mode == 1:
				want = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			elif window_mode == 2:
				want = DisplayServer.WINDOW_MODE_FULLSCREEN
			if DisplayServer.window_get_mode() != want:
				DisplayServer.window_set_mode(want)
	revision += 1


static func changed() -> void:
	apply()
	save()
