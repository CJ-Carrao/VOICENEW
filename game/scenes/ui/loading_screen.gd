class_name LoadingScreen
extends CanvasLayer








const LOGO: = "res://assets/intro/logos/lavoice.svg"
const YELLOW: = Color("#ffc928")


static var current: LoadingScreen = null

var _progress: float = 0.0
var _shown: float = 0.0
var _clock: float = 0.0
var _closing: = false
var _root: Control
var _logo: TextureRect
var _logo_material: ShaderMaterial
var _dots: Array[Panel] = []
var _label: Label
var _stripe: ColorRect
const SWAP_S: = 0.9
const SECTIONS: Array[String] = ["rear", "front", "muzzle"]
var _gun_view: SubViewport
var _gun_screen: TextureRect
var _gun_pivot: Node3D
var _gun: Node3D
var _parts: = {}
var _weapons: Array[String] = []
var _swap_left: = 0.0
var _pop: = 0.0
var _rng: = RandomNumberGenerator.new()



static func open(tree: SceneTree) -> LoadingScreen:
	if current != null and is_instance_valid(current):
		return current
	var screen: = LoadingScreen.new()
	tree.root.add_child(screen)
	current = screen
	return screen



func set_progress(value: float) -> void :
	_progress = maxf(_progress, clampf(value, 0.0, 1.0))



func close() -> void :
	if _closing:
		return
	_closing = true
	_progress = 1.0
	if current == self:
		current = null
	var tween: = create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(_root, "modulate:a", 0.0, 0.35)
	tween.tween_callback(queue_free)


func _ready() -> void :
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var background: = ColorRect.new()
	background.color = YELLOW
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(background)
	_stripe = ColorRect.new()
	_stripe.color = Color("#0d0d10")
	_root.add_child(_stripe)
	var font: = MainMenu._variation(load("res://assets/fonts/oxanium/Oxanium-Variable.ttf") as Font, 800, 6)
	_label = Label.new()
	_label.text = "CARREGANDO"
	_label.add_theme_font_override("font", font)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_root.add_child(_label)
	for i in 3:
		var dot: = Panel.new()
		var style: = StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.set_corner_radius_all(64)
		dot.add_theme_stylebox_override("panel", style)
		_root.add_child(dot)
		_dots.append(dot)
	_logo = TextureRect.new()
	if ResourceLoader.exists(LOGO):
		_logo.texture = load(LOGO)
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var shader: = Shader.new()


	shader.code = "\nshader_type canvas_item;\nuniform float progress = 0.0;\nuniform vec2 grid = vec2(56.0, 14.0);\nfloat hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }\nvoid fragment() {\n\tvec2 cell = floor(UV * grid);\n\tfloat order = (cell.x / grid.x) * 0.75 + hash(cell) * 0.25;\n\tfloat k = clamp((progress * 1.2 - order) / 0.12, 0.0, 1.0);\n\tfloat s = k * (1.0 + 0.25 * sin(k * 3.14159));\n\tvec2 local = fract(UV * grid) - 0.5;\n\tif (s <= 0.001 || abs(local.x) > s * 0.5 || abs(local.y) > s * 0.5) { discard; }\n\tvec2 uv = (cell + 0.5 + local / s) / grid;\n\tCOLOR = vec4(1.0, 1.0, 1.0, texture(TEXTURE, uv).a);\n}\n"















	_logo_material = ShaderMaterial.new()
	_logo_material.shader = shader
	_logo.material = _logo_material
	_root.add_child(_logo)
	_build_gun_stage()



