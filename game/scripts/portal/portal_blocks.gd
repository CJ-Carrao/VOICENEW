class_name PortalBlocks
extends MultiMeshInstance3D








var _cells: Array[Dictionary] = []
var _mode: = ""
var _clock: = 0.0
var _cfg: Dictionary = {}
var _cell: = 0.25

var _origin: = Transform3D.IDENTITY



func setup(portal: Portal) -> void :
	name = "Blocks"
	_cfg = Lexicon.bal("portal.fx", {})
	_cell = float(_cfg.get("cell_m", 0.25))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var half: = portal.size * 0.5
	var space: = portal.get_world_3d().direct_space_state
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(portal.global_position)
	var columns: = int(ceil(half.x / _cell))
	var rows: = int(ceil(half.y / _cell))
	for i in range( - columns, columns):
		for j in range( - rows, rows):
			var center: = Vector2((i + 0.5) * _cell, (j + 0.5) * _cell)
			if absf(center.x) > half.x or absf(center.y) > half.y:
				continue
			var at: = Vector3(center.x, center.y, 0.0)
			var normal: = Vector3.BACK
			var from: = portal.global_transform * Vector3(center.x, center.y, 0.6)
			var to: = portal.global_transform * Vector3(center.x, center.y, -1.5)
			var hit: = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, PhysicsLayers.WORLD | PhysicsLayers.THINGS))
			if not hit.is_empty():
				at = portal.to_local_point(hit["position"])
				normal = (portal.global_basis.inverse() * (hit["normal"] as Vector3)).normalized()
			var grey: = 0.62 + rng.randf() * 0.1
			_cells.append({"at": at, "normal": normal, "dist": center.length(), 
				"axis": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), 
				"color": Color(grey, grey, grey), "fling": Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0.0)})
	var box: = BoxMesh.new()
	box.size = Vector3.ONE * _cell * 0.94
	var material: = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.85
	box.material = material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = _cells.size()
	for i in _cells.size():
		multimesh.set_instance_color(i, _cells[i]["color"])
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	visible = false


func play(mode: String) -> void :
	_mode = mode
	_clock = 0.0
	visible = true



func burst(new_parent: Node) -> void :
	_origin = global_transform
	var keep: = global_transform
	get_parent().remove_child(self)
	new_parent.add_child(self)
	top_level = true
	global_transform = keep
	play("burst")


func advance(delta: float) -> void :
	if _mode.is_empty():
		return
	_clock += delta
	var wave: = float(_cfg.get("wave_ms", 4.0))
	var jump: = float(_cfg.get("jump_m", 0.22))
	var jump_s: = float(_cfg.get("jump_s", 0.28))
	var pop_s: = float(_cfg.get("pop_s", 0.35))
	var reveal: = float(_cfg.get("reveal_ms", 3.5))
	var burst_s: = float(_cfg.get("burst_s", 0.7))
	var busy: = false
	for i in _cells.size():
		var cell: Dictionary = _cells[i]
		var normal: Vector3 = cell["normal"]

		var rest: Vector3 = (cell["at"] as Vector3) - normal * _cell * 0.5
		var shown: = Transform3D(Basis.from_scale(Vector3.ZERO), rest)
		match _mode:
			"open":
				var t: = _clock - float(cell["dist"]) / wave
				if t >= 0.0 and t <= jump_s:
					var k: = sin(PI * t / jump_s)
					shown = Transform3D(Basis(cell["axis"], k * 0.35), rest + normal * jump * k)
				busy = busy or t < jump_s
			"reveal":
				var t: = _clock - float(cell["dist"]) / reveal
				if t >= 0.0 and t <= pop_s:
					var k: = t / pop_s
					var size: = 1.0 - smoothstep(0.25, 1.0, k)
					shown = Transform3D(Basis(cell["axis"], k * 1.6).scaled(Vector3.ONE * size), 
						rest + normal * jump * 0.8 * sin(minf(k * 1.4, 1.0) * PI * 0.5))
				busy = busy or t < pop_s
			"burst":
				var t: = _clock - float(cell["dist"]) / (wave * 2.0)
				if t >= 0.0 and t <= burst_s:
					var speed: = float(_cfg.get("burst_speed_ms", 3.0))
					var velocity: Vector3 = normal * speed + (cell["fling"] as Vector3) * speed * 0.5
					var fall: = _origin.basis.inverse() * Vector3.DOWN * 9.8 * 0.5 * t * t
					shown = Transform3D(Basis(cell["axis"], t * 8.0).scaled(Vector3.ONE * (1.0 - t / burst_s)), 
						rest + velocity * t + fall)
				busy = busy or t < burst_s
		multimesh.set_instance_transform(i, shown)
	if not busy:
		_mode = ""
		visible = false
		if top_level:
			queue_free()
