class_name RobotBody
extends Node3D












const CONFIG_PATH: = "res://data/character/robot.json"

static var _config: Dictionary = {}
static var _clip_meta: Dictionary = {}
static var _face_data: Dictionary = {}

var player: Player
var rig: RobotRig
var animator: RobotAnimator
var ik: RobotLegIK
var face: RobotFace

var _paint_canvas: RobotPaintCanvas
var _paint_task: = -1
var _paint_pending: RobotPaintCanvas = null
var model: Node3D


var _step_offset: = 0.0
var _model_base: = Vector3.ZERO

var assembling: bool = false
var _layer: int = 1
var _cfg: Dictionary
var _pieces: Array[Dictionary] = []
var arms: RobotArmIK

var orb: MatterOrb

var _last_pose: RobotRig.Pose
var _upper_now: String = ""

var _upper_base_now: String = ""
var _throw_until: float = 0.0
var _hold_expression: String = ""
var _hold_until: float = 0.0
var _talk_until: float = 0.0
var _think_until: float = 0.0
var _still_s: float = 0.0
var _clock: float = 0.0
var _match_hooked: bool = false
var _socket_hand: int = -1
var _last_yaw: float = 0.0
var _last_phase: float = 0.0
var _steps: int = 0
var _slide_sound: AudioStreamPlayer3D
var _free_look: float = 0.0
var _yaw_ready: bool = false
var _network_state: Dictionary = {}
var _network_pose: RobotRig.Pose
var _network_pose_now: RobotRig.Pose
var _network_move_state: int = -1
var _network_stagger_until: float = 0.0


static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		_clip_meta = (JSON.parse_string(FileAccess.get_file_as_string(String(_config["clips_meta"]))) as Dictionary)["clips"]
		_face_data = JSON.parse_string(FileAccess.get_file_as_string(String(_config["face_data"])))
	return _config


func setup(owner_player: Player) -> void :
	player = owner_player
	name = "Robot"
	_cfg = Lexicon.bal("robot", {})
	var cfg: = config()
	model = (load(String(cfg["model"])) as PackedScene).instantiate() as Node3D
	add_child(model)
	_model_base = model.position
	rig = RobotRig.new(model, _clip_meta)
	animator = RobotAnimator.new(rig, cfg["clips"], player.player_id)
	ik = RobotLegIK.new(rig)
	arms = RobotArmIK.new(rig)
	orb = MatterOrb.new()
	add_child(orb)
	orb.setup(player)

	process_priority = 10
	_socket_hand = rig.bone(String(cfg["hand_socket"]))
	var meshes: = model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in meshes:
		var mesh: = node as MeshInstance3D
		if (cfg["hidden_meshes"] as Array).has(String(mesh.name)):
			mesh.visible = false
			continue
		_pieces.append({"mesh": mesh, "bone": _mesh_bone(mesh), "bind": _mesh_bind(mesh)})
	var screen: = model.find_child(String(cfg["face_mesh"]), true, false) as MeshInstance3D
	var face_material: = ShaderMaterial.new()
	face_material.shader = load(String(cfg["face_shader"]))
	screen.material_override = face_material
	face = RobotFace.new(face_material, _face_data, player.player_id)
	_paint_team(player.body_color)
	_apply_paint(player.paint_bytes)
	_layer = 2 if player.is_local else 1
	_set_layers(model, 1)
	if player.is_local:

		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			if (cfg.get("fp_hidden_meshes", []) as Array).has(String(node.name)):
				(node as MeshInstance3D).layers = 1 << (_layer - 1)
	player.hands.used.connect(_on_used)
	player.damaged.connect(_on_damaged)
	player.died.connect(_on_died)
	player.revived.connect(_on_revived)
	player.move.stepped.connect(_on_stepped)
	player.move.landed.connect(_on_landed)
	player.move.jumped.connect( func() -> void :
		FeelSounds.play_at(self, FeelSounds.jump(), global_position + Vector3.UP, Lexicon.balf("feel.sound.jump_db")))
	player.move.state_changed.connect(_on_move_state)
	player.move.pivot_requested.connect(animator.start_pivot)
	player.move.mantle_started.connect(_on_mantle)
	player.move.staggered.connect(_on_staggered)
	Forge.request_processed.connect(_on_request)
	Forge.build_finished.connect(_on_build_finished)


