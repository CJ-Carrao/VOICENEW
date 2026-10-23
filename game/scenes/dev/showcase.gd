extends Node3D









const CELL: = Vector2(2.2, 1.5)

const FIT: = 1.6
const YAW_DEG: = -70.0
const WAIT_S: = 0.6

var _png: = ""
var _from_top: = false
var _as_thing: = false


func _ready() -> void :
	var phrases: Array[String] = []
	var columns: = 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frase="):
			phrases.append(arg.trim_prefix("--frase="))
		elif arg.begins_with("--png="):
			_png = arg.trim_prefix("--png=")
		elif arg == "--de-cima":
			_from_top = true
		elif arg == "--coisa":
			_as_thing = true
		elif arg.begins_with("--colunas="):
			columns = maxi(1, arg.trim_prefix("--colunas=").to_int())
	if phrases.is_empty():
		phrases.append("quero uma pistola")
	_studio()
	columns = mini(columns, phrases.size())
	var rows: = ceili(float(phrases.size()) / columns)
	for i in phrases.size():
		@warning_ignore("integer_division")
		var cell: = Vector2(i % columns - (columns - 1) * 0.5, - (i / columns) + (rows - 1) * 0.5)
		_show(phrases[i], Vector3(cell.x * CELL.x, cell.y * CELL.y, 0.0))
	var camera: = Camera3D.new()
	camera.fov = 30.0
	var view: = get_viewport().get_visible_rect().size
	var span: = maxf(columns * CELL.x / (view.x / maxf(view.y, 1.0)), rows * CELL.y)
	camera.position = Vector3(0.0, 0.35, span / (2.0 * tan(deg_to_rad(camera.fov * 0.5))) + 0.6)
	add_child(camera)
	camera.make_current()
	if not _png.is_empty():
		await get_tree().create_timer(WAIT_S).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_png)
		print("[Vitrine] print salvo em ", _png)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()



func _show(phrase: String, at: Vector3) -> void :
	var result: = PhraseParser.parse(phrase, Lexicon.data)
	var holder: = Node3D.new()
	holder.position = at
	add_child(holder)
	var label: = Label3D.new()
	label.text = "%s\n%s" % [phrase, result["pretty"] if result["ok"] else "(não entendi)"]
	label.font_size = 30
	label.outline_size = 8
	label.pixel_size = 0.0035
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = CELL.x * 0.95 / label.pixel_size
	label.position = Vector3(0.0, - CELL.y * 0.38, 0.0)
	label.modulate = Color(0.92, 0.94, 1.0)
	holder.add_child(label)
	if not result["ok"] or (result["recipe"] as Dictionary).has("ability"):
		return
	var recipe: Dictionary = result["recipe"]
	var model: Node3D
	var bounds: AABB
	if _as_thing:
		var thing: = Assembler.build(recipe, "head", Lexicon.data)
		thing.set_physics_process(false)
		model = thing
		bounds = thing.bounds
	else:
		var built: = ModelBuilder.build(String(recipe["thing"]), recipe.get("mods", {}), Lexicon.data)
		model = built["root"]
		bounds = built["bounds"]
	var size: = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit: = FIT / maxf(size, 0.001)
	var pivot: = Node3D.new()
	pivot.rotation_degrees = Vector3(0.0, YAW_DEG, 0.0)
	if _from_top:

		pivot.basis = Basis(Vector3.BACK, - PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	pivot.scale = Vector3.ONE * fit
	pivot.position = Vector3(0.0, 0.12, 0.0)
	holder.add_child(pivot)
	pivot.add_child(model)
	model.position = - bounds.get_center() / maxf(model.scale.x, 0.001)


func _studio() -> void :
	var environment: = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.14, 0.17)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	var world: = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key: = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)
	var fill: = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.75, 0.82, 1.0)
	add_child(fill)
