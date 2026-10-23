extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var match_script = load("res://scenes/main.gd")
	match_script.next_mode = "practice"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	var forge = root.get_node("Forge")
	forge.test_free_matter = true
	forge.test_instant_builds = true
	game.player.add_matter(300.0)
	var anomalies = load("res://scripts/things/action/action_anomaly.gd")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chaos_catalog.json"))
	var report := []
	await create_timer(1.0).timeout
	for entry in catalog.creations:
		if entry.group != "Armas especiais":
			continue
		forge.request(1, "quero " + String(entry.name))
		await create_timer(0.5).timeout
		var item = game.player.hands.current_item()
		if item == null or item.thing_id != entry.id:
			failures.append("Weapon not equipped: " + entry.id)
			continue
		var deadline := Time.get_ticks_msec() + 7000
		while item.is_building or forge.is_assembling(1):
			await create_timer(0.05).timeout
			if Time.get_ticks_msec() > deadline:
				failures.append("Weapon assembly timed out: " + entry.id)
				break
		var fired := [false]
		item.fired.connect(func(_ctx): fired[0] = true)
		var ammo: int = item.ammo
		game.player.hands.use_pressed()
		game.player.hands.use_released()
		await create_timer(1.2).timeout
		if not fired[0]:
			failures.append("Hands did not fire weapon: " + entry.id)
		if entry.id.ends_with("_launcher") and item.ammo >= ammo:
			failures.append("Creature launcher did not consume ammunition: " + entry.id)
		report.append({"id": entry.id, "fired": fired[0], "ammo_before": ammo, "ammo_after": item.ammo})
	for mode in ["rift", "weapon_repulsion", "weapon_storm", "weapon_frost", "weapon_inferno"]:
		if int(anomalies.executed.get(mode, 0)) < 1:
			failures.append("Weapon power did not activate: " + mode)
	var old_ants := {}
	for child in game.get_node("Things").get_children():
		if child.get("thing_id") == "ant":
			old_ants[child.get_instance_id()] = true
	forge.request(1, "quero uma granada de formigas")
	await create_timer(0.5).timeout
	var grenade = game.player.hands.current_item()
	if grenade == null or grenade.thing_id != "ant_grenade":
		failures.append("Swarm grenade was not equipped")
	else:
		var deadline := Time.get_ticks_msec() + 7000
		while grenade.is_building or forge.is_assembling(1):
			await create_timer(0.05).timeout
			if Time.get_ticks_msec() > deadline:
				failures.append("Swarm grenade assembly timed out")
				break
		game.player.hands.use_pressed()
		game.player.hands.use_released()
		await create_timer(3.0).timeout
		var new_ants := 0
		for child in game.get_node("Things").get_children():
			if child.get("thing_id") == "ant" and not child.is_dead and not old_ants.has(child.get_instance_id()):
				new_ants += 1
		if new_ants != 6:
			failures.append("Hand-thrown swarm grenade did not release six ants: " + str(new_ants))
		report.append({"id": "ant_grenade", "hand_thrown_living_ants": new_ants})
	var result := {"weapons": report, "activated_modes": anomalies.executed, "failures": failures}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/chaos-weapons.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	print("CHAOS_WEAPONS ", JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
