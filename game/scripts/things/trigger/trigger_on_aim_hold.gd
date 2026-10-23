class_name TriggerOnAimHold
extends ThingTrigger





const MARK_HEIGHT: = 0.03

var _progress: float = 0.0
var _point: Vector3 = Vector3.ZERO
var _armed: bool = true
var _active: bool = false
var _tolerance: float = 0.0
var _mark_radius: float = 0.0
var _mark: Node3D
var _fill: MeshInstance3D


func activate() -> void :
	_tolerance = Lexicon.balf("triggers.aim_hold_tolerance_m")
	_mark_radius = Lexicon.balf("triggers.aim_hold_mark_radius")
	_active = true


func _physics_process(delta: float) -> void :
	if not thing.has_simulation_authority():
		return
	if not _active or thing.is_dead:
		return
	var owner: = thing.owner_player as Player
	var engaged: = owner != null and owner.aiming and ( not thing.is_held or owner.hands.current_item() == thing)
	if not engaged:
		_progress = 0.0
		_armed = true
		_show_mark(false)
		return
	if not _armed:
		return
	var point: = Forge.ground_point(Forge.clamp_to_arena(owner.aim()["point"]), owner.up())
	if _progress > 0.0 and point.distance_to(_point) > _tolerance:
		_progress = 0.0
	if _progress == 0.0:
		_point = point
	_progress += delta
	var duration: = param("s", 2.0)
	_show_mark(true, clampf(_progress / duration, 0.0, 1.0))
	if _progress >= duration:
		_progress = 0.0
		_armed = false
		_show_mark(false)
		var direction: = _point - owner.global_position
		direction.y = 0.0
		fire(ActionContext.make(_point, direction))


func _exit_tree() -> void :
	if is_instance_valid(_mark):
		_mark.queue_free()


func network_presentation() -> Dictionary:
	return {"visible": is_instance_valid(_mark) and _mark.visible, "point": _point, 
		"fill": clampf(_progress / maxf(param("s", 2.0), 0.001), 0.0, 1.0)}


func apply_network_presentation(state: Dictionary) -> void :
	if not thing.network_replica:
		return
	_mark_radius = Lexicon.balf("triggers.aim_hold_mark_radius")
	_point = state.get("point", Vector3.ZERO)
	_show_mark(bool(state.get("visible", false)), float(state.get("fill", 0.0)))



func _show_mark(visible_now: bool, fill: float = 0.0) -> void :
	if not visible_now:
		if is_instance_valid(_mark):
			_mark.visible = false
		return
	if not is_instance_valid(_mark):
		_build_mark()
	_mark.visible = true
	var up: = Gravity.up_at(_point, owner_up())
	_mark.global_transform = Transform3D(Gravity.frame_for(up), _point + up * MARK_HEIGHT)
	_fill.scale = Vector3(maxf(fill, 0.05), 1.0, maxf(fill, 0.05))


func _build_mark() -> void :
	_mark = Node3D.new()
	_mark.name = "AimHoldMark"
	var material: = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.2, 0.15, 0.55)
	var ring: = MeshInstance3D.new()
	var torus: = TorusMesh.new()
	torus.inner_radius = _mark_radius * 0.92
	torus.outer_radius = _mark_radius
	ring.mesh = torus
	ring.material_override = material
	_mark.add_child(ring)
	_fill = MeshInstance3D.new()
	var disc: = CylinderMesh.new()
	disc.top_radius = _mark_radius * 0.9
	disc.bottom_radius = _mark_radius * 0.9
	disc.height = 0.01
	_fill.mesh = disc
	_fill.material_override = material
	_mark.add_child(_fill)
	Forge.fx_root(thing).add_child(_mark)



func owner_up() -> Vector3:
	var owner: = thing.owner_player as Player
	return owner.up() if owner != null and is_instance_valid(owner) else thing.up()
