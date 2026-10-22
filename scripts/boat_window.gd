class_name BoatWindow
extends PanelContainer
## Tekne penceresi (teknenin yanında B / telefonda "Tekne"):
##  Depo: yakaladığın canlıları teknede sakla.  Sat: canlı ve inci sat, altın kazan.
##  Geliştir: gövde, depo, sonar, boya.  Pazar: oyunculara eşya sat, başkalarınınkini al.

var world: Node            # World

var _gold_lbl: Label
var _tabs: TabContainer
var _depo: VBoxContainer
var _sell: VBoxContainer
var _upg: VBoxContainer
var _market: VBoxContainer
var _sig := ""
var _refresh := 0.0
# pazara koyma formu
var _m_item: OptionButton
var _m_count: SpinBox
var _m_price: SpinBox
var _m_slots: Array[int] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER, true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	visible = false
	custom_minimum_size = Vector2(760, 470)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	outer.add_child(head)
	head.add_child(UiTheme.label("Teknem", 22, UiTheme.ACCENT))
	var coin := TextureRect.new()
	coin.texture = load("res://assets/coin.png")
	coin.custom_minimum_size = Vector2(24, 24)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(coin)
	_gold_lbl = UiTheme.label("0", 20, UiTheme.GOLD)
	_gold_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_gold_lbl)
	var close := Button.new()
	close.text = "Kapat"
	close.custom_minimum_size = Vector2(96, 40)
	close.pressed.connect(func(): visible = false)
	head.add_child(close)

	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_tabs)
	_depo = _tab("Depo")
	_sell = _tab("Sat")
	_upg = _tab("Geliştir")
	_market = _tab("Pazar")


func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(740, 380)
	_tabs.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 5)
	scroll.add_child(v)
	return v


func open() -> void:
	visible = true
	_sig = ""
	_rebuild()


func toggle() -> void:
	if visible:
		visible = false
	else:
		open()


func _process(delta: float) -> void:
	if not visible:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.2
		_rebuild()


func _rebuild() -> void:
	var inv: Dictionary = world.inventory
	if inv.is_empty():
		return
	Economy.ensure(inv)
	var sig := str(inv.slots) + str(inv.boat) + str(inv.gold) + str(world.economy.market)
	if sig == _sig:
		return
	_sig = sig
	_gold_lbl.text = "%d Altın" % Economy.gold(inv)
	_build_depo(inv)
	_build_sell(inv)
	_build_upg(inv)
	_build_market(inv)


func _clear(v: VBoxContainer) -> void:
	for c in v.get_children():
		c.queue_free()


func _row(parent: VBoxContainer) -> HBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.06, 0.11, 0.7), Color(1, 1, 1, 0.06), 6, 1, 6))
	parent.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	return h