func _process(delta: float) -> void :
	if _paint_task >= 0 and WorkerThreadPool.is_task_completed(_paint_task):
		_finish_paint()
	_clock += delta
	_hook_match()
	if not model.visible:
		return
	_step_offset = RobotSpring.damp(_step_offset, 0.0, Lexicon.balf("robot.step_halflife_s"), delta)
	model.position = _model_base + Vector3.UP * _step_offset
	if not player.has_simulation_authority() and _network_pose != null:

		if _network_pose_now == null:
			_network_pose_now = _network_pose.duplicate_pose()
		_network_pose_now.blend(_network_pose, 1.0 - exp( - Hands.POSE_SMOOTH * delta))
		model.rotation.y = float(_network_state.get("model_yaw", 0.0))
		rig.apply(_network_pose_now)
		_last_pose = _network_pose_now
		_follow_eye(_network_pose_now, delta)
		face.set_expression(str(_network_state.get("expression", _expression())))
		face.advance(delta)
		return
	var to_model: = model.global_basis.inverse()
	var velocity: = to_model * player.velocity
	velocity.y = 0.0
	var yaw: = player.yaw
	var yaw_delta: = wrapf(yaw - _last_yaw, - PI, PI) if _yaw_ready else 0.0
	_last_yaw = yaw
	_yaw_ready = true
	_upper_base_now = _upper_base()
	_upper_now = _upper_clip()
	animator.set_upper(_upper_now)
	var pose: = animator.update(delta, {"velocity": velocity, "world_velocity": player.planar_velocity(), "up": player.gravity_frame.y, "to_model": to_model, 
		"on_floor": player.network_on_floor(), "vertical_speed": player.velocity.dot(player.gravity_frame.y), "flying": player.is_flying(), 
		"yaw_delta": yaw_delta, "effort": _effort(), "crouch": player.move.crouch_amount, "crouched": player.move.state == FpsMove.State.CROUCH, 
		"sliding": player.move.sliding})

	model.rotation.y = animator.body_yaw

	var free: = player.is_free_view() and not player.faces_aim()
	var look_goal: = 0.0
	if free:
		var raw: = wrapf(player.view_yaw - player.yaw, - PI, PI)
		var limit: = deg_to_rad(Lexicon.balf("robot.free_look.max_deg"))

		if absf(raw) < deg_to_rad(Lexicon.balf("robot.free_look.give_up_deg")):
			look_goal = clampf(raw, - limit, limit)
	_free_look = RobotSpring.damp_angle(_free_look, look_goal, Lexicon.balf("robot.free_look.halflife_s"), delta)
	if absf(_free_look) > 0.001:
		animator.turn_bones(pose, {"neck": 0.4, "head": 0.6}, Vector3.UP, _free_look)
	var armed: = (player.hands.current_item() != null or not player.hands.network_item_state().is_empty()) and not free
	animator.apply_pitch(pose, player.head.rotation.x * (Lexicon.balf("robot.free_look.pitch_mult") if free else 1.0), 
		_cfg.get("aim_split" if armed else "look_split", {}), Basis(Vector3.UP, _free_look - animator.body_yaw) * Vector3.RIGHT)
	animator.apply_roll(pose, "head", face.head_tilt())
	ik.solve(pose, rig.skeleton.global_transform, animator.stance, animator.planted, animator.ground_weight, _probe, delta, 
		animator.foot_shift, animator.pelvis_drop)
	_place_arms(pose, delta)
	rig.apply(pose)
	_last_pose = pose
	_follow_eye(pose, delta)
	_footsteps()
	_still_s = _still_s + delta if animator.move_weight < 0.05 else 0.0
	face.set_expression(_expression())
	face.advance(delta)




