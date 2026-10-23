extends Control













const CONFIG: = "res://data/intro.json"
const NEXT_SCENE: = "res://scenes/main.tscn"
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9]

var _cfg: Dictionary = {}
var _clock: float = 0.0
var _music: AudioStreamPlayer
var _music_db: float = 0.0
var _events: Array[Dictionary] = []
var _leaving: bool = false

var _going: = false
var _leave_at: float = INF
var _leave_s: float = 1.0
var _started_real: float = 0.0

var _stage: Node2D
var _blocks: IntroBlocks
var _quote: Node2D
var _words: Array[Dictionary] = []
var _dash: ColorRect
var _author: Label
var _caixa: Sprite2D
var _somyst: Sprite2D
var _wordmark: Node2D
var _pieces: Array[Dictionary] = []


var _whole: Sprite2D
var _whole_material: ShaderMaterial
var _whole_at: float = INF
var _glow: Sprite2D
var _ball_glow: Sprite2D
var _flash: ColorRect
var _fade: ColorRect
var _sounds: Array[AudioStreamPlayer] = []
var _next_sound: int = 0

var _squash_at: float = - INF
var _squash_amp: float = 0.0
var _crisp: Dictionary = {}
var _orb: Dictionary = {}
var _shine: Dictionary = {}
var _letter_times: = PackedFloat32Array()

var _frames: Dictionary = {}

var _menu: MainMenu
var _background: MenuBackground
var _options: OptionsMenu
var _lobby: LobbyMenu
var _customize: CustomizeMenu
var _online_launch: = false
var _voice: VoiceInput
var _dev_choice: String = ""
var _fx: IntroCinematicFX
var _post: ColorRect
var _post_material: ShaderMaterial
var _cinema: Dictionary = {}
var _impacts: Array[Dictionary] = []
var _event_audible: bool = true
var _scheduled_s: float = 0.0
var _last_music_position: float = 0.0
var _music_epoch: float = 0.0
var _seek_target: float = -1.0
var _exit_visual: IntroExit
var _fx_sounds: Dictionary = {}
var _menu_logo_tween: Tween
var _skip_hint: Label
var _skip_armed: = false
var _skip_space_down: = false
var _skip_timer: = 0.0


func _ready() -> void :
	var returning: = Match.return_to_menu
	Match.return_to_menu = false
	var args: = OS.get_cmdline_user_args()
	AudioMix.apply(get_tree())
	VideoSettings.start(get_tree())
	var dev_intro: = false
	for arg in args:
		if arg.begins_with("--intro"):
			dev_intro = true
	if not args.is_empty() and not dev_intro and not returning:
		_go_next.call_deferred("")
		return
	if not returning:
		VideoSettings.apply_display()
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	_cinema = _cfg["cinematic"]
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_build()
	var seek: = 30.0 if returning else 0.0
	for arg in args:
		if arg.begins_with("--intro-em="):
			seek = arg.trim_prefix("--intro-em=").to_float()
		elif arg.begins_with("--intro-quadros="):
			var spec: = arg.trim_prefix("--intro-quadros=").split("x")
			_frames["count"] = spec[0].to_int()
			_frames["step"] = spec[1].to_float() if spec.size() > 1 else 0.5
		elif arg.begins_with("--intro-png="):
			_frames["path"] = arg.trim_prefix("--intro-png=")
		elif arg.begins_with("--intro-escolher="):
			_dev_choice = arg.trim_prefix("--intro-escolher=")
	_clock = seek
	if _music != null:
		_music.play(seek)
		_seek_target = seek
	if _frames.has("path"):
		_frames["next"] = seek + 0.2
		_frames["images"] = []




func _build() -> void :
	var colors: Dictionary = _cfg["colors"]
	var black: = ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_background = MenuBackground.new()
	add_child(_background)
	_background.setup(_cfg["menu"].get("background", {}), float(_cfg["menu"]["times"]["start_s"]))


	_menu = MainMenu.new()
	_menu.setup(_cfg["menu"], _cfg["menu"]["colors"], String(_cfg["font"]))
	add_child(_menu)

	_menu.moved.connect( func() -> void : UiSound.play_at(self, "navigate"))
	_menu.chosen.connect(_on_menu_chosen)
	_stage = Node2D.new()
	add_child(_stage)
	_quote = Node2D.new()
	add_child(_quote)
	_build_quote()

	var block_cfg: Dictionary = _cfg["blocks"]
	_blocks = IntroBlocks.new(int(block_cfg["count"]))
	_blocks.gap = float(block_cfg.get("gap", 0.16))
	_stage.add_child(_blocks)
	_blocks.configure_surface(_cinema["surface"], float(_cfg["lavoice"]["start_s"]))

	_glow = _make_glow(Color(String(colors["matter"])))
	_stage.add_child(_glow)
	_ball_glow = _make_glow(Color(String(colors["accent"])))
	_stage.add_child(_ball_glow)

	_plan_caixa()
	var first_plan: = _blocks.capture_plan()
	_plan_somyst()
	_plan_lavoice()
	_blocks.use_plan(first_plan)
	_build_quote_source()
	_fx = IntroCinematicFX.new()
	_fx.setup(_cinema["fx"])
	_stage.add_child(_fx)
	_plan_menu_impacts()

	BuildSounds.click()
	BuildSounds.thunk()
	_fx_sounds = IntroSound.make_bank(_cinema["sfx"])
	_plan_sound_layers()

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_material = ShaderMaterial.new()
	_post_material.shader = load("res://scenes/intro/cinematic_post.gdshader")
	_post.material = _post_material
	_post_material.set_shader_parameter("threshold", float(_cinema["post"]["threshold"]))
	_post_material.set_shader_parameter("vignette", float(_cinema["post"]["vignette"]))
	_post_material.set_shader_parameter("radius_px", float(_cinema["post"]["radius_px"]))
	_post_material.set_shader_parameter("mip_lod", float(_cinema["post"]["mip_lod"]))
	add_child(_post)
	_exit_visual = IntroExit.new()
	_exit_visual.setup(_cinema["exit"])
	add_child(_exit_visual)
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0, 0, 0, 0)
	add_child(_fade)
	_skip_hint = Label.new()
	_skip_hint.text = "Para pular clique ESPAÇO"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.add_theme_font_override("font", _font(600, 0))
	_skip_hint.add_theme_color_override("font_color", Color("#f5f1e8"))
	_skip_hint.add_theme_color_override("font_outline_color", Color("#161619"))
	_skip_hint.add_theme_constant_override("outline_size", 4)
	_skip_hint.modulate.a = 0.0
	_skip_hint.hide()
	add_child(_skip_hint)

	for i in 10:
		var player: = AudioStreamPlayer.new()
		player.bus = AudioMix.bus(AudioMix.EFFECTS)
		add_child(player)
		_sounds.append(player)
	var music_path: = String(_cfg.get("music", ""))
	if ResourceLoader.exists(music_path):
		_music = AudioStreamPlayer.new()
		_music.bus = AudioMix.bus(AudioMix.MUSIC)
		var stream: = (load(music_path) as AudioStream).duplicate() as AudioStream

		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
			(stream as AudioStreamOggVorbis).loop_offset = float(_cfg["menu"].get("music_loop_s", 0.0))
		_music.stream = stream
		_music_db = float(_cfg.get("music_db", 0.0)) + float(_cinema["mix_gain_db"])
		_music.volume_db = _music_db
		add_child(_music)
	_events.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))


