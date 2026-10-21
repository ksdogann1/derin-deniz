class_name SlotGrid
extends Control
## Envanter penceresinde bir yuva ızgarası. kind: "inv" (envanter), "grid"
## (üretim), "out" (sonuç), "trash" (çöp). Tıklamalar World.inv_click'e gider.

var world: Node            # World
var window: Node           # InventoryWindow
var kind := "inv"
var start := 0
var count := 9
var cols := 9
var slot := 46.0
var gap := 4.0
var on_click := Callable()   # verilirse tıklama envantere değil buraya gider (takas penceresi)


func _ready() -> void:
	var rows := int(ceil(float(count) / cols))
	custom_minimum_size = Vector2(cols * (slot + gap) - gap, rows * (slot + gap) - gap)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _rect(i: int) -> Rect2:
	return Rect2((i % cols) * (slot + gap), (i / cols) * (slot + gap), slot, slot)


func _index_at(p: Vector2) -> int:
	for i in count:
		if _rect(i).has_point(p):
			return i
	return -1


func _data(i: int) -> Variant:
	var inv: Dictionary = world.inventory
	if inv.is_empty():
		return null
	match kind:
		"inv":
			return inv.slots[start + i]
		"grid":
			return inv.grid[i]
		"mine", "theirs":
			var list: Array = world.trade.state.get(kind, [])
			return list[i] if i < list.size() else null
		"out":
			var ri := Inventory.match_recipe(inv.grid)
			if ri < 0:
				return null
			var r: Dictionary = Blocks.RECIPES[ri]
			return [int(r["out"]), int(r["count"])]
	return null


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in count:
		var r := _rect(i)
		var selected: bool = kind == "inv" and start + i == world.selected_slot and start + i < Inventory.HOTBAR
		var bg := Color(0.02, 0.06, 0.11, 0.85)
		var border := Color(1, 1, 1, 0.12)
		if kind == "out":
			bg = Color(0.06, 0.14, 0.08, 0.9)
			border = UiTheme.GOOD if _data(0) != null else Color(1, 1, 1, 0.12)
		elif kind == "trash":
			bg = Color(0.14, 0.04, 0.04, 0.85)
			border = Color(1, 0.4, 0.4, 0.4)
		if selected:
			border = UiTheme.GOLD
		draw_style_box(UiTheme.box(bg, border, 6, 2 if selected else 1, 0), r)
		if kind == "trash":
			var c := r.get_center()
			draw_line(c + Vector2(-9, -9), c + Vector2(9, 9), Color(1, 0.5, 0.5, 0.8), 3.0)
			draw_line(c + Vector2(9, -9), c + Vector2(-9, 9), Color(1, 0.5, 0.5, 0.8), 3.0)
			continue
		var s = _data(i)
		if s == null:
			continue
		var id := int(s[0])
		var n := int(s[1])
		var dim := 1.0
		if kind == "out" and not Inventory.upgrade_ok(world.inventory, id):
			dim = 0.35
		var tint := Species.tint(id) if Species.is_species(id) else Color.WHITE
		draw_texture_rect(TileAtlas.icon(id), r.grow(-8), false, Color(tint, dim))
		var txt := ""
		if Blocks.UPGRADE_MAX.has(id):
			txt = "Sv%d" % (Inventory.level(world.inventory, id) + 1)
		elif n > 1:
			txt = str(n)
		if txt != "":
			var pos := r.position + Vector2(0, slot - 4)
			draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, slot - 4, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_RIGHT, slot - 4, 13, Color.WHITE)
		if kind == "inv" and start + i < Inventory.HOTBAR:
			draw_string(font, r.position + Vector2(4, 12), str(start + i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color(1, 1, 1, 0.45))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var i := _index_at(event.position)
		var s = _data(i) if i >= 0 and kind != "trash" else null
		window.set_hover("" if s == null else Blocks.item_name(int(s[0])))
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		var i := _index_at(mb.position)
		if i < 0:
			return
		var button := 2 if (mb.button_index == MOUSE_BUTTON_RIGHT or window.single_mode) else 1
		var shift: bool = mb.shift_pressed or window.quick_mode
		var idx := start + i if kind == "inv" else i
		if on_click.is_valid():
			on_click.call(idx, button)
			accept_event()
			return
		world.inv_click(kind, idx, button, shift)
		window.play_click(kind)
		accept_event()


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()