func _follow_eye(pose: RobotRig.Pose, delta: float) -> void :
	var g: = rig.globals(pose)
	var eyes: = rig.skeleton.global_transform * ((g[rig.bone("eye.L")].origin + g[rig.bone("eye.R")].origin) * 0.5)
	var cfg: Dictionary = _cfg.get("eye", {})
	var want: = (player.head.global_transform.affine_inverse() * eyes).limit_length(float(cfg.get("max_offset_m", 0.6)))
	var now: = player.eye_offset
	var side: = float(cfg.get("halflife_s", 0.03))
	player.eye_offset = Vector3(RobotSpring.damp(now.x, want.x, side, delta), 
		RobotSpring.damp(now.y, want.y, float(cfg.get("vertical_halflife_s", 0.08)), delta), RobotSpring.damp(now.z, want.z, side, delta))
	if player.feel == null:
		player.camera.position = player.eye_offset




func _on_stepped(rise: float) -> void :
	var limit: = Lexicon.balf("robot.step_max_m")
	var before: = _step_offset
	_step_offset = clampf(_step_offset - rise, - limit, limit)
	var moved: = player.head.global_basis.inverse() * (player.gravity_frame.y * (_step_offset - before))
	player.eye_offset += moved

	player.camera.position += moved




static func hold_class(item: Thing) -> String:
	if item == null:
		return "none"
	if bool(Lexicon.data.thing_def(item.thing_id).get("held_protection", false)):
		return "shield"
	if item.melee:
		return "melee"
	var holds: Dictionary = config()["holds"]
	return String((holds.get("class_of", {}) as Dictionary).get(hold_clip(item), "rifle"))



static func hold_clip(item: Thing) -> String:
	if bool(Lexicon.data.thing_def(item.thing_id).get("held_protection", false)):
		return "Hold_Pistol"
	var holds: Dictionary = config()["holds"]
	var by_thing: Dictionary = holds["by_thing"]
	if by_thing.has(item.thing_id):
		return String(by_thing[item.thing_id])
	if item.weight >= Lexicon.balf("robot.heavy_hold_kg"):
		return String(holds["heavy"])
	return String(holds["default"])




func _upper_clip() -> String:
	var clip: = _upper_base_now
	if clip.is_empty():
		return clip
	var names: Dictionary = config()["clips"]
	if player.move.sliding:
		var slide: = String(names.get("slide_aim", "")) if player.aiming else "Slide_" + clip
		return slide if animator.rig.has_clip(slide) else clip
	if player.move.crouching and animator.rig.has_clip("Crouch_" + clip):
		return "Crouch_" + clip
	if player.move.sprinting and animator.rig.has_clip(clip + "_Sprint"):
		return clip + "_Sprint"
	if player.aiming and animator.rig.has_clip(clip + "_ADS"):
		return clip + "_ADS"
	return clip


func _upper_base() -> String:
	var names: Dictionary = config()["clips"]
	if player.piloting != null:
		return ""
	if player.shaper.active:
		return String(names["point"])
	if player.extracting and player.extractor.pulling:
		return String(names["extract"])
	var item: = player.hands.current_item()
	if item == null:
		var metadata: = player.hands.network_item_state()
		if metadata.is_empty():
			return ""
		if bool(metadata.get("melee", false)):
			return String(names["block"]) if player.is_blocking() else String(names["charge"] if player.hands.is_charging() else names["hold_melee"])
		return str(metadata.get("hold_clip", ""))
	if item.melee:
		if player.is_blocking():
			return String(names["block"])
		return String(names["charge"]) if player.hands.is_charging() else String(names["hold_melee"])
	return hold_clip(item)



func _expression() -> String:
	var e: Dictionary = config()["expressions"]
	if _clock < _hold_until:
		return _hold_expression
	var voice: = _local_voice_state()
	if voice == "thinking" or _clock < _think_until:
		return String(e["think"])
	if voice == "listening" or _clock < _talk_until:
		return String(e["talk"])
	if player.extracting and player.extractor.pulling:
		return String(e["extract"])
	var status: = Status.of(player)
	if status != null and status.remaining.has("frozen"):
		return String(e["frozen"])
	if status != null and status.remaining.has("burning"):
		return String(e["burning"])
	if player.aiming and not player.hands.network_item_state().is_empty():
		return String(e["aim"])
	if player.health < player.max_health * Lexicon.balf("robot.low_health_fraction"):
		return String(e["low_health"])
	if _still_s > Lexicon.balf("robot.sleepy_after_s"):
		return String(e["sleepy"])
	if _still_s > Lexicon.balf("robot.bored_after_s"):
		return String(e["bored"])
	return String(e["idle"])



