extends Node3D


var pivot: Node3D
var _front: Node3D
var _back: Node3D
var _title: Label3D
var _heading: Label3D
var _mode: String = ""


const MAPS_PATH: = "res://data/world/maps.json"
const GRID_COLUMNS: = 4
const GRID_ROWS: = 2
const CELL: = 0.52
const GAP: = 0.06
const GRID_CENTER: = Vector3(0.0, -0.23, 0.1)
var _cells: Array[Dictionary] = []
var _cursor: Node3D
var _cursor_tween: Tween
var _slots: Array[Label3D] = []
var _lamps: Array[StandardMaterial3D] = []
var _font: Font

func _ready() -> void :
	pivot = Node3D.new()
	add_child(pivot)
	var font: = FontVariation.new()
	font.base_font = load("res://assets/fonts/oxanium/Oxanium-Variable.ttf")
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 600}
	_font = font
	var body: = _chamfered_panel()
	pivot.add_child(body)
	_front = Node3D.new()
	_front.rotation.y = PI
	pivot.add_child(_front)
	_back = Node3D.new()
	_back.rotation.y = PI
	_back.rotation.x = PI
	pivot.add_child(_back)
	for i in 4:
		var x: = -0.65 if i % 2 == 0 else 0.65
		var y: = 0.49 if i < 2 else -0.49
		var panel: = _box(Vector3(1.14, 0.72, 0.022), Color("242a32"))
		panel.position = Vector3(x, y, 0.09)
		_front.add_child(panel)
		_lamps.append(panel.material_override as StandardMaterial3D)
		var label: = _label(_front, "P%d  /  LIVRE" % (i + 1), Vector3(x, y, 0.112), 0.0035, 32)
		_slots.append(label)
	_heading = _label(_back, "DESTINO DA PARTIDA", Vector3(0, 0.91, 0.095), 0.0042, 38)
	var bold: = font.duplicate() as FontVariation
	bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	_heading.font = bold
	_title = _label(_back, "ARENA ORIGINAL", Vector3(0, 0.64, 0.11), 0.0038, 32)
	_title.font = bold
	_build_grid(bold)
	set_arena("ARENA ORIGINAL", "res://assets/menu/arena_original.png")
	pose(0.0)


func set_arena(title: String, texture_path: String = "") -> void :
	if _title == null: return
	_title.text = title.to_upper()
	for cell: Dictionary in _cells:
		if String(cell["name"]).to_upper() == title.to_upper() or ( not texture_path.is_empty() and cell["image"] == texture_path):
			_move_cursor(cell["position"])
			return


func _build_grid(font: Font) -> void :
	var maps: Array = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS_PATH))
	if parsed is Dictionary:
		maps = (parsed as Dictionary).get("maps", [])
	for i in GRID_COLUMNS * GRID_ROWS:
		var column: = i % GRID_COLUMNS
		var row: = i / GRID_COLUMNS
		var at: = GRID_CENTER + Vector3((float(column) - (GRID_COLUMNS - 1) * 0.5) * (CELL + GAP), 
			((GRID_ROWS - 1) * 0.5 - float(row)) * (CELL + GAP), 0.0)
		var map: Dictionary = maps[i] if i < maps.size() else {}
		var cell: = _box(Vector3(CELL, CELL, 0.03), Color("2b313a") if not map.is_empty() else Color("181c22"))
		cell.position = at
		_back.add_child(cell)
		if map.is_empty():
			continue
		var image: = String(map.get("image", ""))
		if ResourceLoader.exists(image):

			var texture: = load(image) as Texture2D
			var photo: = MeshInstance3D.new()
			var quad: = QuadMesh.new()
			quad.size = Vector2.ONE * (CELL - 0.04)
			photo.mesh = quad
			var material: = StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.albedo_texture = texture
			var keep: = float(texture.get_height()) / float(texture.get_width())
			material.uv1_scale = Vector3(keep, 1.0, 1.0)
			material.uv1_offset = Vector3((1.0 - keep) * 0.5, 0.0, 0.0)
			photo.material_override = material
			photo.position = Vector3(0.0, 0.0, 0.0155)
			cell.add_child(photo)

		var band: = MeshInstance3D.new()
		var strip: = QuadMesh.new()
		strip.size = Vector2(CELL - 0.04, 0.1)
		band.mesh = strip
		var shade: = StandardMaterial3D.new()
		shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shade.albedo_color = Color(0.0, 0.0, 0.0, 0.66)
		band.material_override = shade
		band.position = Vector3(0.0, - (CELL - 0.04 - 0.1) * 0.5, 0.02)
		cell.add_child(band)
		var name_label: = _label(cell, String(map.get("name", "")).to_upper(), Vector3(0.0, - (CELL - 0.04 - 0.1) * 0.5, 0.025), 0.0019, 30)
		name_label.font = font
		_cells.append({"name": String(map.get("name", "")), "image": image, "position": at, "node": cell})

	_cursor = Node3D.new()
	_back.add_child(_cursor)
	var reach: = CELL * 0.5 + 0.03
	for side in 4:
		var horizontal: = side < 2
		var bar: = _box(Vector3(reach * 2.0 + 0.04, 0.035, 0.04) if horizontal else Vector3(0.035, reach * 2.0 + 0.04, 0.04), 
			Color("f2601a"), true)
		var sign: = 1.0 if side % 2 == 0 else -1.0
		bar.position = Vector3(0.0, sign * reach, 0.03) if horizontal else Vector3(sign * reach, 0.0, 0.03)
		_cursor.add_child(bar)
	if not _cells.is_empty():
		_cursor.position = _cells[0]["position"]




