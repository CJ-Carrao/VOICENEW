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
	if OS.get_cmdline_user_args().has("--test-tactics"):
		await create_timer(3.3).timeout
		if role == "host":
			var forge = root.get_node("Forge")
			var lex = root.get_node("Lexicon").data
			var recipe = load("res://scripts/language/recipe.gd")
			var assembler = load("res://scripts/things/assembler.gd")
			var source = assembler.build(recipe.new_node("pistol"),"head",lex)
			source.set_owner_info(2,2,game.get_player(2),null)
			game.add_thing(source)
			for id in [1,2]: game.get_player(id).set_physics_process(false)
			game.get_player(1).global_position = Vector3(10,40,-2)
			game.get_player(2).global_position = Vector3(0,40,8)
			game.get_player(2).add_matter(1000.0)
			var actors := []
			for i in 4:
				await create_timer(.16).timeout
				var node = recipe.new_node(["eagle","dog","cat","butterfly_shield"][i])
				if i == 2: node.mods.transform_to = "tank"
				var actor = forge.spawn_child(node,"spawned",[Vector3(0,40,0),Vector3(0,40,2),Vector3(8,40,0),Vector3(-8,40,0)][i],Vector3.FORWARD,source,0.0)
				if actor == null: _finish(false,"Tactics fixture could not spawn: "+str(i)); return
				actor.set_physics_process(false)
				actor.move.set_physics_process(false)
				actors.append(actor)
			var until := Time.get_ticks_msec()+7000
			while Time.get_ticks_msec() < until:
				if actors[0].get_node("CreatureTactics").passenger() == actors[1] and actors[2].get_node("CreatureTactics").rule == "defend_owner": break
				await create_timer(.05).timeout
			if actors[0].get_node("CreatureTactics").passenger() != actors[1] or actors[2].get_node("CreatureTactics").rule != "defend_owner": _finish(false,"Remote transport/conditional commands failed"); return
			actors[2].hp = actors[2].max_hp*.3
			await create_timer(.12).timeout
			actors[2].get_node("CreatureTransform").shot_left = 60.0
			source.set_owner_info(1,1,game.get_player(1),null)
			load("res://scripts/things/combat.gd").apply_damage(game.get_player(2),1,"melee",source)
			var bullet = forge.spawn_child(recipe.new_node("bullet"),"projectile",Vector3(-5.5,40,8),Vector3.FORWARD,source,0.0)
			if bullet == null: _finish(false,"Online converter bullet missing"); return
			bullet.move.set_physics_process(false)
			bullet.move.travel(Vector3(0,0,-16))
			await create_timer(1.2).timeout
			if actors[3].get_node("ButterflyShield").converted != 1 or not actors[1].get_node("AnimalOrders").automatic_active: _finish(false,"Host conversion/owner defense failed"); return
			actors[0].get_node("CreatureTactics").unload()
			actors[0].get_node("AnimalOrders").set_order("stay",actors[0].global_position)
			actors[2].get_node("CreatureTransform").revert()
			await create_timer(1.5).timeout
		else:
			var until := Time.get_ticks_msec()+14000
			var sent := false
			var carried := false
			var released := false
			var transformed := false
			var reverted := false
			var converted := false
			var defended := false
			var rule_seen := false
			while Time.get_ticks_msec() < until:
				var found := 0
				for actor in game.get_node("Things").get_children():
					if actor.thing_id in ["eagle","dog","cat","butterfly_shield"]: found += 1
					if actor.thing_id == "dog":
						if actor.get_node("CreatureTactics").carrier_id > 0: carried = true
						elif carried: released = true
						if actor.get_node("AnimalOrders").automatic_active: defended = true
					if actor.thing_id == "cat":
						if actor.get_node("CreatureTactics").rule == "defend_owner": rule_seen = true
						if actor.get_node("CreatureTransform").active and actor.bounds.size.length() > 2.0: transformed = true
						elif transformed: reverted = true
					if actor.thing_id == "butterfly_shield" and actor.get_node("ButterflyShield").converted == 1: converted = true
				if found == 4 and not sent:
					session.creations.submit_request("aguia carregue cachorro",false,true)
					session.creations.submit_request("gato se eu for atacado me proteja",false,true)
					sent = true
				if carried and released and transformed and reverted and converted and defended and rule_seen: break
				await create_timer(.05).timeout
			if not (carried and released and transformed and reverted and converted and defended and rule_seen): _finish(false,"Remote tactics states failed: %s" % str([carried,released,transformed,reverted,converted,defended,rule_seen])); return
	elif OS.get_cmdline_user_args().has("--test-progression"):
		await create_timer(3.3).timeout
		var coop = load("res://scripts/things/coop_encounter.gd")
		if role == "host":
			var forge = root.get_node("Forge")
			var lex = root.get_node("Lexicon").data
			var recipe = load("res://scripts/language/recipe.gd")
			var assembler = load("res://scripts/things/assembler.gd")
			var source = assembler.build(recipe.new_node("pistol"),"head",lex)
			source.set_owner_info(1,1,game.get_player(1),game.get_player(1))
			game.add_thing(source)
			var animals := []
			for i in 3:
				await create_timer(.15).timeout
				var node: Dictionary = recipe.new_node("pikachu" if i == 0 else "dog" if i == 1 else "chicken")
				if i == 0: node.mods.fusion_squirtle = true
				var animal = forge.spawn_child(node,"spawned",Vector3(i*4,40,0),Vector3.FORWARD,source,0.0)
				if animal == null: _finish(false,"Could not create progression fixture"); return
				animal.set_physics_process(false)
				animal.move.set_physics_process(false)
				forge.transfer_owner(animal,game.get_player(2))
				animals.append(animal)
			animals[0].get_node("CreatureBond").trust = 75.0
			var temporary = load("res://scripts/things/creative_effects.gd")
			if not temporary.swap(animals[1].get_node("CreativeEffects"),animals[2].get_node("CreativeEffects"),source): _finish(false,"Online swap failed"); return
			await create_timer(.7).timeout
			animals[1].get_node("CreativeEffects").restore()
			animals[2].get_node("CreativeEffects").restore()
			if not animals[1].get_node("CreativeEffects").charm(source):
				animals[1].get_node("CreativeEffects").immunity = 0
				if not animals[1].get_node("CreativeEffects").charm(source): _finish(false,"Online conversion failed"); return
			await create_timer(.7).timeout
			animals[1].get_node("CreativeEffects").restore()
			for player in game.get_players(): player.add_matter(1000)
			coop.request(game.get_player(1),"invite")
			var encounter = coop.of(game)
			var until := Time.get_ticks_msec()+6000
			while encounter.phase != "battle" and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if encounter.phase != "battle": _finish(false,"Remote acceptance did not start coop"); return
			var boss = encounter.boss_ref.get_ref()
			if boss.max_hp != 950.0 or not coop.allied(1,2): _finish(false,"Boss scaling or alliance failed"); return
			var before: float = game.get_player(2).health
			load("res://scripts/things/combat.gd").apply_damage(game.get_player(2),50,"melee",source)
			if game.get_player(2).health != before: _finish(false,"Coop friendly damage was not blocked"); return
			await create_timer(1.5).timeout
			boss.take_damage(10000,"world_cut",source)
			await create_timer(1.0).timeout
			if encounter.phase != "victory" or coop.allied(1,2): _finish(false,"Coop did not end cleanly"); return
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec()+14000
			var fused := false
			var swapped := false
			var restored := false
			var converted := false
			var returned := false
			var accepted := false
			var battle := false
			var boss_seen := false
			var victory := false
			while Time.get_ticks_msec() < until:
				for animal in game.get_node("Things").get_children():
					if animal.thing_id == "coop_chimera" and animal.team == 99 and animal.max_hp == 950.0 and animal.get_node_or_null("CoopBoss") != null: boss_seen = true
					if animal.thing_id == "pikachu": fused = animal.get_node("FusionPowers").companions.size() == 1 and animal.get_node("CreatureBond").trust == 75.0
					if animal.thing_id == "dog":
						if animal.node_data.get("mods",{}).get("anatomy",{}).get("head","") == "chicken": swapped = true
						elif swapped: restored = true
						if animal.team == 1: converted = true
						elif converted and animal.team == 2: returned = true
				var encounter = coop.of(game)
				if encounter != null:
					if encounter.phase == "waiting" and not accepted:
						session.creations.submit_request("aceitar desafio",false,true)
						accepted = true
					if encounter.phase == "battle": battle = true
					if encounter.phase == "victory": victory = true
				if fused and swapped and restored and converted and returned and battle and victory and boss_seen: break
				await create_timer(.05).timeout
			if not (fused and swapped and restored and converted and returned and battle and victory and boss_seen): _finish(false,"Progression replication failed: %s" % str([fused,swapped,restored,converted,returned,battle,victory,boss_seen])); return
	elif OS.get_cmdline_user_args().has("--test-domain-clash"):
		await create_timer(3.3).timeout
		var sword_fx = load("res://scripts/fx/space_sword.gd")
		if role == "host":
			var lex = root.get_node("Lexicon").data
			var assembler = load("res://scripts/things/assembler.gd")
			var recipe = load("res://scripts/language/recipe.gd")
			var forge = root.get_node("Forge")
			var caster = assembler.build(recipe.new_node("pistol"), "head", lex)
			game.add_thing(caster)
			var users := []
			for i in 2:
				await create_timer(.15).timeout
				caster.set_owner_info(i+1,i+1,game.get_player(i+1),game.get_player(i+1))
				var id := "unlimited_void" if i == 0 else "malevolent_shrine"
				var tool = forge.spawn_child(recipe.new_node(id), "spawned", Vector3(-3 if i == 0 else 3,40,0), Vector3.FORWARD, caster, 0.0)
				if tool == null: _finish(false,"Cannot spawn clash domain"); return
				tool.set_physics_process(false)
				tool.move.set_physics_process(false)
				users.append(tool.get_node("Jujutsu"))
			for user in users:
				if not user.expand_domain(): _finish(false,"Cannot expand clash domain"); return
			await create_timer(.8).timeout
			if not users[0].domain_clashing or not users[1].domain_clashing: _finish(false,"Host domains did not clash"); return
			caster.set_owner_info(1,1,game.get_player(1),game.get_player(1))
			var sword = forge.spawn_child(recipe.new_node("rift_knife"), "spawned", Vector3(0,40,8), Vector3.FORWARD, caster, 0.0)
			if sword == null: _finish(false,"Cannot spawn online space sword"); return
			sword.set_physics_process(false)
			sword.get_node("Do_anomaly").run(load("res://scripts/things/action_context.gd").make(sword.center(),Vector3.FORWARD))
			await create_timer(3.5).timeout
			if users[0].domain_outcome != "tie" or users[1].domain_outcome != "tie": _finish(false,"Host clash did not resolve as a tie"); return
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec()+7000
			var seen := false
			var ended := false
			while Time.get_ticks_msec() < until:
				var clashing := 0
				var resolved := 0
				for user in get_nodes_in_group("jujutsu_users"):
					if user.domain_clashing and user.clash_elapsed > .1 and user.clash_axis.length() > .9: clashing += 1
					if user.domain_outcome == "tie" and not user.domain_clashing and user.domain_until == 0: resolved += 1
				seen = seen or clashing == 2
				ended = resolved == 2
				if seen and ended and sword_fx.casts > 0: break
				await create_timer(.05).timeout
			if not seen or not ended or sword_fx.casts == 0: _finish(false,"Client clash/sword replication failed: %s/%s/%s" % [seen,ended,sword_fx.casts]); return
	elif OS.get_cmdline_user_args().has("--test-beams"):
		await create_timer(3.3).timeout
		if role == "host":
			var lex = root.get_node("Lexicon").data
			var assembler = load("res://scripts/things/assembler.gd")
			var recipe = load("res://scripts/language/recipe.gd")
			var action_context = load("res://scripts/things/action_context.gd")
			var forge = root.get_node("Forge")
			var caster = assembler.build(recipe.new_node("pistol"), "head", lex)
			game.add_thing(caster)
			for i in 2:
				await create_timer(.15).timeout
				caster.set_owner_info(i + 1, i + 1, game.get_player(i + 1), game.get_player(i + 1))
				var direction := Vector3.RIGHT if i == 0 else Vector3.LEFT
				var emitter = forge.spawn_child(recipe.new_node("ryu_beam_technique" if i == 0 else "yuta_beam_technique"), "spawned", Vector3(-12 if i == 0 else 12, 40, 0), direction, caster, 0.0)
				if emitter == null: _finish(false, "Cannot create network beam emitter"); return
				emitter.get_node("Jujutsu").cast(action_context.make(emitter.center(), direction))
			await create_timer(1.0).timeout
			var clashing := 0
			for beam in get_nodes_in_group("cursed_beams"):
				if beam.clashing: clashing += 1
			if clashing != 2: _finish(false, "Host did not create beam clash"); return
			await create_timer(4.0).timeout
		else:
			var until := Time.get_ticks_msec() + 7000
			var seen := false
			while not seen and Time.get_ticks_msec() < until:
				var clashing := 0
				for beam in get_nodes_in_group("cursed_beams"):
					if beam.clashing and beam.origin.distance_to(beam.endpoint) > 1.0: clashing += 1
				seen = clashing == 2
				await create_timer(.05).timeout
			if not seen: _finish(false, "Client did not receive both beam clash visuals"); return
			while not get_nodes_in_group("cursed_beams").is_empty() and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if not get_nodes_in_group("cursed_beams").is_empty(): _finish(false, "Client retained ended beam actors"); return
	elif OS.get_cmdline_user_args().has("--test-spatial"):
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
	elif OS.get_cmdline_user_args().has("--test-jujutsu") or OS.get_cmdline_user_args().has("--test-dinosaurs"):
		await create_timer(3.3).timeout
		if role == "host":
			var r = load("res://scripts/language/recipe.gd")
			var a = load("res://scripts/things/assembler.gd")
			var caster_node = r.new_node("pistol")
			if OS.get_cmdline_user_args().has("--test-jujutsu"): caster_node.mods.jj_fuga = true
			var caster = a.build(caster_node, "head", root.get_node("Lexicon").data)
			caster.set_owner_info(1,1,game.get_player(1),game.get_player(1))
			game.add_thing(caster)
			var node = r.new_node("dog")
			node.mods.jj_adaptation = true
			if OS.get_cmdline_user_args().has("--test-dinosaurs"): node.mods.anatomy = {"head": "trex"}
			var dog = root.get_node("Forge").spawn_child(node,"spawned",Vector3(0,40,0),Vector3.FORWARD,caster,0.0)
			if dog == null:
				_finish(false,"Cursed animal failed to spawn")
				return
			dog.get_node("Jujutsu").exposure.infinity = 3
			if OS.get_cmdline_user_args().has("--test-jujutsu"):
				caster.activate()
				caster.global_position = Vector3(-10,40,0)
				caster.get_node("Jujutsu").cast(load("res://scripts/things/action_context.gd").make(caster.center(), Vector3.RIGHT))
				load("res://scripts/fx/jujutsu_impact.gd").play(game, Vector3(0,40,0), Vector3.RIGHT, "black_flash")
			await create_timer(2.5).timeout
		else:
			var deadline := Time.get_ticks_msec() + 4000
			var found := false
			var projectile_seen := false
			while Time.get_ticks_msec() < deadline and not found:
				if not get_nodes_in_group("cursed_projectiles").is_empty(): projectile_seen = true
				for entry in session.creations.entries.values():
					var animal = entry.thing
					if is_instance_valid(animal) and animal.thing_id == "dog" and animal.get_node_or_null("Jujutsu") != null:
						if animal.get_node("Jujutsu").exposure.get("infinity",0) == 3:
							if not OS.get_cmdline_user_args().has("--test-dinosaurs"):
								found = projectile_seen and load("res://scripts/fx/jujutsu_impact.gd").last_style == "black_flash"
							else:
								for piece in animal.model_pieces:
									if piece.get_meta("source", "") == "trex": found = true
				await create_timer(.05).timeout
			if not found:
				_finish(false,"Adaptation state did not reach client")
				return
			await create_timer(.5).timeout
	elif OS.get_cmdline_user_args().has("--test-capture"):
		await create_timer(3.3).timeout
		if role == "host":
			var r = load("res://scripts/language/recipe.gd")
			var a = load("res://scripts/things/assembler.gd")
			var forge = root.get_node("Forge")
			var caster = a.build(r.new_node("pistol"),"head",root.get_node("Lexicon").data)
			caster.set_owner_info(1,1,game.get_player(1),null)
			game.add_thing(caster)
			var animal = forge.spawn_child(r.new_node("dog"),"spawned",Vector3(0,40,0),Vector3.FORWARD,caster,0.0)
			await process_frame
			var p = game.get_player(2)
			var spot = p.head.global_position + Vector3.FORWARD
			var ball = forge.spawn_child(r.new_node("capture_ball"),"projectile",spot,Vector3.FORWARD,caster,0.0)
			await process_frame
			caster.set_owner_info(2,2,p,null)
			var gun = forge.spawn_child(r.new_node("pistol"),"spawned",spot,Vector3.FORWARD,caster,0.0)
			if animal == null or ball == null or gun == null:
				_finish(false,"Capture fixture failed to spawn")
				return
			gun.ammo = 7
			p.hands.give(gun,false)
			await process_frame
			ball.get_node("GroundMotion").set_physics_process(false)
			ball.velocity = Vector3.ZERO
			ball.global_position = spot
			if not ball.get_node("CaptureBall")._attempt(weakref(animal),0.0):
				_finish(false,"Capture failed on host")
				return
			await create_timer(.8).timeout
			ball.pickup_after_ms = 0
			if not p.hands.pickup(ball):
				_finish(false,"Second player could not pick up full ball")
				return
			await create_timer(1.5).timeout
			p.hands._throw(ball,p.head.global_position + Vector3.FORWARD,Vector3.FORWARD)
			await create_timer(3.0).timeout
			if animal.is_captured or animal.owner_id != 2 or not gun.ground_item:
				_finish(false,"Host release/ownership failed")
				return
		else:
			var deadline := Time.get_ticks_msec() + 6500
			var captured_seen := false
			var held_seen := false
			var released_seen := false
			var dropped_seen := false
			while Time.get_ticks_msec() < deadline:
				for entry in session.creations.entries.values():
					var item = entry.thing
					if not is_instance_valid(item): continue
					if item.thing_id == "dog":
						if item.is_captured and not item.visible: captured_seen = true
						if captured_seen and not item.is_captured and item.owner_id == 2 and item.team == 2 and item.visible: released_seen = true
					if item.thing_id == "capture_ball" and item.is_held and item.owner_id == 2: held_seen = true
					if item.thing_id == "pistol" and item.ground_item and not item.is_held and item.visible and item.ammo == 7: dropped_seen = true
				if captured_seen and held_seen and released_seen and dropped_seen: break
				await create_timer(.05).timeout
			if not (captured_seen and held_seen and released_seen and dropped_seen):
				_finish(false,"Client capture flow failed: %s/%s/%s/%s" % [captured_seen,held_seen,released_seen,dropped_seen])
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-orders-builders"):
		await create_timer(3.3).timeout
		var volume = load("res://scripts/world/block_volume.gd").new()
		volume.setup(777, Vector3i(32, 8, 24), Vector3(-4, 18, -3))
		var soil: int = volume.add_type("soil", Color("72583d"))
		var bedrock: int = volume.add_type("soil", Color("363636"), 2)
		volume.blocks.fill(soil)
		for x in 32:
			for z in 24: volume.blocks[volume.index_of(Vector3i(x, 0, z))] = bedrock
		game.add_child(volume)
		volume.add_to_group("terrain")
		volume.commit_base()
		if role == "host":
			var callback = session.world_sync._on_cells.bind(volume)
			volume.cells_changed.connect(callback)
			session.world_sync._watched[volume] = callback
		var protected_cells: int = volume.blocks.count(bedrock)
		if role == "host":
			var a = load("res://scripts/things/assembler.gd")
			var r = load("res://scripts/language/recipe.gd")
			var forge = root.get_node("Forge")
			var caster = a.build(r.new_node("pistol"), "head", root.get_node("Lexicon").data)
			caster.set_owner_info(2, 2, game.get_player(2), game.get_player(2))
			game.add_thing(caster)
			for id in [1, 2]:
				game.get_player(id).set_physics_process(false)
				game.get_player(id).global_position = Vector3(20 if id == 1 else 0, 20, 8)
			game.get_player(2).matter = 300.0
			var workers := []
			for species in ["beaver", "spider", "ant"]:
				await create_timer(.12).timeout
				var animal = forge.spawn_child(r.new_node(species), "spawned", Vector3(2, 20, 2), Vector3.FORWARD, caster, 0.0)
				if animal == null:
					_finish(false, "Cannot spawn builder fixture")
					return
				animal.move.set_physics_process(false)
				animal.set_physics_process(false)
				workers.append(animal)
			var until := Time.get_ticks_msec() + 14000
			while workers[0].get_node("AnimalOrders").mode != "follow" and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if workers[0].get_node("AnimalOrders").mode != "follow":
				_finish(false, "Remote universal animal command did not reach host")
				return
			var points := [Vector3(0, 20, -1.5), Vector3(-2, 20, 0), Vector3(2, 20, 0)]
			for i in workers.size():
				var builder = workers[i].get_node("CreatureBuilder")
				var reply: Dictionary = builder.begin(points[i], Vector3.FORWARD)
				if reply.get("blocked", false):
					_finish(false, "Builder rejected site: " + str(reply))
					return
				workers[i].get_node("AnimalOrders").set_order("build", builder.work_point)
				workers[i].global_position = builder.work_point + Vector3(2 if i == 0 else 0, 0, 2)
			while Time.get_ticks_msec() < until:
				var finished_jobs := 0
				for animal in workers:
					if animal.get_node("CreatureBuilder").completed > 0: finished_jobs += 1
				if finished_jobs == 3: break
				await create_timer(.05).timeout
			for animal in workers:
				if animal.get_node("CreatureBuilder").completed != 1:
					_finish(false, "Online builder did not finish: " + str(animal.get_node("CreatureBuilder").snapshot()))
					return
			var dug: int = workers[2].get_node("CreatureBuilder").dug_total
			if dug <= 0 or volume.blocks.count(bedrock) != protected_cells or not is_equal_approx(game.get_player(2).matter, 300.0 - 48.0 - dug * .3):
				_finish(false, "Online digging or builder economy failed")
				return
			await create_timer(1.5).timeout
			for product in get_nodes_in_group("creature_builder_products"): product.thing.take_damage(1000.0, "explosive", caster)
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec() + 14000
			var beaver = null
			var ant = null
			while (beaver == null or ant == null) and Time.get_ticks_msec() < until:
				for item in game.get_node("Things").get_children():
					if item.thing_id == "beaver": beaver = item
					if item.thing_id == "ant": ant = item
				await create_timer(.05).timeout
			if beaver == null or ant == null:
				_finish(false, "Builder animals did not replicate")
				return
			root.get_node("Forge").request(2, "castores me sigam", false, true)
			var seen := false
			while not seen and Time.get_ticks_msec() < until:
				var products := 0
				for product in get_nodes_in_group("creature_builder_products"):
					if not product.thing.is_dead: products += 1
				seen = products == 2 and ant.get_node("CreatureBuilder").completed == 1 and not volume.network_changes.is_empty()
				await create_timer(.05).timeout
			if not seen or ant.get_node("CreatureBuilder").dug_total <= 0 or volume.blocks.count(bedrock) != protected_cells:
				_finish(false, "Constructions, digging or progress did not replicate")
				return
			var removed := false
			while not removed and Time.get_ticks_msec() < until:
				removed = true
				for product in get_nodes_in_group("creature_builder_products"):
					if not product.thing.is_dead: removed = false
				await create_timer(.05).timeout
			if not removed:
				_finish(false, "Construction destruction did not replicate")
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-creature-combos"):
		await create_timer(3.3).timeout
		var status = load("res://scripts/things/status.gd")
		var effects = load("res://scripts/fx/pokemon_fx.gd")
		if role == "host":
			var a = load("res://scripts/things/assembler.gd")
			var r = load("res://scripts/language/recipe.gd")
			var caster = a.build(r.new_node("pistol"), "head", root.get_node("Lexicon").data)
			caster.set_owner_info(2, 2, game.get_player(2), game.get_player(2))
			game.add_thing(caster)
			for id in [1, 2]:
				game.get_player(id).set_physics_process(false)
				game.get_player(id).global_position = Vector3(15 if id == 1 else 0, 20, 4)
			for species in ["squirtle", "pikachu", "bulbasaur", "charmander"]:
				await create_timer(.12).timeout
				var animal = root.get_node("Forge").spawn_child(r.new_node(species), "spawned", Vector3(0, 20, 0), Vector3.FORWARD, caster, 0.0)
				if animal == null:
					_finish(false, "Cannot spawn combo companion")
					return
				animal.move.set_physics_process(false)
				animal.set_physics_process(false)
			caster.set_owner_info(1, 1, game.get_player(1), game.get_player(1))
			await create_timer(.12).timeout
			var victim = root.get_node("Forge").spawn_child(r.new_node("elephant"), "spawned", Vector3(0, 20, -5), Vector3.FORWARD, caster, 0.0)
			if victim == null:
				_finish(false, "Cannot spawn combo target")
				return
			victim.hp = 5000.0
			victim.max_hp = 5000.0
			victim.move.set_physics_process(false)
			victim.set_physics_process(false)
			var combos = load("res://scripts/things/creature_combos.gd")
			var until := Time.get_ticks_msec() + 12000
			while combos.count < 2 and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if combos.count != 2 or victim.hp >= 4900.0 or status.snapshot(victim).has("entangled") or not status.snapshot(victim).has("combo_vine_lock"):
				_finish(false, "Remote combo damage or state failed on host")
				return
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec() + 12000
			var victim = null
			var ready := false
			while not ready and Time.get_ticks_msec() < until:
				var found := 0
				for item in game.get_node("Things").get_children():
					if item.thing_id in ["squirtle", "pikachu", "bulbasaur", "charmander"]: found += 1
					if item.thing_id == "elephant": victim = item
				ready = found == 4 and victim != null
				await create_timer(.05).timeout
			if not ready:
				_finish(false, "Combo companions did not replicate")
				return
			game.player.look_at_point(victim.center())
			root.get_node("Forge").request(2, "squirtle jato de agua", false, true)
			while not status.snapshot(victim).has("wet") and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if not status.snapshot(victim).has("wet") or victim.get_node_or_null("Status/CreatureComboMarks") == null:
				_finish(false, "Wet state or visual did not replicate")
				return
			root.get_node("Forge").request(2, "pikachu choque do trovao", false, true)
			while (effects.combo_count < 1 or status.snapshot(victim).has("wet")) and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if effects.last_combo != "conductive" or status.snapshot(victim).has("wet"):
				_finish(false, "Conductive reaction did not replicate")
				return
			root.get_node("Forge").request(2, "bulbasaur chicote de cipo", false, true)
			while not status.snapshot(victim).has("entangled") and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if not status.movement_locked(victim):
				_finish(false, "Vine binding did not replicate")
				return
			root.get_node("Forge").request(2, "charmander brasa", false, true)
			while (effects.combo_count < 2 or status.snapshot(victim).has("entangled")) and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if effects.combo_count != 2 or effects.last_combo != "vine_fire" or status.movement_locked(victim) or victim.hp >= 4900.0:
				_finish(false, "Vine fire damage, release or effect did not replicate")
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-pokemon-evolution"):
		await create_timer(3.3).timeout
		if role == "host":
			var a = load("res://scripts/things/assembler.gd")
			var r = load("res://scripts/language/recipe.gd")
			var caster = a.build(r.new_node("pistol"), "head", root.get_node("Lexicon").data)
			caster.set_owner_info(2, 2, game.get_player(2), game.get_player(2))
			game.add_thing(caster)
			var actor = root.get_node("Forge").spawn_child(r.new_node("charmander"), "spawned", Vector3(0, 20, 0), Vector3.FORWARD, caster, 0.0)
			if actor == null:
				_finish(false, "Cannot spawn evolution fixture")
				return
			actor.move.set_physics_process(false)
			actor.set_physics_process(false)
			actor.hp = actor.max_hp * .4
			actor.get_node("PokemonCompanion").experience = 180.0
			for id in [1, 2]:
				game.get_player(id).set_physics_process(false)
				game.get_player(id).global_position = Vector3(12 if id == 1 else 0, 20, 3)
			game.get_player(2).matter = 300.0
			var until := Time.get_ticks_msec() + 10000
			while actor.thing_id != "charizard" and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if actor.thing_id != "charizard" or actor.get_node("PokemonCompanion").experience != 50.0 or not is_equal_approx(game.get_player(2).matter, 85.0):
				_finish(false, "Remote evolution lost XP, form or matter on host")
				return
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec() + 10000
			var actor = null
			while actor == null and Time.get_ticks_msec() < until:
				for item in game.get_node("Things").get_children():
					var power = item.get_node_or_null("PokemonCompanion")
					if item.thing_id == "charmander" and power != null and power.experience == 180.0: actor = item
				await create_timer(.05).timeout
			if actor == null:
				_finish(false, "Initial Pokemon progression did not replicate")
				return
			var identity: int = actor.network_id
			root.get_node("Forge").request(2, "charmander evolua", false, true)
			while actor.thing_id != "charmeleon" and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			root.get_node("Forge").request(2, "charmeleon evolua", false, true)
			while actor.thing_id != "charizard" and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if actor.thing_id != "charizard" or actor.network_id != identity or actor.get_node("PokemonCompanion").experience != 50.0 or not actor.move.hovers() or not is_equal_approx(actor.hp / actor.max_hp, .4):
				_finish(false, "Evolved form, flight or progression did not replicate")
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-pokemon"):
		await create_timer(3.3).timeout
		var effects = load("res://scripts/fx/pokemon_fx.gd")
		if role == "host":
			var r = load("res://scripts/language/recipe.gd")
			var a = load("res://scripts/things/assembler.gd")
			var caster = a.build(r.new_node("pistol"), "head", root.get_node("Lexicon").data)
			caster.set_owner_info(2, 2, game.get_player(2), game.get_player(2))
			game.add_thing(caster)
			var forge = root.get_node("Forge")
			var pikachu = forge.spawn_child(r.new_node("pikachu"), "spawned", Vector3(0, 20, 0), Vector3.FORWARD, caster, 0.0)
			await process_frame
			caster.set_owner_info(1, 1, game.get_player(1), game.get_player(1))
			var prey = forge.spawn_child(r.new_node("squirtle"), "spawned", Vector3(0, 20, -7), Vector3.FORWARD, caster, 0.0)
			if pikachu == null or prey == null:
				_finish(false, "Pokemon network fixture could not spawn")
				return
			for animal in [pikachu, prey]:
				animal.move.set_physics_process(false)
				animal.set_physics_process(false)
			for id in [1, 2]:
				game.get_player(id).set_physics_process(false)
				game.get_player(id).global_position = Vector3(12 if id == 1 else 0, 20, 3)
			game.get_player(2).look_at_point(prey.center())
			var hp: float = prey.hp
			var until := Time.get_ticks_msec() + 6000
			while effects.count == 0 and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if effects.count != 1 or prey.hp >= hp or pikachu.get_node("PokemonCompanion").last_move != "thunderbolt":
				_finish(false, "Remote Pokemon order did not execute on host")
				return
			if game.get_player(2).hands.current_item() != null:
				_finish(false, "Command-only voice created an item on the host")
				return
			await create_timer(1.0).timeout
		else:
			var until := Time.get_ticks_msec() + 6000
			var ready := false
			while not ready and Time.get_ticks_msec() < until:
				var found := 0
				for item in game.get_node("Things").get_children():
					if item.thing_id in ["pikachu", "squirtle"]: found += 1
				ready = found == 2
				await create_timer(.05).timeout
			if not ready:
				_finish(false, "Pokemon models did not replicate")
				return
			root.get_node("Forge").request(2, "quero uma pistola", false, true)
			root.get_node("Forge").request(2, "picachu ataque", false, true)
			while effects.count == 0 and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if effects.count != 1 or effects.last_style != "electric":
				_finish(false, "Pokemon attack effect did not reach remote player")
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-void-duel"):
		await create_timer(3.3).timeout
		var status = load("res://scripts/things/status.gd")
		if role == "host":
			for id in [1, 2]:
				game.get_player(id).set_physics_process(false)
				game.get_player(id).global_position = Vector3(0, 20, 7 if id == 1 else -7)
			var a = load("res://scripts/things/assembler.gd")
			var r = load("res://scripts/language/recipe.gd")
			var item = a.build(r.new_node("unlimited_void"), "head", root.get_node("Lexicon").data)
			item.set_owner_info(1, 1, game.get_player(1), null)
			game.get_player(1).hands.give(item, false)
			item.activate()
			session.creations.publish_creation(item, 0.0, true, 0.0)
			if not root.get_node("Forge").request(1, "expansão de domínio", false, true).has("domain_expanded"):
				_finish(false, "Could not expand Gojo domain in duel")
				return
			await create_timer(2.0).timeout
			if not status.paralyzed(game.get_player(2)) or status.paralyzed(game.get_player(1)):
				_finish(false, "Host did not paralyze only the opponent")
				return
			item.get_node("Jujutsu").cancel_domain()
			await create_timer(2.0).timeout
		else:
			var until := Time.get_ticks_msec() + 5500
			var caught := false
			while Time.get_ticks_msec() < until:
				if status.paralyzed(game.player):
					caught = true
					break
				await create_timer(.05).timeout
			if not caught or game.player.can_act():
				_finish(false, "Paralysis did not replicate to second player's controls")
				return
			var inside := false
			for environment in get_nodes_in_group("domain_environments"):
				if environment.mode == "void" and game.player.center().distance_to(environment.global_position) < 9.0 and game.opponent.center().distance_to(environment.global_position) < 9.0: inside = true
			if not inside:
				_finish(false, "Remote sphere did not enclose both players")
				return
			while status.paralyzed(game.player) and Time.get_ticks_msec() < until: await create_timer(.05).timeout
			if status.paralyzed(game.player) or not game.player.can_act():
				_finish(false, "Remote controls did not recover after domain cancellation")
				return
			await create_timer(.3).timeout
	elif OS.get_cmdline_user_args().has("--test-domain-command"):
		await create_timer(3.3).timeout
		var spoken = load("res://scripts/fx/domain_callout.gd")
		if role == "host":
			var r = load("res://scripts/language/recipe.gd")
			var a = load("res://scripts/things/assembler.gd")
			var forge = root.get_node("Forge")
			for id in ["unlimited_void", "malevolent_shrine"]:
				var item = a.build(r.new_node(id),"head",root.get_node("Lexicon").data)
				item.set_owner_info(1,1,game.get_player(1),null)
				game.get_player(1).hands.give(item,false)
				item.activate()
				session.creations.publish_creation(item,0.0,true,0.0)
				var reply = forge.request(1,"expansão de domínio")
				if not reply.has("domain_expanded"):
					_finish(false,"Host domain command failed")
					return
				await create_timer(.8).timeout
			await create_timer(1.5).timeout
		else:
			var deadline := Time.get_ticks_msec() + 5000
			var found := false
			while not found and Time.get_ticks_msec() < deadline:
				for environment in get_nodes_in_group("domain_environments"):
					if environment.mode == "shrine" and environment.get_node_or_null("MalevolentShrineAltar") != null and environment.get_node_or_null("ClosedShrineBarrier") != null: found = true
				await create_timer(.05).timeout
			if spoken.count != 0:
				_finish(false,"Domain dialogue should remain silent on the second player")
				return
			if not found:
				_finish(false, "Persistent shrine environment did not reach the second player")
				return
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
