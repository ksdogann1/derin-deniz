class_name Hud
extends CanvasLayer
## Oyun içi arayüz: oksijen, derinlik çubuğu, hotbar, sohbet, üretim paneli.

const SLOT := 52.0
const SLOT_GAP := 6.0
const CHAT_LIFE := 12.0

var world: Node            # World
var loading := true

var _root: Control
var _vignette: TextureRect
var _danger: TextureRect
var _depth_lbl: Label
var _layer_lbl: Label
var _o2: Control
var _pearl_lbl: Label
var _tank_lbl: Label
var _station_lbl: Label
var _info_lbl: Label
var _gauge: Control
var _hotbar: Control
var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _chat_lines: Array[Dictionary] = []
var _inv: InventoryWindow
var _toast: Label
var _toast_time := 0.0
var _loading_lbl: Label
var _refresh := 0.0
var _t := 0.0
var _bag_row: HBoxContainer
var _bag_lbl: Label
var _bag_sig := ""
var _best_lbl: Label
var _codex: PanelContainer
var _codex_title: Label
var _codex_cards: Array[Dictionary] = []
var _aq_panel: PanelContainer
var _aq_list: VBoxContainer
var _aq_cell := Vector2i.ZERO
var _flash: ColorRect
var _help: Label
var _quest_card: PanelContainer
var _quest_head: Label
var _quest_text: Label
var _quest_bar: Control
var _pause: PanelContainer
var _conn_lbl: Label
var _settings: SettingsPanel
var touch: TouchControls
var _fps_lbl: Label
var _trade_win: TradeWindow
var _map_panel: PanelContainer
var _map_title: Label
var _minimap: MapView
var _players_panel: PanelContainer
var _players_list: VBoxContainer
var _invite: PanelContainer
var _invite_lbl: Label
var _invite_from := -1
var _invite_time := 0.0


func _ready() -> void:
	layer = 10
	loading = not multiplayer.is_server()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.get_theme()
	add_child(_root)

	_vignette = _full_rect_tex(UiTheme.vignette_texture(Color(0.0, 0.02, 0.06), 0.5), 0.55)
	_danger = _full_rect_tex(UiTheme.vignette_texture(Color(0.9, 0.08, 0.05), 0.35), 0.0)

	_build_stats()
	_build_gauge()
	_build_hotbar()
	_build_chat()
	_inv = InventoryWindow.new()
	_inv.world = world
	_root.add_child(_inv)
	_build_codex()
	_build_aquarium_panel()
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_root.add_child(_flash)

	_toast = UiTheme.label("", 21, UiTheme.GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.offset_top = 96
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)

	_info_lbl = UiTheme.label("", 14, UiTheme.MUTED)
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_info_lbl.offset_left = -360
	_info_lbl.offset_right = -16
	_info_lbl.offset_top = 12
	_root.add_child(_info_lbl)

	_help = UiTheme.label(
		"WASD yüz · Sol tık kır / yakala · Sağ tık koy · 1-9 seç · E envanter · K ansiklopedi · M harita · T takas · Enter sohbet · Esc menü",
		12, Color(1, 1, 1, 0.45))
	_help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_help.offset_left = 14
	_help.offset_top = -22
	_help.offset_bottom = -6
	_root.add_child(_help)
	_fps_lbl = UiTheme.label("", 13, UiTheme.GOOD)
	_fps_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fps_lbl.offset_left = -60
	_fps_lbl.offset_right = 60
	_fps_lbl.offset_top = 4
	_fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_fps_lbl)
	_build_trade_ui()
	_build_map_ui()
	_build_quest_card()
	_build_pause()
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.touch_changed.connect(_update_touch)
	_root.add_child(_settings)
	_update_touch()

	_loading_lbl = UiTheme.label("Dünya yükleniyor…", 28)
	_loading_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_loading_lbl)


