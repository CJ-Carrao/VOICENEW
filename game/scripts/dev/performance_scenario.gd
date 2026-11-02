extends Node



const DEVICE_ID: = 126
const MIN_EXPLOSIVE_TEST_DISTANCE: = 10.0
const MOVE_ACTIONS: = ["move_forward", "move_back", "move_left", "move_right", "sprint"]

var scenario: = ""
var match_node: Match
var player: Player
var measuring: = false
var stopped: = false
var counters: = {}
var failures: Array[String] = []
var _held: = {}
var _pulse_until: = {}
var _time: = 0.0
var _last_request: = -100.0
var _last_fire: = -100.0
var _last_matter: = 0.0
var _last_position: = Vector3.ZERO
var _last_direction: = Vector3.FORWARD
var _last_up: = Vector3.UP
var _was_grounded: = true
var _received_this_tick: = false
var _target: Structure
var _target_point: = Vector3.INF
var _retarget_at: = 0.0
var _spending_until: = 0.0
var _spend_point: = Vector3.ZERO
var _spend_requested: = false
var _observed_state: = ""
var _awaiting_next_round: = false
var _connected_volumes: = {}
var _next_scan: = 0.0
var _initial_pose_applied: = false
var _snapshots_sent_start: = 0
var _snapshots_received_start: = 0
var _initial_matter: = 0.0
var _explosion_tick: = -100
var _extraction_windows: = {}


func configure(id: String, scene: Node) -> void :
	scenario = "four_players" if id.begins_with("four_players") else id
	match_node = scene as Match
	if match_node != null:
		player = match_node.player
	if scenario not in ["menu", "arena_walk", "extraction", "explosions", "space", "bot_duel", "four_players"]:
		failures.append("Cenário automático desconhecido: " + scenario)
	if scenario != "menu" and player == null:
		failures.append("Partida/jogador indisponível")
	if not OS.is_debug_build():
		failures.append("Automação disponível somente em debug")
	if Forge.test_free_matter or Forge.test_instant_builds:
		failures.append("Economia ou montagem de teste habilitada")
	stopped = not failures.is_empty()


func _ready() -> void :
	process_priority = 100
	_reset_counters()
	if player == null or stopped:
		return
	_last_matter = player.matter
	_initial_matter = player.matter
	player.matter_changed.connect(_on_matter)
	player.hands.used.connect(_on_used)
	Forge.exploded.connect(_on_exploded)
	Forge.build_finished.connect(_on_built)
	Forge.request_processed.connect(_on_request_result)
	match_node.state_changed.connect(_on_state_changed)
	_observed_state = match_node.state

	match_node.voice.player = player
	if scenario in ["extraction", "explosions"] and not Session.is_online():
		_find_source()
		if _target_point != Vector3.INF:
			var away: = (player.global_position - _target_point).slide(Vector3.UP).normalized()
			if away.is_zero_approx(): away = Vector3.BACK
			var spot: = _target_point + away * Match.DEV_EXTRACT_DISTANCE
			var height: = match_node.arena.terrain.height_at(spot.x, spot.z) if match_node.arena.terrain != null else player.position.y
			player.global_position = Vector3(spot.x, height + 0.1, spot.z)
			player.velocity = Vector3.ZERO
			player.look_at_point(_target_point)
			_initial_pose_applied = true
	_capture_baseline()


func begin_measurement() -> void :
	_reset_counters()
	_capture_baseline()
	measuring = true


func _reset_counters() -> void :
	_extraction_windows.clear()
	_awaiting_next_round = false
	counters = {"observed_s": 0.0, "controllable_s": 0.0, "distance_m": 0.0, "moving_s": 0.0, 
		"look_turn_rad": 0.0, "gravity_up_turn_rad": 0.0, "jumps_observed": 0, 
		"matter_received_while_extracting": 0.0, "matter_spent_or_lost": 0.0, "extraction_receiving_s": 0.0, 
		"extraction_use_held_s": 0.0, "extraction_gain_windows_5s": 0, 
		"shots_observed": 0, "explosions_observed": 0, "requests_sent": 0, "requests_rejected": 0, 
		"builds_finished": 0, "rounds_completed": 0, "rounds_started": 0, "rounds_restarted": 0, "four_connected_s": 0.0, 
		"max_connected_players": 0, "world_cells_removed": 0, "teleports_excluded": 0, 
		"snapshots_sent": 0, "snapshots_received": 0, "world_cells_removed_in_explosion_tick": 0}
	counters.merge({"menu_visible_s": 0.0})