func _font(weight: int, spacing: int = 0) -> FontVariation:
	var font: = FontVariation.new()
	font.base_font = load(String(_cfg["font"]))
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	font.spacing_glyph = spacing
	return font



func _build_quote() -> void :
	var q: Dictionary = _cfg["quote"]
	var colors: Dictionary = _cfg["colors"]
	var font: = _font(int(q["weight"]))
	var font_size: = int(q["size"])
	var lines: Array = q["lines"]
	var line_h: = font_size * float(q["line_gap"])
	var top: = - line_h * (lines.size() + 0.9) * 0.5
	var t: = float(q["start_s"])
	var space: = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	for li in lines.size():
		var accent: = li == int(q.get("accent_line", -1))
		if accent:
			t = float(q["accent_at_s"])
		var words: = String(lines[li]).split(" ")
		var widths: Array[float] = []
		var total: = 0.0
		for word in words:
			var w: = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			widths.append(w)
			total += w
		total += space * (words.size() - 1)
		var x: = - total * 0.5
		for wi in words.size():
			var label: = Label.new()
			label.text = words[wi]
			var settings: = LabelSettings.new()
			settings.font = font
			settings.font_size = font_size
			settings.font_color = Color(String(colors["accent" if accent else "text"]))
			label.label_settings = settings
			label.position = Vector2(x, top + li * line_h)
			label.modulate.a = 0.0
			_quote.add_child(label)
			var focus: = ShaderMaterial.new()
			focus.shader = load("res://scenes/intro/quote_focus.gdshader")
			focus.set_shader_parameter("grain_px", float(_cinema["quote"]["grain_px"]))
			label.material = focus
			_words.append({"node": label, "t": t, "x": x, "y": label.position.y, "accent": accent, "focus": focus})
			x += widths[wi] + space
			t += float(q["word_step_s"]) * (0.7 if accent else 1.0)

	var name_font: = _font(int(q["author_weight"]), int(q["author_spacing"]))
	var name_size: = int(q["author_size"])
	var author_name: = String(q["author"]).to_upper()
	var name_w: = name_font.get_string_size(author_name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x
	var dash_w: = float(q["dash_m"])
	var gap: = 16.0
	var y: = top + lines.size() * line_h + line_h * 0.45
	var left: = - (dash_w + gap + name_w) * 0.5
	_dash = ColorRect.new()
	_dash.color = Color(String(colors["muted"]))
	_dash.position = Vector2(left, y + name_size * 0.62)
	_dash.size = Vector2(0.0, 2.0)
	_quote.add_child(_dash)
	_author = Label.new()
	_author.text = author_name
	var author_settings: = LabelSettings.new()
	author_settings.font = name_font
	author_settings.font_size = name_size
	author_settings.font_color = Color(String(colors["muted"]))
	_author.label_settings = author_settings
	_author.position = Vector2(left + dash_w + gap, y)
	_author.modulate.a = 0.0
	_quote.add_child(_author)


func _build_quote_source() -> void :
	var q: Dictionary = _cfg["quote"]
	var source: Dictionary = _cinema["quote_matter"]
	var font: = _font(int(q["weight"]))
	var text: = String(q["lines"][int(q["accent_line"])])
	var width: = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(q["size"])).x
	var line_y: = 0.0
	for word: Dictionary in _words:
		if bool(word["accent"]):
			line_y = float(word["y"])
			break
	var grow: = float(q["drift"]) * _smooth((float(source["start_s"]) - float(q["start_s"])) / 9.0) + 0.035
	_blocks.configure_quote_source(_logo_image(String(source["mask"])), source, Vector2( - width * 0.5, line_y), 1.0 + grow, 
		Color(String(_cfg["colors"]["accent"])), Color(String(_cfg["colors"]["matter"])), float(_cfg["somyst"]["start_s"]))


func _make_glow(color: Color) -> Sprite2D:
	var gradient: = Gradient.new()
	gradient.set_color(0, Color(color, 0.9))
	gradient.set_color(1, Color(color, 0.0))
	gradient.add_point(0.25, Color(color, 0.45))
	var texture: = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	var sprite: = Sprite2D.new()
	sprite.texture = texture
	var additive: = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = additive
	sprite.modulate.a = 0.0
	return sprite



