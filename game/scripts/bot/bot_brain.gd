class_name BotBrain
extends Node














var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value


		if not value and _bot != null:
			_bot.release_input()

var _bot: Player
var _rng: = RandomNumberGenerator.new()
var _cfg: Dictionary = {}
var _think: float = 0.0
var _source: = Vector3.INF
var _source_left: float = 0.0
var _until_request: float = 0.0
var _strafe: float = 1.0
var _until_strafe_change: float = 0.0
var _aim_offset: Vector3 = Vector3.ZERO
var _pilot_time: float = 0.0

var _gathering: bool = false
var _gather_target: float = 0.0
var _gather_time: float = 0.0
var _planned: String = ""


var _travel_phase: int = 0
var _travel_time: float = 0.0


func _ready() -> void :
	_bot = get_parent() as Player
	_cfg = Lexicon.bal("bot", {})
	_rng.randomize()



func set_seed(value: int) -> void :
	_rng.seed = value



func reset() -> void :
	_think = 0.0
	_until_request = _rng.randf_range(0.5, 1.5)
	_pilot_time = 0.0
	_travel_phase = 0
	_travel_time = 0.0
	_gathering = false
	_planned = ""
	if _bot != null:
		_bot.release_input()
		_bot.set_extracting(false)


func _physics_process(delta: float) -> void :
	if _bot == null:
		return
	if not enabled:
		return
	if not _bot.can_act():
		_bot.release_input()
		return
	var enemy: = Combat.nearest_enemy(_bot.center(), _bot.team, get_tree())
	if _bot.piloting != null:
		_pilot(enemy, delta)
		return
	if _gathering:
		_gather(delta)
		return
	if _travel(enemy, delta):
		return
	_move(enemy, delta)
	_think -= delta
	_until_request -= delta
	if _think <= 0.0:
		_think = _f("reaction_s")
		_decide()
		_roll_aim_error(enemy)
	_aim_and_use(enemy)



func _decide() -> void :
	if Forge.is_assembling(_bot.player_id):
		return
	if _waiting_matter():
		_start_gathering("", _bot.matter + _f("extract_target_min"))
		return
	if Forge.is_building(_bot.player_id):
		return
	var item: = _bot.hands.current_item()
	if item != null and item.magazine > 0 and item.ammo <= 0 and not item.loading:
		var reload: = compose_request("reload")
		if not reload.is_empty():
			_request_or_gather(reload)
			return
	if item == null or _until_request <= 0.0:
		_until_request = _rng.randf_range(_f("request_interval_min_s"), _f("request_interval_max_s"))
		var text: = compose_request("armed" if _bot.hands.current_item() == null else "any")
		if not text.is_empty():
			_request_or_gather(text)



func _request_or_gather(text: String) -> void :
	var recipe: Dictionary = PhraseParser.parse(text, Lexicon.data).get("recipe", {})
	var cost: = Forge.cost_for(_bot.player_id, recipe)

	if Forge.matter_for(_bot.player_id, recipe) + 0.001 >= cost:
		_request(text)
		return
	_start_gathering(text, maxf(cost * _f("extract_margin"), _f("extract_target_min")))



func _request(text: String) -> void :
	Forge.request(_bot.player_id, text)
	if Forge.has_draft(_bot.player_id):
		Forge.confirm_draft(_bot.player_id)


func _waiting_matter() -> bool:
	for thing: Thing in Forge.builds(_bot.player_id):
		if Forge.build_waiting_matter(thing):
			return true
	return false


func _start_gathering(text: String, target: float) -> void :
	_gathering = true
	_planned = text
	_gather_target = minf(target, _bot.max_matter)
	_gather_time = 0.0




func _gather(delta: float) -> void :
	_gather_time += delta
	if _bot.matter >= _gather_target - 0.001 or _gather_time > _f("extract_give_up_s") or _bot.is_full_of_matter():
		_gathering = false
		_bot.set_extracting(false)
		_bot.control_wish = Vector2.ZERO
		if not _planned.is_empty():
			var text: = _planned
			_planned = ""
			_request(text)
		return

	_source_left -= delta
	if _source_left <= 0.0 or _source == Vector3.INF:
		_source_left = 0.3
		_source = _nearest_source()
	var source: = _source
	if source == Vector3.INF:
		_gather_time = INF
		return
	_bot.aiming = false
	_bot.look_at_point(source)
	var flat: = Gravity.flat(source - _bot.global_position, _bot.up()).length()
	var close: = flat <= Lexicon.balf("extraction.range_m") * 0.6
	_bot.control_wish = Vector2(0.0, 0.0 if close else -1.0)
	_bot.control_jump = false
	_bot.set_extracting(true)
	if close or not _bot.extractor.target().is_empty():
		_bot.hands.use_pressed()
	else:
		_bot.hands.use_released()