func _capture_baseline() -> void :
	_snapshots_sent_start = int(Session.replication.stats.snapshots_sent)
	_snapshots_received_start = int(Session.replication.stats.snapshots_received)
	if not is_instance_valid(player): return
	_last_position = player.global_position
	_last_direction = player.look_ray().direction
	_last_up = player.up()
	_last_matter = player.matter
	_was_grounded = player.grounded()
	_received_this_tick = false


func _physics_process(delta: float) -> void :
	if stopped: return
	_time += delta
	for action: String in _pulse_until.keys():
		if _time >= float(_pulse_until[action]):
			_set_action(action, false)
			_pulse_until.erase(action)
	if measuring:
		counters.observed_s += delta
	if scenario == "menu":
		_observe_menu(delta)
		return
	if not is_instance_valid(player) or not is_instance_valid(match_node):
		failures.append("A cena terminou durante a medição")
		stop()
		return
	_observe(delta)
	if _time >= _next_scan:
		_next_scan = _time + 1.0
		_watch_volumes()
	if match_node.state == "match_over":
		_release_actions()
		if fmod(_time, 2.0) < delta: _pulse("jump")
		return
	if not player.input_enabled or not player.can_act() or get_tree().paused:
		_release_actions()
		return
	match scenario:
		"arena_walk", "space", "four_players": _walk(delta)
		"extraction": _extract_workload(delta)
		"explosions": _weapon_workload(delta, true)
		"bot_duel": _weapon_workload(delta, false)


func _observe_menu(delta: float) -> void :
	var scene: = get_tree().current_scene
	if scene == null or scene.get_script() != load("res://scenes/intro/intro.gd"):
		failures.append("Menu deixou de ser a cena visível")
		stop()
		return
	var menu: = scene.get("_menu") as MainMenu
	if not measuring: return
	if menu != null and menu.is_visible_in_tree() and menu.ready_for_input:
		counters.menu_visible_s += delta


func _observe(delta: float) -> void :
	var at: = player.global_position
	var direction: Vector3 = player.look_ray().direction
	var up: = player.up()
	var grounded: = player.grounded()
	if measuring:
		if player.input_enabled and player.can_act(): counters.controllable_s += delta
		var distance: = at.distance_to(_last_position)

		if distance <= maxf(2.0, player.velocity.length() * delta * 2.0 + 0.5):
			counters.distance_m += distance
			if distance > 0.001: counters.moving_s += delta
		else:
			counters.teleports_excluded += 1
		counters.look_turn_rad += _last_direction.angle_to(direction)
		counters.gravity_up_turn_rad += _last_up.angle_to(up)
		if _was_grounded and not grounded and Input.is_action_pressed("jump"):
			counters.jumps_observed += 1
		if _received_this_tick: counters.extraction_receiving_s += delta
		if player.extracting and player.can_act() and Input.is_action_pressed("use"):
			counters.extraction_use_held_s += delta
		var connected: = 0
		if Session.is_online():
			for id: int in Session.player_ids():
				if Session.peer_for_player(id) > 0: connected += 1
		counters.max_connected_players = maxi(counters.max_connected_players, connected)
		if connected == 4 and Session.replication.is_active(): counters.four_connected_s += delta
		counters.snapshots_sent = maxi(0, int(Session.replication.stats.snapshots_sent) - _snapshots_sent_start)
		counters.snapshots_received = maxi(0, int(Session.replication.stats.snapshots_received) - _snapshots_received_start)
	_last_position = at
	_last_direction = direction
	_last_up = up
	_was_grounded = grounded
	_received_this_tick = false


func _walk(delta: float) -> void :
	_set_move("move_forward", true)
	_set_action("sprint", fmod(_time, 18.0) < 10.0)

	_mouse(Vector2((90.0 if fmod(_time, 36.0) < 18.0 else -70.0) * delta, 0.0))
	if fmod(_time, 4.0) < delta: _pulse("jump", 0.2)
	if scenario == "space" and fmod(_time, 14.0) < delta:
		_pulse("crouch", 0.1)
		_pulse("jump", 0.25)


