class_name SpaceIntro
extends Node3D











signal countdown_started(seconds: float)
signal finished

var _cfg: Dictionary
var _space: SpaceMap
var _player: Player
var _camera: Camera3D
var _music: AudioStreamPlayer
var _ui: CanvasLayer
var _black: ColorRect

var _knockout: ColorRect
var _knockout_material: ShaderMaterial
var _letters: SubViewport
var _subtitle: Label
var _hint: Label

var _t: float = 0.0
var _offset: float = 0.0
var _music_started: = false
var _counted: = false
var _done: = false
var _skip_armed: = false

var _builds: Array[Dictionary] = []
var _streams: MultiMeshInstance3D
var _stream_state: Array[Dictionary] = []
var _rng: = RandomNumberGenerator.new()

var _path: = PackedVector3Array()
var _path_len: = PackedFloat32Array()
var _sun_half: float = 5.0

var _dust: MultiMeshInstance3D
var _dust_material: ShaderMaterial
var _bars: Array[ColorRect] = []
var _attributes: CameraAttributesPractical

var _robot_built: = false
var _home: BlockPlanet


func setup(space: SpaceMap, player: Player) -> void :
	name = "SpaceIntro"
	_space = space
	_player = player
	_cfg = space.config.get("intro", {})
	_sun_half = float((space.config.get("sun", {}) as Dictionary).get("half", 5.0))
	_rng.seed = 7202610
	_space.set_walls_fade(0.0)
	_build_planets()
	_build_streams()
	_build_dust()
	_build_camera()
	_build_ui()
	_build_music()
	_build_flight()
	if _player.view != null:
		_player.view.suspended = true
	_home = _home_planet()
	if _player.robot != null:
		_player.robot.model.visible = false
	_update(0.0)






func _build_planets() -> void :
	var cube: = float(_cfg.get("interior_cube_m", 1.0))
	var relief: = Lexicon.balf("space.voxel.relief_m")
	var crust_m: = float(Lexicon.bal("space.voxel.crust_m", 2.0))
	var shader: = Shader.new()
	shader.code = "\nshader_type spatial;\nuniform float reveal = 0.0;\nuniform float band = 1.4;\nuniform vec3 hot : source_color = vec3(1.0, 0.42, 0.12);\nvarying float heat;\nvarying vec4 tint;\nvoid vertex() {\n\tfloat d = INSTANCE_CUSTOM.x;\n\tfloat k = clamp((reveal - d) / band, 0.0, 1.0);\n\theat = 1.0 - clamp((reveal - d) / (band * 0.7), 0.0, 1.0);\n\ttint = COLOR;\n\t// Cada cubo nasce do zero, passa um pouco do tamanho e assenta (a frente pulsa).\n\tVERTEX *= k * (1.0 + 0.3 * sin(k * 3.14159));\n}\nvoid fragment() {\n\tvec3 base = pow(tint.rgb, vec3(2.2));\n\tALBEDO = base;\n\tROUGHNESS = 0.8;\n\tEMISSION = base * tint.a * 2.2 + hot * heat * heat * 1.8;\n}\n"





















	for entry: Array in _cfg.get("build", []):
		var index: = int(entry[0])
		if index < 0 or index >= _space.planets.size():
			continue
		var planet: BlockPlanet = _space.planets[index]
		planet.set_reveal(0.0)
		var inner: = planet.radius - relief - cube * 0.6
		var deep_r: = maxf(planet.core_radius, planet.radius - crust_m)
		var cells: Array = []
		var n: = ceili(inner / cube)
		for x in range( - n, n + 1):
			for y in range( - n, n + 1):
				for z in range( - n, n + 1):
					var at: = Vector3(x, y, z) * cube
					var d: = at.length()
					if d <= inner:
						cells.append([d, at])
		cells.sort_custom( func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var multimesh: = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		var box: = BoxMesh.new()
		box.size = Vector3.ONE * cube * 0.98
		multimesh.mesh = box
		multimesh.instance_count = cells.size()
		var deep: = planet.color.darkened(0.45)
		var core: = Color(Lexicon.bal("materials.core.color", "#ff8a2a"))
		for i in cells.size():
			var d: float = cells[i][0]
			multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, cells[i][1]))
			multimesh.set_instance_custom_data(i, Color(d, 0.0, 0.0, 0.0))
			var color: = Color(core, 1.2) if d <= planet.core_radius else (Color(deep, 0.0) if d <= deep_r else Color(planet.color, 0.0))
			multimesh.set_instance_color(i, color)
		var material: = ShaderMaterial.new()
		material.shader = shader
		var node: = MultiMeshInstance3D.new()
		node.multimesh = multimesh
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		node.global_position = planet.global_position
		_builds.append({"planet": planet, "node": node, "material": material, 
			"full": planet.radius + relief + planet.size_m * 2.0, "start": float(entry[1]), "dur": float(entry[2])})