func _crisp_sprite(image: Image, display: Vector2) -> Sprite2D:
	var mipmapped: = image.duplicate() as Image
	mipmapped.generate_mipmaps()
	var sprite: = Sprite2D.new()
	sprite.texture = ImageTexture.create_from_image(mipmapped)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.scale = display / Vector2(image.get_size())
	sprite.modulate.a = 0.0
	_stage.add_child(sprite)
	return sprite


static func _logo_image(path: String) -> Image:
	var texture: = load(path) as Texture2D
	var image: = texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image




func _at(t: float, action: Callable) -> void :
	_events.append({"t": t, "do": action})




func _plan_caixa() -> void :
	var c: Dictionary = _cfg["caixa"]
	var image: = _logo_image(String(c["logo"]))
	var display: = Vector2(image.get_width(), image.get_height()) * (float(c["height"]) / image.get_height())
	var formation: = IntroBlocks.sample(image, display, _blocks.count, float(c["threshold"]), false)
	var source: = Vector2(float(c["source"][0]), float(c["source"][1]))
	var matter: = Color(String(_cfg["colors"]["matter"]))
	var plan: = _blocks.assemble(formation, float(c["start_s"]), source, c, matter)
	var launches: PackedFloat32Array = plan["launches"]
	_orb = {"at": source, "from": float(c["start_s"]) - 0.5, "first": launches[0], "last": launches[launches.size() - 2], 
		"final": int(plan["final"]), "final_launch": float(plan["final_launch"]), "final_land": float(plan["final_land"])}
	_schedule_clicks(launches, float(_cfg["blocks"]["clicks"]))
	var land: = float(plan["final_land"])
	var final_at: Vector2 = plan["final_at"]
	_at(land, func() -> void : _impact(final_at, 0.55, Color.WHITE, 1.0))
	_caixa = _crisp_sprite(image, display)
	_crisp["caixa"] = {"node": _caixa, "in": land + float(c["crisp_after_s"]), "in_s": float(c["crisp_fade_s"]), 
		"out": float(_cfg["somyst"]["start_s"]) - 0.22, "out_s": 0.22}
	_at(land + float(c["crisp_after_s"]) + float(c["crisp_fade_s"]), func() -> void : _blocks.vanish_all(_clock, 0.05))
	_at(float(_cfg["somyst"]["start_s"]) - 0.24, _blocks.show_all)



func _plan_somyst() -> void :
	var s: Dictionary = _cfg["somyst"]
	var image: = _logo_image(String(s["logo"]))
	var display: = Vector2(image.get_width(), image.get_height()) * (float(s["height"]) / image.get_height())
	var formation: = IntroBlocks.sample(image, display, _blocks.count, float(s["threshold"]), true)
	var start: = float(s["start_s"])
	var end: = _blocks.morph(formation, start, s)
	var motion: = _blocks.capture_plan()
	_at(start, func() -> void :
		_blocks.use_plan(motion)
		_squash(0.04)
		for k in 6:
			_at_now(start + k * 0.09, func() -> void : _click(0.8 + 0.08 * k, -14.0))
		_at_now(end, func() -> void : _impact(Vector2(0, display.y * 0.5), 0.22, Color.WHITE, 0.7))
		_crisp["somyst"] = {"node": _somyst, "in": end + float(s["crisp_after_s"]), "in_s": float(s["crisp_fade_s"]), 
			"out": float(_cfg["lavoice"]["start_s"]) - 0.22, "out_s": 0.22}
		_at_now(end + float(s["crisp_after_s"]) + float(s["crisp_fade_s"]), func() -> void : _blocks.vanish_all(_clock, 0.05)))
	_at(float(_cfg["lavoice"]["start_s"]) - 0.24, _blocks.show_all)
	_somyst = _crisp_sprite(image, display)





