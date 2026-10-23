class_name ViewCamera
extends Camera3D












const OWN_BODY_LAYER: = 2

var player: Player

var distance: float = 0.0

var current_distance: float = 0.0

var suspended: = false
var _cfg: Dictionary
var _fov_mult: float = 1.0
var _aim_w: float = 0.0


func setup(owner_player: Player) -> void :
	player = owner_player
	name = "ViewCamera"
	_cfg = Lexicon.bal("player.camera", {})
	top_level = true
	cull_mask = 1048575


	if owner_player.get_tree() == null or owner_player.get_tree().get_script() == null:
		distance = clampf(float(UserSettings.get_value("camera", "distance", 0.0)), 0.0, _f("max_m"))
		current_distance = distance



func is_third_person() -> bool:
	return current_distance >= _f("first_person_below_m")




func zoom_by_player(steps: int) -> void :
	zoom(steps)
	UserSettings.set_value("camera", "distance", distance)


func zoom(steps: int) -> void :
	var step: = _f("step_m")
	if steps > 0:

		if distance < _f("min_third_m"):
			distance = _f("min_third_m")
			steps -= 1
		distance = minf(distance + step * steps, _f("max_m"))
	elif steps < 0:
		distance = distance + step * steps
		if distance < _f("min_third_m") - 0.001:
			distance = 0.0


func _process(delta: float) -> void :
	if player == null or not player.is_local:
		return
	var want: = distance
	var item: = player.hands.network_item_state()
	var scoped: = player.is_aiming_down_sights() and float(item.get("zoom", 1.0)) >= Lexicon.balf("aim.scope_overlay_zoom")
	var shoulder_aim: = player.aiming and distance > 0.0 and not scoped and not player.is_blocking()
	if scoped or player.piloting != null:
		want = 0.0
	elif shoulder_aim:
		want = minf(distance, _f("aim_distance_m"))
	current_distance = lerpf(current_distance, want, 1.0 - exp( - _f("smoothing") * delta))
	if absf(current_distance - want) < 0.005:
		current_distance = want
	var eye: = player.camera
	if not is_third_person():
		if current and player.piloting == null and not suspended:
			eye.make_current()
		return

	var basis: = player.gravity_frame * Basis.from_euler(Vector3(player.head.rotation.x, player.view_yaw, 0.0)) * eye.transform.basis

	var away: = smoothstep(_f("first_person_below_m"), _f("min_third_m"), current_distance)

	_aim_w = lerpf(_aim_w, 1.0 if shoulder_aim else 0.0, 1.0 - exp( - _f("smoothing") * delta))
	var shoulder: = lerpf(_f("shoulder_m"), _f("aim_shoulder_m"), _aim_w)
	var height: = lerpf(_f("height_m"), _f("aim_height_m"), _aim_w)
	var pivot: = eye.global_position + basis.x * shoulder * away + player.gravity_frame.y * height * away
	var desired: = pivot + basis.z * current_distance
	var query: = PhysicsRayQueryParameters3D.create(eye.global_position, desired, PhysicsLayers.WORLD | PhysicsLayers.THINGS, 
		[player.get_rid()])
	var hit: = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var back: Vector3 = (desired - eye.global_position).normalized()
		desired = (hit["position"] as Vector3) - back * _f("wall_margin_m")
	global_transform = Transform3D(basis, desired)
	_fov_mult = lerpf(_fov_mult, _f("aim_fov_mult") if shoulder_aim else 1.0, 1.0 - exp( - _f("smoothing") * delta))
	fov = eye.fov * _fov_mult

	var near: = eye.global_position.distance_to(desired) < _f("hide_body_below_m")
	cull_mask = (1048575 & ~ (1 << (OWN_BODY_LAYER - 1))) if near else 1048575
	if player.piloting == null and not current and not suspended:
		make_current()


func _f(key: String) -> float:
	return float(_cfg.get(key, 0.0))