func _icon(h: HBoxContainer, id: int, px := 34) -> void:
	var t := TextureRect.new()
	t.texture = TileAtlas.icon(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if Species.is_species(id):
		t.modulate = Species.tint(id)
	h.add_child(t)


func _text(h: HBoxContainer, text: String, size := 15, color := UiTheme.TEXT, expand := true) -> Label:
	var l := UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if expand:
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return l


func _btn(h: HBoxContainer, text: String, cb: Callable, disabled := false, w := 110) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = disabled
	b.pressed.connect(cb)
	h.add_child(b)
	return b


func _species_in_inv(inv: Dictionary) -> Array:
	var out := []
	for s in inv.slots:
		if s != null and Species.is_species(int(s[0])) and not out.has(int(s[0])):
			out.append(int(s[0]))
	out.sort()
	return out


func _rarity_text(id: int) -> String:
	var r := int(Species.get_def(id).get("rarity", 0))
	return Species.RARITY_NAMES[clampi(r, 0, Species.RARITY_NAMES.size() - 1)]


# --- Depo
func _build_depo(inv: Dictionary) -> void:
	_clear(_depo)
	var boat: Dictionary = inv.boat
	_depo.add_child(UiTheme.label("Teknede: %d / %d canlı  ·  Gövde ve Depo geliştirmeleri yeri büyütür" % [
		Economy.stored(boat), Economy.capacity(boat)], 14, UiTheme.GOLD))
	var store: Dictionary = boat.store
	if store.is_empty():
		_depo.add_child(UiTheme.label("Tekne deposu boş.", 13, UiTheme.MUTED))
	for sp in store:
		var h := _row(_depo)
		_icon(h, int(sp))
		_text(h, "%s ×%d" % [Species.display_name(int(sp)), int(store[sp])])
		var spi := int(sp)
		_btn(h, "1 al", func(): world.economy.take(spi, 1), false, 80)
		_btn(h, "Hepsini al", func(): world.economy.take(spi, 999))
	_depo.add_child(HSeparator.new())
	_depo.add_child(UiTheme.label("Envanterindeki canlılar", 14, UiTheme.MUTED))
	var list := _species_in_inv(inv)
	if list.is_empty():
		_depo.add_child(UiTheme.label("Envanterinde canlı yok. Ağla yakala, yüzeye getir.", 13, UiTheme.MUTED))
	for sp in list:
		var h := _row(_depo)
		_icon(h, sp)
		_text(h, "%s ×%d" % [Species.display_name(sp), Inventory.count(inv, sp)])
		var spi: int = sp
		_btn(h, "1 koy", func(): world.economy.store(spi, 1), false, 80)
		_btn(h, "Hepsini koy", func(): world.economy.store(spi, 999))


# --- Sat
func _build_sell(inv: Dictionary) -> void:
	_clear(_sell)
	_sell.add_child(UiTheme.label("Balıkçı tüccarı: nadir canlılar çok daha pahalı. Ansiklopediye kayıtlıdır, satsan da kaybolmaz.",
		13, UiTheme.MUTED))
	var any := false
	var items: Array = []
	for sp in _species_in_inv(inv):
		items.append(["inv", sp, Inventory.count(inv, sp)])
	for sp in inv.boat.store:
		items.append(["store", int(sp), int(inv.boat.store[sp])])
	if Inventory.count(inv, Blocks.PEARL) > 0:
		items.append(["inv", Blocks.PEARL, Inventory.count(inv, Blocks.PEARL)])
	for it in items:
		any = true
		var src: String = it[0]
		var id: int = it[1]
		var n: int = it[2]
		var each := Economy.price(id)
		var h := _row(_sell)
		_icon(h, id)
		var extra := "" if not Species.is_species(id) else "  ·  " + _rarity_text(id)
		_text(h, "%s ×%d%s%s\ntanesi %d Altın" % [Blocks.item_name(id), n, extra, "  (teknede)" if src == "store" else "", each], 14)
		_btn(h, "1 sat", func(): world.economy.sell(src, id, 1), false, 80)
		_btn(h, "Hepsi +%d" % (each * n), func(): world.economy.sell(src, id, n), false, 130)
	if not any:
		_sell.add_child(UiTheme.label("Satacak canlı ya da inci yok.", 13, UiTheme.MUTED))


# --- Geliştir
func _build_upg(inv: Dictionary) -> void:
	_clear(_upg)
	var b: Dictionary = inv.boat
	var g := Economy.gold(inv)
	var hull := int(b.hull)
	var h := _row(_upg)
	if hull + 1 < Economy.HULLS.size():
		var nx: Dictionary = Economy.HULLS[hull + 1]
		_text(h, "Gövde: %s → %s\n+%d depo yeri, daha büyük ve gösterişli tekne" % [Economy.HULLS[hull]["name"],
			nx["name"], int(nx["cap"]) - int(Economy.HULLS[hull]["cap"])], 14)
		_btn(h, "%d Altın" % int(nx["cost"]), func(): world.economy.upgrade("hull", 0), g < int(nx["cost"]), 130)
	else:
		_text(h, "Gövde: %s (en üst seviye)" % Economy.HULLS[hull]["name"], 14)
	var dep := int(b.depot)
	h = _row(_upg)
	if dep + 1 < Economy.DEPOT_COST.size():
		_text(h, "Depo %d → %d\n%d → %d canlı yeri" % [dep + 1, dep + 2, int(Economy.DEPOT_CAP[dep]),
			int(Economy.DEPOT_CAP[dep + 1])], 14)
		_btn(h, "%d Altın" % int(Economy.DEPOT_COST[dep + 1]), func(): world.economy.upgrade("depot", 0),
			g < int(Economy.DEPOT_COST[dep + 1]), 130)
	else:
		_text(h, "Depo %d (en üst seviye)" % (dep + 1), 14)
	var son := int(b.sonar)
	h = _row(_upg)
	if son + 1 < Economy.SONAR_COST.size():
		_text(h, "Sonar %d → %d\nÇok nadir, efsanevi ve mitik canlıları mini haritada %d hücreden gösterir" % [
			son, son + 1, int(Economy.SONAR_RANGE[son + 1])], 14)
		_btn(h, "%d Altın" % int(Economy.SONAR_COST[son + 1]), func(): world.economy.upgrade("sonar", 0),
			g < int(Economy.SONAR_COST[son + 1]), 130)
	else:
		_text(h, "Sonar %d (en üst seviye)" % son, 14)
	_upg.add_child(UiTheme.label("Boya (%d Altın)" % Economy.PAINT_COST, 14, UiTheme.MUTED))
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 6)
	_upg.add_child(sw)
	for i in Economy.PAINTS.size():
		var bt := Button.new()
		bt.custom_minimum_size = Vector2(52, 42)
		var c: Color = Economy.PAINTS[i]
		var sel := i == int(b.paint)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			bt.add_theme_stylebox_override(st, UiTheme.box(c, Color.WHITE if sel else Color(0, 0, 0, 0.5), 6, 3 if sel else 1, 0))
		bt.disabled = sel or g < Economy.PAINT_COST
		var idx := i
		bt.pressed.connect(func(): world.economy.upgrade("paint", idx))
		sw.add_child(bt)