func _plan_lavoice() -> void :
	var l: Dictionary = _cfg["lavoice"]
	var folder: = String(l["pieces"])
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "posicoes.json"))
	var canvas: = Vector2(float(layout["canvas"]["width"]), float(layout["canvas"]["height"]))
	var k: = float(l["width"]) / canvas.x
	var display: = canvas * k
	var letters: Array = l["letters"]
	var accent: = Color(String(_cfg["colors"]["accent"]))
	_wordmark = Node2D.new()
	_stage.add_child(_wordmark)
	var shader: = load("res://scenes/intro/shine.gdshader") as Shader
	var piece_images: Array[Dictionary] = []
	for spec: Dictionary in layout["pieces"]:
		var color: = Color(String(spec["color"]))
		var group: = 7 if color.is_equal_approx(accent) else letters.find(String(spec["letter"]))
		var image: = _logo_image(folder + String(spec["file"]))
		var rect: = Rect2(float(spec["x"]), float(spec["y"]), float(spec["width"]), float(spec["height"]))
		var sprite: = Sprite2D.new()
		var mipmapped: = image.duplicate() as Image
		mipmapped.generate_mipmaps()
		sprite.texture = ImageTexture.create_from_image(mipmapped)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

		var piece_size: = rect.size * k + Vector2(1.6, 1.6)
		sprite.scale = piece_size / Vector2(image.get_size())
		sprite.position = rect.get_center() * k - display * 0.5
		var shine: = ShaderMaterial.new()
		shine.shader = shader
		sprite.material = shine
		sprite.modulate.a = 0.0
		_wordmark.add_child(sprite)
		_pieces.append({"node": sprite, "group": group, "base_scale": sprite.scale, "material": shine, "shown": INF})
		piece_images.append({"image": image, "rect": rect, "group": group})

	var full: = _logo_image(String(l["logo"]))
	_whole = _crisp_sprite(full, display)
	_whole.reparent(_wordmark)
	_whole_material = ShaderMaterial.new()
	_whole_material.shader = shader
	_whole.material = _whole_material
	var formation: = IntroBlocks.sample(full, display, _blocks.count, float(l["threshold"]), false)
	formation.groups.resize(formation.points.size())
	piece_images.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return int(a["group"]) > int(b["group"]))
	for i in formation.points.size():
		var at: = (formation.points[i] + display * 0.5) / k
		formation.groups[i] = _piece_group(at, piece_images)
	var start: = float(l["start_s"])
	_letter_times.resize(letters.size())
	for li in letters.size():
		_letter_times[li] = float(l["first_letter_s"]) + li * float(l["letter_step_s"])
	var slam: = float(l["slam_s"])
	_blocks.finale(formation, start, l, _letter_times)
	var motion: = _blocks.capture_plan()
	_at(start, func() -> void :
		_blocks.use_plan(motion)
		_impact(Vector2.ZERO, 0.25, Color.WHITE, 0.0))
	for li in letters.size():
		var group: = li
		_at(_letter_times[li], func() -> void :
			_show_group(group, 1.0)
			_blocks.vanish_group(group, _clock, 0.07)
			_click(0.9 * pow(2.0, PENTATONIC[group % 5] / 12.0 + floorf(group / 5.0)), -6.0)
			_dust(_group_center(group), Color.WHITE, 16, 0.6))
	_at(slam, func() -> void :
		_show_group(7, 2.0)
		_blocks.vanish_group(7, _clock, 0.05)
		_impact(_group_center(7), 1.0, accent, 1.0)
		_squash(0.07)
		_whole_at = slam + float(l.get("whole_after_s", 0.3)))
	_shine = {"at": float(l["shine_at_s"]), "s": float(l["shine_s"]), "from": - display.x * 0.5 - 200.0, 
		"to": display.x * 0.5 + 300.0}
	_ball_glow.set_meta("from", start + 0.5)
	_ball_glow.set_meta("to", slam)
	_at(float(_cfg["menu"]["times"]["start_s"]), func() -> void : Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)


static func _piece_group(at: Vector2, pieces: Array[Dictionary]) -> int:
	var nearest: = 0
	var best: = INF
	for piece: Dictionary in pieces:
		var rect: Rect2 = piece["rect"]
		if rect.has_point(at):
			var image: Image = piece["image"]
			var local: = (at - rect.position) / rect.size * Vector2(image.get_size())
			var px: = clampi(int(local.x), 0, image.get_width() - 1)
			var py: = clampi(int(local.y), 0, image.get_height() - 1)
			if image.get_pixel(px, py).a > 0.3:
				return int(piece["group"])
		var d: = rect.get_center().distance_squared_to(at)
		if d < best:
			best = d
			nearest = int(piece["group"])
	return nearest


func _group_center(group: int) -> Vector2:
	var sum: = Vector2.ZERO
	var n: = 0
	for piece: Dictionary in _pieces:
		if int(piece["group"]) == group:
			sum += (piece["node"] as Sprite2D).position
			n += 1
	return sum / maxf(n, 1.0)


func _show_group(group: int, pop: float) -> void :
	for piece: Dictionary in _pieces:
		if int(piece["group"]) == group:
			piece["shown"] = _clock
			piece["pop"] = pop


func _schedule_clicks(launches: PackedFloat32Array, clicks: float) -> void :
	var n: = launches.size()
	var steps: = maxi(int(clicks), 1)
	for k in steps:
		var rank: = mini(int(float(k) / steps * (n - 1)), n - 2)
		var semitone: = PENTATONIC[k % 5] + 12 * int(k / 5.0)
		_at(launches[rank], func() -> void : _click(0.9 * pow(2.0, semitone / 12.0), float(_cfg["blocks"]["click_db"])))



func _at_now(t: float, action: Callable) -> void :
	_events.append({"t": t, "do": action})
	_events.sort_custom( func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))





func _impact(at: Vector2, strength: float, color: Color, thunk: float) -> void :
	_impacts.append({"t": _clock, "strength": strength, "color": color})
	_fx.burst(at, color, 0, strength, _clock, true)
	_squash(0.05 * strength)
	if thunk > 0.0:
		_play(BuildSounds.thunk(), 0.85 + 0.15 * (1.0 - strength), float(_cfg["blocks"]["thunk_db"]))
	_dust(at, color, int(30 + 70 * strength), strength)


func _squash(amount: float) -> void :
	_squash_at = _clock
	_squash_amp = amount


func _dust(at: Vector2, color: Color, amount: int, strength: float) -> void :
	if amount > 0:
		_fx.burst(at, color, amount, strength, _clock)


func _click(pitch: float, db: float) -> void :
	_play(BuildSounds.click(), pitch, db)


func _play(stream: AudioStream, pitch: float, db: float) -> void :
	if not _event_audible:
		return
	var player: = _sounds[_next_sound]
	_next_sound = (_next_sound + 1) % _sounds.size()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = db + float(_cinema["mix_gain_db"])
	player.play()




func _process(delta: float) -> void :
	if _cfg.is_empty():
		return
	_advance_clock(delta)
	var t: = _clock
	_background.update_clock(t)
	_dispatch_to(t)
	_menu.music_time = t - _music_epoch
	_menu.update(t, delta)
	var view: = get_viewport_rect().size
	_update_skip_hint(view, delta)
	_quote.position = view * 0.5
	_update_quote(t)
	_update_camera(t, view)
	_update_logo_flight(t)
	_update_stage(t, delta, view)
	if not _dev_choice.is_empty() and _menu.ready_for_input:
		_on_menu_chosen(_dev_choice)
		_dev_choice = ""
	_blocks.visible = t < float(_cfg["lavoice"]["slam_s"]) + 0.2
	if _blocks.visible:
		_blocks.update(t)
	_fx.update(t)
	_update_leave(t)
	_capture_frames(t)


