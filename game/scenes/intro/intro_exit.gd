class_name IntroExit
extends Node2D

var cfg: Dictionary = {}
var _mesh: MultiMesh
var _buffer: = PackedFloat32Array()
var _origins: = PackedVector2Array()
var _tile: float = 24.0
var _columns: int = 0


func setup(config: Dictionary) -> void :
	cfg = config
	visible = false


func capture(screen: Texture2D, panel_width: float, canvas: Vector2) -> void :
	var picture: = screen.get_image()
	var texture: = ImageTexture.create_from_image(picture)
	_tile = float(cfg["tile_px"]) * canvas.y / 720.0
	_columns = ceili(panel_width / _tile)
	var rows: = ceili(canvas.y / _tile)
	var total: = _columns * rows
	_mesh = MultiMesh.new()
	_mesh.transform_format = MultiMesh.TRANSFORM_2D
	_mesh.use_colors = true
	_mesh.use_custom_data = true
	var quad: = QuadMesh.new()
	quad.size = Vector2.ONE
	_mesh.mesh = quad
	_mesh.instance_count = total
	var instance: = MultiMeshInstance2D.new()
	instance.multimesh = _mesh
	instance.texture = texture
	var surface: = ShaderMaterial.new()
	surface.shader = load("res://scenes/intro/exit_tiles.gdshader")
	instance.material = surface
	add_child(instance)
	_buffer.resize(total * 16)
	_origins.resize(total)
	for i in total:
		@warning_ignore("integer_division")
		var at: = Vector2(i % _columns, i / _columns) * _tile
		_origins[i] = at + Vector2.ONE * _tile * 0.5
		var b: = i * 16
		_buffer[b + 8] = 1.0
		_buffer[b + 9] = 1.0
		_buffer[b + 10] = 1.0
		_buffer[b + 12] = at.x / canvas.x
		_buffer[b + 13] = at.y / canvas.y
		_buffer[b + 14] = _tile / canvas.x
		_buffer[b + 15] = _tile / canvas.y
	visible = true
	sample(0.0)


func sample(progress: float) -> void :
	if _mesh == null:
		return
	var stagger: = float(cfg["stagger"])
	for i in _origins.size():
		var noise: = fposmod(float(i) * 0.61803398875, 1.0)
		var delay: = (1.0 - float(i % _columns) / maxf(_columns - 1, 1.0)) * stagger
		var u: = clampf((progress - delay) / (1.0 - stagger), 0.0, 1.0)
		var at: = _origins[i] + Vector2( - float(cfg["travel_px"]) * u * u, (noise - 0.65) * float(cfg["lift_px"]) * u)
		var angle: = (noise - 0.5) * float(cfg["spin"]) * u
		var side: = _tile * (1.0 - 0.65 * u)
		var b: = i * 16
		_buffer[b] = cos(angle) * side
		_buffer[b + 1] = - sin(angle) * side
		_buffer[b + 3] = at.x
		_buffer[b + 4] = sin(angle) * side
		_buffer[b + 5] = cos(angle) * side
		_buffer[b + 7] = at.y
		_buffer[b + 11] = 1.0 - u
	_mesh.buffer = _buffer
