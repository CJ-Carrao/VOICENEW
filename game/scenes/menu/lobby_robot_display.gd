extends Node3D

const WEAPON: = preload("res://scenes/menu/lobby_weapon_display.gd")

var rig: RobotRig
var face: RobotFace
var parts: Array[Dictionary] = []
var slot: int
var _skeleton_local: Transform3D
var weapon: Node3D
var color_rgb24: int = -2
var _tinted_materials: Array[Dictionary] = []
var _selection_tint: float = 1.0

var _paint_materials: Dictionary = {}

func setup(config: Dictionary, clips: Dictionary, face_data: Dictionary, player_slot: int) -> void :
	slot = player_slot
	_selection_tint = clampf(float(config.get("selection_tint", 1.0)), 0.0, 1.0)
	var model: = (load(String(config["model"])) as PackedScene).instantiate() as Node3D
	add_child(model)
	rig = RobotRig.new(model, clips)
	_skeleton_local = global_transform.affine_inverse() * rig.skeleton.global_transform
	var face_material: = ShaderMaterial.new()
	face_material.shader = load(String(config["face_shader"]))
	face = RobotFace.new(face_material, face_data, 601 + slot)
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var source: = child as MeshInstance3D
		if (config["hidden_meshes"] as Array).has(String(source.name)) or source.skin == null:
			continue
		var bones: PackedInt32Array = source.mesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
		if bones.is_empty(): continue
		var bind_index: = bones[0]
		var bone: = rig.bone(String(source.skin.get_bind_name(bind_index)))
		if bone < 0: bone = source.skin.get_bind_bone(bind_index)
		if bone < 0: continue
		var pivot: = Node3D.new()
		pivot.name = "Part_" + String(source.name)
		add_child(pivot)
		var shape: = MeshInstance3D.new()
		shape.mesh = source.mesh
		shape.material_override = source.material_override
		var center: = source.mesh.get_aabb().get_center()
		shape.position = - center
		if String(source.name) == String(config["face_mesh"]):
			shape.material_override = face_material
		elif (config["team_parts"] as Array).has(String(source.name)) or RobotPaint.is_paintable(String(source.name)):
			var original: = source.get_active_material(0) as StandardMaterial3D
			if original != null:
				var own: = original.duplicate() as StandardMaterial3D
				shape.material_override = own
				if (config["team_parts"] as Array).has(String(source.name)):
					_tinted_materials.append({"material": own, "original": original.albedo_color})
				if RobotPaint.is_paintable(String(source.name)):
					_paint_materials[String(source.name)] = own
		pivot.add_child(shape)
		var i: = parts.size()
		parts.append({"node": pivot, "shape": shape, "name": String(source.name), "bone": bone, "bind": source.skin.get_bind_pose(bind_index), 
			"center": center, "from": Vector3(sin(i * 2.399 + slot) * 0.38, -0.2, cos(i * 2.399 + slot) * 0.38), 
			"spin": Vector3(0.3, -0.6, 0.22) * (1.0 if i % 2 == 0 else -1.0), 
			"delay": clampf(center.y / 1.81, 0.0, 1.0) * 0.66})
	model.visible = false
	weapon = WEAPON.new()
	weapon.name = "WeaponDisplay"
	add_child(weapon)
	weapon.setup(rig, config, _skeleton_local, slot)
	set_color_rgb24(-1)


func set_color_rgb24(rgb24: int) -> void :
	var next: = rgb24 if rgb24 >= 0 and rgb24 <= 16777215 else -1
	if next == color_rgb24: return
	color_rgb24 = next
	var color: = RobotColor.from_rgb24(next)
	for entry: Dictionary in _tinted_materials:
		var original: Color = entry["original"]
		(entry["material"] as StandardMaterial3D).albedo_color = original.lerp(color, _selection_tint) if next >= 0 else original


func show_rest() -> void :
	if rig == null: return
	var globals: = rig.globals(rig.rest)
	for part: Dictionary in parts:
		var pivot: = part["node"] as Node3D
		pivot.visible = true
		var xf: Transform3D = _skeleton_local * globals[int(part["bone"])] * (part["bind"] as Transform3D)
		pivot.transform = Transform3D(xf.basis, xf * (part["center"] as Vector3))



func set_paint(canvas: RobotPaintCanvas) -> void :
	for part: String in _paint_materials:
		var material: = _paint_materials[part] as StandardMaterial3D
		var texture: = canvas.texture(part) if canvas != null else null
		material.detail_enabled = texture != null
		material.detail_albedo = texture
		material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1



func set_stickers(paint: RobotPaint) -> void :
	var shapes: = {}
	for part: Dictionary in parts:
		shapes[String(part["name"])] = part["shape"]
	StickerDecals.rebuild(paint, func(name: String) -> Node3D: return shapes.get(name), shapes.values())


func set_weapon(id: String) -> void :
	if weapon != null: weapon.set_item(id)

func animate(delta: float, age: float, assembly: float, clip: String = "Idle", expression: String = "Neutral", strength: float = 1.0, gaze: Vector2 = Vector2.ZERO) -> void :
	if not visible or rig == null: return
	var pose: = rig.sample("Idle", age, rig.rest)
	rig.add_delta("Breath_Calm_Add", age, 0.42, pose)
	if clip != "Idle":
		pose.blend(rig.sample(clip, age, rig.rest), strength)
	else:
		var fidget: = fposmod(age + float(slot) * 1.71, 18.0) - 8.0
		var length: = rig.length("Idle_HeadTilt")
		if fidget > 0.0 and fidget < length:
			pose.blend(rig.sample("Idle_HeadTilt", fidget, rig.rest), sin(fidget / length * PI) * 0.5)
	if weapon != null: pose = weapon.apply_hold(pose, age, delta, assembly)
	var globals: = rig.globals(pose)
	for part: Dictionary in parts:
		var pivot: = part["node"] as Node3D
		var amount: = clampf((assembly * 1.18 - float(part["delay"])) / 0.52, 0.0, 1.0)
		pivot.visible = amount > 0.001
		if not pivot.visible: continue
		var ease: = 1.0 - pow(1.0 - amount, 3.0)
		var xf: Transform3D = _skeleton_local * globals[int(part["bone"])] * (part["bind"] as Transform3D)
		var spin: Vector3 = (part["spin"] as Vector3) * (1.0 - ease)
		var growth: = maxf(0.001, smoothstep(0.0, 0.7, amount)) + sin(clampf((amount - 0.7) / 0.3, 0.0, 1.0) * PI) * 0.02
		pivot.transform = Transform3D((Basis.from_euler(spin) * xf.basis).scaled(Vector3.ONE * growth), 
			(part["from"] as Vector3).lerp(xf * (part["center"] as Vector3), ease))
	face.set_expression(expression)
	face.advance(delta)
	if gaze != Vector2.ZERO:
		face.material.set_shader_parameter("gaze", gaze + Vector2(sin(age * 1.7), sin(age * 2.1)) * 0.003)