func _advance_clock(delta: float) -> void :
	if _music != null and _music.playing:
		var at: = _music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
		if _seek_target >= 0.0:

			if at < _seek_target - float(_cinema["event_sound_window_s"]):
				return
			_seek_target = -1.0
			_last_music_position = at

		if at < _last_music_position - 1.0:


			var stream: = _music.stream
			var loop_from: = (stream as AudioStreamOggVorbis).loop_offset if stream is AudioStreamOggVorbis else 0.0
			_music_epoch += maxf(0.0, stream.get_length() - loop_from)
		_last_music_position = at
		_clock = maxf(_clock, at + _music_epoch)
	else:
		_clock += delta


func _update_quote(t: float) -> void :
	var q: Dictionary = _cfg["quote"]
	var fade: = float(q["word_fade_s"])
	var out: = 1.0 - _smooth((t - float(q["fade_out_at_s"])) / float(q["fade_out_s"]))
	var source: Dictionary = _cinema["quote_matter"]
	var accent_out: = 1.0 - _smooth((t - float(source["start_s"])) / float(source["text_fade_s"]))
	for word: Dictionary in _words:
		var label: = word["node"] as Label
		var e: = _smooth((t - float(word["t"])) / fade)
		var word_out: = accent_out if bool(word["accent"]) else out
		label.modulate.a = e * word_out
		var polish: Dictionary = _cinema["quote"]
		label.position.x = float(word["x"]) * (1.0 + float(polish["tracking_ratio"]) * (1.0 - e))
		label.position.y = float(word["y"]) + float(q["word_rise"]) * (1.0 - e) - (0.0 if bool(word["accent"]) else float(polish["exit_rise_px"]) * (1.0 - out))
		var focus: ShaderMaterial = word["focus"]
		focus.set_shader_parameter("focus_px", float(polish["focus_in_px"]) * (1.0 - e) + float(polish["focus_out_px"]) * (1.0 - word_out))
		focus.set_shader_parameter("dissolve", float(polish["dissolve"]) * (1.0 - word_out))
	var author_at: = float(q["author_at_s"])
	_dash.size.x = float(q["dash_m"]) * _smooth((t - author_at) / 0.55)
	var author_out: = 1.0 - _smooth((t - float(q["fade_out_at_s"]) + 0.2) / (float(q["fade_out_s"]) * 0.6))
	_dash.modulate.a = author_out
	_author.modulate.a = _smooth((t - author_at - 0.35) / 0.8) * author_out

	var grow: = float(q["drift"]) * _smooth((t - float(q["start_s"])) / 9.0) + 0.035 * (1.0 - out)
	_quote.scale = Vector2.ONE * (1.0 + grow)
	_quote.visible = maxf(out, accent_out) > 0.001


func _update_stage(t: float, _delta: float, _view: Vector2) -> void :

	for key: String in _crisp:
		var c: Dictionary = _crisp[key]
		var alpha: = _smooth((t - float(c["in"])) / float(c["in_s"])) * (1.0 - _smooth((t - float(c["out"])) / float(c["out_s"])))
		(c["node"] as Sprite2D).modulate.a = alpha

	if not _orb.is_empty():
		var lit: = _smooth((t - float(_orb["from"])) / 0.5)
		var left: = 1.0 - _smooth((t - float(_orb["first"])) / (float(_orb["last"]) - float(_orb["first"]) + 0.15))
		_glow.position = _orb["at"]
		_glow.scale = Vector2.ONE * (0.6 + 1.6 * left) * (1.0 + 0.08 * sin(t * 9.0))
		_glow.modulate.a = lit * (0.15 + 0.85 * left)

		var final_launch: = float(_orb["final_launch"])
		var final_land: = float(_orb["final_land"])
		if t >= final_launch - 0.1 and t <= final_land + 0.05:
			var carry: = _smooth((t - final_launch + 0.1) / 0.2)
			_glow.position = _glow.position.lerp(_blocks.block_position(int(_orb["final"]), t), carry)
			_glow.scale = Vector2.ONE * lerpf(_glow.scale.x, 0.9, carry)
			_glow.modulate.a = maxf(_glow.modulate.a, 0.8 * carry)
		elif t > final_land:
			_glow.modulate.a = 0.0

	var ball_from: = float(_ball_glow.get_meta("from", INF))
	var ball_to: = float(_ball_glow.get_meta("to", INF))
	if t >= ball_from:
		var on: = _smooth((t - ball_from) / 0.6) * (1.0 - _smooth((t - ball_to) / 0.12))
		var hold: = 1.0 - on
		_ball_glow.position = _blocks.ball_center(t) if t < ball_to else _wordmark.transform * _group_center(7)
		var beat: = 0.5 + 0.5 * cos((t - float(_cfg["lavoice"]["start_s"])) * TAU / 0.594)
		var charge: = _smooth((t - float(_cfg["lavoice"]["ball"]["rise_at_s"])) / maxf(ball_to - float(_cfg["lavoice"]["ball"]["rise_at_s"]), 0.01))
		_ball_glow.scale = Vector2.ONE * (1.1 + 0.35 * beat) * _wordmark.scale.x * (1.0 - charge * float(_cinema["surface"]["ball_compress"]))
		_ball_glow.self_modulate = Color.WHITE.lerp(Color(1.0, 1.35, 1.65), charge * float(_cinema["surface"]["ball_heat"]))
		_ball_glow.modulate.a = on * (0.55 + 0.3 * beat) + (0.25 + 0.15 * beat) * _smooth((t - ball_to) / 0.4) * hold

	var shine_x: = INF
	var shine_strength: = 0.0
	if not _shine.is_empty():
		var u: = (t - float(_shine["at"])) / float(_shine["s"])
		if u >= 0.0 and u <= 1.0:
			shine_x = lerpf(float(_shine["from"]), float(_shine["to"]), _smooth(u)) + _stage.position.x
			shine_strength = 0.85 * sin(PI * u)
	var whole: = _smooth((t - _whole_at) / 0.12)
	_whole.modulate.a = whole
	_whole_material.set_shader_parameter("shine_x", shine_x if shine_x < INF else -100000.0)
	_whole_material.set_shader_parameter("strength", shine_strength)
	for piece: Dictionary in _pieces:
		var sprite: = piece["node"] as Sprite2D
		if whole >= 1.0:
			sprite.visible = false
			continue
		var since_shown: = t - float(piece["shown"])
		var shine_material: = piece["material"] as ShaderMaterial
		if since_shown < 0.0:
			sprite.modulate.a = 0.0
			continue
		var pop: = float(piece.get("pop", 1.0))
		sprite.modulate.a = _smooth(since_shown / 0.05)
		var bounce: = 0.18 * pop * exp(-9.0 * since_shown) * cos(26.0 * since_shown)
		sprite.scale = (piece["base_scale"] as Vector2) * (1.0 + bounce)
		shine_material.set_shader_parameter("flash", clampf(1.0 - since_shown / (0.18 * pop), 0.0, 1.0))
		shine_material.set_shader_parameter("shine_x", shine_x if shine_x < INF else -100000.0)
		shine_material.set_shader_parameter("strength", shine_strength)





