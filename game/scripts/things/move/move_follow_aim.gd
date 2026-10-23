class_name MoveFollowAim
extends MoveStraight



const DOT_RADIUS: = 0.14

var _turn: float = 0.0
var _dot: MeshInstance3D


func _configure(lex: LexiconData) -> void :
	super._configure(lex)
	_turn = deg_to_rad(lex.balf("movement.follow_aim_turn_deg_per_s"))


func step(delta: float) -> void :
	var owner: = thing.owner_player as Player
	if owner != null and owner.aiming and not steering:
		var point: Vector3 = owner.aim()["point"]
		thing.velocity = steer(thing.velocity, point - thing.global_position, _turn * delta)
		_show_dot(point)
	else:
		_hide_dot()
	super.step(delta)


func _exit_tree() -> void :
	if is_instance_valid(_dot):
		_dot.queue_free()


func _show_dot(point: Vector3) -> void :
	if not is_instance_valid(_dot):
		_dot = MeshInstance3D.new()
		var sphere: = SphereMesh.new()
		sphere.radius = DOT_RADIUS
		sphere.height = DOT_RADIUS * 2.0
		_dot.mesh = sphere
		var material: = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.15, 0.1)
		material.no_depth_test = true
		_dot.material_override = material
		_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Forge.fx_root(thing).add_child(_dot)
	_dot.visible = true
	_dot.global_position = point


func _hide_dot() -> void :
	if is_instance_valid(_dot):
		_dot.visible = false