func _build_streams() -> void :
	var cfg: Dictionary = _cfg.get("streams", {})
	var count: = int(cfg.get("count", 400))
	var multimesh: = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	var box: = BoxMesh.new()
	box.size = Vector3.ONE * float(cfg.get("cube_m", 0.4))
	multimesh.mesh = box
	multimesh.instance_count = count
	var shader: = Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode unshaded, shadows_disabled;\nvoid fragment() {\n\tvec3 base = pow(COLOR.rgb, vec3(2.2));\n\tALBEDO = base * (1.0 + COLOR.a * 3.5);\n}\n"







	var material: = ShaderMaterial.new()
	material.shader = shader
	_streams = MultiMeshInstance3D.new()
	_streams.multimesh = multimesh
	_streams.material_override = material
	_streams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_streams)
	for i in count:
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO))

		_stream_state.append({"launch": - INF, "next": _rng.randf_range(0.0, 1.4), "build": -1})


func _build_camera() -> void :
	_camera = Camera3D.new()
	_camera.name = "IntroCamera"
	_camera.far = 600.0
	_camera.near = 0.05
	_attributes = CameraAttributesPractical.new()
	_attributes.dof_blur_far_enabled = false
	_camera.attributes = _attributes
	add_child(_camera)
	_camera.make_current()




func _build_dust() -> void :
	var cfg: Dictionary = _cfg.get("dust", {})
	var count: = int(cfg.get("count", 700))
	var box: = float(cfg.get("box_m", 36.0))
	var multimesh: = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cube: = BoxMesh.new()
	cube.size = Vector3.ONE
	multimesh.mesh = cube
	multimesh.instance_count = count
	for i in count:
		var at: = Vector3(_rng.randf(), _rng.randf(), _rng.randf()) * box
		var size: = _rng.randf_range(0.012, 0.045)
		multimesh.set_instance_transform(i, Transform3D(Basis(Vector3(_rng.randf(), _rng.randf(), _rng.randf()).normalized(), 
			_rng.randf() * TAU).scaled(Vector3.ONE * size), at))
	var shader: = Shader.new()
	shader.code = "\nshader_type spatial;\nrender_mode unshaded, shadows_disabled, blend_add, depth_draw_never, world_vertex_coords;\nuniform vec3 cam;\nuniform vec3 drift;\nuniform float box = 36.0;\nuniform float strength = 1.0;\nuniform vec3 tint : source_color = vec3(0.62, 0.7, 0.95);\nvarying float fade;\nvoid vertex() {\n\tvec3 origin = MODEL_MATRIX[3].xyz;\n\tvec3 rel = mod(origin + drift - cam + box * 0.5, box) - box * 0.5;\n\tfloat d = length(rel);\n\tfade = (1.0 - smoothstep(box * 0.28, box * 0.5, d)) * smoothstep(1.2, 4.0, d) * strength;\n\tVERTEX = VERTEX - origin + cam + rel;\n}\nvoid fragment() {\n\tALBEDO = tint * fade * 0.9;\n}\n"



















	_dust_material = ShaderMaterial.new()
	_dust_material.shader = shader
	_dust_material.set_shader_parameter("box", box)
	_dust = MultiMeshInstance3D.new()
	_dust.multimesh = multimesh
	_dust.material_override = _dust_material
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_dust.extra_cull_margin = 16384.0
	add_child(_dust)



func _build_ui() -> void :
	_ui = CanvasLayer.new()
	_ui.layer = 60
	add_child(_ui)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_black)

	for i in 2:
		var bar: = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui.add_child(bar)
		_bars.append(bar)
	var font: = load("res://assets/fonts/oxanium/Oxanium-Variable.ttf") as Font
	_build_knockout(font)
	var small: = MainMenu._variation(font, 520, 9)
	var thin: = MainMenu._variation(font, 300, 7)
	_subtitle = _label(String(_cfg.get("subtitle", "")), thin, 30, Color(0.96, 0.93, 0.88, 0.92))
	_hint = _label("Para pular clique ESPAÇO", small, 18, Color(0.94, 0.91, 0.86, 0.7))
	for node: CanvasItem in [_subtitle, _hint]:
		node.modulate.a = 0.0




