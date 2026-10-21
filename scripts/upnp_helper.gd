class_name UpnpHelper
extends Node
## Kurucu tarafında, modemde portu otomatik açmayı dener (UPnP).
## Arka planda çalışır; bitince `finished` sinyali gelir.

signal finished(ok: bool, external_ip: String, message: String)

var port := NetTools.GAME_PORT
var ok := false
var external_ip := ""
var message := "Modemde port açılmaya çalışılıyor…"
var _thread: Thread
var _upnp: UPNP


func start() -> void:
	_thread = Thread.new()
	_thread.start(_work)


func _work() -> void:
	var upnp := UPNP.new()
	var err := upnp.discover(2000, 2, "InternetGatewayDevice")
	if err != UPNP.UPNP_RESULT_SUCCESS or upnp.get_gateway() == null or not upnp.get_gateway().is_valid_gateway():
		_done.call_deferred(false, "", "Modem otomatik port açmayı (UPnP) desteklemiyor ya da kapalı.")
		return
	var r1 := upnp.add_port_mapping(port, port, "Derin Deniz", "UDP")
	var ext := upnp.query_external_address()
	if r1 != UPNP.UPNP_RESULT_SUCCESS:
		_done.call_deferred(false, ext, "Modem portu açmayı reddetti (UPnP hata %d)." % r1)
		return
	_upnp = upnp
	if ext == "" or NetTools.is_private(ext):
		_done.call_deferred(false, ext,
			"Port açıldı ama internet sağlayıcın ortak IP (CGNAT) kullanıyor; internetten doğrudan bağlanılamaz.")
		return
	_done.call_deferred(true, ext, "Port açıldı. İnternetten bu adresle katılınabilir.")


func _done(p_ok: bool, ip: String, msg: String) -> void:
	ok = p_ok
	external_ip = ip
	message = msg
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	finished.emit(ok, ip, msg)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	if _upnp != null:
		_upnp.delete_port_mapping(port, "UDP")
