extends Node3D













const CELL: = Vector2(2.2, 1.5)

const FIT: = 1.6
const YAW_DEG: = -70.0
const WAIT_S: = 0.6

var _png: = ""
var _transparent: = false
var _yaw: = NAN
var _tilt: = 0.0

var _size: = 1.0
var _from_top: = false

var _fit: = FIT
var _as_thing: = false
var _anim_mode: = ""
var _frames: = 0
var _preview_time: = 0.0
var _animators: Array[CreatureAnimator] = []


func _ready() -> void :
	var phrases: Array[String] = []
	var columns: = 3
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frase="):
			phrases.append(arg.trim_prefix("--frase="))
		elif arg.begins_with("--modelo="):
			phrases.append("#" + arg.trim_prefix("--modelo="))
		elif arg.begins_with("--catalogo="):
			var ids: Array[String] = []
			for file in DirAccess.get_files_at("res://data/models"):
				if file.ends_with(".json"):
					ids.append(file.get_basename())
			ids.sort()
			var page: = arg.trim_prefix("--catalogo=").to_int()
			for id in ids.slice(page * 30, page * 30 + 30):
				phrases.append("#" + id)
			columns = 6
			_fit = 1.0
		elif arg.begins_with("--png="):
			_png = arg.trim_prefix("--png=")
		elif arg == "--de-cima":
			_from_top = true
		elif arg == "--coisa":
			_as_thing = true
		elif arg == "--transparente":
			_transparent = true
		elif arg.begins_with("--giro="):
			_yaw = arg.trim_prefix("--giro=").to_float()
		elif arg.begins_with("--tamanho="):
			_size = arg.trim_prefix("--tamanho=").to_float()
		elif arg.begins_with("--inclina="):
			_tilt = arg.trim_prefix("--inclina=").to_float()
		elif arg.begins_with("--colunas="):
			columns = maxi(1, arg.trim_prefix("--colunas=").to_int())
		elif arg.begins_with("--animar="):
			_anim_mode = arg.trim_prefix("--animar=")
		elif arg.begins_with("--quadros="):
			_frames = maxi(1, arg.trim_prefix("--quadros=").to_int())
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
	if _frames > 0 and _png.is_empty():
		_png = "user://creature_anim.png"
	if _frames > 0:
		await get_tree().create_timer(WAIT_S).timeout
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_png.get_base_dir()))
		for frame in _frames:
			await RenderingServer.frame_post_draw
			var path: = _png.get_basename() + "_%04d.png" % frame
			get_viewport().get_texture().get_image().save_png(path)
		print("[Vitrine] sequência salva em ", _png.get_base_dir())
		get_tree().quit()
	elif not _png.is_empty():
		await get_tree().create_timer(WAIT_S).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_png)
		print("[Vitrine] print salvo em ", _png)
		get_tree().quit()


func _process(delta: float) -> void :
	if _anim_mode.is_empty():
		return
	var speed: = 1.4 if _anim_mode == "andar" else 4.0 if _anim_mode == "correr" else 0.0
	for animator in _animators:
		if _preview_time < delta and _anim_mode == "pousar":
			animator.on_hit()
		if _preview_time < delta and _anim_mode == "morrer":
			animator.on_death()
		animator.preview_step(speed * delta, speed, delta, _anim_mode == "atacar" and _preview_time < delta)
	_preview_time += delta


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()



func _show(phrase: String, at: Vector3) -> void :

	var result: = {"ok": true, "pretty": phrase.substr(1), "recipe": {"thing": phrase.substr(1), "mods": {}}} if phrase.begins_with("#") else PhraseParser.parse(phrase, Lexicon.data)
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
	if not _transparent:
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
		if not _anim_mode.is_empty() and thing.creature_animator != null:
			_animators.append(thing.creature_animator)
	else:
		var built: = ModelBuilder.build(String(recipe["thing"]), recipe.get("mods", {}), Lexicon.data)
		model = built["root"]
		bounds = built["bounds"]
		if not _anim_mode.is_empty() and not (built.get("rig", {}) as Dictionary).is_empty():
			var animator: = CreatureAnimator.new()
			animator.setup(null, built)
			holder.add_child(animator)
			_animators.append(animator)
	var size: = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var fit: = _fit * _size / maxf(size, 0.001)
	var pivot: = Node3D.new()
	pivot.rotation_degrees = Vector3(_tilt, YAW_DEG if is_nan(_yaw) else _yaw, 0.0)
	if _from_top:

		pivot.basis = Basis(Vector3.BACK, - PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	pivot.scale = Vector3.ONE * fit

	pivot.position = Vector3(0.0, 0.35 if _transparent else 0.12, 0.0)
	holder.add_child(pivot)
	pivot.add_child(model)
	model.position = - bounds.get_center() / maxf(model.scale.x, 0.001)


func _studio() -> void :
	var environment: = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.13, 0.14, 0.17)
	if _transparent:
		get_viewport().transparent_bg = true
		environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.65)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = not _transparent
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
