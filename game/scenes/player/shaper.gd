class_name Shaper
extends Node










signal changed


const GROUND_LINE_Y: = 0.02
const LINE_HEIGHT: = 0.01

var player: Player
var active: bool = false

var dims: Dictionary = {}

var focus: String = "scale"
var placement: String = ""
var thing_id: String = ""
var _spoken: Dictionary = {}
var _preview: Node3D
var _bounds: = AABB()
var _footprint: float = 0.0

static var _chalk: ShaderMaterial
static var _chalk_line: ShaderMaterial


func _ready() -> void :
	Forge.draft_changed.connect(_on_draft_changed)


func _exit_tree() -> void :
	_clear_preview()



func recipe() -> Dictionary:
	return Shape.apply(_spoken, dims, Lexicon.data)



func cost() -> float:
	return Forge.draft_cost(player.player_id, dims)



func size_m() -> Vector3:
	return _bounds.size



func measure_m(dim: String) -> float:
	match _axis_of(dim):
		"x":
			return _bounds.size.x
		"y":
			return _bounds.size.y
		"z":
			return _bounds.size.z
	return maxf(_bounds.size.x, maxf(_bounds.size.y, _bounds.size.z))



func weight_kg() -> float:
	var mods: Dictionary = recipe().get("mods", {})
	return Lexicon.data.thing_statf(thing_id, "weight_kg") * Shape.volume_factor(mods, Lexicon.balf("carry.weight_exponent"))


func in_hand() -> bool:
	return placement == "hand" or placement == "throwable"



func adjust(steps: int) -> void :
	if not active or steps == 0:
		return
	var before: = float(dims[focus])
	dims[focus] = Shape.clamp_dim(focus, before * pow(Lexicon.balf("shaping.step"), steps), Lexicon.data)
	if is_equal_approx(float(dims[focus]), before):

		dims[focus] = Shape.clamp_dim(focus, before + signf(steps) * Lexicon.balf("shaping.snap"), Lexicon.data)
	_rebuild()
	changed.emit()



func cycle_focus() -> void :
	if not active:
		return
	var ids: = Shape.dim_ids(Lexicon.data)
	focus = ids[(ids.find(focus) + 1) % ids.size()]
	changed.emit()



func confirm() -> void :
	if not active:
		return
	if in_hand():
		Forge.confirm_draft(player.player_id, dims)
		return
	var spot: Dictionary = Forge.placement_spot(player, placement)
	Forge.confirm_draft(player.player_id, dims, spot["base"], spot["forward"])



func cancel() -> void :
	if active:
		Forge.cancel_draft(player.player_id)


func _on_draft_changed(player_id: int) -> void :
	if player == null or player_id != player.player_id:
		return
	var draft: Dictionary = Forge.draft_of(player_id)
	if draft.is_empty():
		_end()
	else:
		_begin(draft)


func _begin(draft: Dictionary) -> void :
	_spoken = draft["recipe"]
	thing_id = String(_spoken.get("thing", ""))
	placement = Lexicon.data.placement_for(thing_id)
	dims = Shape.dims_of(_spoken, Lexicon.data)
	focus = String(draft.get("focus", "scale"))
	active = true
	if player.extracting:
		player.set_extracting(false)
	_rebuild()
	changed.emit()


func _end() -> void :
	if not active:
		return
	active = false
	_clear_preview()

	if player.hands != null:
		player.hands.select(player.hands.current)
	changed.emit()


func _process(_delta: float) -> void :
	if not active or _preview == null or in_hand() or not _preview.is_inside_tree():
		return
	var spot: Dictionary = Forge.placement_spot(player, placement)
	_preview.global_transform = Transform3D(Basis.looking_at(spot["forward"], spot["up"]), spot["base"])



func _rebuild() -> void :
	var final: = recipe()
	var mods: Dictionary = final.get("mods", {})
	var count: = maxi(1, int(mods.get("count", 1))) if not in_hand() else 1
	_clear_preview()
	_preview = Node3D.new()
	_preview.name = "ChalkDraft"
	var offsets: = PackedFloat32Array()
	for i in count:
		var built: = ModelBuilder.build(thing_id, mods, Lexicon.data)
		var model: Node3D = built["root"]
		if i == 0:
			_bounds = built["bounds"]
			_footprint = maxf(_bounds.size.x, _bounds.size.z)
			offsets = Forge.side_offsets(count, _footprint)
		model.position.x = offsets[i]
		_chalk_all(model)
		_preview.add_child(model)
		if not in_hand():
			_preview.add_child(_ground_outline(_bounds, offsets[i]))
	if not player.is_local:
		_preview.free()
		_preview = null
		return
	if in_hand():
		var held: = player.hands.current_item()
		if held != null:
			held.visible = false
		player.hands.add_child(_preview)
	else:
		Forge.fx_root(player).add_child(_preview)
		_process(0.0)


func _clear_preview() -> void :
	if _preview != null and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


func _chalk_all(node: Node) -> void :
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = _chalk_material()
		(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_chalk_all(child)



func _ground_outline(box: AABB, offset_x: float) -> Node3D:
	var outline: = Node3D.new()
	outline.name = "GroundOutline"
	var line: = Lexicon.balf("shaping.chalk_line_m")
	var x0: = box.position.x + offset_x
	var x1: = x0 + box.size.x
	var z0: = box.position.z
	var z1: = z0 + box.size.z
	for segment: Array in [[Vector3(x0, 0, z0), Vector3(x1, 0, z0)], [Vector3(x0, 0, z1), Vector3(x1, 0, z1)], 
			[Vector3(x0, 0, z0), Vector3(x0, 0, z1)], [Vector3(x1, 0, z0), Vector3(x1, 0, z1)]]:
		var a: Vector3 = segment[0]
		var b: Vector3 = segment[1]
		var stroke: = MeshInstance3D.new()
		var mesh: = BoxMesh.new()
		mesh.size = Vector3(maxf(absf(b.x - a.x), line), LINE_HEIGHT, maxf(absf(b.z - a.z), line))
		stroke.mesh = mesh
		stroke.material_override = _chalk_line_material()
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stroke.position = (a + b) * 0.5 + Vector3.UP * GROUND_LINE_Y
		outline.add_child(stroke)
	return outline


func _axis_of(dim: String) -> String:
	if dim == "scale":
		return ""
	var axes: Dictionary = Lexicon.data.thing_def(thing_id).get("shape_axes", {})
	return String(axes.get(dim, ModelBuilder.DEFAULT_AXES.get(dim, "")))


static func _chalk_material() -> ShaderMaterial:
	if _chalk == null:
		_chalk = _make_chalk(Lexicon.balf("shaping.chalk_alpha"))
	return _chalk


static func _chalk_line_material() -> ShaderMaterial:
	if _chalk_line == null:
		_chalk_line = _make_chalk(0.85)
	return _chalk_line


static func _make_chalk(alpha: float) -> ShaderMaterial:
	var material: = ShaderMaterial.new()
	material.shader = preload("res://scenes/player/chalk.gdshader")
	material.set_shader_parameter("chalk", Color.from_string(String(Lexicon.bal("shaping.chalk_color", "#f3efe2")), Color.WHITE))
	material.set_shader_parameter("alpha", alpha)
	return material
