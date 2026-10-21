class_name InventoryWindow
extends PanelContainer
## Minecraft tarzı envanter penceresi (E / C): çanta, hotbar, 3x3 üretim
## ızgarası, sonuç yuvası, çöp ve tarif kitabı.
## Sol tık: al / bırak / değiştir. Sağ tık: yarısını al / tek tek bırak.
## Shift + tık: hotbar ile çanta arasında hızlı taşı, sonuçta: hepsini üret.

const SLOT := 46.0

var world: Node            # World
var single_mode := false   # dokunmatik için sağ tık yerine
var quick_mode := false    # dokunmatik için shift yerine

var _hover: Label
var _levels: Label
var _cursor: Control
var _book_rows: Array[Dictionary] = []
var _refresh := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER, true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)

	var head := HBoxContainer.new()
	outer.add_child(head)
	var title := UiTheme.label("Envanter ve Üretim", 22, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_hover = UiTheme.label("", 15, UiTheme.GOLD)
	_hover.custom_minimum_size = Vector2(220, 0)
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_hover)
	var close := Button.new()
	close.text = "Kapat (E)"
	close.pressed.connect(close_window)
	head.add_child(close)
	outer.add_child(HSeparator.new())

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	outer.add_child(cols)

	# --- sol: çanta + hotbar
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(UiTheme.label("Çanta", 14, UiTheme.MUTED))
	left.add_child(_grid("inv", Inventory.HOTBAR, Inventory.SLOTS - Inventory.HOTBAR, 9))
	left.add_child(UiTheme.label("Hotbar (1-9)", 14, UiTheme.MUTED))
	left.add_child(_grid("inv", 0, Inventory.HOTBAR, 9))
	_levels = UiTheme.label("", 13, UiTheme.MUTED)
	left.add_child(_levels)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	left.add_child(modes)
	var single := CheckButton.new()
	single.text = "Tek tek koy"
	single.tooltip_text = "Açıkken tıklama sağ tık gibi çalışır (telefon için)"
	single.toggled.connect(func(on): single_mode = on)
	modes.add_child(single)
	var quick := CheckButton.new()
	quick.text = "Hızlı taşı"
	quick.tooltip_text = "Açıkken tıklama Shift+tık gibi çalışır (telefon için)"
	quick.toggled.connect(func(on): quick_mode = on)
	modes.add_child(quick)

	# --- orta: üretim ızgarası
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 6)
	cols.add_child(mid)
	mid.add_child(UiTheme.label("Üretim ızgarası", 14, UiTheme.MUTED))
	var craft_row := HBoxContainer.new()
	craft_row.add_theme_constant_override("separation", 10)
	mid.add_child(craft_row)
	craft_row.add_child(_grid("grid", 0, 9, 3))
	var arrow := UiTheme.label("→", 30, UiTheme.MUTED)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_row.add_child(arrow)
	var out_box := VBoxContainer.new()
	out_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_row.add_child(out_box)
	out_box.add_child(_grid("out", 0, 1, 1, 56.0))
	out_box.add_child(UiTheme.label("Sonuç", 12, UiTheme.MUTED))
	var trash_row := HBoxContainer.new()
	trash_row.add_theme_constant_override("separation", 8)
	mid.add_child(trash_row)
	trash_row.add_child(_grid("trash", 0, 1, 1))
	var tl := UiTheme.label("Çöp: imleçteki\neşyayı siler", 12, UiTheme.MUTED)
	trash_row.add_child(tl)
	var help := UiTheme.label("Sol tık: al / bırak\nSağ tık: yarısı / tek tek\nShift+tık: hızlı taşı,\nsonuçta hepsini üret",
		12, UiTheme.MUTED)
	mid.add_child(help)

	# --- sağ: tarif kitabı
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(UiTheme.label("Tarif kitabı", 14, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for i in Blocks.RECIPES.size():
		_book_row(list, i)

	_cursor = Control.new()
	_cursor.top_level = true
	_cursor.z_index = 100
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_draw_cursor)
	add_child(_cursor)


func _grid(kind: String, start: int, count: int, cols: int, slot := SLOT) -> SlotGrid:
	var g := SlotGrid.new()
	g.world = world
	g.window = self
	g.kind = kind
	g.start = start
	g.count = count
	g.cols = cols
	g.slot = slot
	return g


func _book_row(list: VBoxContainer, i: int) -> void:
	var r: Dictionary = Blocks.RECIPES[i]
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.06, 0.11, 0.7), Color(1, 1, 1, 0.06), 6, 1, 6))
	list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var pat := Control.new()
	pat.custom_minimum_size = Vector2(3 * 15, 3 * 15)
	pat.draw.connect(func(): _draw_pattern(pat, r))
	h.add_child(pat)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name := UiTheme.label("%s ×%d" % [Blocks.item_name(r["out"]), r["count"]], 14)
	v.add_child(name)
	if Blocks.RECIPE_HINTS.has(r["out"]):
		var hint := UiTheme.label(Blocks.RECIPE_HINTS[r["out"]], 10, UiTheme.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	var b := Button.new()
	b.text = "Diz"
	b.tooltip_text = "Malzemeleri ızgaraya diz"
	b.custom_minimum_size = Vector2(56, 0)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		world.inv_autofill(i)
		play_click("grid"))
	h.add_child(b)
	_book_rows.append({"button": b, "name": name, "recipe": r, "index": i})


