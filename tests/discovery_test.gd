extends SceneTree
## Yerel ağ keşfi testi: çalışan bir sunucuyu yayın sorgusuyla bulmalı.
##   godot --headless --path . --script res://tests/discovery_test.gd -- --world <ad>

func _initialize() -> void:
	_run()


func _run() -> void:
	var want := ""
	var a := OS.get_cmdline_user_args()
	for i in a.size():
		if a[i] == "--world" and i + 1 < a.size():
			want = a[i + 1]
	var lan := LanDiscovery.new()
	root.add_child(lan)
	lan.start_browser()
	var ok := false
	for i in 50:
		await create_timer(0.1).timeout
		for k in lan.found.keys():
			if lan.found[k].get("world", "") == want:
				ok = true
		if ok:
			break
	print("%s  yerel ağda dünya bulundu (%s) %s" % ["OK  " if ok else "FAIL", want, str(lan.found.keys())])
	print("yerel IP'ler: ", NetTools.local_ipv4s(), "  yayın: ", NetTools.broadcast_addresses())
	quit(0 if ok else 1)