func clear_moment() -> void :
	_hold_until = 0.0
	_talk_until = 0.0
	_think_until = 0.0


func _hold(expression_key: String) -> void :
	var e: Dictionary = config()["expressions"]
	_hold_expression = String(e[expression_key])
	_hold_until = _clock + float((Lexicon.bal("robot.expression_hold_s", {}) as Dictionary).get(expression_key, 1.0))



func _local_voice_state() -> String:
	if not player.is_local or Forge.world == null or Forge.world.voice == null:
		return ""
	var voice: = Forge.world.voice
	if voice.state == "listening" and voice.held_seconds() <= Lexicon.balf("extraction.tap_max_s"):
		return ""
	return voice.state


func _on_used(_item: Thing, kind: String) -> void :
	var names: Dictionary = config()["clips"]
	match kind:
		"fire":
			animator.play_once(String(names["recoil"]))
		"throw":
			animator.play_once(String(names["throw"]))

			_throw_until = _clock + animator.rig.length(String(names["throw"]))
		"strike":
			var item: = player.hands.current_item()
			var style: = item.strike_style if item != null else "slash"
			var strike: = String((config()["strikes"] as Dictionary).get(style, names["strike"]))
			if player.move.crouching and animator.rig.has_clip("Crouch_" + strike):
				strike = "Crouch_" + strike
			animator.play_once(strike)


func _on_damaged(_amount: float, source: Node) -> void :
	var clip: = "Hit_Front"
	if source is Node3D and (source as Node3D).is_inside_tree():
		var to: = global_basis.inverse() * ((source as Node3D).global_position - global_position)
		var hits: Dictionary = config()["hits"]
		if absf(to.x) > absf(to.z):
			clip = String(hits["right"] if to.x > 0.0 else hits["left"])
		else:
			clip = String(hits["front"] if to.z < 0.0 else hits["back"])
	animator.play_once(clip)
	_hold("hurt")


func _on_request(player_id: int, _text: String, result: Dictionary) -> void :
	if player_id != player.player_id:
		return
	if not result.get("ok", false):
		_hold("failed")
	elif not player.is_local:

		_talk_until = _clock + Lexicon.balf("robot.bot_talk_s")


func _on_build_finished(player_id: int, _thing: Thing) -> void :
	if player_id == player.player_id and player.is_alive():
		_hold("built")


func _hook_match() -> void :
	if _match_hooked or Forge.world == null:
		return
	_match_hooked = true
	Forge.world.state_changed.connect( func() -> void :
		if Forge.world.state in ["round_over", "match_over"] and Forge.world.last_winner == player:
			_hold("won"))



func _on_died(_who: Player) -> void :
	if not model.visible:
		return
	var burst: = RobotPieces.new()
	burst.name = "RobotBurst"
	Forge.fx_root(player).add_child(burst)

	burst.global_transform = Transform3D(player.gravity_frame, global_position)
	burst.start("burst", _piece_transforms(burst.global_transform.affine_inverse()), Vector3.ZERO, 1, player.player_id)
	model.visible = false
	assembling = false



func _on_revived() -> void :
	assemble()



func assemble() -> void :
	ik.reset()
	player.eye_offset = Vector3.ZERO
	animator.reset()
	model.rotation.y = 0.0
	_yaw_ready = false
	for child in get_children():
		if child is RobotPieces:
			child.queue_free()
	model.visible = true

	rig.apply(rig.sample(String(config()["clips"]["idle"]), 0.0, rig.rest))
	var pieces: = RobotPieces.new()
	pieces.name = "RobotAssemble"
	add_child(pieces)
	pieces.start("assemble", _piece_transforms(global_transform.affine_inverse()), Vector3.ZERO, 1 << (_layer - 1), 
		player.player_id + 101)
	model.visible = false
	assembling = true
	pieces.assembled.connect( func() -> void :
		assembling = false
		model.visible = player.is_alive() or player.respawn_on_death)