func _build_knockout(font: Font) -> void :
	var cfg: Dictionary = _cfg.get("title_knockout", {})
	_letters = SubViewport.new()
	_letters.size = Vector2i(2400, 600)
	_letters.transparent_bg = true
	_letters.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_letters)
	var heavy: = MainMenu._variation(font, int(cfg.get("weight", 800)), int(cfg.get("spacing", 46)))
	var label: = Label.new()
	label.text = String(_cfg.get("title", "ESPAÇO"))
	label.add_theme_font_override("font", heavy)
	label.add_theme_font_size_override("font_size", 400)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(_letters.size)
	_letters.add_child(label)
	var shader: = Shader.new()
	shader.code = "\nshader_type canvas_item;\nuniform sampler2D letters : filter_linear_mipmap;\nuniform float scale = 1.0;\nuniform float width = 0.72;\nuniform float aspect = 1.7778;\nuniform float shade = 1.0;\nvoid fragment() {\n\t// Posição na tela em unidades da altura, centro em 0; a imagem das letras ocupa `width` da largura × scale.\n\tvec2 p = (UV - 0.5) * vec2(aspect, 1.0);\n\tfloat w = width * aspect * scale;\n\tvec2 uv = p / vec2(w, w * 0.25) + 0.5;\n\tfloat a = 0.0;\n\tif (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {\n\t\ta = texture(letters, uv).a;\n\t}\n\tCOLOR = vec4(0.0, 0.0, 0.0, (1.0 - a) * shade);\n}\n"


















	_knockout_material = ShaderMaterial.new()
	_knockout_material.shader = shader
	_knockout_material.set_shader_parameter("letters", _letters.get_texture())
	_knockout_material.set_shader_parameter("width", float(cfg.get("width", 0.72)))
	_knockout = ColorRect.new()
	_knockout.material = _knockout_material
	_knockout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_knockout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knockout.visible = false
	_ui.add_child(_knockout)
	_ui.move_child(_knockout, _black.get_index() + 1)


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var label: = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("size", size)
	_ui.add_child(label)
	return label


func _build_music() -> void :
	_music = AudioStreamPlayer.new()
	_music.name = "MapMusic"
	_music.bus = _music_bus()
	var path: = String(_cfg.get("music", ""))
	if ResourceLoader.exists(path):
		var stream: = load(path) as AudioStream
		if "loop" in stream:
			stream.set("loop", true)
		_music.stream = stream
	_music.volume_db = float(_cfg.get("music_db", 0.0))
	add_child(_music)





func _music_bus() -> StringName:
	var fx: Dictionary = _cfg.get("music_fx", {})
	var name: = StringName(String(fx.get("bus", "MapMusic")))
	var index: = AudioServer.get_bus_index(name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, name)
	AudioServer.set_bus_send(index, AudioMix.bus(AudioMix.MUSIC))
	while AudioServer.get_bus_effect_count(index) > 0:
		AudioServer.remove_bus_effect(index, 0)
	var reverb: = AudioEffectReverb.new()
	reverb.room_size = float(fx.get("room_size", 0.85))
	reverb.damping = float(fx.get("damping", 0.55))
	reverb.spread = float(fx.get("spread", 1.0))
	reverb.hipass = float(fx.get("hipass", 0.3))
	reverb.predelay_msec = float(fx.get("predelay_ms", 40.0))
	reverb.predelay_feedback = float(fx.get("predelay_feedback", 0.25))
	reverb.dry = float(fx.get("dry", 1.0))
	reverb.wet = float(fx.get("wet", 0.14))
	AudioServer.add_bus_effect(index, reverb)
	return name




func _build_flight() -> void :
	var fly: Dictionary = _cfg.get("fly", {})
	var start: = _shot_pose(float(fly.get("from", 9.5)))["pos"] as Vector3
	var arrive: = _arrive_pose(0.0)
	var up: = _player.up()
	var back: = _player.global_basis.z
	var approach_cfg: Array = fly.get("approach_offset", [8.0, 9.0])
	var approach: = _player.global_position + up * float(approach_cfg[1]) + back * float(approach_cfg[0])
	var points: = PackedVector3Array()
	for i in 48:
		points.append(start.lerp(approach, float(i) / 48.0))
	for i in 17:
		points.append(approach.lerp(arrive["pos"], float(i) / 16.0))
	var obstacles: Array = []
	var home: = _home_planet()
	for planet: BlockPlanet in _space.planets:
		var clearance: = float(fly.get("home_clearance_m", 1.4)) if planet == home else float(fly.get("clearance_m", 4.5))
		obstacles.append([planet.global_position, planet.radius + clearance])
	obstacles.append([Vector3.ZERO, _sun_half * 1.75 + float(fly.get("clearance_m", 4.5))])
	var limit: = _space.box_half - 4.0
	for round_i in 60:
		for i in range(1, points.size() - 1):
			points[i] = _push_out(points[i], obstacles, limit)
		var smooth: = points.duplicate()
		for i in range(1, points.size() - 1):
			smooth[i] = points[i] * 0.5 + (points[i - 1] + points[i + 1]) * 0.25
		points = smooth
	for i in range(1, points.size() - 1):
		points[i] = _push_out(points[i], obstacles, limit)
	_path = points
	_path_len.resize(points.size())
	_path_len[0] = 0.0
	for i in range(1, points.size()):
		_path_len[i] = _path_len[i - 1] + points[i].distance_to(points[i - 1])