func _build_gun_stage() -> void :
	for id: String in Lexicon.data.models:
		if Lexicon.data.is_weapon(id) and not Lexicon.data.is_melee(id) and not (Lexicon.data.models[id].get("pieces", []) as Array).is_empty():
			_weapons.append(id)
	_weapons.sort()
	if _weapons.is_empty():
		return
	_rng.randomize()
	_gun_view = SubViewport.new()
	_gun_view.size = Vector2i(1280, 640)
	_gun_view.transparent_bg = true
	_gun_view.own_world_3d = true
	add_child(_gun_view)
	var world: = WorldEnvironment.new()
	var env: = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1d0")
	env.ambient_light_energy = 0.55
	world.environment = env
	_gun_view.add_child(world)
	var key: = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.3
	_gun_view.add_child(key)
	var rim: = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, 200, 0)
	rim.light_energy = 0.6
	_gun_view.add_child(rim)
	var camera: = Camera3D.new()
	camera.position = Vector3(0, 0.12, 2.6)
	camera.fov = 30.0
	_gun_view.add_child(camera)
	_gun_pivot = Node3D.new()
	_gun_view.add_child(_gun_pivot)
	_gun_screen = TextureRect.new()
	_gun_screen.texture = _gun_view.get_texture()
	_gun_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gun_screen.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gun_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_gun_screen)
	var start: = _weapons[_rng.randi() % _weapons.size()]
	for section: String in SECTIONS:
		_parts[section] = start
	_rebuild_gun()



func _swap_part() -> void :
	var section: = SECTIONS[_rng.randi() % SECTIONS.size()]
	var pick: = _weapons[_rng.randi() % _weapons.size()]
	if pick == _parts[section] and _weapons.size() > 1:
		pick = _weapons[(_weapons.find(pick) + 1) % _weapons.size()]
	_parts[section] = pick
	_rebuild_gun()
	_pop = 1.0




func _rebuild_gun() -> void :
	if _gun != null:
		_gun.queue_free()
	var built: = ModelBuilder.build(String(_parts["rear"]), {"parts": _parts.duplicate()}, Lexicon.data)
	var model: Node3D = built["root"]
	var holder: = Node3D.new()
	holder.add_child(model)
	_gun_pivot.add_child(holder)
	_gun = holder
	var box: = AABB()
	var first: = true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: = node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var piece: = (holder.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
		box = piece if first else box.merge(piece)
		first = false
	if first:
		return
	var fit: = 2.0 / maxf(box.size.x, maxf(box.size.y, box.size.z))
	model.position -= box.get_center()
	holder.scale = Vector3.ONE * fit


func _process(delta: float) -> void :
	_clock += delta
	var view: = get_viewport().get_visible_rect().size
	var k: = view.y / 1080.0

	var stripe_h: = 132.0 * k
	var gap: = 78.0 * k
	_stripe.position = Vector2(0.0, view.y - gap - stripe_h)
	_stripe.size = Vector2(view.x, stripe_h)
	var mid: = _stripe.position.y + stripe_h * 0.5
	_label.add_theme_font_size_override("font_size", int(38.0 * k))
	_label.size = _label.get_minimum_size()
	_label.position = Vector2(72.0 * k, mid - _label.size.y * 0.5)
	var dot: = 10.0 * k
	for i in 3:

		var hop: = maxf(0.0, sin(_clock * 6.5 - float(i) * 0.75)) * 14.0 * k
		_dots[i].size = Vector2.ONE * dot
		_dots[i].position = Vector2(_label.position.x + _label.size.x + 16.0 * k + i * dot * 1.9, mid + 8.0 * k - hop)
	var logo_h: = 74.0 * k
	var logo_w: = logo_h * 5.0
	_logo.size = Vector2(logo_w, logo_h)
	_logo.position = Vector2(view.x - 72.0 * k - logo_w, mid - logo_h * 0.5)

	if _gun_pivot != null:

		var free_h: = _stripe.position.y
		_gun_screen.size = Vector2(view.x * 0.8, free_h * 0.92)
		_gun_screen.position = Vector2((view.x - _gun_screen.size.x) * 0.5, (free_h - _gun_screen.size.y) * 0.5)
		_gun_pivot.rotation.y = PI * 0.5 + _clock * 0.55
		_gun_pivot.rotation.x = sin(_clock * 0.7) * 0.12
		_pop = move_toward(_pop, 0.0, delta * 4.0)
		_gun_pivot.scale = Vector3.ONE * (1.0 + 0.12 * sin(_pop * PI))
		_swap_left -= delta
		if _swap_left <= 0.0:
			_swap_left = SWAP_S
			_swap_part()
	var want: = maxf(_progress, minf(_clock / 6.0, 0.35))
	_shown = move_toward(_shown, want, delta * 1.6)
	_logo_material.set_shader_parameter("progress", _shown)