func _extract_workload(delta: float) -> void :
	if _spending_until > _time:
		_set_move("", false)
		_set_action("use", false)
		_ensure_extraction(false)
		if _aim_at(_spend_point, delta) < 0.15 and not _spend_requested:
			_request("quero uma torre gigante")
			_spend_requested = true
		if player.shaper.active: _pulse("use")
		return
	if player.matter > player.max_matter * 0.85 and not Forge.is_building(player.player_id):
		_set_action("use", false)
		_spending_until = _time + 3.0
		_spend_requested = false
		_spend_point = player.global_position - (player.look_ray().direction as Vector3).slide(player.up()).normalized() * 8.0
		return
	_extract(delta)


func _weapon_workload(delta: float, explosive: bool) -> void :
	var item: = player.hands.current_item()
	var weapon_id: = "rocket_launcher" if explosive else "rifle"

	if Forge.is_building(player.player_id):
		var waiting_matter: = false
		for pending: Thing in Forge.builds(player.player_id):
			if is_instance_valid(pending) and not pending.is_dead and Forge.build_waiting_matter(pending):
				waiting_matter = true
		if waiting_matter: _extract(delta)
		else: _release_actions()
		return
	if item != null and (item.is_dead or item.is_queued_for_deletion() or item.is_building or item.loading):
		_release_actions()
		return
	if item == null or String(item.node_data.get("thing", "")) != weapon_id:
		if player.shaper.active:
			_pulse("use")
		elif player.matter >= (150.0 if explosive else 60.0):
			_set_action("use", false)
			_ensure_extraction(false)
			_request("quero uma bazuca gigante" if explosive else "quero um rifle")
		else:
			_extract(delta)
		return
	if item.ammo <= 0:
		if item.magazine <= 0:
			failures.append("A arma selecionada não usa pente; recarga automática indisponível")
			stop()
			return
		if player.matter < 30.0:
			_extract(delta)
		elif _time - _last_request >= 4.0:
			_set_action("use", false)
			_ensure_extraction(false)
			_request("quero um pente")
		return
	_set_action("use", false)
	_ensure_extraction(false)
	if explosive:
		_update_source()
	else:
		var opponent: = match_node.get_opponent(player.player_id)
		_target_point = opponent.center() if opponent != null else Vector3.INF
	if _target_point == Vector3.INF: return
	var distance: = player.global_position.distance_to(_target_point)
	_set_move("move_back" if explosive and distance < 14.0 else ("move_forward" if distance > 22.0 else ""), true)
	var angle: = _aim_at(_target_point, delta)


	if angle < 0.12 and ( not explosive or distance >= MIN_EXPLOSIVE_TEST_DISTANCE)\
	and _time - _last_fire >= (1.5 if explosive else 0.2):
		_last_fire = _time
		_pulse("use")


func _extract(delta: float) -> void :
	_update_source()
	if _target_point == Vector3.INF:
		_release_actions()
		return
	_ensure_extraction(true)
	var angle: = _aim_at(_target_point, delta)
	var distance: = player.camera.global_position.distance_to(_target_point)
	_set_move("move_forward" if distance > 3.5 else "", true)
	_set_action("use", angle < 0.2 and distance < Lexicon.balf("extraction.range_m") - 0.25)
	if distance > 3.5 and fmod(_time, 3.0) < delta: _pulse("jump", 0.2)


func _update_source() -> void :
	if _time < _retarget_at and is_instance_valid(_target): return
	_retarget_at = _time + 0.8
	_find_source()


func _find_source() -> void :
	_target_point = Vector3.INF
	_target = null
	var nearest: = INF
	for structure: Structure in match_node.arena.structures():
		if structure.distance_hint(player.global_position) >= nearest: continue
		var point: = structure.facing_chunk_point(player.global_position)
		if point == Vector3.INF: continue
		var distance: = player.global_position.distance_to(point)
		if distance < nearest:
			nearest = distance
			_target_point = point
			_target = structure


