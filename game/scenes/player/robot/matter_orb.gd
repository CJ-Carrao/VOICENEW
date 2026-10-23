class_name MatterOrb
extends Node3D






const GROUP: = "matter_orbs"

var player: Player
var _cfg: Dictionary
var _core: MeshInstance3D
var _core_material: StandardMaterial3D
var _blocks: MultiMeshInstance3D

var _colors: = PackedColorArray()
var _last_color: = Color.WHITE
var _spin: float = 0.0
var _pulse: = Vector2.ZERO
var _clock: float = 0.0
var _anchor: = Vector3.ZERO
var _anchor_ready: bool = false


func setup(owner_player: Player) -> void :
	player = owner_player
	name = "MatterOrb"
	top_level = true
	add_to_group(GROUP)

	process_priority = 11
	_cfg = Lexicon.bal("matter.orb", {})
	_last_color = Color.from_string(String(_cfg.get("default_color", "#ffd27a")), Color.GOLD)
	_core = MeshInstance3D.new()
	_core.name = "Core"
	var sphere: = SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	_core.mesh = sphere
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = _last_color
	_core_material.emission_enabled = true
	_core_material.emission = _last_color
	_core.material_override = _core_material
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)
	var cube: = BoxMesh.new()
	var size: = float(_cfg.get("block_m", 0.022))
	cube.size = Vector3.ONE * size
	var block_material: = StandardMaterial3D.new()
	block_material.vertex_color_use_as_albedo = true
	block_material.roughness = 0.5
	cube.material = block_material
	var multimesh: = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = int(_cfg.get("max_blocks", 40))
	multimesh.visible_instance_count = 0
	_blocks = MultiMeshInstance3D.new()
	_blocks.name = "Blocks"
	_blocks.multimesh = multimesh
	_blocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blocks)



func world_point() -> Vector3:
	return global_position



func absorb(from: Vector3, color: Color) -> void :
	var bit: = MeshInstance3D.new()
	bit.name = "MatterBit"
	var cube: = BoxMesh.new()
	cube.size = Vector3.ONE * float(_cfg.get("bit_m", 0.05))
	var material: = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color * 0.4
	cube.material = material
	bit.mesh = cube
	bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var root: = Forge.fx_root(player)
	if root == null:
		return
	root.add_child(bit)
	bit.global_position = from
	var flight: = float(_cfg.get("bit_flight_s", 0.35))
	var lift: = float(_cfg.get("bit_arc_m", 0.4))
	var start: = from
	var spin: = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))
	var tween: = bit.create_tween()
	tween.tween_method( func(t: float) -> void :
		if not is_instance_valid(bit):
			return

		var to: = global_position
		var mid: = start.lerp(to, 0.5) + (player.up() if player != null else Vector3.UP) * lift
		var a: = start.lerp(mid, t)
		var b: = mid.lerp(to, t)
		bit.global_position = a.lerp(b, t)
		bit.rotation = spin * t
		bit.scale = Vector3.ONE * lerpf(1.0, 0.35, t * t), 0.0, 1.0, flight).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback( func() -> void :
		_last_color = color
		_pulse.y += float(_cfg.get("pulse_kick", 1.2))
		bit.queue_free())



func spent() -> void :
	_pulse.y -= float(_cfg.get("pulse_kick", 1.2)) * 0.6


func _process(delta: float) -> void :
	if player == null:
		return
	_clock += delta
	visible = player.robot != null and player.robot.model.visible
	if not visible:
		return



	var frame: = player.global_transform
	var want: = frame.affine_inverse() * player.robot.orb_anchor_world()
	_anchor = want if not _anchor_ready else RobotSpring.damp_v3(_anchor, want, float(_cfg.get("follow_halflife_s", 0.05)), delta)
	_anchor = want + (_anchor - want).limit_length(float(_cfg.get("max_lag_m", 0.04)))
	_anchor_ready = true
	global_position = frame * _anchor + player.up() * sin(_clock * TAU * float(_cfg.get("bob_hz", 0.7))) * float(_cfg.get("bob_m", 0.012))


	var own_fp: = player.is_local and player.view != null and not player.view.is_third_person()
	scale = Vector3.ONE * (float(_cfg.get("fp_scale", 0.55)) if own_fp else 1.0)
	var fill: = clampf(player.matter / maxf(player.max_matter, 0.001), 0.0, 1.0)
	_pulse = RobotSpring.bouncy(_pulse, 0.0, float(_cfg.get("pulse_hz", 5.0)), 0.35, delta)

	var core_r: = lerpf(float(_cfg.get("core_min_m", 0.02)), float(_cfg.get("core_max_m", 0.06)), sqrt(fill))
	_core.scale = Vector3.ONE * core_r * 2.0 * (1.0 + _pulse.x * 0.15)
	_core_material.albedo_color = _core_material.albedo_color.lerp(_last_color, 1.0 - exp(-4.0 * delta))
	_core_material.emission = _core_material.albedo_color
	_core_material.emission_energy_multiplier = lerpf(0.4, float(_cfg.get("glow_max", 2.5)), fill)

	var count: = roundi(fill * float(_blocks.multimesh.instance_count))
	while _colors.size() < count:
		_colors.append(_last_color.lerp(Color.WHITE, 0.08 * float(_colors.size() % 3)))
	while _colors.size() > count:
		_colors.remove_at(_colors.size() - 1)
	_spin += delta * float(_cfg.get("spin_rad_s", 1.6)) * (1.0 + fill)
	var shell: = float(_cfg.get("shell_m", 0.07))
	var golden: = PI * (3.0 - sqrt(5.0))
	for i in count:
		var y: = 1.0 - 2.0 * (float(i) + 0.5) / float(maxi(count, 1))
		var r: = sqrt(maxf(0.0, 1.0 - y * y))
		var angle: = golden * i + _spin * (1.0 + 0.3 * float(i % 3))
		var radius: = (shell + core_r * 0.5) * (1.0 + _pulse.x * 0.2) * (0.85 + 0.15 * float(i % 4) / 3.0)
		var at: = Vector3(cos(angle) * r, y * 0.8, sin(angle) * r) * radius
		_blocks.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, angle * 1.7).rotated(Vector3.RIGHT, angle), at))
		_blocks.multimesh.set_instance_color(i, _colors[i])
	_blocks.multimesh.visible_instance_count = count