func _update_logo_flight(t: float) -> void :
	var menu: Dictionary = _cfg["menu"]
	var from: = float(menu["logo_from_s"])
	var to: = float(menu["times"]["lands"]["logo"])
	var u: = clampf((t - from) / maxf(to - from, 0.01), 0.0, 1.0)
	if u <= 0.0:
		_wordmark.position = Vector2.ZERO
		_wordmark.scale = Vector2.ONE
		return
	var e: = u * u * (3.0 - 2.0 * u)
	e = e * e * (3.0 - 2.0 * e)
	var slot: = _menu.logo_slot()
	var target: Vector2 = _stage.to_local(slot["center"])
	var slot_scale: = float(slot["width"]) / float(_cfg["lavoice"]["width"])

	var arc: = Vector2(0.0, -60.0 * sin(PI * e))
	_wordmark.position = Vector2.ZERO.lerp(target, e) + arc
	var since: = t - to
	var punch: = 0.08 * exp(-9.0 * since) * cos(24.0 * since) if since >= 0.0 and since < 2.0 else 0.0
	_wordmark.scale = Vector2.ONE * lerpf(1.0, slot_scale, e) * (1.0 + punch)


func _on_menu_landed(at: Vector2, strength: float, note: int) -> void :
	var local: = at - get_viewport_rect().size * 0.5
	_click(0.9 * pow(2.0, (PENTATONIC[note % 5] + 12 * int(note / 5.0)) / 12.0), -6.0)
	if strength >= 0.5:
		_impact(local, strength * 0.8, Color(String(_cfg["menu"]["colors"]["accent"])) if strength >= 1.0 else Color.WHITE, 
			1.0)
	else:
		_dust(local, Color.WHITE, 14, 0.4)


func _on_menu_chosen(id: String) -> void :
	if _leaving:
		return
	_play(BuildSounds.thunk(), 1.25, -6.0)
	match id:
		"create":
			_open_lobby()
		"practice":

			_open_lobby("maps")
		"customize":
			_open_customize()
		"settings", "voice":
			_open_options()
			if id == "voice": _options.show_voice_test()
		"quit":
			get_tree().quit()



func _open_lobby(start_page: String = "home") -> void :
	if _lobby == null:
		_lobby = LobbyMenu.new()
		add_child(_lobby)
		move_child(_lobby, _exit_visual.get_index())
		_lobby.closed.connect(_close_lobby)
		_lobby.offline_requested.connect( func(mode: String) -> void :

			if mode not in ["practice", "duel"]: Arena.next_map = ""
			Match.next_mode = mode
			_leave(float(_cfg["end"]["fade_s"])))
		_lobby.match_requested.connect( func() -> void :

			Arena.next_map = Session.lobby.chosen_map_id()
			_online_launch = true
			Match.next_mode = "online"
			_leave(float(_cfg["end"]["fade_s"])))
	_menu.set_process_unhandled_input(false)
	_menu.dismiss()
	if _menu_logo_tween != null and _menu_logo_tween.is_valid(): _menu_logo_tween.kill()
	_stage.visible = false
	_post.visible = false
	if start_page == "maps":
		_lobby.open_maps("practice")
	else:
		_lobby.open()



func _open_customize() -> void :
	if _customize == null:
		_customize = CustomizeMenu.new()
		add_child(_customize)
		move_child(_customize, _exit_visual.get_index())
		_customize.closed.connect(_close_lobby)
	_menu.set_process_unhandled_input(false)
	_menu.dismiss()
	if _menu_logo_tween != null and _menu_logo_tween.is_valid(): _menu_logo_tween.kill()
	_stage.visible = false
	_post.visible = false
	_customize.open()


func _close_lobby() -> void :
	_menu.rebuild()
	_stage.visible = true
	_stage.modulate.a = 0.0
	_menu_logo_tween = create_tween()
	_menu_logo_tween.tween_property(_stage, "modulate:a", 1.0, 0.28).set_delay(0.1)
	_post.visible = true
	_menu.set_process_unhandled_input(true)


