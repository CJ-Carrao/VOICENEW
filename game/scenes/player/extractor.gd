class_name Extractor
extends Node










const BEAM_EVERY_S: = 0.08


var pulling: bool = false

var problem: String = ""
var player: Player
var _beam_left: float = 0.0
var _pull_seconds: float = 0.0
var _idle_seconds: float = 0.0

var _last_source: Object = null
var _last_point: Vector3 = Vector3.ZERO
var _bit_color: = Color.GRAY



func pull(delta: float) -> void :
	if not player.has_simulation_authority() or not player.can_act():
		return
	pulling = false
	if player.is_full_of_matter():
		stop()
		problem = "full"
		return
	var hit: = target()
	if hit.is_empty():
		hit = _stick()
	if hit.is_empty():
		_lose_momentum(delta)
		problem = "nothing"
		return
	problem = ""
	pulling = true
	var source: Object = hit["collider"]
	var shape: = int(hit["shape"])
	var point: Vector3 = hit["position"]

	if "extract_origin" in source:
		source.set("extract_origin", player.look_ray().origin)

	var from: Vector3 = source.call("extract_point", shape, point)
	_last_source = source
	_last_point = from
	var previous_seconds: = _pull_seconds
	var previous_rate: = rate_per_second()
	_pull_seconds = minf(_pull_seconds + delta, Lexicon.balf("extraction.ramp_s"))
	var amount: = minf((previous_rate + rate_per_second()) * 0.5 * delta, player.max_matter - player.matter)
	var taken: = float(source.call("extract_from", shape, point, amount))
	player.add_matter(taken)

	var block: Variant = source.get("last_extracted")
	if block is Dictionary and int((block as Dictionary).get("tick", -1)) == Engine.get_physics_frames() and player.robot != null:
		Fx.block_flight(Forge.fx_root(player), block.center, player.robot.orb, float(block.size), block.color)
	if taken > 0.0:
		_idle_seconds = 0.0
	else:

		_pull_seconds = previous_seconds
		_lose_momentum(delta)
	_beam_left -= delta
	if _beam_left <= 0.0:
		_beam_left = BEAM_EVERY_S
		var color: = Color.from_string(String(Lexicon.bal("extraction.beam_color", "#ffc65c")), Color.ORANGE)
		Fx.extraction_beam(Forge.fx_root(player), from, player.robot.hand_world(), color)
		var bit_color: Color = source.call("extract_color", shape, point) if source.has_method("extract_color") else color
		_bit_color = bit_color
		player.robot.orb.absorb(from, bit_color)



func pull_point() -> Vector3:
	return _last_point



func rate_per_second() -> float:
	var initial: = Lexicon.balf("extraction.rate_per_s")
	var maximum: = maxf(initial, Lexicon.balf("extraction.max_rate_per_s"))
	var progress: = clampf(_pull_seconds / maxf(Lexicon.balf("extraction.ramp_s"), 0.001), 0.0, 1.0)
	return lerpf(initial, maximum, progress)



func _lose_momentum(delta: float) -> void :
	_idle_seconds += delta
	if _idle_seconds >= Lexicon.balf("extraction.gap_grace_s"):
		_pull_seconds = 0.0



func stop() -> void :
	pulling = false
	problem = ""
	_beam_left = 0.0
	_pull_seconds = 0.0
	_idle_seconds = 0.0
	_last_source = null





func _stick() -> Dictionary:
	if _last_source == null or not is_instance_valid(_last_source) or (_last_source as Node).is_queued_for_deletion():
		return {}
	var ray: = player.look_ray()
	var origin: Vector3 = ray["origin"]
	var aim: Vector3 = origin + (ray["direction"] as Vector3) * origin.distance_to(_last_point)

	if _last_source.has_method("can_extract_at"):
		if "extract_origin" in _last_source:
			_last_source.set("extract_origin", origin)
		if not _last_source.call("can_extract_at", aim):
			return {}
	var next: Vector3 = _last_source.call("extract_point", -1, aim)
	if next.distance_to(aim) > Lexicon.balf("extraction.stick_m") or next.distance_to(origin) > Lexicon.balf("extraction.range_m"):
		return {}
	return {"collider": _last_source, "shape": -1, "position": aim}




func target() -> Dictionary:
	if player == null or not player.is_inside_tree():
		return {}
	var ray: = player.look_ray()
	var origin: Vector3 = ray["origin"]
	var direction: Vector3 = ray["direction"]
	var query: = PhysicsRayQueryParameters3D.create(origin, origin + direction * Lexicon.balf("extraction.range_m"), 
		PhysicsLayers.SOLID | PhysicsLayers.DEBRIS, [player.get_rid()])
	var hit: = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit["collider"] == null or not (hit["collider"] as Object).has_method("extract_from"):
		return {}
	return hit


func network_state() -> Dictionary:
	return {"pulling": pulling, "problem": problem, "point": _last_point, "color": _bit_color, "seconds": _pull_seconds}


func apply_network_state(data: Dictionary) -> void :
	if player.has_simulation_authority():
		return
	pulling = bool(data.get("pulling", false))
	problem = str(data.get("problem", ""))
	_last_point = data.get("point", Vector3.ZERO)
	_bit_color = data.get("color", Color.GRAY)
	_pull_seconds = float(data.get("seconds", 0.0))


func _process(delta: float) -> void :
	if player.has_simulation_authority() or not player.network_active:
		return
	if player.is_local and player.network_role == "predicted":
		# Immediate visual response; matter and actual cells remain host-authoritative.
		pulling = false
		if player.extracting and player.is_using_input() and player.can_act() and not player.is_full_of_matter():
			var hit := target()
			if not hit.is_empty():
				var source: Object = hit.collider
				_last_point = source.call("extract_point", int(hit.shape), hit.position)
				_bit_color = source.call("extract_color", int(hit.shape), hit.position) if source.has_method("extract_color") else Color("ffc65c")
				pulling = true
	if not pulling:
		_beam_left = 0.0
		return
	_beam_left -= delta
	if _beam_left <= 0.0:
		_beam_left = BEAM_EVERY_S
		Fx.extraction_beam(Forge.fx_root(player), _last_point, player.robot.hand_world(), _bit_color)
		player.robot.orb.absorb(_last_point, _bit_color)