func _aim_at(point: Vector3, delta: float) -> float:
	var direction: = (point - player.camera.global_position).normalized()
	var local: = player.gravity_frame.transposed() * direction


	var actual: = player.gravity_frame.transposed() * (player.look_ray().direction as Vector3)
	var yaw_error: = angle_difference(atan2( - actual.x, - actual.z), atan2( - local.x, - local.z))
	var pitch_error: = atan2(local.y, Vector2(local.x, local.z).length()) - atan2(actual.y, Vector2(actual.x, actual.z).length())
	var sensitivity: = maxf(player._mouse_sensitivity * player.camera.fov / maxf(player._base_fov, 1.0), 1e-05)

	_mouse(Vector2( - clampf(yaw_error * 0.35, - delta * 2.0, delta * 2.0), - clampf(pitch_error * 0.35, - delta * 2.0, delta * 2.0)) / sensitivity)
	return (player.look_ray().direction as Vector3).angle_to(direction)


func _mouse(relative: Vector2) -> void :
	var event: = InputEventMouseMotion.new()
	event.device = DEVICE_ID
	event.relative = get_viewport().get_final_transform().basis_xform(relative)
	event.screen_relative = event.relative
	Input.parse_input_event(event)


func _ensure_extraction(on: bool) -> void :
	if player.extracting == on: return
	_set_action("use", false)
	_set_action("talk", true)
	_set_action("talk", false)


func _set_move(action: String, pressed: bool) -> void :
	for candidate: String in MOVE_ACTIONS:
		_set_action(candidate, pressed and candidate == action)


func _set_action(action: String, pressed: bool) -> void :
	if bool(_held.get(action, false)) == pressed: return
	_held[action] = pressed
	var event: = InputEventAction.new()
	event.device = DEVICE_ID
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _pulse(action: String, seconds: float = 0.05) -> void :
	if bool(_held.get(action, false)): return
	_set_action(action, true)
	_pulse_until[action] = _time + seconds


func _request(text: String) -> void :
	if _time - _last_request < 1.0: return
	_last_request = _time
	if measuring: counters.requests_sent += 1
	Forge.request(player.player_id, text)


func _on_matter(current: float, _capacity: float) -> void :
	var change: = current - _last_matter
	if measuring:
		if change > 0.0 and player.extracting and player.extractor.pulling:
			counters.matter_received_while_extracting += change
			_received_this_tick = true
			_extraction_windows[int(float(counters.observed_s) / 5.0)] = true
			counters.extraction_gain_windows_5s = _extraction_windows.size()
		elif change < 0.0: counters.matter_spent_or_lost -= change
	_last_matter = current


func _on_used(_item: Thing, kind: String) -> void :
	if measuring and kind == "fire": counters.shots_observed += 1


func _on_exploded(id: int) -> void :
	if id != player.player_id: return
	_explosion_tick = Engine.get_physics_frames()
	if measuring: counters.explosions_observed += 1


func _on_built(id: int, thing: Thing) -> void :
	if measuring and id == player.player_id and is_instance_valid(thing) and not thing.is_dead and not thing.is_building:
		counters.builds_finished += 1


func _on_request_result(id: int, _text: String, result: Dictionary) -> void :
	if measuring and id == player.player_id and ( not result.get("ok", false) or result.get("blocked", false)):
		counters.requests_rejected += 1


func _on_state_changed() -> void :
	_record_round_state(match_node.state)


func _record_round_state(next_state: String) -> void :
	if measuring and next_state != _observed_state:
		if next_state in ["round_over", "match_over"]:
			counters.rounds_completed += 1
			_awaiting_next_round = true
		if next_state in ["fight", "online_play"]:
			counters.rounds_started += 1
			if _awaiting_next_round:
				counters.rounds_restarted += 1
				_awaiting_next_round = false
	_observed_state = next_state


func _watch_volumes() -> void :
	for volume: Node in get_tree().get_nodes_in_group(BlockVolume.GROUP):
		var id: = volume.get_instance_id()
		if not _connected_volumes.has(id):
			_connected_volumes[id] = true
			(volume as BlockVolume).cells_changed.connect(_on_cells_changed)


func _on_cells_changed(changes: Dictionary) -> void :
	if not measuring: return
	for value: int in changes.values():
		if value == BlockVolume.AIR:
			counters.world_cells_removed += 1
			if Engine.get_physics_frames() == _explosion_tick:
				counters.world_cells_removed_in_explosion_tick += 1