func _piece_transforms(to_space: Transform3D) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var skeleton_xf: = rig.skeleton.global_transform
	for info: Dictionary in _pieces:
		var bone: int = info["bone"]
		if bone < 0:
			continue
		var xf: = skeleton_xf * rig.skeleton.get_bone_global_pose(bone) * (info["bind"] as Transform3D)
		out.append({"mesh": info["mesh"], "xf": to_space * xf})
	return out



func hand_world() -> Vector3:
	if _socket_hand < 0:
		return global_position + Vector3.UP
	return rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(_socket_hand).origin





func _place_arms(pose: RobotRig.Pose, delta: float) -> void :
	var to_model: = rig.skeleton.global_transform.affine_inverse()
	var reference: = String(config()["clips"].get("orb_reference", "Hold_Pistol"))
	var left: Variant = null
	if player.piloting == null and player.is_alive():
		var anchor: = player.orb_hand.global_transform
		left = arms.held_target("L", anchor.origin, anchor.basis, to_model, reference)
	arms.reach(pose, "L", left, delta)
	var right: Variant = null
	var item: = player.hands.current_item()
	if player.piloting == null and _clock >= _throw_until:
		if player.extracting and player.extractor.pulling:
			right = arms.pull_target(pose, player.extractor.pull_point(), to_model, reference)
		elif item != null and not player.extracting:
			var hold: = String(config()["clips"]["hold_melee"]) if item.melee else hold_clip(item)
			if item.melee or _upper_base_now == hold:
				right = arms.weapon_target(item, to_model, hold)
		elif not player.extracting:
			var metadata: = player.hands.network_item_state()
			if not metadata.is_empty():
				var hold: = String(config()["clips"]["hold_melee"]) if bool(metadata.get("melee", false)) else str(metadata.get("hold_clip", ""))
				right = arms.weapon_target_data(metadata.get("grip_main", Vector3.ZERO), player.hands.network_item_world(), to_model, hold)
	arms.reach(pose, "R", right, delta)



func orb_anchor_world() -> Vector3:
	var palm: = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(rig.bone("socket_hand.L")).origin

	return palm + player.up() * Lexicon.balf("matter.orb.above_hand_m")



func _probe(point: Vector3) -> Dictionary:
	var ik_cfg: Dictionary = _cfg.get("ik", {})

	var up: = player.gravity_frame.y
	var query: = PhysicsRayQueryParameters3D.create(point + up * float(ik_cfg.get("probe_up_m", 0.5)), 
		point - up * float(ik_cfg.get("probe_down_m", 0.7)), PhysicsLayers.WORLD | PhysicsLayers.THINGS, [player.get_rid()])
	var hit: = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	return {"y": float((hit["position"] as Vector3).y), "point": hit["position"], "normal": hit["normal"]}




func _footsteps() -> void :
	var phase: = animator.phase
	var last: = _last_phase
	_last_phase = phase
	if animator.move_weight < 0.4 or animator.ground_weight < 0.5 or player.move.sliding:
		return
	for side: String in ["L", "R"]:
		var contact: = 0.0 if side == "L" else 0.5
		var crossed: = (last < contact and phase >= contact) if phase >= last else (contact > last or contact <= phase)
		if not crossed:
			continue
		_steps += 1
		var sound: Dictionary = Lexicon.bal("feel.sound", {})
		var db: = float(sound.get("step_db", -6.0))
		if player.move.sprinting:
			db += float(sound.get("step_sprint_db", 3.0))
		elif player.move.crouching:
			db += float(sound.get("step_crouch_db", -10.0))
		var foot: = rig.skeleton.global_transform * rig.skeleton.get_bone_global_pose(rig.bone("foot." + side)).origin
		FeelSounds.play_at(self, FeelSounds.step(_steps), foot, db, 1.0 + float(posmod(_steps * 7, 5) - 2) * 0.035)


