extends SceneTree

var session
var role := "client"
var port := 29841
var deadline := 0
var finished := false
var selected := false
var readied := false
var voted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			role = argument.trim_prefix("--test-role=")
	session = root.get_node("Session")
	session.lobby.match_requested.connect(_success)
	var error: int = session.start_host(port, "127.0.0.1") if role == "host" else session.start_client("127.0.0.1", port)
	if error != OK:
		_finish(false, "Cannot open transport: " + error_string(error) + "; " + session.last_error)
		return
	deadline = Time.get_ticks_msec() + 25000
	while not finished:
		await create_timer(0.1).timeout
		if finished:
			break
		if Time.get_ticks_msec() > deadline:
			_finish(false, "Timed out; state=%s phase=%s error=%s" % [session.state, session.lobby.phase, session.last_error])
			return
		if session.state != "ready" or session.player_ids().size() != 2 or not session.lobby.synchronized:
			continue
		var lobby = session.lobby
		if not selected:
			var body_script = load("res://scenes/player/robot/robot_body.gd")
			var color_script = load("res://scenes/player/robot/robot_color.gd")
			var palette: Array = body_script.config()["player_colors"]
			selected = lobby.set_local_color(color_script.to_rgb24(Color(String(palette[0 if role == "host" else 1]))))
		elif not readied and lobby.color_for_player(session.local_player_id) >= 0:
			lobby.set_local_ready(true)
			readied = true
		elif lobby.phase == "arena" and not lobby.transition_locked and not voted:
			lobby.set_local_map(0)
			lobby.set_local_vote(true)
			voted = true


func _success() -> void:
	if finished:
		return
	finished = true
	var match_script = load("res://scenes/main.gd")
	match_script.next_mode = "online"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	game.configure_session = false
	root.add_child(game)
	current_scene = game
	var replication_deadline := Time.get_ticks_msec() + 20000
	while not session.replication.is_active() or not session.creations.is_active():
		await create_timer(0.1).timeout
		if Time.get_ticks_msec() > replication_deadline:
			_finish(false, "Match replication did not become active: " + session.last_error)
			return
	var chaos_test := OS.get_cmdline_user_args().has("--test-chaos")
	if OS.get_cmdline_user_args().has("--test-spatial"):
		await create_timer(3.3).timeout
		if role == "host":
			var lex = root.get_node("Lexicon").data
			var assembler = load("res://scripts/things/assembler.gd")
			var recipe = load("res://scripts/language/recipe.gd")
			var forge = root.get_node("Forge")
			var caster = assembler.build(recipe.new_node("pistol"), "head", lex)
			caster.set_owner_info(1, 1, game.get_player(1), game.get_player(1))
			game.add_thing(caster)
			forge.spawn_child(recipe.new_node("cursed_blue"), "projectile", Vector3(0, 40, 0), Vector3.FORWARD, caster, 0.0)
			await create_timer(0.3).timeout
			caster.set_owner_info(2, 2, game.get_player(2), game.get_player(2))
			forge.spawn_child(recipe.new_node("reversal_red"), "projectile", Vector3(.4, 40, 0), Vector3.FORWARD, caster, 0.0)
			for step in 30: await physics_frame
			await create_timer(1.3).timeout
		else:
			var spatial_deadline := Time.get_ticks_msec() + 4000
			while Time.get_ticks_msec() < spatial_deadline:
				var arrived := false
				for item in game.get_node("Things").get_children():
					if item.thing_id == "hollow_purple" and not item.is_dead: arrived = true
				if arrived: break
				await create_timer(0.05).timeout
		var purples := 0
		for item in game.get_node("Things").get_children():
			if item.thing_id == "hollow_purple" and not item.is_dead: purples += 1
		if purples != 1:
			_finish(false, "Spatial fusion was not replicated: purple count=" + str(purples))
			return
		await create_timer(1.0 if role == "host" else 2.0).timeout
	elif OS.get_cmdline_user_args().has("--test-jujutsu"):
		await create_timer(3.3).timeout
		if role == "host":
			var r = load("res://scripts/language/recipe.gd")
			var a = load("res://scripts/things/assembler.gd")
			var caster = a.build(r.new_node("pistol"), "head", root.get_node("Lexicon").data)
			caster.set_owner_info(1,1,game.get_player(1),game.get_player(1))
			game.add_thing(caster)
			var node = r.new_node("dog")
			node.mods.jj_adaptation = true
			var dog = root.get_node("Forge").spawn_child(node,"spawned",Vector3(0,40,0),Vector3.FORWARD,caster,0.0)
			if dog == null:
				_finish(false,"Cursed animal failed to spawn")
				return
			dog.get_node("Jujutsu").exposure.infinity = 3
			await create_timer(2.5).timeout
		else:
			var deadline := Time.get_ticks_msec() + 4000
			var found := false
			while Time.get_ticks_msec() < deadline and not found:
				for entry in session.creations.entries.values():
					var animal = entry.thing
					if is_instance_valid(animal) and animal.thing_id == "dog" and animal.get_node_or_null("Jujutsu") != null:
						if animal.get_node("Jujutsu").exposure.get("infinity",0) == 3: found = true
				await create_timer(.05).timeout
			if not found:
				_finish(false,"Adaptation state did not reach client")
				return
			await create_timer(.5).timeout
	elif chaos_test:
		await create_timer(3.3).timeout
		if role == "host":
			var forge = root.get_node("Forge")
			forge.test_free_matter = true
			forge.test_instant_builds = true
			game.player.add_matter(300.0)
			forge.request(1, "quero uma capivara")
			forge.request(1, "quero uma bomba de gravidade")
			await create_timer(0.5).timeout
			var item = game.player.hands.current_item()
			if item == null:
				_finish(false, "Gravity bomb was not equipped")
				return
			var thrown = forge.spawn_child(item.node_data, "projectile", Vector3(0, 3, 0), Vector3.DOWN, item, 0.0, Vector3.ZERO, true)
			await create_timer(0.1).timeout
			if thrown == null:
				_finish(false, "Gravity bomb projectile was not replicated")
				return
			thrown.get_node("Do_anomaly").run(thrown.context_here())
		await create_timer(7.0 if role == "host" else 6.0).timeout
		var capybaras := 0
		for creation in game.get_node("Things").get_children():
			if creation.get("thing_id") == "capybara":
				capybaras += 1
		var effects = load("res://scripts/fx/expansion_fx.gd")
		if capybaras != 1 or effects.burst_count == 0:
			_finish(false, "Chaos replication failed: capybaras=%d voxel_fx=%d" % [capybaras, effects.burst_count])
			return
	else:
		await create_timer(4.0).timeout
	var stats: Dictionary = session.replication.stats
	var snapshot_count: int = stats.snapshots_sent if role == "host" else stats.snapshots_received
	_finish(snapshot_count > 0, "ENet lobby and online match replication completed; snapshots=%d" % snapshot_count)


func _finish(ok: bool, message: String) -> void:
	finished = true
	var report := {"ok": ok, "role": role, "message": message, "player_id": session.local_player_id, "roster": session.roster, "phase": session.lobby.phase, "map": session.lobby.chosen_map_id(), "replication": session.replication.stats}
	var report_path := ProjectSettings.globalize_path("res://").path_join("../analysis/network-" + role + ".json").simplify_path()
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	print("NETWORK_SMOKE ", JSON.stringify(report))
	quit(0 if ok else 1)