func _push_out(point: Vector3, obstacles: Array, limit: float) -> Vector3:
	for obstacle: Array in obstacles:
		var center: Vector3 = obstacle[0]
		var radius: float = obstacle[1]
		var off: = point - center
		if off.length() < radius:
			point = center + (off.normalized() if off.length() > 0.001 else Vector3.UP) * radius
	return point.clamp( - Vector3.ONE * limit, Vector3.ONE * limit)


func _home_planet() -> BlockPlanet:
	var best: BlockPlanet = null
	var best_d: = INF
	for planet: BlockPlanet in _space.planets:
		var d: = planet.global_position.distance_to(_player.global_position) - planet.radius
		if d < best_d:
			best_d = d
			best = planet
	return best






func music_time() -> float:
	var clock: = _t - float(_cfg.get("pre_roll_s", 2.6)) + _offset
	if _music.playing:
		var heard: = _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if absf(heard - clock) < 0.4:
			return heard
	return clock


func _process(delta: float) -> void :
	if _done:
		return
	_t += delta
	var m: = music_time()
	if not _music_started and m >= 0.0 and _music.stream != null:
		_music_started = true
		_music.play(maxf(m, 0.0))
	_update(delta)


func _unhandled_input(event: InputEvent) -> void :
	if _done or not event is InputEventKey:
		return
	var key: = event as InputEventKey
	if key.keycode != KEY_SPACE or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if not _skip_armed:
		_skip_armed = true
		return
	skip()



func _show_robot(animated: bool) -> void :
	_robot_built = true
	if _player.robot == null:
		return
	if animated:
		_player.robot.assemble()
	else:
		_player.robot.model.visible = true



func skip() -> void :
	var to: = float(_cfg.get("skip_to", 14.9))
	if music_time() >= to:
		return
	_offset += to - music_time()
	_skip_armed = false
	if not _robot_built:
		_show_robot(false)
	if _music.stream != null:
		_music_started = true
		_music.play(to)




func _update(delta: float) -> void :
	var m: = music_time()
	_update_builds(m)
	_update_streams(m, delta)
	_update_sun(m)
	_update_ui(m)
	_update_dust(m)
	var blend_until: = float((_cfg.get("blend", {}) as Dictionary).get("until", 15.45))
	if m < blend_until:
		var pose: = _pose(m)
		var up: Vector3 = pose.get("up", Vector3.UP)
		var forward: Vector3 = ((pose["look"] as Vector3) - (pose["pos"] as Vector3)).normalized()
		var basis: = Basis.looking_at(forward, up if absf(forward.dot(up)) < 0.98 else Vector3.FORWARD)
		basis = Basis(forward, deg_to_rad(float(pose.get("roll", 0.0)))) * basis
		if pose.has("basis"):
			basis = pose["basis"]
		_camera.global_transform = Transform3D(basis.orthonormalized(), pose["pos"])
		_camera.fov = float(pose.get("fov", 50.0))

		var near: = _camera.global_position.distance_to(_player.camera.global_position) < 0.9
		_camera.cull_mask = (1048575 & ~ (1 << (ViewCamera.OWN_BODY_LAYER - 1))) if near else 1048575
		_update_focus(m)
	else:
		_hand_over()
	if not _counted and m >= float(_cfg.get("countdown_at", 15.66)):
		_counted = true
		countdown_started.emit(float(_cfg.get("go_at", 16.564)) - float(_cfg.get("countdown_at", 15.66)))




func _update_builds(m: float) -> void :
	var expo: = float(_cfg.get("growth_exp", 1.6))
	for build: Dictionary in _builds:
		var radius: = _front(build, m, expo)
		(build["material"] as ShaderMaterial).set_shader_parameter("reveal", radius)
		var planet: BlockPlanet = build["planet"]
		planet.set_reveal(radius if radius < float(build["full"]) else INF)
		(build["node"] as Node3D).visible = radius < float(build["full"]) and radius > 0.0
		if planet == _home and not _robot_built and radius >= float(build["full"]):
			_show_robot(true)