func _on_landed(fall_speed: float) -> void :
	var sound: Dictionary = Lexicon.bal("feel.sound", {})
	if fall_speed < float(sound.get("land_min_ms", 2.5)) or not model.visible:
		return
	var db: = float(sound.get("land_db", -2.0)) + clampf((fall_speed - 6.0) * 0.8, -8.0, 4.0)
	FeelSounds.play_at(self, FeelSounds.land(), global_position, db)




func export_network_state() -> Dictionary:
	if not player.has_simulation_authority():
		return _network_state.duplicate(true)
	var movement: = int(player.move.state)
	if rig == null or not (player.move.state == FpsMove.State.MANTLE or _clock < _network_stagger_until):
		return {"rigid": false, "move_state": movement}
	var pose: = _last_pose
	if pose == null:
		pose = rig.rest
	var rotations: = PackedFloat32Array()
	for rotation_value: Quaternion in pose.rot:
		rotations.append_array(PackedFloat32Array([rotation_value.x, rotation_value.y, rotation_value.z, rotation_value.w]))
	return {"rigid": true, "positions": pose.pos.duplicate(), 
		"rotations": rotations, "model_yaw": model.rotation.y, "move_state": movement, "expression": _expression()}


func apply_network_state(state: Dictionary) -> void :
	if player.has_simulation_authority() or rig == null:
		return
	_network_state = state.duplicate(true)
	var movement: = int(state.get("move_state", FpsMove.State.STAND))
	if player.network_role == "proxy" and _network_move_state >= 0 and movement != _network_move_state:
		_on_move_state(_network_move_state as FpsMove.State, movement as FpsMove.State)
	_network_move_state = movement
	if not bool(state.get("rigid", false)):
		if _network_pose != null:
			animator.reset()
		_network_pose = null
		_network_pose_now = null
		return
	var positions: Variant = state.get("positions")
	var rotations: Variant = state.get("rotations")
	if not positions is PackedVector3Array or not rotations is PackedFloat32Array:
		return
	if positions.size() != rig.bone_count or rotations.size() != rig.bone_count * 4:
		return
	var pose: = RobotRig.Pose.new()
	pose.pos = positions.duplicate()
	for bone_index in rig.bone_count:
		var at: = bone_index * 4
		var rotation_value: = Quaternion(rotations[at], rotations[at + 1], rotations[at + 2], rotations[at + 3])
		if not rotation_value.is_finite() or rotation_value.length_squared() < 0.001 or not pose.pos[bone_index].is_finite():
			return
		pose.rot.append(rotation_value.normalized())
	_network_pose = pose



func _on_staggered(impulse: Vector3) -> void :
	var local: = global_basis.inverse() * impulse
	var names: Dictionary = config()["clips"]
	var key: = "stagger_b" if local.z < 0.0 and absf(local.z) >= absf(local.x) else "stagger_f" if absf(local.z) >= absf(local.x)\
	else "stagger_r" if local.x < 0.0 else "stagger_l"
	animator.play_once(String(names.get(key, "")), 1.0, true)
	_network_stagger_until = _clock + rig.length(String(names.get(key, "")))



func _on_mantle(height: float, duration: float) -> void :
	var names: Dictionary = config()["clips"]
	var clip: = String(names.get("mantle_low" if height <= float(names.get("mantle_low_max_m", 1.2)) else "mantle_high", ""))
	if animator.rig.has_clip(clip):
		animator.play_once(clip, animator.rig.length(clip) / maxf(duration, 0.05), true)




func _on_move_state(from: FpsMove.State, to: FpsMove.State) -> void :
	if from == FpsMove.State.SPRINT and not player.hands.network_item_state().is_empty():
		animator.play_once(String(config()["clips"].get("sprint_out", "")))
	if to == FpsMove.State.SLIDE:
		if _slide_sound == null:
			_slide_sound = AudioStreamPlayer3D.new()
			_slide_sound.name = "SlideSound"
			_slide_sound.bus = AudioMix.bus(AudioMix.EFFECTS)
			_slide_sound.stream = FeelSounds.slide()
			_slide_sound.unit_size = 6.0
			add_child(_slide_sound)
		_slide_sound.volume_db = Lexicon.balf("feel.sound.slide_db")
		_slide_sound.play()
	elif from == FpsMove.State.SLIDE and _slide_sound != null:
		_slide_sound.stop()



