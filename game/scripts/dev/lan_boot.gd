extends RefCounted




static func start(tree: SceneTree, arguments: PackedStringArray) -> void :
	var count: = 4
	for argument: String in arguments:
		if argument.begins_with("--lan-players="):
			count = clampi(argument.trim_prefix("--lan-players=").to_int(), 2, 4)
	var result: = Session.start_from_args(arguments)
	if result != OK or not Session.is_online():
		push_error("[LAN] não foi possível abrir a sessão de medição")
		tree.quit(1)
		return
	var deadline: = Time.get_ticks_msec() + 180000
	while Session.player_ids().size() < count or Session.state != "ready":
		if Time.get_ticks_msec() > deadline or Session.state in ["failed", "disconnected"]:
			push_error("[LAN] sessão não reuniu %d jogadores compatíveis" % count)
			tree.quit(1)
			return
		await tree.process_frame
	print("[LAN] ", count, " jogadores autenticados; carregando arena")
	Match.next_mode = "online"
	tree.change_scene_to_file("res://scenes/main.tscn")