func _open_options() -> void :
	if _options == null:
		_voice = VoiceInput.new()
		_voice.name = "Voice"
		add_child(_voice)
		_voice.setup(null, Lexicon.data)
		_options = OptionsMenu.new()
		add_child(_options)
		_options.bind(_voice, null)
		_options.use_menu_context()
		_options.closed.connect( func() -> void : _menu.set_process_unhandled_input(true))
	_menu.set_process_unhandled_input(false)
	_options.open()




func _update_skip_hint(view: Vector2, delta: float) -> void :
	if _clock >= float(_cfg["end"]["skip_to_s"]) or _leaving:
		_skip_armed = false
		_skip_hint.hide()
		return
	if _skip_armed:
		_skip_timer = maxf(0.0, _skip_timer - delta)
		if _skip_timer <= 0.0:
			_skip_armed = false
	if not _skip_armed:
		if _skip_hint.visible:
			_skip_hint.modulate.a = move_toward(_skip_hint.modulate.a, 0.0, delta * 7.0)
			if _skip_hint.modulate.a <= 0.0:
				_skip_hint.hide()
		return
	var k: = view.y / 720.0
	_skip_hint.size = Vector2(490, 32) * k
	_skip_hint.position = view - Vector2(530, 58) * k
	_skip_hint.add_theme_font_size_override("font_size", maxi(14, roundi(20.0 * k)))
	_skip_hint.modulate.a = move_toward(_skip_hint.modulate.a, 1.0, delta * 7.0)


func _unhandled_input(event: InputEvent) -> void :
	if _cfg.is_empty() or _leaving or _frames.has("path"):
		return
	if (_options != null and _options.is_open) or (_lobby != null and _lobby.is_open) or (_customize != null and _customize.is_open):
		return
	var skip_to: = float(_cfg["end"]["skip_to_s"])
	if _clock >= skip_to:
		return


	var pressed: = false
	var is_space: = false
	if event is InputEventKey:
		var key: = event as InputEventKey
		is_space = key.keycode == KEY_SPACE or key.physical_keycode == KEY_SPACE
		if is_space and not key.pressed:
			_skip_space_down = false
			return
		if not key.pressed or key.echo or (is_space and _skip_space_down):
			return
		pressed = true
		if is_space:
			_skip_space_down = true
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed()
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if not _skip_armed:
		_skip_armed = true
		_skip_timer = float(_cfg["end"]["skip_hint_s"])
		_skip_hint.show()
		return

	if is_space:
		_skip_armed = false
		_skip_hint.hide()
		_skip_hint.modulate.a = 0.0
		_clock = skip_to
		_last_music_position = skip_to
		if _music != null:
			_music.seek(skip_to)
			_seek_target = skip_to
	else:
		_skip_timer = float(_cfg["end"]["skip_hint_s"])


func _leave(seconds: float) -> void :
	if _leaving:
		return
	_leaving = true
	_menu.set_process_unhandled_input(false)
	var panel_width: = float(_cfg["menu"]["layout"]["panel_edge_x"]) + float(_cinema["exit"]["panel_margin_px"])
	if _lobby != null and _lobby.visible:
		_lobby.process_mode = Node.PROCESS_MODE_DISABLED
	elif DisplayServer.get_name() != "headless":
		_exit_visual.capture(get_viewport().get_texture(), panel_width * get_viewport_rect().size.y / float(_cfg["menu"]["layout"]["height"]), get_viewport_rect().size)
	_menu.visible = false
	_stage.visible = false
	_post.visible = false
	_leave_at = _clock
	_leave_s = maxf(seconds, 0.05)
	_started_real = Time.get_ticks_msec() * 0.001


func _update_leave(_t: float) -> void :
	if not _leaving:
		return
	if _online_launch and not _lobby_connection_valid():
		_cancel_lobby_leave()
		return

	var u: = clampf((Time.get_ticks_msec() * 0.001 - _started_real) / _leave_s, 0.0, 1.0)
	_exit_visual.sample(u)
	_fade.color.a = _smooth(clampf((u - 0.35) / 0.65, 0.0, 1.0))
	if _music != null:
		_music.volume_db = lerpf(_music_db, -60.0, u * u)
	_background.fade_audio(u * u)
	if u >= 1.0:
		_go_next()


func _go_next(_unused: String = "") -> void :


	if _going:
		return
	if _online_launch and not _lobby_connection_valid():
		_cancel_lobby_leave()
		return
	_going = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


	if Session.is_online():
		get_tree().change_scene_to_file(NEXT_SCENE)
		return
	var screen: = LoadingScreen.open(get_tree())
	Arena.build_async = true
	BlockVolume.loading = true
	await get_tree().process_frame

	var robot_model: = String(RobotBody.config()["model"])
	ResourceLoader.load_threaded_request(NEXT_SCENE)
	ResourceLoader.load_threaded_request(robot_model)
	while ResourceLoader.load_threaded_get_status(NEXT_SCENE) == ResourceLoader.THREAD_LOAD_IN_PROGRESS or ResourceLoader.load_threaded_get_status(robot_model) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var progress: Array = []
		ResourceLoader.load_threaded_get_status(NEXT_SCENE, progress)
		if not progress.is_empty():
			screen.set_progress(0.25 * float(progress[0]))
		await get_tree().process_frame
	ResourceLoader.load_threaded_get(robot_model)
	var scene: = ResourceLoader.load_threaded_get(NEXT_SCENE) as PackedScene

	var holder: = {}
	var task: = WorkerThreadPool.add_task( func() -> void : holder["node"] = scene.instantiate())
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	screen.set_progress(0.3)
	var tree: = get_tree()
	var match_node: Node = holder["node"]
	tree.root.add_child(match_node)
	tree.current_scene = match_node
	queue_free()


func _lobby_connection_valid() -> bool:
	return Session.is_online() and Session.state == "ready" and Session.lobby.launch_committed


