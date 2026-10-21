class_name NetTools
extends RefCounted
## Ağ yardımcıları: yerel IP adresleri, adres türleri, yayın adresleri.

const GAME_PORT := 7777
const DISCOVERY_PORT := 7778
const MAGIC_QUERY := "DERINDENIZ?"
const MAGIC_REPLY := "DERINDENIZ!"


static var version_override := ""     # yalnızca testler için


static func version() -> String:
	if version_override != "":
		return version_override
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## Bilgisayarın IPv4 adresleri, en kullanışlısı başta.
static func local_ipv4s() -> PackedStringArray:
	var scored := []
	for ip in IP.get_local_addresses():
		if ":" in ip or ip.begins_with("127.") or ip.begins_with("169.254."):
			continue
		scored.append([_score(ip), ip])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var out := PackedStringArray()
	for s in scored:
		out.append(s[1])
	return out


static func _score(ip: String) -> int:
	if ip.begins_with("192.168."):
		return 50
	if ip.begins_with("10."):
		return 40
	if _is_172_private(ip):
		return 35
	if ip.begins_with("26."):
		return 30      # Radmin VPN
	if ip.begins_with("100."):
		return 25      # Tailscale
	if ip.begins_with("25."):
		return 20      # Hamachi
	return 10


static func _is_172_private(ip: String) -> bool:
	var p := ip.split(".")
	return p.size() == 4 and p[0] == "172" and int(p[1]) >= 16 and int(p[1]) <= 31


## Adresin ne olduğu (oyuncuya gösterilen kısa açıklama)
static func describe(ip: String) -> String:
	if ip.begins_with("26."):
		return "Radmin VPN"
	if ip.begins_with("100."):
		return "Tailscale / VPN"
	if ip.begins_with("25."):
		return "Hamachi"
	if ip.begins_with("192.168.") or ip.begins_with("10.") or _is_172_private(ip):
		return "aynı ağ / Wi-Fi"
	return "ağ"


## Özel (internetten erişilemeyen) adres mi? CGNAT tespiti için.
static func is_private(ip: String) -> bool:
	if ip.begins_with("10.") or ip.begins_with("192.168.") or _is_172_private(ip):
		return true
	var p := ip.split(".")
	# 100.64.0.0/10: operatör NAT'ı (CGNAT)
	return p.size() == 4 and p[0] == "100" and int(p[1]) >= 64 and int(p[1]) <= 127


## Keşif sorgusunun gideceği yayın adresleri
static func broadcast_addresses() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	for ip in local_ipv4s():
		var p := ip.split(".")
		for cand in ["%s.%s.%s.255" % [p[0], p[1], p[2]], "%s.%s.255.255" % [p[0], p[1]],
				"%s.255.255.255" % p[0]]:
			if not out.has(cand):
				out.append(cand)
	return out