func _nearest_source() -> Vector3:
	var from: = _bot.global_position
	var best: = Vector3.INF
	var best_d: = INF
	for node in get_tree().get_nodes_in_group(Structure.STRUCTURES):
		var structure: = node as Structure
		if structure.is_queued_for_deletion() or pow(structure.distance_hint(from), 2.0) >= best_d:
			continue
		var point: = structure.nearest_chunk_point(from)
		if point != Vector3.INF and point.distance_squared_to(from) < best_d:
			best_d = point.distance_squared_to(from)
			best = point
	for node in get_tree().get_nodes_in_group(Rubble.GROUP):
		var pile: = node as Rubble
		if pile.is_queued_for_deletion():
			continue
		var point: = pile.extract_point(-1, pile.global_position)
		if point.distance_squared_to(from) < best_d:
			best_d = point.distance_squared_to(from)
			best = point

	if Gravity.active() and _bot.is_on_floor() and best_d > pow(_f("space_rubble_m"), 2.0):
		var up: = _bot.up()
		var ahead: = Gravity.flat( - _bot.global_basis.z, up).normalized()
		return from + ahead * _f("space_dig_ahead_m") - up * 0.3
	return best



func compose_request(list: String) -> String:
	var table: Dictionary = Lexicon.data.lexicon.get("bot", {})
	var templates: Array = table.get(list, [])
	var slots: Dictionary = table.get("slots", {})
	if templates.is_empty():
		return ""
	for attempt in 8:
		var text: = String(templates[_rng.randi() % templates.size()])
		for slot: String in slots:
			var options: Array = slots[slot]
			var token: = "{%s}" % slot
			var at: = text.find(token)
			while at >= 0 and not options.is_empty():
				text = text.substr(0, at) + String(options[_rng.randi() % options.size()]) + text.substr(at + token.length())
				at = text.find(token)
		if PhraseParser.parse(text, Lexicon.data)["ok"]:
			return text
	return ""




func _aim_and_use(enemy: Node3D) -> void :
	var item: = _bot.hands.current_item()
	if enemy == null:
		_bot.aiming = false
		_bot.hands.use_released()
		return
	var target: = Combat.center_of(enemy) + _aim_offset
	_bot.look_at_point(target + _bot.up() * _lob_height(item, target))
	_bot.aiming = item != null
	if item == null or item.is_building or Forge.is_assembling(_bot.player_id):
		_bot.hands.use_released()
		return
	if item.melee and Combat.center_of(enemy).distance_to(_bot.camera.global_position) > item.strike_reach() + 0.3:
		_bot.hands.use_released()
		return
	_bot.hands.use_pressed()
	if not item.automatic:
		_bot.hands.use_released()





func _lob_height(item: Thing, target: Vector3) -> float:
	if item == null:
		return 0.0
	var projectile: = _projectile_id(item)
	var def: = Lexicon.data.thing_def(projectile)
	var role: Dictionary = (def.get("roles", {}) as Dictionary).get("projectile", {})
	if projectile.is_empty() or Assembler.movement_id({}, def, role, "projectile", Lexicon.data) != "ballistic":
		return 0.0
	var speed: = Lexicon.data.thing_statf(projectile, "speed")

	var gravity: float = _bot.gravity()
	if gravity <= 0.0:
		return 0.0
	var distance: = Gravity.flat(target - _bot.global_position, _bot.up()).length()
	var angle: = 0.5 * asin(clampf(gravity * distance / maxf(speed * speed, 0.01), 0.0, 1.0))
	angle -= deg_to_rad(Lexicon.balf("movement.ballistic_lift_deg"))
	return tan(maxf(angle, 0.0)) * distance



func _projectile_id(item: Thing) -> String:
	if item.category == "projectile":
		return item.thing_id
	var source: = Lexicon.data.behavior_source(item.node_data)
	for behavior: Dictionary in Assembler.merged_behaviors(item.node_data, Lexicon.data.thing_def(source), {}):
		var act: Dictionary = behavior.get("do", {})
		if String((behavior.get("when", {}) as Dictionary).get("type", "")) == "on_fire" and act.get("arg") is Dictionary:
			return String((act["arg"] as Dictionary).get("thing", ""))
	return ""



