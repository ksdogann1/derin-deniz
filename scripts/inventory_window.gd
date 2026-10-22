class_name InventoryWindow
extends PanelContainer
## Basit envanter (E / telefonda "Envanter"). Telefona göre tasarlandı:
##  - Çantadaki eşyaya dokun: seçili hotbar yuvasına geçer (yer değiştirir).
##  - Hotbar'daki yuvaya dokun: o yuva seçilir.
##  - Sağdaki tarif listesinde "Üret": malzemeler yetiyorsa tek dokunuşla üretir.
##  - "At" modu açıkken dokunduğun yığın silinir (iki kez dokun).

const SLOT := 54.0

var world: Node            # World
var single_mode := false   # SlotGrid uyumluluğu (eski)
var quick_mode := false

var _hover: Label
var _levels: Label
var _sel_lbl: Label
var _drop_btn: Button
var _drop_mode := false
var _drop_arm := -1
var _drop_time := 0.0
var _rows: Array[Dictionary] = []
var _refresh := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER, true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	outer.add_child(head)
	var title := UiTheme.label("Envanter", 22, UiTheme.ACCENT)
	head.add_child(title)
	_hover = UiTheme.label("", 15, UiTheme.GOLD)
	_hover.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hover.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_hover)
	var close := Button.new()
	close.text = "Kapat"
	close.custom_minimum_size = Vector2(96, 40)
	close.pressed.connect(close_window)
	head.add_child(close)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	outer.add_child(cols)

	# --- sol: hotbar + çanta
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	cols.add_child(left)
	_sel_lbl = UiTheme.label("", 14, UiTheme.MUTED)
	left.add_child(_sel_lbl)
	left.add_child(_grid(0, Inventory.HOTBAR))
	left.add_child(UiTheme.label("Çanta  ·  eşyaya dokun: seçili hotbar yuvasına geçer", 13, UiTheme.MUTED))
	left.add_child(_grid(Inventory.HOTBAR, Inventory.SLOTS - Inventory.HOTBAR))
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)
	var sort := Button.new()
	sort.text = "Sırala"
	sort.custom_minimum_size = Vector2(110, 42)
	sort.pressed.connect(func():
		world.inv_sort()
		world.play_ui("place"))
	tools.add_child(sort)
	_drop_btn = Button.new()
	_drop_btn.text = "At: kapalı"
	_drop_btn.toggle_mode = true
	_drop_btn.custom_minimum_size = Vector2(130, 42)
	_drop_btn.toggled.connect(func(on):
		_drop_mode = on
		_drop_arm = -1
		_drop_btn.text = "At: AÇIK" if on else "At: kapalı")
	tools.add_child(_drop_btn)
	_levels = UiTheme.label("", 12, UiTheme.MUTED)
	_levels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tools.add_child(_levels)

	# --- sağ: üretim listesi
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	cols.add_child(right)
	right.add_child(UiTheme.label("Üretim", 15, UiTheme.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	for i in Blocks.RECIPES.size():
		_recipe_row(list, i)


func _grid(start: int, count: int) -> SlotGrid:
	var g := SlotGrid.new()
	g.world = world
	g.window = self
	g.kind = "inv"
	g.start = start
	g.count = count
	g.cols = 9
	g.slot = SLOT
	g.on_click = _on_slot
	return g


func _on_slot(idx: int, _button: int) -> void:
	if _drop_mode:
		var s = world.inventory.slots[idx]
		if s == null:
			return
		if _drop_arm == idx and _drop_time > 0.0:
			world.inv_drop(idx)
			world.play_ui("break")
			_drop_arm = -1
			set_hover("")
		else:
			_drop_arm = idx
			_drop_time = 2.0
			set_hover("Silmek için tekrar dokun: %s" % Blocks.item_name(int(s[0])))
		return
	if idx < Inventory.HOTBAR:
		world.selected_slot = idx
		world.play_ui("place")
	else:
		world.inv_swap(idx, world.selected_slot)
		world.play_ui("pickup")


func _recipe_row(list: VBoxContainer, i: int) -> void:
	var r: Dictionary = Blocks.RECIPES[i]
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.06, 0.11, 0.7), Color(1, 1, 1, 0.06), 6, 1, 6))
	list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var icon := TextureRect.new()
	icon.texture = TileAtlas.icon(r["out"])
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var name := UiTheme.label("%s ×%d" % [Blocks.item_name(r["out"]), r["count"]], 15)
	v.add_child(name)
	var need := RichTextLabel.new()
	need.bbcode_enabled = true
	need.fit_content = true
	need.scroll_active = false
	need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	need.add_theme_font_size_override("normal_font_size", 12)
	need.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(need)
	if Blocks.RECIPE_HINTS.has(r["out"]):
		var hint := UiTheme.label(Blocks.RECIPE_HINTS[r["out"]], 11, UiTheme.MUTED)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	var b := Button.new()
	b.text = "Üret"
	b.custom_minimum_size = Vector2(76, 42)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		world.request_craft(i)
		world.play_ui("craft"))
	h.add_child(b)
	_rows.append({"button": b, "name": name, "need": need, "recipe": r, "index": i})


func set_hover(text: String) -> void:
	_hover.text = text


func play_click(_kind: String) -> void:
	world.play_ui("place")


func open_window() -> void:
	visible = true
	_drop_btn.button_pressed = false
	_refresh_rows()


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
	_drop_time = maxf(0.0, _drop_time - delta)
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_refresh_rows()


func _refresh_rows() -> void:
	var inv: Dictionary = world.inventory
	if inv.is_empty():
		return
	var sel_id := Inventory.slot_id(inv, world.selected_slot)
	_sel_lbl.text = "Hotbar  ·  seçili yuva %d: %s" % [world.selected_slot + 1,
		Blocks.item_name(sel_id) if sel_id != 0 else "boş"]
	for row in _rows:
		var r: Dictionary = row.recipe
		var parts: PackedStringArray = []
		var need := Blocks.recipe_inputs(r)
		for id in need:
			var have := Inventory.count(inv, int(id))
			var col := "#7ee2a8" if have >= int(need[id]) else "#ff8a7a"
			parts.append("[color=%s]%d %s[/color] [color=#8aa4b8](%d)[/color]" % [col, int(need[id]),
				Blocks.item_name(int(id)), have])
		(row.need as RichTextLabel).text = "  ".join(parts)
		(row.button as Button).disabled = not Inventory.can_craft(inv, row.index)
		if Blocks.UPGRADE_MAX.has(r["out"]):
			(row.name as Label).text = "%s  (Sv %d/%d)" % [Blocks.item_name(r["out"]),
				Inventory.level(inv, r["out"]), int(Blocks.UPGRADE_MAX[r["out"]])]
	_levels.text = "Tüp %d/3 · Palet %d/2 · Fener %d/2 · Fileye %d/2" % [
		Inventory.level(inv, Blocks.TANK_UPGRADE), Inventory.level(inv, Blocks.FINS),
		Inventory.level(inv, Blocks.HELMET), Inventory.level(inv, Blocks.BIG_BAG)]
