class_name Sfx
extends Node2D
## Ses efektleri, su altı ortam sesi ve derinliğe göre geçiş yapan müzik.
## Ekransız sunucuda hiçbir şey yapmaz.

const NAMES := ["break", "place", "pickup", "craft", "treasure", "chat", "warn", "bubble", "shock", "catch"]

var enabled := true
var _streams := {}
var _pool: Array[AudioStreamPlayer2D] = []
var _ui: AudioStreamPlayer
var _amb: AudioStreamPlayer
var _music_top: AudioStreamPlayer
var _music_deep: AudioStreamPlayer
var _next := 0


static func make_loop(s: AudioStream) -> AudioStream:
	var w := s as AudioStreamWAV
	if w != null:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return s


func _ready() -> void:
	if not enabled:
		return
	Settings.ensure_loaded()
	for n in NAMES:
		var s: AudioStream = load("res://assets/sfx/%s.wav" % n)
		if s != null:
			_streams[n] = s
	for i in 10:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 520.0
		p.attenuation = 1.6
		p.bus = Settings.BUS_SFX
		add_child(p)
		_pool.append(p)
	_ui = AudioStreamPlayer.new()
	_ui.bus = Settings.BUS_SFX
	add_child(_ui)
	_amb = _looping("res://assets/sfx/ambience.wav", Settings.BUS_AMB, -14.0)
	_music_top = _looping("res://assets/music/surface.wav", Settings.BUS_MUSIC, -8.0)
	_music_deep = _looping("res://assets/music/deep.wav", Settings.BUS_MUSIC, -60.0)


func _looping(path: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = Sfx.make_loop(load(path))
	p.bus = bus
	p.volume_db = db
	add_child(p)
	p.play()
	return p


## Dünyada bir konumda çalar (uzaktaki olaylar daha kısık duyulur).
func play_at(sound: String, pos: Vector2, pitch_jitter := 0.08, volume_db := 0.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = _streams[sound]
	p.global_position = pos
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db
	p.play()


## Arayüz sesi (konumsuz).
func play_ui(sound: String, volume_db := -4.0) -> void:
	if not enabled or not _streams.has(sound):
		return
	_ui.stream = _streams[sound]
	_ui.volume_db = volume_db
	_ui.play()


## Ortam sesi ve müziği derinliğe göre ayarla (0 yüzey .. 1 dip).
func set_depth(t: float) -> void:
	if _amb == null:
		return
	_amb.volume_db = lerpf(-18.0, -8.0, t)
	_amb.pitch_scale = lerpf(1.0, 0.7, t)
	var deep := smoothstep(0.12, 0.45, t)
	_music_top.volume_db = linear_to_db(maxf(1.0 - deep, 0.001)) - 8.0
	_music_deep.volume_db = linear_to_db(maxf(deep, 0.001)) - 6.0