func _front(build: Dictionary, m: float, expo: float) -> float:
	var p: = clampf((m - float(build["start"])) / maxf(float(build["dur"]), 0.01), 0.0, 1.0)
	return float(build["full"]) * (1.0 - pow(1.0 - p, expo)) * (1.0 if p > 0.0 else 0.0)




func _update_streams(m: float, _delta: float) -> void :
	var cfg: Dictionary = _cfg.get("streams", {})
	var speed: = float(cfg.get("speed_ms", 24.0))
	var expo: = float(_cfg.get("growth_exp", 1.6))
	var multimesh: = _streams.multimesh
	var emit_from: = float(_cfg.get("title_in", 1.821))
	for i in _stream_state.size():
		var s: Dictionary = _stream_state[i]
		var t: = (m - float(s["launch"])) / float(s.get("travel", 1.0))
		if t >= 1.0 or s["build"] == -1:
			s["build"] = -1
			if m >= emit_from + float(s["next"]):
				_launch(s, m, speed, expo)
			if s["build"] == -1:
				multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO))
				continue
			t = 0.0
		var e: = t * t * (3.0 - 2.0 * t)
		var from: Vector3 = s["from"]
		var to: Vector3 = s["to"]
		var bend: Vector3 = s["bend"]
		var at: = from.lerp(bend, e).lerp(bend.lerp(to, e), e)
		var size: = clampf(t * 8.0, 0.0, 1.0) * lerpf(1.0, 0.55, t)
		var spin: = Basis(s["axis"], t * float(s["spin"])).scaled(Vector3.ONE * maxf(size, 0.0001))
		multimesh.set_instance_transform(i, Transform3D(spin, at))
		var color: Color = Color("#ffd23f").lerp(s["color"], smoothstep(0.35, 1.0, t))
		multimesh.set_instance_color(i, Color(color, lerpf(1.0, 0.2, t)))


func _launch(s: Dictionary, m: float, speed: float, expo: float) -> void :

	var weights: Array[float] = []
	var total: = 0.0
	for build: Dictionary in _builds:
		var end: = float(build["start"]) + float(build["dur"])
		var w: = 0.0
		if m >= float(build["start"]) - 0.6 and m < end - 0.4:
			w = pow(float(build["full"]), 2.0) * (1.0 - clampf((m - float(build["start"])) / float(build["dur"]), 0.0, 1.0) * 0.6)
		weights.append(w)
		total += w
	if total <= 0.0:
		return
	var pick: = _rng.randf() * total
	var index: = 0
	while index < weights.size() - 1 and pick > weights[index]:
		pick -= weights[index]
		index += 1
	var build: Dictionary = _builds[index]
	var planet: BlockPlanet = build["planet"]
	var toward: = planet.global_position.normalized()
	var from: = toward * _sun_half * 1.05 + Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * _sun_half * 0.7
	var dir: = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()

	dir = (dir - toward * 0.6).normalized()
	var travel: = planet.global_position.distance_to(from) / speed * _rng.randf_range(0.85, 1.2)
	var arrival_front: = maxf(_front(build, m + travel, expo), 0.6)
	var to: = planet.global_position + dir * arrival_front
	var mid: = (from + to) * 0.5
	var side: = (to - from).cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var bend: = mid + side * from.distance_to(to) * _rng.randf_range(-0.28, 0.28) + Vector3.UP * from.distance_to(to) * _rng.randf_range(-0.12, 0.2)
	s["build"] = index
	s["launch"] = m
	s["travel"] = travel
	s["from"] = from
	s["to"] = to
	s["bend"] = bend
	s["color"] = planet.color
	s["axis"] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized()
	s["spin"] = _rng.randf_range(4.0, 11.0)
	s["next"] = _rng.randf_range(0.0, 0.25)


func _update_dust(m: float) -> void :
	var cfg: Dictionary = _cfg.get("dust", {})
	_dust_material.set_shader_parameter("cam", _camera.global_position)
	_dust_material.set_shader_parameter("drift", _vec(cfg.get("drift_ms", [0.12, 0.05, -0.08])) * (m + float(_cfg.get("pre_roll_s", 2.6))))
	var blend: Dictionary = _cfg.get("blend", {})
	var settle_until: = float((_cfg.get("settle", {}) as Dictionary).get("until", 14.75))
	_dust_material.set_shader_parameter("strength", 1.0 - smoothstep(settle_until, float(blend.get("until", 15.6)), m))