func _full_rect_tex(tex: Texture2D, alpha: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.modulate.a = alpha
	_root.add_child(r)
	return r


# --------------------------------------------------------------------------
# Kurulum
# --------------------------------------------------------------------------

func _build_stats() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	v.add_child(top)
	_depth_lbl = UiTheme.label("0 m", 24)
	top.add_child(_depth_lbl)
	_layer_lbl = UiTheme.label("", 14, UiTheme.ACCENT)
	_layer_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(_layer_lbl)
	_o2 = Control.new()
	_o2.custom_minimum_size = Vector2(250, 22)
	_o2.draw.connect(_draw_o2)
	v.add_child(_o2)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	row.add_child(_icon(Blocks.PEARL, 20))
	_pearl_lbl = UiTheme.label("0", 16, Color.WHITE)
	row.add_child(_pearl_lbl)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(12, 0)
	row.add_child(sp)
	row.add_child(_icon(Blocks.TANK_UPGRADE, 20))
	_tank_lbl = UiTheme.label("Tüp 0/3", 14, UiTheme.MUTED)
	row.add_child(_tank_lbl)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(12, 0)
	row.add_child(sp2)
	_best_lbl = UiTheme.label("Rekor 0 m", 14, UiTheme.MUTED)
	row.add_child(_best_lbl)
	var bag := HBoxContainer.new()
	bag.add_theme_constant_override("separation", 4)
	v.add_child(bag)
	bag.add_child(_icon(Blocks.NET, 20))
	_bag_lbl = UiTheme.label("Fileye 0/5", 14, UiTheme.MUTED)
	bag.add_child(_bag_lbl)
	_bag_row = HBoxContainer.new()
	_bag_row.add_theme_constant_override("separation", 2)
	bag.add_child(_bag_row)
	_station_lbl = UiTheme.label("", 13, UiTheme.GOOD)
	v.add_child(_station_lbl)


func _icon(id: int, px: int) -> TextureRect:
	var t := TextureRect.new()
	t.texture = TileAtlas.icon(id)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _build_gauge() -> void:
	_gauge = Control.new()
	_gauge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_gauge.offset_left = -46
	_gauge.offset_right = -22
	_gauge.offset_top = -110
	_gauge.offset_bottom = 200
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.draw.connect(_draw_gauge)
	_root.add_child(_gauge)


func _build_hotbar() -> void:
	_hotbar = Control.new()
	var n := Inventory.HOTBAR
	var w := n * SLOT + (n - 1) * SLOT_GAP
	_hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hotbar.offset_left = -w * 0.5
	_hotbar.offset_right = w * 0.5
	_hotbar.offset_top = -SLOT - 34
	_hotbar.offset_bottom = -34
	_hotbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_hotbar.draw.connect(_draw_hotbar)
	_hotbar.gui_input.connect(_on_hotbar_input)
	_root.add_child(_hotbar)


func _build_chat() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.offset_left = 14
	box.offset_right = 434
	box.offset_top = -250
	box.offset_bottom = -30
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_chat_log = RichTextLabel.new()
	_chat_log.bbcode_enabled = true
	_chat_log.fit_content = true
	_chat_log.scroll_active = false
	_chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat_log.add_theme_font_size_override("normal_font_size", 14)
	_chat_log.add_theme_font_size_override("bold_font_size", 14)
	box.add_child(_chat_log)
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Mesaj yaz, Enter ile gönder"
	_chat_input.max_length = World.CHAT_MAX
	_chat_input.visible = false
	_chat_input.text_submitted.connect(_on_chat_submit)
	box.add_child(_chat_input)


func _center_panel(min_w: float) -> PanelContainer:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(min_w, 0)
	p.visible = false
	_root.add_child(p)
	return p


func _panel_head(parent: Control, title: String, on_close: Callable) -> Label:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var t := UiTheme.label(title, 22, UiTheme.ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := Button.new()
	close.text = "Kapat"
	close.pressed.connect(on_close)
	head.add_child(close)
	parent.add_child(HSeparator.new())
	return t


func _build_codex() -> void:
	_codex = _center_panel(640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_codex.add_child(v)
	_codex_title = _panel_head(v, "Deniz Ansiklopedisi", func(): _codex.visible = false)
	var gscroll := ScrollContainer.new()
	gscroll.custom_minimum_size = Vector2(660, 430)
	gscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(gscroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	gscroll.add_child(grid)
	for d in Species.LIST:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.02, 0.06, 0.11, 0.8),
			Color(1, 1, 1, 0.08), 8, 1, 6))
		card.custom_minimum_size = Vector2(116, 0)
		grid.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 1)
		card.add_child(cv)
		var ic := _icon(d["id"], 40)
		ic.custom_minimum_size = Vector2(0, 40)
		cv.add_child(ic)
		var nm := UiTheme.label("", 13)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cv.add_child(nm)
		var rr := UiTheme.label(Species.RARITY_NAMES[d["rarity"]], 11, Species.RARITY_COLORS[d["rarity"]])
		rr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(rr)
		var info := UiTheme.label(Species.depth_text(d["id"]), 11, UiTheme.MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(info)
		_codex_cards.append({"id": d["id"], "icon": ic, "name": nm, "info": info})
	var tip := UiTheme.label("Ağ ile parıldayan canlılara tıkla. Yakaladıkların fileyende durur; yüzeye ya da bir " +
		"oksijen istasyonunun yanına dönünce koleksiyonuna geçer. Oksijenin biterse fileyendekiler kaçar.",
		12, UiTheme.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(600, 0)
	v.add_child(tip)


func _refresh_codex() -> void:
	var found := 0
	for card in _codex_cards:
		var id: int = card.id
		var n := int(world.codex.get(id, 0))
		var have: int = world.have(id)
		var known := n > 0
		if known:
			found += 1
		(card.icon as TextureRect).modulate = Species.tint(id) if known else Color(0, 0, 0, 0.75)
		(card.name as Label).text = Species.display_name(id) if known else "???"
		(card.info as Label).text = "%s · %d yakalandı · %d elde" % [Species.depth_text(id), n, have] if known \
			else Species.depth_text(id)
	_codex_title.text = "Deniz Ansiklopedisi  %d/%d" % [found, Species.LIST.size()]


func _build_aquarium_panel() -> void:
	_aq_panel = _center_panel(340)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_aq_panel.add_child(v)
	_panel_head(v, "Akvaryum", func(): _aq_panel.visible = false)
	_aq_list = VBoxContainer.new()
	_aq_list.add_theme_constant_override("separation", 4)
	v.add_child(_aq_list)


func _build_trade_ui() -> void:
	_trade_win = TradeWindow.new()
	_trade_win.world = world
	_root.add_child(_trade_win)

	_players_panel = _center_panel(380)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_players_panel.add_child(v)
	_panel_head(v, "Oyuncular", func(): _players_panel.visible = false)
	_players_list = VBoxContainer.new()
	_players_list.add_theme_constant_override("separation", 6)
	v.add_child(_players_list)

	_invite = PanelContainer.new()
	_invite.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invite.offset_top = 130
	_invite.offset_left = -220
	_invite.offset_right = 220
	_invite.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_invite.visible = false
	_invite.add_theme_stylebox_override("panel", UiTheme.box(Color(0.05, 0.12, 0.2, 0.95), UiTheme.GOLD, 10, 2, 10))
	_root.add_child(_invite)
	var iv := VBoxContainer.new()
	_invite.add_child(iv)
	_invite_lbl = UiTheme.label("", 16, UiTheme.GOLD)
	_invite_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_invite_lbl)
	var ib := HBoxContainer.new()
	ib.alignment = BoxContainer.ALIGNMENT_CENTER
	ib.add_theme_constant_override("separation", 10)
	iv.add_child(ib)
	var yes := Button.new()
	yes.text = "Kabul et"
	yes.custom_minimum_size = Vector2(140, 40)
	yes.pressed.connect(func():
		_invite.visible = false
		world.trade.answer(_invite_from, true))
	ib.add_child(yes)
	var no := Button.new()
	no.text = "Reddet"
	no.custom_minimum_size = Vector2(140, 40)
	no.pressed.connect(func():
		_invite.visible = false
		world.trade.answer(_invite_from, false))
	ib.add_child(no)


func _build_map_ui() -> void:
	_minimap = MapView.new()
	_minimap.world = world
	_minimap.mini = true
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -204
	_minimap.offset_right = -14
	_minimap.offset_top = 122
	_minimap.offset_bottom = 244
	_root.add_child(_minimap)
	_map_panel = _center_panel(860)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_map_panel.add_child(v)
	_map_title = _panel_head(v, "Harita", func(): _map_panel.visible = false)
	var mv := MapView.new()
	mv.world = world
	mv.custom_minimum_size = Vector2(840, 500)
	v.add_child(mv)


func toggle_map() -> void:
	_map_panel.visible = not _map_panel.visible
	if _map_panel.visible and world.map != null:
		_map_title.text = "Harita  ·  %%%d keşfedildi" % int(world.map.explored_ratio() * 100.0)


func toggle_players() -> void:
	_players_panel.visible = not _players_panel.visible
	if not _players_panel.visible:
		return
	for c in _players_list.get_children():
		c.queue_free()
	var me := world.local_player() as Player
	var any := false
	for n in world.players():
		var pl := n as Player
		if pl == null or pl == me:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_players_list.add_child(row)
		var name_lbl := UiTheme.label(pl.display_name, 16, pl.suit_color.lightened(0.3))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)
		var depth := UiTheme.label("%d m" % int(pl.position.y / 16.0), 13, UiTheme.MUTED)
		row.add_child(depth)
		var b := Button.new()
		b.text = "Takas iste"
		var pid := pl.peer_id
		b.pressed.connect(func():
			_players_panel.visible = false
			world.trade.request(pid))
		row.add_child(b)
	if not any:
		_players_list.add_child(UiTheme.label("Dünyada senden başka oyuncu yok.", 14, UiTheme.MUTED))


