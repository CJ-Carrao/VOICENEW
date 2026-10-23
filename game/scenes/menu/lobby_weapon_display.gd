extends Node3D

const MAX_DISPLAY_LENGTH: = 1.08
const FRONT_DISPLAY_LENGTH: = 0.85
var item_id: String = ""
var hold_clip: String = ""
var main_grip: = Vector3.ZERO
var support_grip: Variant = null
var model: Node3D
var _rig: RobotRig
var _arms: RobotArmIK
var _config: Dictionary
var _skeleton_local: Transform3D
var _reference_hand: = Basis.IDENTITY
var _rest_rotation: = Basis.IDENTITY
var _model_scale: = Vector3.ONE
var _front_slot: bool = false

func setup(rig: RobotRig, config: Dictionary, skeleton_local: Transform3D, slot: int = 0) -> void :
	_rig = rig
	_arms = RobotArmIK.new(rig)
	_config = config
	_skeleton_local = skeleton_local
	_front_slot = slot >= 2

func set_item(id: String) -> void :
	if id == item_id: return
	if model != null:
		remove_child(model)
		model.queue_free()
		model = null
	item_id = ""
	visible = false
	if id.is_empty() or not Lexicon.data.is_weapon(id) or not Lexicon.data.models.has(id): return
	var built: = ModelBuilder.build(id, {}, Lexicon.data)
	model = built["root"]
	model.name = "CatalogueWeapon_" + id
	add_child(model)
	item_id = id
	var bounds: AABB = built["bounds"]
	var longest: = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var display_length: = FRONT_DISPLAY_LENGTH if _front_slot else MAX_DISPLAY_LENGTH
	_model_scale = model.scale * minf(1.0, display_length / maxf(longest, 0.001))
	model.scale = _model_scale
	main_grip = built["grips"]["main"]
	support_grip = built["grips"].get("support")
	var holds: Dictionary = _config["holds"]
	var melee: = bool(Lexicon.data.thing_def(id).get("melee", false))
	if melee:
		hold_clip = String(_config["clips"]["hold_melee"])
	else:
		var fallback: = String(holds["heavy"] if Lexicon.data.thing_statf(id, "weight_kg") >= Lexicon.balf("robot.heavy_hold_kg") else holds["default"])
		hold_clip = String(holds["by_thing"].get(id, fallback))
	var reference: = _rig.globals(_rig.sample(hold_clip, 0.0, _rig.rest))
	_reference_hand = reference[_rig.bone("hand.R")].basis

	_rest_rotation = Basis(Vector3.RIGHT, deg_to_rad(78.0 if _front_slot else 52.0)) if melee else Basis.IDENTITY
	_arms = RobotArmIK.new(_rig)

func apply_hold(base: RobotRig.Pose, age: float, delta: float, assembly: float) -> RobotRig.Pose:
	visible = model != null and assembly > 0.96
	if model == null: return base
	var pose: = _rig.sample(hold_clip, 0.0, base)
	_rig.add_delta("Breath_Calm_Add", age, 0.3, pose)
	var globals: = _rig.globals(pose)
	var hand_bone: = _rig.bone("hand.R")
	if not _rest_rotation.is_equal_approx(Basis.IDENTITY):

		var held: = globals[hand_bone].basis * _reference_hand.inverse() * _rest_rotation
		var parent: = globals[_rig.parent[hand_bone]].basis
		pose.rot[hand_bone] = (parent.inverse() * held * _reference_hand).get_rotation_quaternion()
		globals = _rig.globals(pose)
	var hand: = globals[hand_bone]
	var socket: = globals[_rig.bone(String(_config["hand_socket"]))].origin
	var rotation: = hand.basis * _reference_hand.inverse()
	var weapon: = Transform3D(rotation, socket - rotation * (main_grip * _model_scale))

	if support_grip is Vector3 and hold_clip != "Hold_Pistol":
		var at: Vector3 = weapon * (support_grip * _model_scale)
		var target: = _arms.held_target("L", at, rotation, Transform3D.IDENTITY, hold_clip)
		_arms.reach(pose, "L", target, delta)
	transform = _skeleton_local * weapon
	return pose