# --- Pazar
func _build_market(inv: Dictionary) -> void:
	_clear(_market)
	var me: String = world.player_name
	var local: Player = world.local_player()
	if local != null:
		me = local.display_name
	_market.add_child(UiTheme.label("Satışa koy (eşya pazarda bekler, biri alınca altın sana gelir)", 14, UiTheme.MUTED))
	var form := HBoxContainer.new()
	form.add_theme_constant_override("separation", 8)
	_market.add_child(form)
	_m_item = OptionButton.new()
	_m_item.custom_minimum_size = Vector2(260, 40)
	_m_slots.clear()
	for i in Inventory.SLOTS:
		var s = inv.slots[i]
		if s == null:
			continue
		_m_slots.append(i)
		_m_item.add_icon_item(TileAtlas.icon(int(s[0])), "%s ×%d" % [Blocks.item_name(int(s[0])), int(s[1])])
	form.add_child(_m_item)
	form.add_child(UiTheme.label("Adet", 13, UiTheme.MUTED))
	_m_count = SpinBox.new()
	_m_count.min_value = 1
	_m_count.max_value = 99
	_m_count.value = 1
	form.add_child(_m_count)
	form.add_child(UiTheme.label("Tanesi", 13, UiTheme.MUTED))
	_m_price = SpinBox.new()
	_m_price.min_value = 1
	_m_price.max_value = Economy.MAX_PRICE
	_m_price.value = 10
	form.add_child(_m_price)
	_m_item.item_selected.connect(func(k):
		if k >= 0 and k < _m_slots.size():
			var s2 = inv.slots[_m_slots[k]]
			_m_count.max_value = int(s2[1])
			var p := Economy.price(int(s2[0]))
			if p > 0:
				_m_price.value = p * 2)
	if _m_slots.size() > 0:
		_m_item.select(0)
		_m_item.item_selected.emit(0)
	var lb := Button.new()
	lb.text = "Listele"
	lb.custom_minimum_size = Vector2(100, 40)
	lb.disabled = _m_slots.is_empty()
	lb.pressed.connect(func():
		var k := _m_item.selected
		if k >= 0 and k < _m_slots.size():
			world.economy.list_item(_m_slots[k], int(_m_count.value), int(_m_price.value)))
	form.add_child(lb)
	_market.add_child(HSeparator.new())
	var listings: Array = world.economy.market
	_market.add_child(UiTheme.label("Pazardaki ilanlar (%d)" % listings.size(), 14, UiTheme.MUTED))
	if listings.is_empty():
		_market.add_child(UiTheme.label("Henüz ilan yok.", 13, UiTheme.MUTED))
	var g := Economy.gold(inv)
	for l in listings:
		var h := _row(_market)
		var id := int(l.item)
		_icon(h, id)
		var total := int(l.price) * int(l.n)
		_text(h, "%s ×%d\nsatıcı: %s  ·  toplam %d Altın" % [Blocks.item_name(id), int(l.n), l.seller, total], 14)
		var lid := int(l.id)
		if str(l.seller) == me:
			_btn(h, "Geri al", func(): world.economy.unlist(lid))
		else:
			_btn(h, "Satın al", func(): world.economy.buy(lid), g < total)