func show_trade_invite(from_peer: int, from_name: String) -> void:
	_invite_from = from_peer
	_invite_lbl.text = "%s seninle takas yapmak istiyor" % from_name
	_invite.visible = true
	_invite_time = 20.0


func show_trade(st: Dictionary) -> void:
	_inv.close_window()
	_players_panel.visible = false
	_trade_win.refresh(st)


func close_trade() -> void:
	_trade_win.refresh({})


func _build_quest_card() -> void:
	_quest_card = PanelContainer.new()
	_quest_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_card.offset_left = -330
	_quest_card.offset_right = -14
	_quest_card.offset_top = 40
	_quest_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.035, 0.09, 0.16, 0.72),
		Color(1.0, 0.86, 0.45, 0.35), 8, 1, 8))
	_root.add_child(_quest_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_card.add_child(v)
	_quest_head = UiTheme.label("GÖREV", 11, UiTheme.GOLD)
	v.add_child(_quest_head)
	_quest_text = UiTheme.label("", 14)
	_quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_text.custom_minimum_size = Vector2(290, 0)
	v.add_child(_quest_text)
	_quest_bar = Control.new()
	_quest_bar.custom_minimum_size = Vector2(290, 14)
	_quest_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_bar.draw.connect(_draw_quest_bar)
	v.add_child(_quest_bar)


func _draw_quest_bar() -> void:
	var q: Dictionary = world.quest
	if q.is_empty():
		return
	var need := maxi(1, int(q.need))
	var prog := mini(int(q.prog), need)
	var sz := _quest_bar.size
	var bar := Rect2(0, 3, sz.x - 90, 8)
	_quest_bar.draw_rect(bar, Color(0, 0, 0, 0.5))
	_quest_bar.draw_rect(Rect2(bar.position, Vector2(bar.size.x * prog / need, bar.size.y)), UiTheme.GOLD)
	var font := ThemeDB.fallback_font
	var txt := "%d/%d" % [prog, need] if q.type not in ["depth"] else "%d/%d m" % [prog, need]
	_quest_bar.draw_string(font, Vector2(bar.end.x + 6, 12), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.MUTED)
	_quest_bar.draw_texture_rect(TileAtlas.icon(Blocks.PEARL), Rect2(sz.x - 34, 0, 13, 13), false)
	_quest_bar.draw_string(font, Vector2(sz.x - 19, 12), "+%d" % int(q.reward), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		UiTheme.GOLD)


func _build_pause() -> void:
	_pause = _center_panel(400)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_pause.add_child(v)
	var t := UiTheme.label("Menü", 24, UiTheme.ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var note := UiTheme.label("Oyun arka planda sürüyor", 12, UiTheme.MUTED)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	_conn_lbl = UiTheme.label("", 13)
	_conn_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conn_lbl.custom_minimum_size = Vector2(380, 0)
	v.add_child(_conn_lbl)
	for item in [["Devam et", func(): _pause.visible = false],
			["Ayarlar", func():
				_pause.visible = false
				_settings.visible = true],
			["Ana menüye dön", func(): world.request_leave()]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(item[1])
		v.add_child(b)


func _update_touch() -> void:
	var on := Settings.touch_enabled()
	if on and touch == null:
		touch = TouchControls.new()
		touch.hud = self
		touch.world = world
		add_child(touch)
	elif not on and touch != null:
		touch.queue_free()
		touch = null
	_help.visible = not on


## Kurucunun ekranında arkadaşların hangi adresle katılacağı
func connection_text() -> String:
	var hi: Dictionary = world.host_info
	if hi.is_empty():
		return ""
	var lines: PackedStringArray = ["Arkadaşların şu adreslerden biriyle katılır (port %d):" % int(hi.port)]
	for ip in hi.ips:
		lines.append("  •  %s   (%s)" % [ip, NetTools.describe(ip)])
	if str(hi.get("ext", "")) != "":
		lines.append("  •  %s   (internet, UPnP ile açıldı)" % hi.ext)
	lines.append(str(hi.get("upnp", "")))
	lines.append("Aynı ağdakiler menüdeki listede seni kendiliğinden görür.")
	if bool(hi.get("web", false)) and (hi.ips as PackedStringArray).size() > 0:
		lines.append("iPhone / tarayıcı (aynı Wi-Fi): Safari'de  http://%s:%d  aç." % [hi.ips[0], NetTools.WEB_PORT])
	return "\n".join(lines)


## Arayüz boyutu: katmanı ölçekle, kök denetimi ekranı dolduracak boyuta getir
func _apply_scale() -> void:
	var s := Settings.ui_scale
	if not is_equal_approx(scale.x, s):
		scale = Vector2(s, s)
	var want := get_viewport().get_visible_rect().size / s
	if _root.size != want or _root.position != Vector2.ZERO:
		_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_root.position = Vector2.ZERO
		_root.size = want


func any_panel_open() -> bool:
	return _inv.visible or _codex.visible or _aq_panel.visible or _pause.visible or _settings.visible \
		or _trade_win.visible or _players_panel.visible or _map_panel.visible


## Esc ya da Android geri tuşu
func back() -> void:
	if typing():
		_close_chat()
	elif _trade_win.visible:
		world.trade.cancel()
	elif any_panel_open():
		_players_panel.visible = false
		_map_panel.visible = false
		_inv.close_window()
		_codex.visible = false
		_aq_panel.visible = false
		_pause.visible = false
		_settings.visible = false
	else:
		_pause.visible = true


func open_chat() -> void:
	_chat_input.visible = true
	_chat_input.grab_focus()
	_rebuild_chat()


func toggle_codex() -> void:
	_codex.visible = not _codex.visible
	_refresh_codex()


func open_aquarium(cell: Vector2i) -> void:
	_aq_cell = cell
	for c in _aq_list.get_children():
		c.queue_free()
	var current: int = world.aquariums.get(cell, 0)
	if current != 0:
		_aq_list.add_child(UiTheme.label("İçinde: " + Species.display_name(current), 14, UiTheme.GOLD))
	var any := false
	for d in Species.LIST:
		var id: int = d["id"]
		var n: int = world.have(id)
		if n <= 0:
			continue
		any = true
		var b := Button.new()
		b.text = "%s  (%d)" % [Species.display_name(id), n]
		b.icon = Species.icon(id)
		b.expand_icon = false
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			world.request_aquarium(cell, id)
			_aq_panel.visible = false)
		_aq_list.add_child(b)
	if not any:
		var l := UiTheme.label("Koleksiyonunda canlı yok. Ağ ile yakalayıp yüzeye dön.", 13, UiTheme.MUTED)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		_aq_list.add_child(l)
	if current != 0:
		var e := Button.new()
		e.text = "Akvaryumu boşalt"
		e.pressed.connect(func():
			world.request_aquarium(cell, 0)
			_aq_panel.visible = false)
		_aq_list.add_child(e)
	_aq_panel.visible = true


func flash(color: Color) -> void:
	_flash.color = Color(color, 0.55)


# --------------------------------------------------------------------------
# Dış API
# --------------------------------------------------------------------------

func toast(text: String) -> void:
	_toast.text = text
	_toast_time = 3.2


func typing() -> bool:
	return _chat_input.visible and _chat_input.has_focus()


func pointer_over_ui() -> bool:
	return _root.get_viewport().gui_get_hovered_control() != null


func craft_open() -> bool:
	return _inv.visible


func add_chat(sender: String, text: String, color: Color) -> void:
	var safe := text.replace("[", "[lb]")
	var line := ""
	if sender == "":
		line = "[i][color=#%s]%s[/color][/i]" % [color.to_html(false), safe]
	else:
		line = "[b][color=#%s]%s:[/color][/b] %s" % [color.lightened(0.25).to_html(false),
			sender.replace("[", "[lb]"), safe]
	_chat_lines.append({"text": line, "t": _t})
	if _chat_lines.size() > 30:
		_chat_lines.pop_front()
	_rebuild_chat()


func toggle_craft() -> void:
	_inv.toggle()


# --------------------------------------------------------------------------
# Girdi
# --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if loading or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := (event as InputEventKey).physical_keycode
	if typing():
		if k == KEY_ESCAPE:
			_close_chat()
			get_viewport().set_input_as_handled()
		return
	if k == KEY_ESCAPE:
		back()
		get_viewport().set_input_as_handled()
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		open_chat()
		get_viewport().set_input_as_handled()
	elif k == KEY_C or k == KEY_E or k == KEY_I or k == KEY_TAB:
		toggle_craft()
		get_viewport().set_input_as_handled()
	elif k == KEY_K:
		toggle_codex()
		get_viewport().set_input_as_handled()
	elif k == KEY_T:
		toggle_players()
		get_viewport().set_input_as_handled()
	elif k == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()


func _on_chat_submit(text: String) -> void:
	if not text.strip_edges().is_empty():
		world.send_chat(text)
	_close_chat()


func _close_chat() -> void:
	_chat_input.text = ""
	_chat_input.release_focus()
	_chat_input.visible = false
	_rebuild_chat()


func _on_hotbar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := int(event.position.x / (SLOT + SLOT_GAP))
		world.selected_slot = clampi(i, 0, Inventory.HOTBAR - 1)
		_hotbar.accept_event()


# --------------------------------------------------------------------------
# Güncelleme
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	if _invite.visible:
		_invite_time -= delta
		if _invite_time <= 0.0:
			_invite.visible = false
	_apply_scale()
	_fps_lbl.visible = Settings.show_fps
	var busy := any_panel_open()
	_minimap.visible = Settings.minimap and not loading and not busy
	if Settings.show_fps:
		_fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	_toast_time = maxf(0.0, _toast_time - delta)
	_toast.modulate.a = clampf(_toast_time, 0.0, 1.0)
	var p := world.local_player() as Player
	_loading_lbl.visible = loading or p == null
	if p == null:
		return

	var row := int(p.depth_row())
	_depth_lbl.text = "%d m" % maxi(row, 0)
	_layer_lbl.text = WorldGen.layer_name(row)
	_layer_lbl.add_theme_color_override("font_color", WorldGen.layer_color(row).lightened(0.35))
	_pearl_lbl.text = str(world.have(Blocks.PEARL))
	_tank_lbl.text = "Tüp %d/%d" % [Inventory.level(world.inventory, Blocks.TANK_UPGRADE), Blocks.MAX_TANK_LEVEL]
	_station_lbl.text = "Oksijen istasyonu yakında: doluyor" if p.near_station and row > 1 else ""
	_station_lbl.visible = _station_lbl.text != ""
	_info_lbl.text = "%s  ·  %d oyuncu" % [world.world_name, world.player_count()]
	var hi: Dictionary = world.host_info
	if not hi.is_empty() and (hi.ips as PackedStringArray).size() > 0:
		_info_lbl.text += "  ·  IP %s" % hi.ips[0]
	if _pause.visible:
		_conn_lbl.text = connection_text()
		_conn_lbl.visible = _conn_lbl.text != ""
	var q: Dictionary = world.quest
	_quest_card.visible = not q.is_empty() and not busy
	if not q.is_empty():
		_quest_head.text = "SERBEST GÖREV" if q.free else "GÖREV %d/%d" % [int(q.step), int(q.total)]
		_quest_text.text = q.text
		_quest_bar.queue_redraw()
	_best_lbl.text = "Rekor %d m" % maxi(world.best_depth, row)
	_flash.color.a = maxf(0.0, _flash.color.a - delta * 1.6)
	var sig := str(world.bag) + str(World.bag_max(world.inventory))
	if sig != _bag_sig:
		_bag_sig = sig
		for c in _bag_row.get_children():
			c.queue_free()
		for sp in world.bag:
			var ic := _icon(sp, 20)
			ic.modulate = Species.tint(sp)
			_bag_row.add_child(ic)
		_bag_lbl.text = "Fileye %d/%d" % [world.bag.size(), World.bag_max(world.inventory)]
		_bag_lbl.add_theme_color_override("font_color",
			UiTheme.GOLD if world.bag.size() >= World.bag_max(world.inventory) else UiTheme.MUTED)

	var frac := p.oxygen / p.max_oxygen()
	_danger.modulate.a = (0.45 + 0.25 * sin(_t * 7.0)) * clampf((0.28 - frac) / 0.28, 0.0, 1.0)
	_vignette.modulate.a = lerpf(0.35, 0.8, clampf(row / 200.0, 0.0, 1.0)) if Settings.vignette else 0.0

	_o2.queue_redraw()
	_gauge.queue_redraw()
	_hotbar.queue_redraw()
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 0.25
		_rebuild_chat()
		if _codex.visible:
			_refresh_codex()


func _rebuild_chat() -> void:
	var show_all := _chat_input.visible
	var parts: PackedStringArray = []
	var start := maxi(0, _chat_lines.size() - 8)
	for i in range(start, _chat_lines.size()):
		var l: Dictionary = _chat_lines[i]
		if show_all or _t - float(l.t) < CHAT_LIFE:
			parts.append(l.text)
	var text := "\n".join(parts)
	if _chat_log.text != text:
		_chat_log.text = text


# --------------------------------------------------------------------------
# Çizimler
# --------------------------------------------------------------------------

func _draw_o2() -> void:
	var p := world.local_player() as Player
	if p == null:
		return
	var sz := _o2.size
	var maxo := p.max_oxygen()
	var frac := clampf(p.oxygen / maxo, 0.0, 1.0)
	var bar := Rect2(0, 3, sz.x - 70, sz.y - 6)
	_o2.draw_style_box(UiTheme.box(Color(0, 0, 0, 0.5), Color(1, 1, 1, 0.12), 6, 1, 0), bar)
	var col := Color(0.3, 0.85, 1.0)
	if frac < 0.25:
		col = UiTheme.BAD
	elif frac < 0.5:
		col = Color(1.0, 0.78, 0.3)
	var fill := Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * frac, bar.size.y - 4))
	if fill.size.x > 1:
		_o2.draw_style_box(UiTheme.box(col, Color(0, 0, 0, 0), 4, 0, 0), fill)
		_o2.draw_rect(Rect2(fill.position + Vector2(3, 1), Vector2(maxf(fill.size.x - 6, 0), 2)),
			Color(1, 1, 1, 0.35))
	# bölmeler (her 10 sn)
	var step := (bar.size.x - 4) * 10.0 / maxo
	var x := bar.position.x + 2 + step
	while x < bar.end.x - 3:
		_o2.draw_line(Vector2(x, bar.position.y + 3), Vector2(x, bar.end.y - 3), Color(0, 0, 0, 0.35), 1.0)
		x += step
	var font := ThemeDB.fallback_font
	_o2.draw_string(font, Vector2(bar.end.x + 8, 17), "O₂ %d sn" % int(ceil(p.oxygen)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col.lightened(0.3))


func _draw_gauge() -> void:
	var sz := _gauge.size
	var h := sz.y
	var bands := [[0, WorldGen.LAYER_TWILIGHT], [WorldGen.LAYER_TWILIGHT, WorldGen.LAYER_MIDNIGHT],
		[WorldGen.LAYER_MIDNIGHT, WorldGen.LAYER_ABYSS], [WorldGen.LAYER_ABYSS, WorldGen.H]]
	var bx := sz.x * 0.5 - 4
	for b in bands:
		var y0: float = float(b[0]) / WorldGen.H * h
		var y1: float = float(b[1]) / WorldGen.H * h
		_gauge.draw_rect(Rect2(bx, y0, 8, y1 - y0), Color(WorldGen.layer_color(b[0]), 0.85))
	_gauge.draw_rect(Rect2(bx - 1, -1, 10, h + 2), Color(1, 1, 1, 0.25), false, 1.0)
	var me := world.local_player() as Player
	for n in world.players():
		var pl := n as Player
		if pl == null or pl == me:
			continue
		var py := clampf(pl.position.y / (WorldGen.H * 16.0), 0, 1) * h
		_gauge.draw_circle(Vector2(sz.x * 0.5, py), 3.0, pl.suit_color)
	if me != null:
		var my := clampf(me.position.y / (WorldGen.H * 16.0), 0, 1) * h
		var tri := PackedVector2Array([Vector2(bx - 9, my - 5), Vector2(bx - 2, my), Vector2(bx - 9, my + 5)])
		_gauge.draw_colored_polygon(tri, Color.WHITE)
		_gauge.draw_line(Vector2(bx - 2, my), Vector2(bx + 10, my), Color.WHITE, 2.0)


func _draw_hotbar() -> void:
	var font := ThemeDB.fallback_font
	var inv: Dictionary = world.inventory
	if inv.is_empty():
		return
	for i in Inventory.HOTBAR:
		var r := Rect2(i * (SLOT + SLOT_GAP), 0, SLOT, SLOT)
		var selected: bool = i == world.selected_slot
		var bg := Color(0.03, 0.08, 0.14, 0.82) if not selected else Color(0.08, 0.2, 0.3, 0.92)
		var border := Color(1, 1, 1, 0.14) if not selected else UiTheme.GOLD
		_hotbar.draw_style_box(UiTheme.box(bg, border, 8, 2 if selected else 1, 0), r)
		_hotbar.draw_string(font, r.position + Vector2(5, 14), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 1, 1, 0.55))
		var s = inv.slots[i]
		if s == null:
			continue
		var id := int(s[0])
		var tint := Species.tint(id) if Species.is_species(id) else Color.WHITE
		_hotbar.draw_texture_rect(TileAtlas.icon(id), r.grow(-11), false, tint)
		if int(s[1]) > 1:
			var cs := str(int(s[1]))
			var cpos := r.position + Vector2(0, SLOT - 6)
			_hotbar.draw_string_outline(font, cpos, cs, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 6, 14, 4, Color(0, 0, 0, 0.8))
			_hotbar.draw_string(font, cpos, cs, HORIZONTAL_ALIGNMENT_RIGHT, SLOT - 6, 14, Color.WHITE)
	var sel: int = world.selected_block()
	var title := Blocks.item_name(sel) if sel != 0 else ""
	if sel != 0 and not Blocks.PLACEABLE.has(sel):
		title += "  (yere konmaz)"
	_hotbar.draw_string_outline(font, Vector2(0, -10), title, HORIZONTAL_ALIGNMENT_CENTER, _hotbar.size.x, 16, 4,
		Color(0, 0, 0, 0.7))
	_hotbar.draw_string(font, Vector2(0, -10), title, HORIZONTAL_ALIGNMENT_CENTER, _hotbar.size.x, 16, UiTheme.GOLD)
