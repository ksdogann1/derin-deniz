extends Node
## Ana menü ve ağ kurulumu.
##
## Komut satırı (oyun argümanları "--" sonrasına yazılır):
##   godot --headless --path . -- --server [--port 7777] [--world ad]   # sadece sunucu
##   godot --path . -- --host  [--name Ali] [--world ad]                # menüsüz sunucu+oyuncu
##   godot --path . -- --join 127.0.0.1 [--port 7777]                   # doğrudan katıl
## Geliştirici: --shot dosya.png [--depth satır] [--shotdelay sn] [--ui craft|chat]

const DEFAULT_PORT := 7777
const MAX_CLIENTS := 16

var _menu_layer: CanvasLayer
var _menu: Control
var _status: Label
var _name_edit: LineEdit
var _world_edit: LineEdit
var _addr_edit: LineEdit
var _port_edit: LineEdit
var _worlds_lbl: Label
var _color_btns: Array[Button] = []
var _color_index := 4
var _world: World
var _dedicated := false
var _pending_name := "Dalgıç"
var _menu_settings: SettingsPanel
var _lan_list: VBoxContainer
var _lan: LanDiscovery             # menüde: ağdaki dünyaları arar
var _responder: LanDiscovery       # kurucuyken: aramalara cevap verir
var _upnp: UpnpHelper
var _web_host: WebHost
var _quit_btn: Button
var _tip_lbl: Label
var _joining := false
var _join_time := 0.0
var _join_target := ""
var _host_port := DEFAULT_PORT
var _menu_music: AudioStreamPlayer

var _shot_path := ""
var _shot_delay := 3.0
var _shot_depth := 0
var _shot_x := -1
var _shot_ui := ""
var _shot_time := 0.0
var _shot_prepared := false


func _ready() -> void:
	Settings.ensure_loaded()
	RenderingServer.set_default_clear_color(Color("06223d"))
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args := _parse_args()
	var port := int(args.get("port", DEFAULT_PORT))
	var pname := str(args.get("name", "Dalgıç"))
	var wname := str(args.get("world", "okyanus"))
	_color_index = clampi(int(args.get("color", randi() % Player.SUIT_COLORS.size())), 0,
		Player.SUIT_COLORS.size() - 1)
	if args.has("shot"):
		_shot_path = str(args["shot"])
		_shot_delay = float(args.get("shotdelay", 3.0))
		_shot_depth = int(args.get("depth", 0))
		_shot_x = int(args.get("atx", -1))
		_shot_ui = str(args.get("ui", ""))

	if args.has("fakeversion"):
		NetTools.version_override = str(args["fakeversion"])
	if args.has("quitafter"):
		get_tree().create_timer(float(args["quitafter"])).timeout.connect(func():
			print("[Durum] ", _status.text if _status != null else "", " | dünyada: ", _world != null)
			get_tree().quit())

	if args.has("server"):
		_dedicated = true
		_start_host(port, pname, wname)
		return

	_build_menu()
	if not NetTools.is_web():
		_lan = LanDiscovery.new()
		add_child(_lan)
		_lan.servers_changed.connect(_refresh_lan)
		_lan.start_browser()
	else:
		_setup_web_menu()
	_name_edit.text = pname
	_world_edit.text = wname
	if args.has("host"):
		_start_host(port, pname, wname)
	elif args.has("join"):
		_start_join(str(args["join"]), port, pname)


func _parse_args() -> Dictionary:
	var out := {}
	var a := OS.get_cmdline_user_args()
	var i := 0
	while i < a.size():
		var key := a[i]
		if key.begins_with("--"):
			var k := key.substr(2)
			if i + 1 < a.size() and not a[i + 1].begins_with("--"):
				out[k] = a[i + 1]
				i += 1
			else:
				out[k] = true
		i += 1
	return out


# --------------------------------------------------------------------------
# Menü
# --------------------------------------------------------------------------