func _cancel_lobby_leave() -> void :
	_online_launch = false
	_leaving = false
	Match.next_mode = ""
	_fade.color.a = 0.0
	_exit_visual.visible = false
	if _music != null: _music.volume_db = _music_db
	_background.fade_audio(0.0)
	if _lobby != null:
		_lobby.process_mode = Node.PROCESS_MODE_INHERIT
		_lobby.cancel_launch()



func _capture_frames(t: float) -> void :
	if not _frames.has("path") or t < float(_frames["next"]):
		return
	var images: Array = _frames["images"]
	images.append(get_viewport().get_texture().get_image())
	_frames["next"] = float(_frames["next"]) + float(_frames.get("step", 0.5))
	if images.size() < int(_frames.get("count", 1)):
		return
	var first: Image = images[0]
	var w: = first.get_width()
	var h: = first.get_height()
	var cols: = mini(4, images.size())
	var rows: = ceili(images.size() / float(cols))
	var sheet: = Image.create(w * cols, h * rows, false, first.get_format())
	for i in images.size():
		@warning_ignore("integer_division")
		sheet.blit_rect(images[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png(String(_frames["path"]))
	get_tree().quit()


static func _smooth(x: float) -> float:
	var v: = clampf(x, 0.0, 1.0)
	return v * v * (3.0 - 2.0 * v)



func _dispatch_to(target_s: float) -> void :
	while not _events.is_empty() and float(_events[0]["t"]) <= target_s:
		var event: Dictionary = _events.pop_front()
		_scheduled_s = float(event["t"])
		_clock = _scheduled_s
		_event_audible = target_s - _scheduled_s <= float(_cinema["event_sound_window_s"])
		(event["do"] as Callable).call()
	_clock = target_s
	_event_audible = true


func _plan_menu_impacts() -> void :
	var lands: Dictionary = _cfg["menu"]["times"]["lands"]
	var note: = 0
	for key: String in lands:
		var event_note: = note
		var strength: = 1.0 if key == "ignite" else (0.55 if key in ["logo", "quit"] else 0.3)
		_at(float(lands[key]), func() -> void : _on_menu_landed(_menu.timeline_land_point(key), strength, event_note))
		note += 1


func _plan_sound_layers() -> void :
	var sound: Dictionary = _cinema["sfx"]
	for impact_s: float in [float(_cfg["somyst"]["start_s"]), float(_cfg["lavoice"]["start_s"]), float(_cfg["menu"]["times"]["lands"]["panel"])]:
		_at(impact_s - float(sound["whoosh_s"]), func() -> void : _play(_fx_sounds["whoosh"], 1.0, float(sound["whoosh_db"])))
	var slam: = float(_cfg["lavoice"]["slam_s"])
	_at(slam - float(sound["rise_s"]), func() -> void : _play(_fx_sounds["rise"], 1.0, float(sound["rise_db"])))
	_at(slam, func() -> void : _play(_fx_sounds["impact"], 1.0, float(sound["impact_db"])))
	_at(float(_cfg["menu"]["times"]["lock_s"]), func() -> void : _play(_fx_sounds["impact"], 1.0, float(sound["impact_db"])))


func _update_camera(t: float, view: Vector2) -> void :
	var camera: Dictionary = _cinema["camera"]
	var fx: Dictionary = _cinema["post"]
	var zoom: = 0.0
	var shake: = 0.0
	var flash: = 0.0
	var chroma: = 0.0
	var flash_color: = Color.WHITE
	for impact: Dictionary in _impacts:
		var age: = t - float(impact["t"])
		if age < 0.0 or age > float(camera["settle_s"]):
			continue
		var strength: = float(impact["strength"])
		zoom += float(camera["punch"]) * strength * exp( - float(camera["punch_decay"]) * age) * sin(age * TAU * float(camera["punch_hz"]))
		shake += strength * strength * exp( - float(camera["shake_decay"]) * age)
		var flare: = strength * maxf(0.0, 1.0 - age / float(_cinema["impact_flash_s"]))
		if flare > flash:
			flash = flare
			flash_color = impact["color"]
		if strength >= 1.0:
			chroma = maxf(chroma, maxf(0.0, 1.0 - age / float(fx["aberration_s"])))
	var camera_end: = float(_cfg["menu"]["logo_from_s"])
	var active: = _smooth(t - float(_orb["from"])) * (1.0 - _smooth((t - camera_end + 0.5) / 0.5))
	var drift: Array = camera["drift_px"]
	var rates: Array = camera["drift_hz"]
	var offset: = Vector2(sin(t * float(rates[0]) * TAU) * float(drift[0]), cos(t * float(rates[1]) * TAU) * float(drift[1])) * active
	var punch: = Vector2(sin(t * 71.0), cos(t * 59.0)) * shake * float(camera["shake_px"])
	_stage.position = view * 0.5 + offset + punch
	var slam: = float(_cfg["lavoice"]["slam_s"])
	var charge: = _smooth((t - slam + float(camera["breath_s"])) / float(camera["breath_s"])) if t < slam else 0.0
	var push: = float(camera["push"]) * active + float(camera["breath_zoom"]) * charge
	var since: = t - _squash_at
	var squash: = _squash_amp * exp(-7.0 * since) * cos(22.0 * since) if since >= 0.0 and since < 3.0 else 0.0
	_stage.scale = Vector2(1.0 + squash, 1.0 - squash) * (1.0 + zoom + push)
	_flash.color = Color(flash_color.lerp(Color.WHITE, 0.5), flash * float(_cinema["impact_flash"]))
	_post_material.set_shader_parameter("bloom", float(fx["bloom"]) + flash * float(fx["impact_bloom"]))
	_post_material.set_shader_parameter("aberration_px", chroma * float(fx["aberration_px"]))
