class_name WorldMap
extends Node
## İstemci tarafı harita: hücre başına 1 piksellik dünya resmi ve keşif sisi.
## Keşfedilen alanlar user://maps/<dünya>_<oyuncu>.bin dosyasına kaydedilir.

const CHUNK := 4                     # sis çözünürlüğü (hücre)
const REVEAL := 18                   # oyuncu çevresinde açılan yarıçap (hücre)

var world: Node                      # World
var map_image: Image
var map_tex: ImageTexture
var fog_image: Image
var fog_tex: ImageTexture
var _explored := PackedByteArray()
var _fw := 0
var _fh := 0
var _timer := 0.0
var _save_timer := 10.0
var _dirty_fog := false
var _dirty_map := false


func _ready() -> void:
	name = "WorldMap"
	_fw = int(ceil(float(WorldGen.W) / CHUNK))
	_fh = int(ceil(float(WorldGen.H) / CHUNK))
	_explored.resize(_fw * _fh)
	_explored.fill(0)


func _path() -> String:
	return "user://maps/%s_%s.bin" % [SaveStore.sanitize(world.world_name), SaveStore.sanitize(world.player_name)]


## Dünya yüklenince çağrılır: resmi baştan kurar, keşif kaydını okur.
func build() -> void:
	map_image = Image.create(WorldGen.W, WorldGen.H, false, Image.FORMAT_RGB8)
	var palette := {}
	for id in range(1, Blocks.COUNT):
		palette[id] = Blocks.color_of(id)
	for y in WorldGen.H:
		var water := WorldGen.layer_color(y).darkened(0.45)
		for x in WorldGen.W:
			map_image.set_pixel(x, y, _cell_color(x, y, palette, water))
	map_tex = ImageTexture.create_from_image(map_image)
	_load_explored()
	fog_image = Image.create(_fw, _fh, false, Image.FORMAT_LA8)
	for y in _fh:
		for x in _fw:
			fog_image.set_pixel(x, y, Color(0, 0, 0, 0.0 if _explored[y * _fw + x] else 1.0))
	fog_tex = ImageTexture.create_from_image(fog_image)


func _cell_color(x: int, y: int, palette: Dictionary, water: Color) -> Color:
	var i := y * WorldGen.W + x
	var id: int = world.cells[i]
	if id != Blocks.AIR:
		return palette.get(id, Color.WHITE)
	var w: int = world.walls[i]
	if w != Blocks.AIR:
		return (palette.get(w, Color.GRAY) as Color).darkened(0.65)
	if y < 1:
		return Color("8fd3ff")
	return water


func on_cell(c: Vector2i, id: int) -> void:
	if map_image == null:
		return
	var water := WorldGen.layer_color(c.y).darkened(0.45)
	var palette := {id: Blocks.color_of(id)}
	if id == Blocks.AIR:
		var w: int = world.walls[c.y * WorldGen.W + c.x]
		if w != Blocks.AIR:
			palette[w] = Blocks.color_of(w)
	map_image.set_pixel(c.x, c.y, _cell_color(c.x, c.y, palette, water))
	_dirty_map = true


func explored_at(c: Vector2i) -> bool:
	var fx := c.x / CHUNK
	var fy := c.y / CHUNK
	if fx < 0 or fy < 0 or fx >= _fw or fy >= _fh:
		return false
	return _explored[fy * _fw + fx] != 0


func explored_ratio() -> float:
	return float(_explored.count(1)) / float(_explored.size())


func reveal(center: Vector2i, radius: int) -> void:
	var r := int(ceil(float(radius) / CHUNK))
	var cx := center.x / CHUNK
	var cy := center.y / CHUNK
	for fy in range(maxi(0, cy - r), mini(_fh, cy + r + 1)):
		for fx in range(maxi(0, cx - r), mini(_fw, cx + r + 1)):
			if (fx - cx) * (fx - cx) + (fy - cy) * (fy - cy) > r * r:
				continue
			var i := fy * _fw + fx
			if _explored[i] == 0:
				_explored[i] = 1
				if fog_image != null:
					fog_image.set_pixel(fx, fy, Color(0, 0, 0, 0))
				_dirty_fog = true


func _process(delta: float) -> void:
	if map_image == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.3
		var p: Node2D = world.local_player()
		if p != null:
			reveal(Vector2i(int(p.position.x / 16.0), int(p.position.y / 16.0)), REVEAL)
		if _dirty_fog:
			_dirty_fog = false
			fog_tex.update(fog_image)
		if _dirty_map:
			_dirty_map = false
			map_tex.update(map_image)
	_save_timer -= delta
	if _save_timer <= 0.0:
		_save_timer = 10.0
		save()


func save() -> void:
	if world.world_name == "":
		return
	DirAccess.make_dir_recursive_absolute("user://maps")
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_buffer(_explored)
		f.close()


func _load_explored() -> void:
	var path := _path()
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() == _explored.size():
		_explored = data


func _exit_tree() -> void:
	if map_image != null:
		save()