func _build_menu() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.layer = 20
	add_child(_menu_layer)
	_menu = Control.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.theme = UiTheme.get_theme()
	_menu_layer.add_child(_menu)

	var bg := MenuBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	center.add_child(outer)

	var title := UiTheme.label("DERİN DENİZ", 64, Color(0.8, 0.96, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.1, 0.25, 0.8))
	outer.add_child(title)
	var sub := UiTheme.label("Birlikte kaz, kur, derine dal.", 17, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(sub)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 14)
	outer.add_child(cols)

	# --- sol: dünya kur
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	cols.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiTheme.label("Dalgıç", 18, UiTheme.ACCENT))
	_name_edit = _field(box, "Adın", "Dalgıç")
	box.add_child(UiTheme.label("Takım rengi", 13, UiTheme.MUTED))
	var colors := HBoxContainer.new()
	colors.add_theme_constant_override("separation", 6)
	box.add_child(colors)
	for i in Player.SUIT_COLORS.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(38, 30)
		b.toggle_mode = true
		var idx := i
		b.pressed.connect(func(): _select_color(idx))
		colors.add_child(b)
		_color_btns.append(b)
	_select_color(_color_index)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Dünya Kur", 18, UiTheme.ACCENT))
	_world_edit = _field(box, "Dünya adı", "okyanus")
	_worlds_lbl = UiTheme.label("", 12, UiTheme.MUTED)
	_worlds_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_worlds_lbl.custom_minimum_size = Vector2(370, 0)
	box.add_child(_worlds_lbl)
	_refresh_worlds()
	var host_btn := Button.new()
	host_btn.text = "Dünya Kur ve Oyna"
	host_btn.custom_minimum_size = Vector2(0, 44)
	host_btn.pressed.connect(func(): _start_host(_get_port(), _name_edit.text, _world_edit.text))
	box.add_child(host_btn)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	box.add_child(bottom)
	var set_btn := Button.new()
	set_btn.text = "Ayarlar"
	set_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_btn.pressed.connect(func(): _menu_settings.visible = true)
	bottom.add_child(set_btn)
	var quit_btn := Button.new()
	_quit_btn = quit_btn
	quit_btn.text = "Çık"
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_btn.pressed.connect(func(): get_tree().quit())
	bottom.add_child(quit_btn)

	# --- sağ: katıl
	var jpanel := PanelContainer.new()
	jpanel.custom_minimum_size = Vector2(400, 0)
	cols.add_child(jpanel)
	var jbox := VBoxContainer.new()
	jbox.add_theme_constant_override("separation", 8)
	jpanel.add_child(jbox)
	jbox.add_child(UiTheme.label("Katıl", 18, UiTheme.ACCENT))
	jbox.add_child(UiTheme.label("Aynı ağdaki dünyalar (kendiliğinden bulunur)", 13, UiTheme.MUTED))
	_lan_list = VBoxContainer.new()
	_lan_list.add_theme_constant_override("separation", 4)
	_lan_list.custom_minimum_size = Vector2(0, 120)
	jbox.add_child(_lan_list)
	jbox.add_child(HSeparator.new())
	jbox.add_child(UiTheme.label("Ya da adresi elle yaz (kurucunun ekranında yazar)", 13, UiTheme.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	jbox.add_child(row)
	var addr_box := VBoxContainer.new()
	addr_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(addr_box)
	_addr_edit = _field(addr_box, "Sunucu adresi", "127.0.0.1")
	var port_box := VBoxContainer.new()
	port_box.custom_minimum_size = Vector2(96, 0)
	row.add_child(port_box)
	_port_edit = _field(port_box, "Port", str(DEFAULT_PORT))
	var join_btn := Button.new()
	join_btn.text = "Katıl"
	join_btn.custom_minimum_size = Vector2(0, 44)
	join_btn.pressed.connect(func(): _start_join(_addr_edit.text.strip_edges(), _get_port(), _name_edit.text))
	jbox.add_child(join_btn)
	_tip_lbl = UiTheme.label("Farklı evlerdeyseniz: ikiniz de Radmin VPN kurup aynı ağa girin; dünya burada kendiliğinden görünür.",
		12, UiTheme.MUTED)
	_tip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_lbl.custom_minimum_size = Vector2(370, 0)
	jbox.add_child(_tip_lbl)
	_refresh_lan()

	_menu_settings = SettingsPanel.new()
	_menu_settings.visible = false
	_menu.add_child(_menu_settings)

	if DisplayServer.get_name() != "headless":
		_menu_music = AudioStreamPlayer.new()
		_menu_music.stream = Sfx.make_loop(load("res://assets/music/surface.wav"))
		_menu_music.bus = Settings.BUS_MUSIC
		_menu_music.volume_db = -8.0
		add_child(_menu_music)
		_menu_music.play()

	_status = UiTheme.label("", 14, UiTheme.GOLD)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(_status)

	var credit := UiTheme.label("Sürüm %s  ·  Godot Engine ile yapıldı (MIT lisansı, godotengine.org/license)" %
		ProjectSettings.get_setting("application/config/version", "0"), 12, Color(1, 1, 1, 0.4))
	credit.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	credit.offset_top = -26
	credit.offset_bottom = -8
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu.add_child(credit)


func _select_color(i: int) -> void:
	_color_index = i
	for k in _color_btns.size():
		var b := _color_btns[k]
		var c := Player.SUIT_COLORS[k]
		var sel := k == i
		b.button_pressed = sel
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, UiTheme.box(c if st != "hover" else c.lightened(0.2),
				Color.WHITE if sel else Color(0, 0, 0, 0.4), 6, 3 if sel else 1, 0))


func _refresh_worlds() -> void:
	var list := SaveStore.list_worlds()
	_worlds_lbl.text = ("Kayıtlı dünyalar: " + ", ".join(list)) if list.size() > 0 \
		else "Henüz kayıtlı dünya yok. Yazdığın adla yeni bir dünya oluşur."


func _field(parent: Control, caption: String, value: String) -> LineEdit:
	parent.add_child(UiTheme.label(caption, 13, UiTheme.MUTED))
	var e := LineEdit.new()
	e.text = value
	parent.add_child(e)
	return e


func _get_port() -> int:
	var p := int(_port_edit.text)
	return p if p > 0 and p < 65536 else DEFAULT_PORT


func _set_status(text: String) -> void:
	if _status != null:
		_status.text = text
	if text != "":
		print(text)


# --------------------------------------------------------------------------
# Bağlantı
# --------------------------------------------------------------------------

func _start_host(port: int, pname: String, wname: String) -> void:
	var peer: MultiplayerPeer
	if NetTools.is_web():
		# tarayıcı sunucu olamaz: tek başına oyun
		peer = OfflineMultiplayerPeer.new()
	else:
		peer = NetTools.server_peer(port)
	if peer == null:
		_set_status("Sunucu kurulamadı (port %d kullanımda olabilir)." % port)
		return
	multiplayer.multiplayer_peer = peer
	if not NetTools.is_web():
		print("[Sunucu] %d portunda dinleniyor" % port)
	_host_port = port
	if _lan != null:
		_lan.stop()
	_enter_world(pname, SaveStore.sanitize(wname))
	_start_host_services(port, pname)


func _start_join(addr: String, port: int, pname: String) -> void:
	if addr.is_empty():
		_set_status("Sunucu adresi gir.")
		return
	var peer := NetTools.client_peer(addr, port)
	if peer == null:
		_set_status("Bağlantı başlatılamadı.")
		return
	multiplayer.multiplayer_peer = peer
	_set_status("%s:%d adresine bağlanılıyor…" % [addr, port])
	_pending_name = pname
	_joining = true
	_join_time = 0.0
	_join_target = "%s:%d" % [addr, port]


func _on_connected() -> void:
	_joining = false
	if _lan != null:
		_lan.stop()
	hello.rpc_id(1, NetTools.version())
	_enter_world(_pending_name, "")


func _on_connection_failed() -> void:
	_joining = false
	multiplayer.multiplayer_peer = null
	_set_status(_fail_text())


func _fail_text() -> String:
	return ("%s adresine bağlanılamadı. Kontrol et:\n" % _join_target) + \
		"1) Kurucu \"Dünya Kur ve Oyna\" dedi mi, oyunu açık mı?\n" + \
		"2) Adres, kurucunun ekranında (Esc menüsü) yazan adres mi?\n" + \
		"3) Kurucunun bilgisayarında Windows Güvenlik Duvarı \"Derin Deniz\"e izin verdi mi?\n" + \
		"4) Farklı evlerdeyseniz ikiniz de Radmin VPN'e girin ve onun adresini kullanın."


func _start_host_services(port: int, pname: String) -> void:
	if NetTools.is_web():
		return
	_responder = LanDiscovery.new()
	add_child(_responder)
	_responder.start_server(func():
		return {"world": _world.world_name if _world != null else "", "host": pname, "port": port,
			"players": _world.player_count() if _world != null else 0})
	if _world != null:
		_world.host_info = {"ips": NetTools.local_ipv4s(), "port": port,
			"upnp": "Modemde port açılmaya çalışılıyor…", "ext": "",
			"web": WebHost.available()}
	if WebHost.available():
		_web_host = WebHost.new()
		add_child(_web_host)
		_web_host.start(NetTools.WEB_PORT)
	if not OS.has_feature("editor_hint"):
		_upnp = UpnpHelper.new()
		_upnp.port = port
		add_child(_upnp)
		_upnp.finished.connect(func(ok: bool, ext: String, msg: String):
			if _world != null:
				_world.host_info["upnp"] = msg
				_world.host_info["ext"] = ext if ok else ""
			print("[Sunucu] UPnP: ", msg, " ", ext))
		_upnp.start()


func _stop_host_services() -> void:
	if _web_host != null:
		_web_host.queue_free()
		_web_host = null
	if _responder != null:
		_responder.queue_free()
		_responder = null
	if _upnp != null:
		_upnp.queue_free()
		_upnp = null


## İstemci bağlanınca sürümünü bildirir; uyuşmazsa sunucu nedenini söyleyip bağlantıyı keser.
@rpc("any_peer", "call_remote", "reliable")
func hello(ver: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if ver != NetTools.version():
		reject.rpc_id(peer, "Sürüm uyuşmuyor: kurucuda %s, sende %s. İkiniz de aynı sürümü indirin." %
			[NetTools.version(), ver])
		await get_tree().create_timer(0.5).timeout
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(peer)


@rpc("authority", "call_remote", "reliable")
func reject(msg: String) -> void:
	_leave(msg)


## Tarayıcıda: otomatik bulma yok. Sayfa bir kurucudan açıldıysa onun adresi hazır gelir.
func _setup_web_menu() -> void:
	_quit_btn.visible = false
	_tip_lbl.visible = false
	_port_edit.text = str(NetTools.GAME_PORT)
	var host := NetTools.web_lan_host()
	for c in _lan_list.get_children():
		c.queue_free()
	if host != "":
		_addr_edit.text = host
		var b := Button.new()
		b.text = "Kurucunun dünyasına katıl (%s)" % host
		b.custom_minimum_size = Vector2(0, 48)
		b.pressed.connect(func(): _start_join(host, NetTools.GAME_PORT, _name_edit.text))
		_lan_list.add_child(b)
		_set_status("Adını yaz, sonra \"Kurucunun dünyasına katıl\"a bas.")
	else:
		var l := UiTheme.label("Tarayıcı sürümü: \"Dünya Kur ve Oyna\" ile tek başına oynarsın (internetsiz de çalışır).\n" +
			"Arkadaşınla oynamak için: aynı Wi-Fi'de, kurucunun Esc menüsünde yazan http:// adresini Safari'de aç.",
			13, Color(1, 1, 1, 0.6))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(370, 0)
		_lan_list.add_child(l)


func _refresh_lan() -> void:
	if _lan_list == null or NetTools.is_web():
		return
	for c in _lan_list.get_children():
		c.queue_free()
	var found: Dictionary = _lan.found if _lan != null else {}
	if found.is_empty():
		var l := UiTheme.label("Aranıyor…  (arkadaşın \"Dünya Kur\" dediğinde burada görünür)", 13, Color(1, 1, 1, 0.45))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(370, 0)
		_lan_list.add_child(l)
		return
	for key in found.keys():
		var d: Dictionary = found[key]
		var b := Button.new()
		var same: bool = str(d.get("version", "")) == NetTools.version()
		b.text = "%s  ·  %s  ·  %d oyuncu%s" % [d.get("world", "?"), d.get("host", "?"), int(d.get("players", 0)),
			"" if same else "  (sürüm %s!)" % d.get("version", "?")]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		var ip: String = d["ip"]
		var port: int = d["port"]
		b.pressed.connect(func(): _start_join(ip, port, _name_edit.text))
		_lan_list.add_child(b)


func _on_server_disconnected() -> void:
	_leave("Sunucu ile bağlantı koptu.")


func _enter_world(pname: String, wname: String) -> void:
	if _menu_layer != null:
		_menu_layer.visible = false
	_set_status("")
	if _menu_music != null:
		_menu_music.stop()
	_world = World.new()
	_world.leave_requested.connect(func(): _leave(""))
	_world.dedicated = _dedicated
	_world.player_name = pname
	_world.player_color = Player.SUIT_COLORS[_color_index]
	if wname != "":
		_world.world_name = wname
	add_child(_world)


func _leave(message: String) -> void:
	_joining = false
	_stop_host_services()
	if _world != null:
		_world.queue_free()
		_world = null
	multiplayer.multiplayer_peer = null
	if _lan != null and not _dedicated:
		_lan.start_browser()
		_refresh_lan()
	RenderingServer.set_default_clear_color(Color("06223d"))
	if _menu_layer != null:
		_menu_layer.visible = true
		_refresh_worlds()
	if _menu_music != null:
		_menu_music.play()
	_set_status(message)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		if _world == null and _menu_settings != null and _menu_settings.visible:
			_menu_settings.visible = false


func _notification(what: int) -> void:
	# Android geri tuşu: oyundaysa menüyü aç, ana menüdeyse çık
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _world != null and _world.hud != null:
			_world.hud.back()
		elif _menu_settings != null and _menu_settings.visible:
			_menu_settings.visible = false
		else:
			get_tree().quit()


# --------------------------------------------------------------------------
# Geliştirici: ekran görüntüsü
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _menu_layer != null and _menu != null:
		var sc := Settings.ui_scale
		_menu_layer.scale = Vector2(sc, sc)
		var want := get_viewport().get_visible_rect().size / sc
		if _menu.size != want:
			_menu.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_menu.position = Vector2.ZERO
			_menu.size = want
	if _joining:
		_join_time += delta
		if _join_time > 8.0:
			_joining = false
			multiplayer.multiplayer_peer = null
			_set_status(_fail_text())
	if _shot_path.is_empty():
		return
	_shot_time += delta
	if not _shot_prepared and _world != null and _world.local_player() != null and _shot_time > 0.5:
		_shot_prepared = true
		var p := _world.local_player()
		if _shot_x >= 0:
			p.position = _world.cell_center(Vector2i(_shot_x, _shot_depth))
			p.net_pos = p.position
			p._camera.reset_smoothing()
		elif _shot_depth > 0:
			p.position = _find_open_spot(_shot_depth)
			p.net_pos = p.position
			p._camera.reset_smoothing()
		if _shot_ui == "craft":
			_world._inventories[1] = Inventory.create({Blocks.SAND: 27, Blocks.ROCK: 15, Blocks.CORAL: 6,
				Blocks.KELP: 14, Blocks.GLASS: 8, Blocks.PEARL: 9, Blocks.LAMP: 2, Blocks.OXYGEN: 1,
				Blocks.PLANK: 3, 201: 2, 204: 1})
			var inv: Dictionary = _world._inventories[1]
			Inventory.autofill(inv, 3)        # ağ deseni ızgarada
			inv.cursor = [Blocks.KELP, 6]
			_world._send_inventory(1)
			_world.hud.toggle_craft()
			_world.hud._inv.set_hover("Ağ")
		elif _shot_ui == "codex":
			_world.codex = {200: 7, 201: 4, 202: 3, 204: 2, 205: 1, 206: 5, 209: 1, 212: 1, 224: 3, 229: 1, 239: 1, 242: 1}
			_world.inventory = Inventory.create({204: 1, 206: 2, 209: 1})
			_world.hud._codex.visible = true
			_world.hud._refresh_codex()
		elif _shot_ui == "aquarium":
			var base := _world.cell_at(p.position) + Vector2i(-4, 1)
			var sps := [201, 204, 206, 209, 210, 211, 207, 205]
			for i in sps.size():
				var c := base + Vector2i(i, 0)
				_world._server_set_cell(c, Blocks.AQUARIUM)
				_world._server_set_cell(c + Vector2i(0, 1), Blocks.BRICK)
				_world.apply_aquarium(c, sps[i])
			_world._server_set_cell(base + Vector2i(-1, 0), Blocks.LAMP)
			_world._server_set_cell(base + Vector2i(sps.size(), 0), Blocks.LAMP)
		elif _shot_ui == "catch":
			Inventory.give(_world._inventories[1], Blocks.NET, 1)
			_world._send_inventory(1)
			for k in [[209, Vector2(40, -10)], [212, Vector2(-60, 20)], [208, Vector2(70, -40)],
					[210, Vector2(-30, -45)], [211, Vector2(110, 10)]]:
				_world.wildlife.spawn(k[0], p.position + k[1])
			for sp in [209, 208]:
				_world._bags[1].append(sp)
			_world._send_player_data(1)
		elif _shot_ui == "zoo":
			var pc := _world.cell_at(p.position)
			for dx in range(-22, 23):
				for dy in range(-9, 9):
					_world._server_set_cell(pc + Vector2i(dx, dy), Blocks.AIR)
			for dx in range(-22, 23):
				_world._server_set_cell(pc + Vector2i(dx, 9), Blocks.SAND)
			var zoo := [[220, Vector2(-120, -90)], [216, Vector2(-150, 40)], [218, Vector2(90, 110)],
				[219, Vector2(-40, 135)], [217, Vector2(26, -6)], [214, Vector2(-70, -20)], [213, Vector2(120, -60)],
				[221, Vector2(40, -110)], [222, Vector2(170, 20)], [215, Vector2(-170, 110)], [201, Vector2(-30, 60)],
				[204, Vector2(70, 40)], [205, Vector2(-120, 90)], [200, Vector2(140, 90)]]
			for z in zoo:
				_world.wildlife.spawn(z[0], p.position + z[1])
		elif _shot_ui == "zoo2":
			var pc3 := _world.cell_at(p.position)
			for dx in range(-26, 27):
				for dy in range(-10, 10):
					_world._server_set_cell(pc3 + Vector2i(dx, dy), Blocks.AIR)
			for dx in range(-26, 27):
				_world._server_set_cell(pc3 + Vector2i(dx, 10), Blocks.SAND)
			var zoo2 := [[224, Vector2(-330, -120)], [225, Vector2(-200, -125)], [226, Vector2(-90, -120)],
				[227, Vector2(40, -125)], [228, Vector2(160, -110)], [229, Vector2(300, -110)],
				[230, Vector2(-310, -40)], [231, Vector2(-160, -45)], [234, Vector2(-30, -50)],
				[235, Vector2(150, -40)], [236, Vector2(310, -45)], [237, Vector2(-250, 40)],
				[238, Vector2(-70, 35)], [239, Vector2(50, 40)], [240, Vector2(210, 40)],
				[241, Vector2(340, 40)], [242, Vector2(-330, 100)], [243, Vector2(-180, 100)],
				[244, Vector2(10, 100)], [232, Vector2(160, 150)], [233, Vector2(280, 150)]]
			for z in zoo2:
				_world.wildlife.spawn(z[0], p.position + z[1])
		elif _shot_ui == "deep":
			var pc2 := _world.cell_at(p.position)
			for dx in range(-22, 23):
				for dy in range(-9, 9):
					_world._server_set_cell(pc2 + Vector2i(dx, dy), Blocks.AIR)
			for z in [[223, Vector2(-110, -40)], [209, Vector2(60, -40)], [211, Vector2(110, 50)],
					[210, Vector2(-40, 70)], [208, Vector2(150, -70)], [212, Vector2(-170, 60)], [207, Vector2(30, 90)]]:
				_world.wildlife.spawn(z[0], p.position + z[1])
		elif _shot_ui == "touch":
			Settings.touch_mode = 1
			_world.hud._update_touch()
			_world.hud.touch.mode = "place"
			_world.hud.touch._joy_vec = Vector2(0.6, -0.3)
		elif _shot_ui == "pause":
			_world.hud._pause.visible = true
		elif _shot_ui == "settings":
			_world.hud._settings.visible = true
		elif _shot_ui == "boat" or _shot_ui == "boatview" or _shot_ui == "market":
			var inv: Dictionary = _world._inventories[1]
			inv["gold"] = 1240
			inv.boat.hull = 2 if _shot_ui == "boatview" else 1
			inv.boat.paint = 4
			inv.boat.store = {201: 3, 213: 5, 221: 1}
			Inventory.give(inv, 204, 2)
			Inventory.give(inv, 209, 1)
			Inventory.give(inv, 214, 4)
			_world.economy.listings = [
				{"id": 1, "seller": "Ali", "item": 223, "n": 1, "price": 900},
				{"id": 2, "seller": "Zeynep", "item": Blocks.LAMP, "n": 5, "price": 12},
				{"id": 3, "seller": p.display_name, "item": Blocks.PEARL, "n": 20, "price": 4}]
			_world.economy._broadcast_market()
			_world._send_inventory(1)
			_world.economy.broadcast_boats()
			if _shot_ui != "boatview":
				_world.hud.toggle_boat()
				if _shot_ui == "market":
					_world.hud._boat_win._tabs.current_tab = 3
		elif _shot_ui == "map":
			# örnek keşif: yüzey boyunca ve aşağı inen bir dalış yolu
			for x in range(40, WorldGen.W - 40, 6):
				_world.map.reveal(Vector2i(x, 8), 22)
			for y in range(8, 250, 6):
				_world.map.reveal(Vector2i(WorldGen.W / 2 + int(sin(y * 0.05) * 40.0), y), 20)
			for y in range(60, 160, 6):
				_world.map.reveal(Vector2i(120 + int(cos(y * 0.07) * 20.0), y), 16)
			_world.hud.toggle_map()
		elif _shot_ui == "trade":
			_world._inventories[1] = Inventory.create({Blocks.SAND: 40, Blocks.GLASS: 12, Blocks.PEARL: 14,
				Blocks.LAMP: 3, Blocks.KELP: 20, 213: 1, 217: 1, Blocks.NET: 1})
			_world._send_inventory(1)
			var st := {"id": 1, "other": 2, "other_name": "Ali",
				"mine": [[Blocks.PEARL, 6], [217, 1]], "theirs": [[Blocks.LAMP, 4], [Blocks.CORAL, 12], [221, 1]],
				"my_ok": false, "their_ok": true}
			_world.trade.state = st
			_world.hud.show_trade(st)
		elif _shot_ui == "chat":
			_world.hud.add_chat("", "Deniz kızı dalışa katıldı", Color(0.6, 0.9, 1.0))
			_world.hud.add_chat("Ali", "Batık gemiyi buldum, doğuda!", Color("ffb42e"))
			_world.hud.add_chat(p.display_name, "Geliyorum, fener getiriyorum", p.suit_color)
			p.say("Geliyorum, fener getiriyorum")
			_world.toast("Hazine bulundu!  +5 İnci, +2 Deniz Feneri")
	if _shot_time >= _shot_delay:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_shot_path)
		print("Ekran görüntüsü kaydedildi: ", _shot_path)
		get_tree().quit()


func _find_open_spot(row: int) -> Vector2:
	var cx := WorldGen.W / 2
	for r in range(row, WorldGen.H - 3):
		for dx in range(0, WorldGen.W / 2 - 2):
			for s in [1, -1]:
				var c := Vector2i(cx + dx * s, r)
				if _world.get_cell_id(c) == Blocks.AIR and _world.get_cell_id(c + Vector2i(0, -1)) == Blocks.AIR \
						and Blocks.is_solid(_world.get_cell_id(c + Vector2i(0, 1))):
					return _world.cell_center(c)
	return Vector2(cx * 16.0, row * 16.0)