func _move(enemy: Node3D, delta: float) -> void :
	_until_strafe_change -= delta
	if _until_strafe_change <= 0.0:
		_strafe = - _strafe if _rng.randf() < 0.75 else _strafe
		_until_strafe_change = _rng.randf_range(_f("strafe_change_min_s"), _f("strafe_change_max_s"))
	var forward: = 0.0
	var item: = _bot.hands.current_item()
	if enemy != null:
		var distance: = Combat.center_of(enemy).distance_to(_bot.center())
		if item != null and item.melee:

			forward = -1.0 if distance > item.strike_reach() * 0.8 else 0.0
		elif distance > _f("far_distance"):
			forward = -1.0
		elif distance < _f("near_distance"):
			forward = 1.0
	_bot.control_wish = Vector2(_strafe, forward)
	_bot.control_jump = _rng.randf() < _f("jump_chance_per_s") * delta
	_bot.control_climb = 0.0





func _travel(enemy: Node3D, delta: float) -> bool:
	if not Gravity.active() or enemy == null:
		_travel_phase = 0
		return false
	var enemy_at: = Combat.center_of(enemy)
	if _bot.in_zero_g or (_travel_phase == 2 and not _bot.is_on_floor()):
		_drift_toward(enemy_at)
		return true
	if _travel_phase == 2:
		_travel_phase = 0
	var mine: = Gravity.source_index(_bot.global_position + _bot.up() * 0.9)
	var theirs: = Gravity.source_index(enemy_at)
	if theirs < 0 or mine < 0 or theirs == mine:
		_travel_phase = 0
		_travel_time = 0.0
		return false
	_bot.aiming = false
	_bot.hands.use_released()
	_travel_time += delta
	_bot.look_at_point(enemy_at)
	if _travel_phase == 1:
		_bot.control_wish = Vector2.ZERO
		_bot.control_sprint = false
		if _bot.move.state == FpsMove.State.CROUCH:
			_bot.control_jump = true
			_travel_phase = 2
		return true

	var angle: = _bot.up().angle_to((enemy_at - _bot.global_position).normalized())
	if angle <= _launch_lead() + deg_to_rad(_f("space_align_deg")) or _travel_time > _f("space_align_give_up_s"):
		_bot.control_wish = Vector2.ZERO
		_bot.control_sprint = false
		_bot.control_crouch = _bot.move.state != FpsMove.State.CROUCH
		_travel_phase = 1
		_travel_time = 0.0
		return true

	_bot.control_wish = Vector2(0.0, -1.0)
	_bot.control_sprint = true
	return true



func _launch_lead() -> float:
	var cfg: Dictionary = Lexicon.bal("space.launch", {})
	var g: = maxf(_bot.gravity(), 0.01)
	var escape: = Gravity.escape_height(_bot.global_position + _bot.up() * 0.9)
	var height: = escape + float(cfg.get("extra_m", 3.0))
	var up_speed: = maxf(float(cfg.get("min_ms", 9.0)), sqrt(2.0 * g * height))
	var exit_speed: = sqrt(maxf(up_speed * up_speed - 2.0 * g * escape, 0.01))
	return atan(float(cfg.get("forward_ms", 3.0)) / exit_speed)



func _drift_toward(target: Vector3) -> void :
	_bot.aiming = false
	_bot.hands.use_released()
	_bot.control_sprint = false
	var heading: = _bot.velocity.normalized() if _bot.velocity.length_squared() > 0.01 else Vector3.ZERO
	var want: = (target - _bot.global_position).normalized()
	var lateral: = want - heading * want.dot(heading)
	if lateral.length() < 0.05:
		_bot.control_wish = Vector2.ZERO
		return
	_bot.look_at_point(_bot.camera.global_position + lateral)
	_bot.control_wish = Vector2(0.0, - clampf(lateral.length() * 3.0, 0.0, 1.0))



func _pilot(enemy: Node3D, delta: float) -> void :
	_pilot_time += delta
	var control: = _bot.piloting.control as ControlPlayer
	if enemy == null or _pilot_time > _f("pilot_timeout_s"):
		_bot.stop_piloting()
		_pilot_time = 0.0
		return
	control.point_at(Combat.center_of(enemy))
	_bot.control_pilot_wish = Vector3(0.0, 0.0, -1.0)
	if Combat.center_of(enemy).distance_to(_bot.piloting.center()) < _f("pilot_command_distance"):
		_bot.pilot_command()



func _roll_aim_error(enemy: Node3D) -> void :
	if enemy == null:
		return
	var distance: = Combat.center_of(enemy).distance_to(_bot.center())
	var spread: = tan(deg_to_rad(_f("aim_error_deg"))) * distance
	_aim_offset = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * spread


func _f(key: String) -> float:
	return float(_cfg.get(key, 0.0))