func _update_focus(m: float) -> void :
	var fly: Dictionary = _cfg.get("fly", {})
	var settle_until: = float((_cfg.get("settle", {}) as Dictionary).get("until", 14.75))
	var arrive: = float(fly.get("arrive", 12.3))
	var amount: = smoothstep(arrive - 0.6, arrive + 0.4, m) * (1.0 - smoothstep(settle_until - 0.2, settle_until + 0.4, m))
	_attributes.dof_blur_far_enabled = amount > 0.001
	_attributes.dof_blur_far_distance = _camera.global_position.distance_to(_player.global_position) + 1.6
	_attributes.dof_blur_far_transition = 7.0
	_attributes.dof_blur_amount = 0.11 * amount



func _update_sun(m: float) -> void :
	if _space.sun_material == null:
		return
	var emitting: = smoothstep(1.6, 2.4, m) * (1.0 - smoothstep(10.0, 12.0, m))
	_space.sun_material.set_shader_parameter("energy", 1.5 + emitting * (0.5 + 0.2 * sin(m * 7.0)))



func _update_ui(m: float) -> void :
	var view: = get_viewport().get_visible_rect().size
	var k: = view.y / 1080.0
	var pre: = float(_cfg.get("pre_roll_s", 2.6))
	var black_s: = float(_cfg.get("black_s", 0.9))
	var since: = m + pre
	_black.color.a = 1.0 - smoothstep(black_s, black_s + float(_cfg.get("fade_s", 1.5)), since)
	_update_knockout(m, view, k)
	_place(_hint, k, Vector2(view.x - 230.0 * k, view.y - 48.0 * k - _bars[1].size.y))
	var settle_until: = float((_cfg.get("settle", {}) as Dictionary).get("until", 14.75))
	var open: = _ease((m - settle_until) / maxf(float((_cfg.get("blend", {}) as Dictionary).get("until", 15.6)) - settle_until, 0.01))
	var bar_h: = maxf(0.0, (view.y - view.x / float(_cfg.get("aspect", 2.39))) * 0.5) * (1.0 - open)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(view.x, bar_h)
	_bars[1].position = Vector2(0.0, view.y - bar_h)
	_bars[1].size = Vector2(view.x, bar_h)
	_hint.modulate.a = lerpf(_hint.modulate.a, 1.0 if _skip_armed else 0.0, 0.15)





func _update_knockout(m: float, view: Vector2, k: float) -> void :
	var cfg: Dictionary = _cfg.get("title_knockout", {})
	var t_in: = float(_cfg.get("title_in", 1.821))
	var open_from: = float(cfg.get("open_from", 3.3))
	var open_to: = float(cfg.get("open_to", 3.734))
	var showing: = m >= t_in and m < open_to
	_knockout.visible = showing
	_subtitle.modulate.a = 0.0
	if not showing:
		return
	var pushes: Array = cfg.get("push", [1.0, 1.12])
	var hold: = clampf((m - t_in) / maxf(open_from - t_in, 0.01), 0.0, 1.0)
	var scale: = lerpf(float(pushes[0]), float(pushes[1]), 1.0 - pow(1.0 - hold, 2.0))
	if m > open_from:
		var u: = clampf((m - open_from) / maxf(open_to - open_from, 0.01), 0.0, 1.0)
		scale *= exp(log(float(cfg.get("open_scale", 45.0))) * pow(u, 2.4))
	_knockout_material.set_shader_parameter("scale", scale)
	_knockout_material.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))
	_place(_subtitle, k, Vector2(view.x * 0.5, view.y * 0.5 + view.x * float(cfg.get("width", 0.72)) * 0.125 * scale + 46.0 * k))
	_subtitle.modulate.a = smoothstep(t_in + 0.5, t_in + 1.1, m) * (1.0 - smoothstep(open_from - 0.25, open_from, m))


func _place(label: Label, k: float, center: Vector2) -> void :
	label.add_theme_font_size_override("font_size", int(float(label.get_meta("size")) * k))
	label.size = label.get_minimum_size()
	label.position = center - label.size * 0.5





func _pose(m: float) -> Dictionary:
	var fly: Dictionary = _cfg.get("fly", {})
	var settle: Dictionary = _cfg.get("settle", {})
	if m < float(fly.get("from", 9.5)):
		return _shot_pose(m)
	if m < float(fly.get("arrive", 13.1)):
		return _flight_pose(m)
	if m < float(settle.get("until", 14.55)):
		return _arrive_pose(m - float(fly.get("arrive", 13.1)))
	return _blend_pose(m)



