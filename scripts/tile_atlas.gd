class_name TileAtlas
extends RefCounted
## assets/ içindeki PNG'leri yükler, TileSet ve simgeleri hazırlar.
## Görselleri değiştirmek için PNG'leri düzenlemen yeterli (boyutları koru).

const TILE := 16
const TILES_PATH := "res://assets/tiles.png"
const ICONS_PATH := "res://assets/icons.png"
const COLS := 5
const TOP_COL := 4

static var _tex: Texture2D
static var _icons: Texture2D
static var _icon_cache := {}


static func get_texture() -> Texture2D:
	if _tex == null:
		_tex = load(TILES_PATH)
	return _tex


static func build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = get_texture()
	src.texture_region_size = Vector2i(TILE, TILE)
	ts.add_source(src, 0)

	var half := TILE / 2.0
	var poly := PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half),
		Vector2(half, half), Vector2(-half, half)])
	for id in range(1, Blocks.COUNT):
		var tiles: Array[Vector2i] = []
		if Blocks.is_anim(id):
			var c := Vector2i(0, id)
			src.create_tile(c)
			src.set_tile_animation_frames_count(c, 4)
			src.set_tile_animation_columns(c, 4)
			src.set_tile_animation_mode(c, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES)
			var speed := 0.35 if id == Blocks.KELP else 0.18
			for f in 4:
				src.set_tile_animation_frame_duration(c, f, speed)
			tiles.append(c)
		else:
			var w: Array = Blocks.DEFS[id].get("weights", [1])
			for v in w.size():
				if int(w[v]) > 0:
					tiles.append(Vector2i(v, id))
			if Blocks.has_top(id):
				tiles.append(Vector2i(TOP_COL, id))
			for c2 in tiles:
				src.create_tile(c2)
		if Blocks.is_solid(id):
			for c3 in tiles:
				var td: TileData = src.get_tile_data(c3, 0)
				td.add_collision_polygon(0)
				td.set_collision_polygon_points(0, 0, poly)
	return ts


## Bir blok ya da eşya için HUD simgesi (AtlasTexture, önbellekli).
static func icon(id: int) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	if Species.is_species(id):
		return Species.icon(id)
	var at := AtlasTexture.new()
	if Blocks.is_block(id):
		at.atlas = get_texture()
		at.region = Rect2(0, id * TILE, TILE, TILE)
	else:
		if _icons == null:
			_icons = load(ICONS_PATH)
		at.atlas = _icons
		at.region = Rect2((id - Blocks.PEARL) * TILE, 0, TILE, TILE)
	_icon_cache[id] = at
	return at


static func load_tex(path: String) -> Texture2D:
	return load(path)
