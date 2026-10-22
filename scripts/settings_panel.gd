class_name SettingsPanel
extends PanelContainer
## Sekmeli ayarlar penceresi: Görüntü, Ses, Oyun. Ana menüde ve oyun içi menüde kullanılır.

signal closed
signal touch_changed

var _quality_opt: OptionButton
var _detail: Array[Control] = []      # kalite ön ayarı değişince yenilenen ayrıntı denetimleri
var _refreshing := false


func _ready() -> void:
	Settings.ensure_loaded()
	set_anchors_preset(Control.PRESET_CENTER, true)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(560, 0)
	_build()


func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UiTheme.label("Ayarlar", 22, UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reset := Button.new()
	reset.text = "Varsayılan"
	reset.pressed.connect(_reset_defaults)
	head.add_child(reset)
	var close := Button.new()
	close.text = "Kapat"
	close.pressed.connect(_close)
	head.add_child(close)

	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(540, 420)
	v.add_child(tabs)
	tabs.add_child(_graphics_tab())
	tabs.add_child(_sound_tab())
	tabs.add_child(_game_tab())


# --------------------------------------------------------------------------
# Sekmeler
# --------------------------------------------------------------------------

func _page(name_: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = name_
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	scroll.add_child(v)
	return v


func _graphics_tab() -> Control:
	var v := _page("Görüntü")
	_quality_opt = _options(v, "Kalite ön ayarı", Settings.QUALITY_NAMES, Settings.quality, func(i):
		if i < 4:
			Settings.set_quality(i)
		_changed()
		_refresh_detail())
	var fps_names: Array = []
	for f in Settings.FPS_OPTIONS:
		fps_names.append("Sınırsız" if f == 0 else "%d FPS" % f)
	_options(v, "Kare hızı sınırı", fps_names, maxi(0, Settings.FPS_OPTIONS.find(Settings.fps_limit)), func(i):
		Settings.fps_limit = Settings.FPS_OPTIONS[i]
		_changed())
	_check(v, "Dikey eşitleme (VSync)", Settings.vsync, func(on):
		Settings.vsync = on
		_changed())
	if not Settings.is_mobile():
		_options(v, "Pencere", Settings.WINDOW_NAMES, Settings.window_mode, func(i):
			Settings.window_mode = i
			_changed())
	_check(v, "FPS göstergesi", Settings.show_fps, func(on):
		Settings.show_fps = on
		_changed())
	v.add_child(HSeparator.new())
	v.add_child(UiTheme.label("Ayrıntı (değiştirince ön ayar \"Özel\" olur)", 13, UiTheme.MUTED))
	_detail.append(_slider(v, "Işık sayısı", Settings.lights, 4, 64, 4, "%d", func(x):
		Settings.lights = int(x)
		_custom()))
	_detail.append(_options(v, "Parçacıklar", Settings.PARTICLE_NAMES, Settings.particles, func(i):
		Settings.particles = i
		_custom()))
	_detail.append(_check(v, "Işık huzmeleri", Settings.rays, func(on):
		Settings.rays = on
		_custom()))
	_detail.append(_check(v, "Deniz karı", Settings.snow, func(on):
		Settings.snow = on
		_custom()))
	_detail.append(_check(v, "Kenar karartma (vinyet)", Settings.vignette, func(on):
		Settings.vignette = on
		_custom()))
	_detail.append(_slider(v, "Canlı yoğunluğu", Settings.fauna, 0.2, 2.0, 0.1, "%.1fx", func(x):
		Settings.fauna = x
		_custom()))
	v.add_child(HSeparator.new())
	_slider(v, "Kamera yakınlığı (oyunda: tekerlek / iki parmak)", Settings.zoom, Settings.ZOOM_MIN, Settings.ZOOM_MAX, 0.1, "%.1fx", func(x):
		Settings.zoom = x
		_changed())
	_slider(v, "Arayüz boyutu", Settings.ui_scale, 0.7, 1.6, 0.05, "%d%%", func(x):
		Settings.ui_scale = x
		_changed(), 100.0)
	return v.get_parent()


func _sound_tab() -> Control:
	var v := _page("Ses")
	_slider(v, "Ana ses", Settings.master, 0, 1, 0.05, "%d%%", func(x):
		Settings.master = x
		_changed(), 100.0)
	_slider(v, "Efektler", Settings.sfx, 0, 1, 0.05, "%d%%", func(x):
		Settings.sfx = x
		_changed(), 100.0)
	_slider(v, "Müzik", Settings.music, 0, 1, 0.05, "%d%%", func(x):
		Settings.music = x
		_changed(), 100.0)
	_slider(v, "Su altı ortam sesi", Settings.ambience, 0, 1, 0.05, "%d%%", func(x):
		Settings.ambience = x
		_changed(), 100.0)
	return v.get_parent()


func _game_tab() -> Control:
	var v := _page("Oyun")
	_options(v, "Dokunmatik kontroller", ["Otomatik", "Açık", "Kapalı"], Settings.touch_mode, func(i):
		Settings.touch_mode = i
		_changed()
		touch_changed.emit())
	_check(v, "Oyuncu adlarını göster", Settings.show_names, func(on):
		Settings.show_names = on
		_changed())
	_check(v, "Sohbet balonlarını göster", Settings.show_bubbles, func(on):
		Settings.show_bubbles = on
		_changed())
	_check(v, "Mini harita", Settings.minimap, func(on):
		Settings.minimap = on
		_changed())
	_check(v, "Titreşim (telefonda saldırıya uğrayınca)", Settings.vibration, func(on):
		Settings.vibration = on
		_changed())
	var keys := UiTheme.label("Tuşlar: WASD yüz · Sol tık kır/yakala · Sağ tık koy · 1-9 hotbar · E envanter · " +
		"K ansiklopedi · M harita · T oyuncular ve takas · Enter sohbet · Esc menü", 12, UiTheme.MUTED)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	keys.custom_minimum_size = Vector2(500, 0)
	v.add_child(keys)
	return v.get_parent()


# --------------------------------------------------------------------------
# Denetim yapıcıları
# --------------------------------------------------------------------------

func _row(parent: Control, caption: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var l := UiTheme.label(caption, 15)
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	return row


func _options(parent: Control, caption: String, names: Array, selected: int, cb: Callable) -> OptionButton:
	var row := _row(parent, caption)
	var o := OptionButton.new()
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in names.size():
		o.add_item(str(names[i]), i)
	o.selected = selected
	o.item_selected.connect(func(i):
		if not _refreshing:
			cb.call(i))
	row.add_child(o)
	return o


func _check(parent: Control, caption: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = caption
	c.button_pressed = value
	c.toggled.connect(func(on):
		if not _refreshing:
			cb.call(on))
	parent.add_child(c)
	return c


func _slider(parent: Control, caption: String, value: float, lo: float, hi: float, step: float, fmt: String,
		cb: Callable, mul := 1.0) -> HSlider:
	var row := _row(parent, caption)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(180, 28)
	var lbl := UiTheme.label(fmt % (value * mul), 14, UiTheme.MUTED)
	lbl.custom_minimum_size = Vector2(56, 0)
	s.value_changed.connect(func(x):
		lbl.text = fmt % (x * mul)
		if not _refreshing:
			cb.call(x))
	row.add_child(s)
	row.add_child(lbl)
	return s


func _changed() -> void:
	Settings.changed()


func _custom() -> void:
	Settings.quality = 4
	_refreshing = true
	_quality_opt.selected = 4
	_refreshing = false
	_changed()


func _refresh_detail() -> void:
	_refreshing = true
	(_detail[0] as HSlider).value = Settings.lights
	(_detail[1] as OptionButton).selected = Settings.particles
	(_detail[2] as CheckButton).button_pressed = Settings.rays
	(_detail[3] as CheckButton).button_pressed = Settings.snow
	(_detail[4] as CheckButton).button_pressed = Settings.vignette
	(_detail[5] as HSlider).value = Settings.fauna
	_refreshing = false


func _reset_defaults() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.PATH))
	Settings.master = 1.0
	Settings.sfx = 0.8
	Settings.music = 0.55
	Settings.ambience = 0.7
	Settings.fps_limit = 60
	Settings.vsync = true
	Settings.window_mode = 0
	Settings.zoom = 2.8 if Settings.is_mobile() else 2.5
	Settings.ui_scale = 1.15 if Settings.is_mobile() else 1.0
	Settings.show_fps = false
	Settings.touch_mode = 0
	Settings.show_names = true
	Settings.show_bubbles = true
	Settings.vibration = true
	Settings.set_quality(1 if Settings.is_mobile() else 2)
	_changed()
	# denetimleri yeni değerlerle yeniden kur
	for c in get_children():
		c.free()
	_detail.clear()
	_build()
	touch_changed.emit()


func _close() -> void:
	visible = false
	closed.emit()