func _shot_pose(m: float) -> Dictionary:
	var shots: Dictionary = _cfg.get("shots", {})
	var c: Dictionary = shots.get("planet_c", {})
	if m >= float(c.get("at", 8.78)):
		return _planet_pose(c, m - float(c.get("at", 8.78)))
	var wide: Dictionary = shots.get("wide", {})
	if m >= float(wide.get("at", 7.03)):
		return {"pos": _vec(wide.get("pos", [56, 33, 58])), "look": _vec(wide.get("look", [0, 0, 0])), 
			"fov": float(wide.get("fov", 66.0)), "roll": 0.0}
	var b: Dictionary = shots.get("planet_b", {})
	if m >= float(b.get("at", 5.289)):
		return _planet_pose(b, m - float(b.get("at", 5.289)))
	var a: Dictionary = shots.get("planet_a", {})
	if m >= float(a.get("at", 3.734)):
		return _planet_pose(a, m - float(a.get("at", 3.734)))
	return _sun_pose(m)





func _sun_pose(m: float) -> Dictionary:
	var shots: Dictionary = _cfg.get("shots", {})
	var floating: Dictionary = shots.get("float", {})
	var sun: Dictionary = shots.get("sun", {})
	var pre: = float(_cfg.get("pre_roll_s", 2.6))
	var base: = _vec(floating.get("pos", [6, 5, 46]))
	var sun_look: = _vec(sun.get("look", [0, 2.2, 0]))
	var to_sun: = (sun_look - base).normalized()
	var right: = to_sun.cross(Vector3.UP).normalized()

	var start_dir: = to_sun.rotated(Vector3.UP, deg_to_rad(float(floating.get("turn_deg", 100.0))))
	start_dir = start_dir.rotated(right, deg_to_rad(float(floating.get("pitch_deg", 9.0)))).normalized()
	var turn_from: = - pre + float(floating.get("turn_from_after_s", 0.6))
	var turn_end: = float(_cfg.get("turn_end", 1.821))
	var u: = _ease(clampf((m - turn_from) / (turn_end - turn_from), 0.0, 1.0))
	var fovs: Array = sun.get("fov", [52.0, 46.0])
	var truck: = right * float(floating.get("truck_m", 3.0)) * (u - 1.0)
	var knock: Dictionary = _cfg.get("title_knockout", {})
	var t_in: = float(_cfg.get("title_in", 1.821))
	var fov: = lerpf(float(fovs[0]), float(fovs[1]), u)
	if m >= t_in:

		var open: = smoothstep(float(knock.get("open_from", 3.3)), float(knock.get("open_to", 3.734)), m)
		fov = lerpf(float(knock.get("sun_fov", 8.0)), float(fovs[1]), open * open)

	var drift: = Vector3(0.05, 0.02, -0.04) * minf(m + pre, turn_end + pre)
	return {"pos": base + truck + drift, "look": base + truck + drift + start_dir.slerp(to_sun, u) * 50.0, 
		"fov": fov, "roll": lerpf(float(floating.get("roll_deg", 5.0)), 0.0, u)}




func _planet_pose(shot: Dictionary, _local_t: float) -> Dictionary:
	var index: = clampi(int(shot.get("planet", 0)), 0, _space.planets.size() - 1)
	var planet: BlockPlanet = _space.planets[index]
	var center: = planet.global_position
	var to_sun: = ( - center).normalized()
	var side: = to_sun.cross(Vector3.UP)
	side = (side.normalized() if side.length() > 0.01 else Vector3.RIGHT) * float(shot.get("side", 1.0))
	var dir: = (side * 0.9 - to_sun * 0.25 + Vector3.UP * float(shot.get("low", 0.1))).normalized()
	var pos: = center + dir * planet.radius * float(shot.get("dist", 4.3))

	var look: = center + to_sun * planet.radius * float(shot.get("third", 0.85))
	return {"pos": pos, "look": look, "fov": float(shot.get("fov", 40.0)), "roll": 0.0}



func _flight_pose(m: float) -> Dictionary:
	var fly: Dictionary = _cfg.get("fly", {})
	var from: = float(fly.get("from", 9.5))
	var u: = _ease(clampf((m - from) / (float(fly.get("arrive", 13.1)) - from), 0.0, 1.0))
	var arrive: = _arrive_pose(0.0)

	var pos: = _along(u) + ((arrive["pos"] as Vector3) - _path[_path.size() - 1]) * u
	var c: Dictionary = (_cfg.get("shots", {}) as Dictionary).get("planet_c", {})
	var start_pose: = _planet_pose(c, from - float(c.get("at", 8.78)))
	var w: = smoothstep(0.0, 0.6, u)
	var look: = (start_pose["look"] as Vector3).lerp(arrive["look"], w)
	var up: = Vector3.UP.lerp(_player.up(), smoothstep(0.25, 0.95, u)).normalized()
	return {"pos": pos, "look": look, "up": up, "fov": lerpf(float(start_pose["fov"]), float(fly.get("fov", 46.0)), u), 
		"roll": lerpf(float(start_pose["roll"]), 0.0, u)}




