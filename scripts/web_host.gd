class_name WebHost
extends Node
## Kurucunun bilgisayarı/telefonu, oyunun tarayıcı sürümünü aynı ağa sunar.
## iPhone'daki arkadaş Safari'de http://<kurucu-ip>:8080 adresini açar, sayfa
## kendiliğinden bu kurucunun dünyasına bağlanır.
## Dosyalar res://webapp/ içinde gzip'li durur (*.gz); olduğu gibi gönderilir.

const DIR := "res://webapp/"
const CHUNK := 65536

const TYPES := {
	"html": "text/html; charset=utf-8",
	"js": "application/javascript",
	"wasm": "application/wasm",
	"pck": "application/octet-stream",
	"png": "image/png",
	"json": "application/json",
	"webmanifest": "application/manifest+json",
}

var _server := TCPServer.new()
var _conns: Array[Dictionary] = []      # {tcp, buf, out, sent}
var port := 0


static func available() -> bool:
	return not OS.has_feature("web") and FileAccess.file_exists(DIR + "index.html.gz")


func start(p: int) -> bool:
	port = p
	var err := _server.listen(p, "*")
	if err != OK:
		print("[Web] %d portu açılamadı (%s)" % [p, error_string(err)])
		return false
	print("[Web] Tarayıcı sürümü %d portundan sunuluyor" % p)
	return true


func _exit_tree() -> void:
	for c in _conns:
		(c.tcp as StreamPeerTCP).disconnect_from_host()
	_server.stop()


func _process(_delta: float) -> void:
	while _server.is_connection_available():
		var tcp := _server.take_connection()
		tcp.set_no_delay(true)
		_conns.append({"tcp": tcp, "buf": PackedByteArray(), "out": PackedByteArray(), "sent": 0,
			"t": Time.get_ticks_msec()})
	var keep: Array[Dictionary] = []
	for c in _conns:
		if _step(c):
			keep.append(c)
	_conns = keep


## true: bağlantı sürüyor
func _step(c: Dictionary) -> bool:
	var tcp: StreamPeerTCP = c.tcp
	tcp.poll()
	var st := tcp.get_status()
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return false
	if (c.out as PackedByteArray).is_empty():
		var n := tcp.get_available_bytes()
		if n > 0:
			var r := tcp.get_partial_data(n)
			if r[0] == OK:
				c.buf = (c.buf as PackedByteArray) + (r[1] as PackedByteArray)
		var text := (c.buf as PackedByteArray).get_string_from_ascii()
		if text.find("\r\n\r\n") < 0:
			if Time.get_ticks_msec() - int(c.t) > 10000 or (c.buf as PackedByteArray).size() > 16384:
				tcp.disconnect_from_host()
				return false
			return true
		c.out = _respond(text)
		c.sent = 0
	# gönder
	var out: PackedByteArray = c.out
	var sent: int = c.sent
	while sent < out.size():
		var piece := out.slice(sent, mini(sent + CHUNK, out.size()))
		var r2 := tcp.put_partial_data(piece)
		if r2[0] != OK:
			return false
		var k: int = r2[1]
		if k <= 0:
			break
		sent += k
	c.sent = sent
	if sent >= out.size():
		tcp.disconnect_from_host()
		return false
	return true


func _respond(req: String) -> PackedByteArray:
	var first := req.get_slice("\r\n", 0)
	var parts := first.split(" ")
	if parts.size() < 2 or (parts[0] != "GET" and parts[0] != "HEAD"):
		return _plain(405, "Method Not Allowed")
	var path := parts[1].get_slice("?", 0).uri_decode()
	if path == "/" or path == "":
		path = "/index.html"
	var name := path.trim_prefix("/")
	if name.contains("..") or name.contains("/") or name.contains("\\"):
		return _plain(404, "Not Found")
	var file := DIR + name + ".gz"
	if not FileAccess.file_exists(file):
		return _plain(404, "Not Found")
	var body := FileAccess.get_file_as_bytes(file)
	var ext := name.get_extension().to_lower()
	var head := "HTTP/1.1 200 OK\r\nContent-Type: %s\r\nContent-Encoding: gzip\r\nContent-Length: %d\r\n" % [
		TYPES.get(ext, "application/octet-stream"), body.size()]
	head += "Cache-Control: no-cache\r\nConnection: close\r\n\r\n"
	var out := head.to_utf8_buffer()
	if parts[0] == "GET":
		out.append_array(body)
	return out


func _plain(code: int, msg: String) -> PackedByteArray:
	var body := msg.to_utf8_buffer()
	return ("HTTP/1.1 %d %s\r\nContent-Type: text/plain\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [
		code, msg, body.size()]).to_utf8_buffer() + body
