class_name LanDiscovery
extends Node
## Yerel ağda dünya bulma.
## Sunucu: DISCOVERY_PORT'u dinler, sorgulara dünya bilgisiyle cevap verir.
## Tarayıcı: yayın adreslerine sorgu atar, gelen cevapları listeler.

signal servers_changed

var server_info: Callable          # sunucu modunda: bilgi sözlüğü döndüren fonksiyon
var _udp := PacketPeerUDP.new()
var _is_server := false
var _active := false
var _query_timer := 0.0
var found := {}                    # "ip:port" -> {ip, port, name, world, players, version, seen}


## Sunucu olarak dinle. Başarılıysa true.
func start_server(info: Callable) -> bool:
	stop()
	server_info = info
	_is_server = true
	var err := _udp.bind(NetTools.DISCOVERY_PORT, "*")
	if err != OK:
		push_warning("Keşif portu açılamadı (%d): başka bir oyun açık olabilir" % NetTools.DISCOVERY_PORT)
		return false
	_active = true
	return true


## Ağda dünya ara (menüde)
func start_browser() -> void:
	stop()
	_is_server = false
	_udp.set_broadcast_enabled(true)
	if _udp.bind(0, "*") != OK:
		return
	_active = true
	_query_timer = 0.0


func stop() -> void:
	if _active:
		_udp.close()
	_udp = PacketPeerUDP.new()
	_active = false
	found.clear()


func _process(delta: float) -> void:
	if not _active:
		return
	if _is_server:
		_serve()
	else:
		_browse(delta)


func _serve() -> void:
	while _udp.get_available_packet_count() > 0:
		var msg := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		var port := _udp.get_packet_port()
		if msg != NetTools.MAGIC_QUERY or ip == "":
			continue
		var info: Dictionary = server_info.call()
		info["version"] = NetTools.version()
		var reply := (NetTools.MAGIC_REPLY + JSON.stringify(info)).to_utf8_buffer()
		_udp.set_dest_address(ip, port)
		_udp.put_packet(reply)


func _browse(delta: float) -> void:
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = 1.0
		var q := NetTools.MAGIC_QUERY.to_utf8_buffer()
		for addr in NetTools.broadcast_addresses():
			_udp.set_dest_address(addr, NetTools.DISCOVERY_PORT)
			_udp.put_packet(q)
		# 4 sn'dir cevap vermeyenleri listeden çıkar
		var now := Time.get_ticks_msec()
		var changed := false
		for k in found.keys():
			if now - int(found[k].seen) > 4000:
				found.erase(k)
				changed = true
		if changed:
			servers_changed.emit()
	while _udp.get_available_packet_count() > 0:
		var msg := _udp.get_packet().get_string_from_utf8()
		var ip := _udp.get_packet_ip()
		if not msg.begins_with(NetTools.MAGIC_REPLY):
			continue
		var data = JSON.parse_string(msg.substr(NetTools.MAGIC_REPLY.length()))
		if typeof(data) != TYPE_DICTIONARY:
			continue
		var port := int(data.get("port", NetTools.GAME_PORT))
		var key := "%s:%d" % [ip, port]
		var isnew := not found.has(key)
		data["ip"] = ip
		data["port"] = port
		data["seen"] = Time.get_ticks_msec()
		found[key] = data
		if isnew:
			servers_changed.emit()