func _arrive_pose(since: float) -> Dictionary:
	var fly: Dictionary = _cfg.get("fly", {})
	var settle: Dictionary = _cfg.get("settle", {})
	var up: = _player.up()
	var back: = _player.global_basis.z
	var side: = _player.global_basis.x
	var span: = float(settle.get("until", 14.75)) - float(fly.get("arrive", 12.3))

	var raw: = clampf(since / maxf(span, 0.01), 0.0, 1.6)
	var u: = 1.0 - pow(1.0 - minf(raw, 1.0), 2.2) + maxf(raw - 1.0, 0.0) * 0.15
	var start_deg: = float(settle.get("start_deg", 38.0))
	var turn: = deg_to_rad(start_deg - float(settle.get("orbit_deg", 30.0)) * u)
	var dist: = lerpf(float(settle.get("dist_m", 3.8)), float(settle.get("dist_end_m", 2.9)), u)
	var height: = lerpf(float(settle.get("height_m", 0.75)), float(settle.get("height_end_m", 0.95)), u)
	var arm: = back.rotated(up, turn) * dist
	var chest: = _player.global_position + up * float(settle.get("look_m", 1.35))
	return {"pos": _player.global_position + up * height + arm + side * 0.0, "look": chest, "up": up, 
		"fov": lerpf(float(fly.get("fov", 46.0)), float(settle.get("fov_end", 40.0)), u)}



func _blend_pose(m: float) -> Dictionary:
	var settle_until: = float((_cfg.get("settle", {}) as Dictionary).get("until", 14.55))
	var until: = float((_cfg.get("blend", {}) as Dictionary).get("until", 15.45))
	var w: = _ease(clampf((m - settle_until) / maxf(until - settle_until, 0.01), 0.0, 1.0))
	var fly: Dictionary = _cfg.get("fly", {})
	var from: = _arrive_pose(m - float(fly.get("arrive", 13.1)))
	var target: = _player_camera()
	var forward: = ((from["look"] as Vector3) - (from["pos"] as Vector3)).normalized()
	var from_basis: = Basis.looking_at(forward, from["up"])
	var basis: = Basis(Quaternion(from_basis.orthonormalized()).slerp(Quaternion(target.global_basis.orthonormalized()), w))
	return {"pos": (from["pos"] as Vector3).lerp(target.global_position, w), "look": Vector3.ZERO, "basis": basis, 
		"fov": lerpf(float(from["fov"]), target.fov, w)}


func _player_camera() -> Camera3D:
	if _player.view != null and _player.view.is_third_person():
		return _player.view
	return _player.camera


func _along(u: float) -> Vector3:
	if _path.size() < 2:
		return _player.global_position
	var target: = u * _path_len[_path_len.size() - 1]
	var i: = 1
	while i < _path_len.size() - 1 and _path_len[i] < target:
		i += 1
	var seg: = maxf(_path_len[i] - _path_len[i - 1], 0.0001)
	return _path[i - 1].lerp(_path[i], clampf((target - _path_len[i - 1]) / seg, 0.0, 1.0))



func _hand_over() -> void :
	if _done:
		return
	_done = true
	if not _robot_built:
		_show_robot(false)
	if _player.view != null:
		_player.view.suspended = false
	_player_camera().make_current()
	for build: Dictionary in _builds:
		(build["planet"] as BlockPlanet).set_reveal(INF)
		(build["node"] as Node).queue_free()
	_builds.clear()
	_streams.queue_free()
	_camera.queue_free()
	_space.set_walls_fade(1.0)
	if _space.sun_material != null:
		_space.sun_material.set_shader_parameter("energy", 1.5)
	for node: CanvasItem in [_knockout, _subtitle, _hint, _black, _bars[0], _bars[1]]:
		node.visible = false
	_dust.queue_free()
	finished.emit()

	set_process(true)


func is_playing() -> bool:
	return not _done



func _physics_process(_delta: float) -> void :
	if _done and not _counted:
		_t += _delta
		if music_time() >= float(_cfg.get("countdown_at", 15.66)):
			_counted = true
			countdown_started.emit(float(_cfg.get("go_at", 16.564)) - float(_cfg.get("countdown_at", 15.66)))


static func _ease(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * u * (u * (u * 6.0 - 15.0) + 10.0)


static func _vec(values: Variant) -> Vector3:
	var list: Array = values
	return Vector3(float(list[0]), float(list[1]), float(list[2]))
