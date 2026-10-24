extends SceneTree

var game
var assembler
var lex
var forge
var failures: Array[String] = []
var results: Array[Dictionary] = []
var blasts := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func _spawn(id: String, at: Vector3, team: int = 1):
	var recipe = load("res://scripts/language/recipe.gd").new_node(id)
	var item = assembler.build(recipe, "head", lex)
	item.set_owner_info(team, team, game.player if team == 1 else game.opponent, game.player)
	game.add_thing(item)
	item.global_position = at
	item.activate()
	item.set_physics_process(false)
	return item


func _clear() -> void:
	for child in game.get_node("Things").get_children():
		child.remove()
	await process_frame


func _run() -> void:
	await process_frame
	var match_script = load("res://scenes/main.gd")
	match_script.next_mode = "practice"
	game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	root.add_child(game)
	current_scene = game
	forge = root.get_node("Forge")
	lex = root.get_node("Lexicon").data
	assembler = load("res://scripts/things/assembler.gd")
	forge.explosion_at.connect(func(_at: Vector3, _radius: float, _damage: float) -> void: blasts += 1)
	await create_timer(0.3).timeout
	var origin := Vector3(12, 2, 12)
	var modes := {"nuclear_bomb": "nuclear", "neutron_bomb": "neutron", "gravity_bomb": "gravity", "hypothetical_gravity_bomb": "hypothetical", "singularity_bomb": "singularity", "repulsion_bomb": "repulsion", "frost_bomb": "frost", "inferno_bomb": "inferno", "storm_bomb": "storm", "emp_bomb": "emp", "meteor_bomb": "meteor", "cluster_bomb": "cluster"}
	for id: String in modes:
		var bomb = _spawn(id, origin)
		var target = _spawn("cow", origin + Vector3(2, 0, 0), 2)
		target.hp = 1000
		target.max_hp = 1000
		var wall = _spawn("wall", origin + Vector3(0, 0, 2), 2)
		wall.hp = 1000
		wall.max_hp = 1000
		await create_timer(0.06).timeout
		var before := blasts
		var action = bomb.get_node("Do_anomaly")
		action.run(bomb.context_here())
		await create_timer(0.12).timeout
		var mode: String = modes[id]
		match mode:
			"nuclear":
				_check(blasts > before and target.hp < 1000, "Nuclear blast did not deal damage")
			"neutron":
				_check(target.hp < 1000, "Neutron pulse did not hit creature")
				_check(wall.hp < 1000 and blasts > before, "Neutron blast failed to break nearby structures and terrain")
			"gravity", "singularity":
				_check(target.velocity.x < -0.1, "Gravity did not pull inward: " + mode)
			"hypothetical":
				_check(target.velocity.y > 0.1, "Hypothetical gravity did not lift target")
			"repulsion":
				_check(target.velocity.x > 0.1, "Repulsion did not push outward")
			"frost", "emp":
				var status = target.get_node_or_null("Status")
				_check(status != null and status.remaining.has("frozen"), "Freeze pulse did not apply: " + mode)
			"inferno":
				var status = target.get_node_or_null("Status")
				_check(status != null and status.remaining.has("burning"), "Inferno did not ignite target")
			"storm":
				_check(target.hp < 1000, "Lightning did not deal damage")
			"meteor", "cluster":
				var fragments := 0
				for child in game.get_node("Things").get_children():
					if String(child.get("thing_id")) == ("meteor_fragment" if mode == "meteor" else "cluster_fragment"):
						fragments += 1
				_check(fragments == 6, "Wrong secondary projectile count: " + mode + " " + str(fragments))
		if mode in ["gravity", "singularity", "hypothetical"]:
			await create_timer(4.1).timeout
		results.append({"id": id, "mode": mode, "target_hp": target.hp, "terrain_blasts": blasts - before})
		await _clear()
	for payload in ["ant", "chicken", "duck", "bee", "spider", "crab", "frog", "rat", "pigeon", "raptor", "slime", "beetle"]:
		var source = _spawn(payload + "_grenade", origin)
		await create_timer(0.06).timeout
		source.get_node("Do_burst_into").run(source.context_here())
		var delivery_deadline := Time.get_ticks_msec() + 3000
		while is_instance_valid(source) and not source.is_dead and Time.get_ticks_msec() < delivery_deadline:
			await create_timer(0.03).timeout
		var count := 0
		for child in game.get_node("Things").get_children():
			if child.get("thing_id") == payload and not child.is_dead and child.is_active:
				count += 1
		_check(count == (3 if payload == "raptor" else 6), "Creature grenade failed: " + payload + " count=" + str(count))
		results.append({"id": payload + "_grenade", "living_payload": count})
		await _clear()
	var knife = _spawn("rift_knife", origin)
	var enemy = _spawn("cow", origin, 2)
	enemy.hp = 1000
	enemy.max_hp = 1000
	enemy.global_position = knife.center() + Vector3.FORWARD * 6.0 - enemy.bounds.get_center()
	await create_timer(0.06).timeout
	knife.get_node("Do_anomaly").run(load("res://scripts/things/action_context.gd").make(knife.center(), Vector3.FORWARD))
	_check(enemy.hp < 1000, "Space knife did not damage a distant target")
	results.append({"id": "rift_knife", "target_hp_at_6m": enemy.hp})
	await _clear()
	var report := {"effects": results, "failures": failures}
	var file := FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/chaos-effects.json").simplify_path(), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("CHAOS_EFFECTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
