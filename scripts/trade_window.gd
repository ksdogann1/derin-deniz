class_name TradeWindow
extends PanelContainer
## Takas penceresi: iki tarafın teklifi, kendi envanterin, onay ve iptal.

var world: Node            # World
var _title: Label
var _status: Label
var _ready_btn: Button
var _single := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER, true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UiTheme.label("Takas", 22, UiTheme.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var cancel := Button.new()
	cancel.text = "İptal"
	cancel.pressed.connect(func(): world.trade.cancel())
	head.add_child(cancel)
	v.add_child(HSeparator.new())

	var offers := HBoxContainer.new()
	offers.add_theme_constant_override("separation", 30)
	v.add_child(offers)
	var mine := VBoxContainer.new()
	offers.add_child(mine)
	mine.add_child(UiTheme.label("Senin teklifin (tıkla: geri al)", 14, UiTheme.MUTED))
	mine.add_child(_grid("mine", 0, Trade.MAX_OFFER, 9, func(i, _b): world.trade.remove_offer(i)))
	var theirs := VBoxContainer.new()
	offers.add_child(theirs)
	theirs.add_child(UiTheme.label("Karşı tarafın teklifi", 14, UiTheme.MUTED))
	theirs.add_child(_grid("theirs", 0, Trade.MAX_OFFER, 9, func(_i, _b): pass))

	_status = UiTheme.label("", 15)
	v.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_ready_btn = Button.new()
	_ready_btn.custom_minimum_size = Vector2(220, 44)
	_ready_btn.pressed.connect(func(): world.trade.set_ready(not bool(world.trade.state.get("my_ok", false))))
	row.add_child(_ready_btn)
	var single := CheckButton.new()
	single.text = "Tek tek ekle"
	single.toggled.connect(func(on): _single = on)
	row.add_child(single)
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.label("Envanterin: eşyaya tıkla, teklife eklensin (sol tık: yığın, sağ tık: 1 adet)", 13,
		UiTheme.MUTED))
	var add := func(i, b): world.trade.offer_slot(i, 1 if (b == 2 or _single) else 0)
	v.add_child(_grid("inv", Inventory.HOTBAR, Inventory.SLOTS - Inventory.HOTBAR, 9, add))
	v.add_child(_grid("inv", 0, Inventory.HOTBAR, 9, add))
	var tip := UiTheme.label("Teklif değişirse iki tarafın onayı da sıfırlanır. İkiniz de onaylayınca değiş tokuş olur.",
		12, UiTheme.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(480, 0)
	v.add_child(tip)


func _grid(kind: String, start: int, count: int, cols: int, cb: Callable) -> SlotGrid:
	var g := SlotGrid.new()
	g.world = world
	g.window = self
	g.kind = kind
	g.start = start
	g.count = count
	g.cols = cols
	g.slot = 44.0
	g.on_click = cb
	return g


func set_hover(_t: String) -> void:
	pass


func play_click(_k: String) -> void:
	world.play_ui("place")


var single_mode: bool:
	get:
		return _single
var quick_mode := false


func refresh(st: Dictionary) -> void:
	visible = not st.is_empty()
	if st.is_empty():
		return
	_title.text = "Takas: %s" % st.get("other_name", "?")
	var mine_ok: bool = st.get("my_ok", false)
	var their_ok: bool = st.get("their_ok", false)
	_ready_btn.text = "Onaylandı ✓  (geri al)" if mine_ok else "Onayla"
	_status.text = ("%s onayladı ✓" % st.other_name) if their_ok else ("%s henüz onaylamadı" % st.other_name)
	_status.add_theme_color_override("font_color", UiTheme.GOOD if their_ok else UiTheme.MUTED)