static func criteria_for(id: String, values: Dictionary) -> Dictionary:
	var seconds: = float(values.get("observed_s", 0.0))
	var moving: = float(values.get("distance_m", 0.0)) >= maxf(5.0, seconds * 0.3)
	var looking: = float(values.get("look_turn_rad", 0.0)) >= 1.0
	var checks: = {"observed_at_least_one_second": seconds >= 1.0}
	match id:
		"menu": checks.merge({"menu_visible_for_90_percent": float(values.get("menu_visible_s", 0.0)) >= seconds * 0.9})
		"arena_walk": checks.merge({"distance_at_least_max_5m_or_0_3m_per_second": moving, "look_turn_at_least_1rad": looking})
		"space": checks.merge({"distance_at_least_max_5m_or_0_3m_per_second": moving, "look_turn_at_least_1rad": looking, 
			"jump_observed": int(values.get("jumps_observed", 0)) > 0, "gravity_up_changed_0_25rad": float(values.get("gravity_up_turn_rad", 0.0)) >= 0.25})
		"extraction": checks.merge({"received_at_least_10_matter": float(values.get("matter_received_while_extracting", 0.0)) >= 10.0, 

			"extraction_held_for_at_least_45_percent_observation": float(values.get("extraction_use_held_s", 0.0)) >= seconds * 0.45, 
			"matter_gain_in_at_least_half_5s_windows": int(values.get("extraction_gain_windows_5s", 0)) >= maxi(1, ceili(seconds / 5.0 * 0.5)), 
			"world_cells_removed": int(values.get("world_cells_removed", 0)) > 0})
		"explosions": checks.merge({"two_actual_shots": int(values.get("shots_observed", 0)) >= 2, 
			"two_actual_explosions": int(values.get("explosions_observed", 0)) >= 2, 
			"world_cells_removed_in_explosion_tick": int(values.get("world_cells_removed_in_explosion_tick", 0)) > 0})
		"bot_duel": checks.merge({"actual_shot": int(values.get("shots_observed", 0)) > 0, 
			"round_completed": int(values.get("rounds_completed", 0)) > 0, "next_round_started": int(values.get("rounds_restarted", 0)) > 0})
		"four_players": checks.merge({"four_connected_for_90_percent": float(values.get("four_connected_s", 0.0)) >= seconds * 0.9, 
			"distance_at_least_max_5m_or_0_3m_per_second": moving, "look_turn_at_least_1rad": looking, 
			"actual_replication_snapshots": int(values.get("snapshots_sent", 0)) + int(values.get("snapshots_received", 0)) > 0})
		_: checks["supported_scenario"] = false
	return checks


func snapshot() -> Dictionary:
	var criteria: = criteria_for(scenario, counters)
	var passed: = failures.is_empty() and not criteria.values().has(false)
	var last_state: = {}
	if is_instance_valid(player):
		var item: = player.hands.current_item()
		last_state = {"matter": player.matter, "extracting": player.extracting, "extraction_problem": player.extractor.problem, 
			"mouse_captured": Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "held_use": player.hands.is_using(), 
			"target_distance_m": player.camera.global_position.distance_to(_target_point) if _target_point != Vector3.INF else -1.0, 
			"target_angle_rad": (player.look_ray().direction as Vector3).angle_to((_target_point - player.camera.global_position).normalized()) if _target_point != Vector3.INF else -1.0, 
			"weapon": item.thing_id if item != null else "", "ammo": item.ammo if item != null else 0}
	return {"automatic": true, "scenario": scenario, "counters": counters.duplicate(), "criteria": criteria, 
		"activity_verified": passed, "failures": failures.duplicate(), "initial_pose_applied": _initial_pose_applied, 
		"initial_matter": _initial_matter, "last_state": last_state, 
		"workload": "walking/no-combat" if scenario == "four_players" else scenario, 
		"scope": "Carga automática; não comprova ergonomia, VoIP ou participantes humanos. Four_players exercita locomoção de quatro processos conectados.", 
		"input": "InputEventAction + InputEventMouseMotion; pedidos via Forge.request; economia normal"}


func _release_actions() -> void :
	for action: String in _held.keys(): _set_action(action, false)
	_pulse_until.clear()


func stop() -> void :
	stopped = true
	_release_actions()


func _exit_tree() -> void :
	_release_actions()
