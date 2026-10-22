class_name MapView
extends Control
## Haritayı çizer. mini = true ise oyuncunun çevresini gösteren köşe haritası.

var world: Node            # World
var mini := false
var span := Vector2(72, 46)          # mini haritada görünen alan (hücre)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_d: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var m: WorldMap = world.map
	if m == null or m.map_tex == null:
		return
	var font := ThemeDB.fallback_font
	var me := world.local_player() as Player
	var sz := size
	var src: Rect2
	var dst: Rect2
	if mini:
		var c := Vector2(WorldGen.W * 0.5, 2) if me == null else me.position / 16.0
		var o := (c - span * 0.5).clamp(Vector2.ZERO, Vector2(WorldGen.W, WorldGen.H) - span)
		src = Rect2(o, span)
		dst = Rect2(Vector2.ZERO, sz)
		draw_rect(dst.grow(2), Color(0, 0, 0, 0.6))
	else:
		var k := minf(sz.x / WorldGen.W, sz.y / WorldGen.H)
		var dsz := Vector2(WorldGen.W, WorldGen.H) * k
		src = Rect2(Vector2.ZERO, Vector2(WorldGen.W, WorldGen.H))
		dst = Rect2((sz - dsz) * 0.5, dsz)
	draw_texture_rect_region(m.map_tex, dst, src)
	var fsrc := Rect2(src.position / WorldMap.CHUNK, src.size / WorldMap.CHUNK)
	draw_texture_rect_region(m.fog_tex, dst, fsrc, Color(0.02, 0.03, 0.06, 1.0))
	var sc := dst.size / src.size

	# katman sınırları (tam haritada)
	if not mini:
		for row: int in [WorldGen.LAYER_TWILIGHT, WorldGen.LAYER_MIDNIGHT, WorldGen.LAYER_ABYSS]:
			var y: float = dst.position.y + float(row) * sc.y
			draw_dashed_line(Vector2(dst.position.x, y), Vector2(dst.end.x, y), Color(1, 1, 1, 0.25), 1.0, 6.0)
			draw_string(font, Vector2(dst.position.x + 6, y - 4), "%s  ·  %d m" % [WorldGen.layer_name(row), row],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.55))

	# sonar (tekne geliştirmesi): nadir canlılar
	if world.economy != null:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
		for e in world.economy.sonar:
			var cc: Vector2 = (e[0] as Vector2) / 16.0
			if not src.has_point(cc):
				continue
			var rr := int(Species.get_def(int(e[1])).get("rarity", 0))
			var col: Color = Species.RARITY_COLORS[clampi(rr, 0, Species.RARITY_COLORS.size() - 1)]
			var pp := dst.position + (cc - src.position) * sc
			draw_circle(pp, (3.0 if mini else 4.0) * pulse + 1.0, Color(col, 0.9))
			draw_arc(pp, 7.0 * pulse + 2.0, 0, TAU, 16, Color(col, 0.5), 1.0)

	# oyuncular
	for n in world.players():
		var pl := n as Player
		if pl == null:
			continue
		var cell := pl.position / 16.0
		if not src.has_point(cell):
			continue
		var p := dst.position + (cell - src.position) * sc
		if pl == me:
			draw_circle(p, 5.0 if not mini else 3.5, Color.WHITE)
			draw_circle(p, 3.0 if not mini else 2.0, pl.suit_color)
		else:
			draw_circle(p, 4.0 if not mini else 3.0, pl.suit_color)
			if not mini:
				draw_string_outline(font, p + Vector2(-40, -8), pl.display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 12,
					4, Color(0, 0, 0, 0.8))
				draw_string(font, p + Vector2(-40, -8), pl.display_name, HORIZONTAL_ALIGNMENT_CENTER, 80, 12,
					pl.suit_color.lightened(0.4))
	draw_rect(dst, Color(0.36, 0.78, 0.96, 0.45), false, 1.0)