func _draw_pattern(c: Control, r: Dictionary) -> void:
	var pat: Array = r["pattern"]
	for y in 3:
		for x in 3:
			var rect := Rect2(x * 15, y * 15, 14, 14)
			c.draw_rect(rect, Color(0, 0, 0, 0.35))
			if y < pat.size() and x < (pat[y] as String).length():
				var ch := (pat[y] as String).substr(x, 1)
				if ch != ".":
					c.draw_texture_rect(TileAtlas.icon(Blocks.KEY[ch]), rect.grow(-1), false)


func _draw_cursor() -> void:
	var inv: Dictionary = world.inventory
	if inv.is_empty() or inv.cursor == null:
		return
	var p := _cursor.get_global_mouse_position()
	var id := int(inv.cursor[0])
	var n := int(inv.cursor[1])
	var r := Rect2(p - Vector2(16, 16), Vector2(32, 32))
	_cursor.draw_texture_rect(TileAtlas.icon(id), r, false, Species.tint(id) if Species.is_species(id) else Color.WHITE)
	if n > 1:
		var font := ThemeDB.fallback_font
		_cursor.draw_string_outline(font, r.end - Vector2(30, 0), str(n), HORIZONTAL_ALIGNMENT_RIGHT, 30, 13, 4,
			Color(0, 0, 0, 0.85))
		_cursor.draw_string(font, r.end - Vector2(30, 0), str(n), HORIZONTAL_ALIGNMENT_RIGHT, 30, 13, Color.WHITE)


func set_hover(text: String) -> void:
	_hover.text = text


func play_click(kind: String) -> void:
	world.play_ui("craft" if kind == "out" else "place")


func open_window() -> void:
	visible = true
	_refresh_book()


func close_window() -> void:
	if visible:
		visible = false
		world.inv_close()


func toggle() -> void:
	if visible:
		close_window()
	else:
		open_window()


func _process(delta: float) -> void:
	if not visible:
		return
	_cursor.queue_redraw()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_refresh_book()


func _refresh_book() -> void:
	var inv: Dictionary = world.inventory
	if inv.is_empty():
		return
	for row in _book_rows:
		(row.button as Button).disabled = not Inventory.can_fill(inv, row.index)
		var r: Dictionary = row.recipe
		if Blocks.UPGRADE_MAX.has(r["out"]):
			(row.name as Label).text = "%s (Sv %d/%d)" % [Blocks.item_name(r["out"]),
				Inventory.level(inv, r["out"]), int(Blocks.UPGRADE_MAX[r["out"]])]
	_levels.text = "Ekipman:  Tüp %d/3 · Palet %d/2 · Fener %d/2 · Fileye %d/2" % [
		Inventory.level(inv, Blocks.TANK_UPGRADE), Inventory.level(inv, Blocks.FINS),
		Inventory.level(inv, Blocks.HELMET), Inventory.level(inv, Blocks.BIG_BAG)]