func _effort() -> float:
	var effort: = player.planar_velocity().length() / maxf(Lexicon.balf("player.sprint_speed"), 0.001)
	if not player.network_on_floor():
		effort = maxf(effort, 0.6)
	if player.extracting and player.extractor.pulling:
		effort = maxf(effort, 0.7)
	return clampf(effort, 0.0, 1.0)



func _paint_team(color: Color) -> void :
	var tint: = Lexicon.balf("robot.team_tint")
	if Session.is_online() and Session.lobby.color_for_player(player.player_id) >= 0:
		tint = float(config().get("selection_tint", tint))
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: = node as MeshInstance3D
		if not (config()["team_parts"] as Array).has(String(mesh.name)):
			continue
		var base: = mesh.get_active_material(0)
		var paint: = (base.duplicate() if base != null else StandardMaterial3D.new()) as BaseMaterial3D
		if paint != null:
			paint.albedo_color = paint.albedo_color.lerp(color, tint)
			mesh.material_override = paint



func _apply_paint(bytes: PackedByteArray) -> void :
	if bytes.is_empty():
		return
	var paint: = RobotPaint.decode(bytes)
	_attach_stickers(paint)
	RobotPaintCanvas.prepare()


	_paint_task = WorkerThreadPool.add_task( func() -> void :
		var canvas: = RobotPaintCanvas.new()
		canvas.paint_strokes(paint)
		_paint_pending = canvas)



func paint_ready() -> bool:
	return _paint_task < 0


func _exit_tree() -> void :
	if _paint_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_paint_task)
		_paint_task = -1



func _finish_paint() -> void :
	WorkerThreadPool.wait_for_task_completion(_paint_task)
	_paint_task = -1
	_paint_canvas = _paint_pending
	_paint_pending = null
	if _paint_canvas == null:
		return
	_paint_canvas.commit()
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: = node as MeshInstance3D
		var texture: = _paint_canvas.texture(String(mesh.name))
		if texture == null:
			continue
		var own: = mesh.material_override as BaseMaterial3D
		if own == null:
			var base: = mesh.get_active_material(0)
			own = (base.duplicate() if base != null else StandardMaterial3D.new()) as BaseMaterial3D
			mesh.material_override = own
		own.detail_enabled = true
		own.detail_albedo = texture
		own.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		own.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1




func _attach_stickers(paint: RobotPaint) -> void :
	if paint.stickers.is_empty():
		return
	var spaces: = {}
	for piece: Dictionary in _pieces:
		var mesh: = piece["mesh"] as MeshInstance3D
		if not RobotPaint.is_paintable(String(mesh.name)) or int(piece["bone"]) < 0:
			continue
		var attach: = BoneAttachment3D.new()
		attach.name = "Sticker_" + String(mesh.name)
		rig.skeleton.add_child(attach)
		attach.bone_name = rig.skeleton.get_bone_name(int(piece["bone"]))
		var space: = Node3D.new()
		space.transform = piece["bind"]
		attach.add_child(space)
		spaces[String(mesh.name)] = space
	StickerDecals.rebuild(paint, func(part: String) -> Node3D: return spaces.get(part), spaces.values())



func _mesh_bone(mesh: MeshInstance3D) -> int:
	var bind: = _mesh_bind_index(mesh)
	if bind < 0:
		return -1
	var bone: = rig.skeleton.find_bone(String(mesh.skin.get_bind_name(bind)))
	return bone if bone >= 0 else mesh.skin.get_bind_bone(bind)


func _mesh_bind(mesh: MeshInstance3D) -> Transform3D:
	var bind: = _mesh_bind_index(mesh)
	return mesh.skin.get_bind_pose(bind) if bind >= 0 else Transform3D.IDENTITY


static func _mesh_bind_index(mesh: MeshInstance3D) -> int:
	if mesh.skin == null or mesh.mesh == null:
		return -1
	var bones: PackedInt32Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
	return bones[0] if not bones.is_empty() else -1


static func _set_layers(node: Node, layer: int) -> void :
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = 1 << (layer - 1)
	for child in node.get_children():
		_set_layers(child, layer)