func cell_at(camera: Camera3D, point: Vector2) -> int:
	if not _back.is_visible_in_tree():
		return -1
	for i in _cells.size():
		var at: Vector3 = _cells[i]["position"]
		var half: = CELL * 0.5
		var box: = Rect2()
		for corner: Vector3 in [Vector3( - half, - half, 0), Vector3(half, - half, 0), Vector3(half, half, 0), Vector3( - half, half, 0)]:
			var world: = _back.to_global(at + corner)
			if camera.is_position_behind(world):
				return -1
			var screen: = camera.unproject_position(world)
			box = Rect2(screen, Vector2.ZERO) if box.size == Vector2.ZERO and box.position == Vector2.ZERO else box.expand(screen)
		if box.has_point(point):
			return i
	return -1



func hover(index: int) -> void :
	for i in _cells.size():
		var node: Node3D = _cells[i]["node"]
		var want: = Vector3.ONE * (1.06 if i == index else 1.0)
		if not node.scale.is_equal_approx(want):
			node.create_tween().tween_property(node, "scale", want, 0.08)


func _move_cursor(to: Vector3) -> void :
	if _cursor == null or _cursor.position.is_equal_approx(to):
		return
	if _cursor_tween != null:
		_cursor_tween.kill()
	_cursor_tween = _cursor.create_tween()
	_cursor_tween.tween_property(_cursor, "position", to, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_phase(mode: String) -> void :
	if mode == _mode or _heading == null: return
	_mode = mode
	_heading.text = "ARENA CONFIRMADA" if mode == "versus" else "DESTINO DA PARTIDA"

func set_players(occupied: Dictionary, ready: Dictionary, selected_colors: Dictionary = {}) -> void :
	for i in _slots.size():
		var exists: = bool(occupied.get(i + 1, false))
		var locked: = bool(ready.get(i + 1, false))
		_slots[i].text = "P%d  /  %s" % [i + 1, "PRONTO" if locked else ("NA SALA" if exists else "LIVRE")]
		var rgb24: = int(selected_colors.get(i + 1, -1))
		var color: = RobotColor.from_rgb24(rgb24) if rgb24 >= 0 and rgb24 <= 16777215 else Color("a7adb6")
		_lamps[i].albedo_color = color.darkened(0.56 if locked else 0.75) if exists else Color("1c2127")

func pose(angle: float, anticipation: float = 0.0) -> void :
	if pivot == null: return
	pivot.rotation.x = angle
	pivot.scale = Vector3(1.0 + anticipation * 0.028, 1.0 - anticipation * 0.07, 1.0)
	_front.visible = cos(angle) >= 0.0
	_back.visible = not _front.visible

func _box(size: Vector3, color: Color, unshaded: bool = false) -> MeshInstance3D:
	var node: = MeshInstance3D.new()
	var box: = BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat: = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.35
	mat.roughness = 0.32
	if unshaded: mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = mat
	return node

func _label(parent: Node3D, text: String, position: Vector3, pixel_size: float, font_size: int) -> Label3D:
	var label: = Label3D.new()
	label.text = text
	label.position = position
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.font = _font
	label.outline_size = 2
	parent.add_child(label)
	return label

func _chamfered_panel() -> MeshInstance3D:
	var points: = PackedVector2Array([Vector2(-1.25, -1.15), Vector2(1.25, -1.15), Vector2(1.37, -1.03), Vector2(1.37, 1.03), Vector2(1.25, 1.15), Vector2(-1.25, 1.15), Vector2(-1.37, 1.03), Vector2(-1.37, -1.03)])
	var tool: = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for depth: float in [-0.07, 0.07]:
		for i in points.size():
			var a: = Vector3(points[i].x, points[i].y, depth)
			var b: = Vector3(points[(i + 1) % points.size()].x, points[(i + 1) % points.size()].y, depth)
			tool.add_vertex(Vector3(0, 0, depth))
			tool.add_vertex(a)
			tool.add_vertex(b)
	for i in points.size():
		var a: = points[i]
		var b: = points[(i + 1) % points.size()]
		for p: Vector3 in [Vector3(a.x, a.y, -0.07), Vector3(b.x, b.y, -0.07), Vector3(b.x, b.y, 0.07), Vector3(a.x, a.y, -0.07), Vector3(b.x, b.y, 0.07), Vector3(a.x, a.y, 0.07)]:
			tool.add_vertex(p)
		var bar: = _box(Vector3(a.distance_to(b), 0.025, 0.17), Color("ff791c"), true)
		bar.position = Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, 0)
		bar.rotation.z = (b - a).angle()
		pivot.add_child(bar)
	tool.generate_normals()
	var panel: = MeshInstance3D.new()
	panel.mesh = tool.commit()
	var material: = StandardMaterial3D.new()
	material.albedo_color = Color("15191f")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.metallic = 0.35
	material.roughness = 0.35
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	panel.material_override = material
	return panel
