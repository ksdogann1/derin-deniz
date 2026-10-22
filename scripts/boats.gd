class_name Boats
extends Node2D
## Yüzeydeki oyuncu teknelerini çizer (istemci). Bilgiler Economy.boats'tan gelir.

const FILES := ["sandal", "balikci", "yat", "arastirma"]
const WATERLINE := [30, 40, 46, 66]   # resimdeki su çizgisi satırı

var world: Node            # World
var _base: Array[Texture2D] = []
var _paint: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	z_index = 2
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for f in FILES:
		_base.append(load("res://assets/boats/%s.png" % f))
		_paint.append(load("res://assets/boats/%s_paint.png" % f))


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


## Yerel oyuncunun teknesine yakın mı (Tekne düğmesini göstermek için)
func near_own(p: Node2D) -> bool:
	var b: Dictionary = world.economy.boats.get(multiplayer.get_unique_id(), {})
	if b.is_empty() or p == null:
		return false
	var bx := (float(b.x) + 0.5) * 16.0
	return absf(p.position.x - bx) <= (Economy.BOAT_RANGE - 0.5) * 16.0 and p.position.y <= 2.5 * 16.0


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var me := multiplayer.get_unique_id()
	for peer in world.economy.boats:
		var b: Dictionary = world.economy.boats[peer]
		var tier := clampi(int(b.hull), 0, FILES.size() - 1)
		var tex := _base[tier]
		var cx := (float(b.x) + 0.5) * 16.0
		var bob := sin(_t * 1.6 + cx * 0.05) * 1.5
		var tilt := sin(_t * 1.1 + cx * 0.03) * 0.025
		var pos := Vector2(cx - tex.get_width() * 0.5, -WATERLINE[tier] + 3.0 + bob)
		draw_set_transform(Vector2(cx, bob), tilt, Vector2.ONE)
		var local := pos - Vector2(cx, bob)
		draw_texture(tex, local)
		var col: Color = Economy.PAINTS[clampi(int(b.paint), 0, Economy.PAINTS.size() - 1)]
		draw_texture(_paint[tier], local, col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# isim
		var label := "%s · %s" % [b.name, Economy.HULLS[tier]["name"]]
		var lp := Vector2(cx - 80, pos.y - 6)
		var c := Color(1, 0.9, 0.55) if int(peer) == me else Color(1, 1, 1, 0.85)
		draw_string_outline(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 160, 8, 3, Color(0, 0, 0, 0.7))
		draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_CENTER, 160, 8, c)
