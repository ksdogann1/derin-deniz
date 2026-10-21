class_name SaveStore
extends RefCounted
## Dünya kayıtları: user://worlds/<ad>.dds
## Windows'ta konum: %APPDATA%/Godot/app_userdata/Derin Deniz/worlds

const DIR := "user://worlds"
const EXT := ".dds"
const VERSION := 2

## Son yüklemede eski dünya yedeklendiyse dosya yolu (bildirim için)
static var last_backup := ""


static func sanitize(world_name: String) -> String:
	var out := ""
	for ch in world_name.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "-" or ch == "_":
			out += ch
		elif ch == " ":
			out += "_"
		else:
			var tr := {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u"}
			if tr.has(ch):
				out += tr[ch]
	if out.is_empty():
		out = "okyanus"
	return out.substr(0, 32)


static func path_for(world_name: String) -> String:
	return DIR + "/" + sanitize(world_name) + EXT


static func exists(world_name: String) -> bool:
	return FileAccess.file_exists(path_for(world_name))


## Kayıt yoksa ya da bozuksa boş sözlük döner.
static func load_world(world_name: String) -> Dictionary:
	var path := path_for(world_name)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data: Variant = f.get_var()
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Kayıt okunamadı: " + path)
		return {}
	var d: Dictionary = data
	var expected := WorldGen.W * WorldGen.H
	if int(d.get("version", 0)) != VERSION \
			or (d.get("cells", PackedByteArray()) as PackedByteArray).size() != expected \
			or (d.get("walls", PackedByteArray()) as PackedByteArray).size() != expected:
		# eski (küçük) dünyayı silmeden yedekle; yerine yeni dünya üretilecek
		var backup := path + ".eski"
		DirAccess.rename_absolute(path, backup)
		last_backup = backup
		push_warning("Kayıt sürümü uyumsuz, yedeklendi: " + backup)
		# oyuncuların envanteri, koleksiyonu ve görevleri yeni dünyaya taşınır
		return {"migrate_players": d.get("players", {})}
	return d


static func save_world(world_name: String, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := path_for(world_name)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Kayıt yazılamadı: " + path)
		return false
	data["version"] = VERSION
	f.store_var(data)
	f.close()
	# önce geçici dosyaya yaz, sonra değiştir (yarım kalan kayıt bozmasın)
	var dir := DirAccess.open(DIR)
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


static func list_worlds() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(EXT):
			out.append(f.trim_suffix(EXT))
	return out
