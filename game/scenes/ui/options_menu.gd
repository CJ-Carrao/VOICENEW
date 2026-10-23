class_name OptionsMenu
extends Control






signal opened
signal closed
signal menu_requested

signal talk_key_changed

signal voice_history_toggled(enabled: bool)

const PAPER: = Vector2(1920, 1080)
const SKIN = preload("res://scenes/ui/options_skin.gd")
const BUTTON = preload("res://scenes/menu/menu_chamfer_button.gd")
const ACCENT: = Color("#f2601a")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#b0aca4")
const SECTIONS: = {
	"video": ["01", "VÍDEO"], 
	"sound": ["02", "SOM"], 
	"audio": ["03", "VOZ"], 
	"controls": ["04", "CONTROLES"], 
	"diagnostics": ["05", "DIAGNÓSTICO"], 
}
const MIN_GATE_DB: = -60.0
const MAX_GATE_DB: = -15.0
const COLOR_HEADER: = ACCENT
const COLOR_FAIL: = "#ff7070"
const COLOR_OK: = "#7be08f"
const COLOR_MUTED: = "#b0aca4"

var voice: VoiceInput
var player: Player
var is_open: bool = false

var _main_page: VBoxContainer
var _canvas: Control
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _page_id: = "video"
var _page_title: Label
var _context_hint: Label
var _save_hint: Label
var _font: Font
var _bold: Font
var _fit_scale: = 1.0
var _origin: = Vector2.ZERO
var _motion: Tween
var _return_focus: WeakRef
var _menu_context: = false
var _ui_sound: AudioStreamPlayer
var _voice_off: Label
var _device: OptionButton
var _meter: LevelMeter
var _gate: HSlider
var _gate_label: Label
var _talk_button: Button
var _talk_note: Label
var _waiting_key: bool = false
var _playback: CheckButton
var _history: CheckButton
var _test_hint: Label
var _test_result: RichTextLabel
var _sensitivity: HSlider
var _sensitivity_label: Label
var _title: Label
var _video: Dictionary = {}
var _preset_buttons: Dictionary = {}
var _volumes: Dictionary = {}
var _mute_unfocused: CheckButton
var _preview: AudioStreamPlayer
var _back_button: Button
var _quit_button: Button
var _menu_button: Button


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var source_font: = load(str(config.font)) as Font
	_font = MainMenu._variation(source_font, 500, 0)
	_bold = MainMenu._variation(source_font, 800, 0)
	theme = SKIN.create_theme(_font)
	_canvas = Control.new()
	_canvas.name = "SettingsCanvas"
	_canvas.size = PAPER
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_build_main_page(_canvas)
	_ui_sound = AudioStreamPlayer.new()
	_ui_sound.bus = AudioMix.bus(AudioMix.INTERFACE)
	add_child(_ui_sound)
	resized.connect(_fit)
	_fit()


func bind(voice_input: VoiceInput, local_player: Player) -> void :
	voice = voice_input
	player = local_player
	voice.utterance_done.connect(_on_utterance)
	_sensitivity.set_value_no_signal(float(UserSettings.get_value("controls", "mouse_scale", 1.0)))
	_refresh_sensitivity_label()



func use_menu_context() -> void :
	_menu_context = true
	_back_button.text = "VOLTAR"
	_quit_button.visible = false
	_menu_button.visible = false
	_context_hint.text = "MENU PRINCIPAL"
	_wire_focus()



func show_voice_test() -> void :
	_show_page("audio")
	_reveal_voice_test.call_deferred()


func _reveal_voice_test() -> void :
	if is_open and _page_id == "audio":
		(_pages.audio as ScrollContainer).ensure_control_visible(_test_hint)


func open() -> void :
	if is_open: return
	var focused: = get_viewport().gui_get_focus_owner()
	_return_focus = weakref(focused) if focused != null else null
	is_open = true
	visible = true
	if voice != null: voice.set_chat_blocked(true)
	_refresh_voice_section()
	_refresh_video()
	_refresh_sound()
	_context_hint.text = "MENU PRINCIPAL" if _menu_context else ("PARTIDA ONLINE · EM ANDAMENTO" if Session.is_online() else "PARTIDA PAUSADA")
	opened.emit()
	_show_page(_page_id, false)
	if _motion != null and _motion.is_valid(): _motion.kill()
	modulate.a = 0.0
	_motion = create_tween()
	_motion.tween_property(self, "modulate:a", 1.0, 0.16)
	for i in _tab_buttons.size(): MenuAssembly.piece(_tab_buttons.values()[i], i)
	MenuAssembly.piece(_pages[_page_id], 2)
	(_tab_buttons[_page_id] as Button).grab_focus()
	_sound(true)


func close() -> void :
	if not is_open: return
	UiSound.play_at(get_parent(), "back")
	if voice != null and voice.is_private_talk() and voice.state == "listening": voice.end_talk()
	_set_waiting_key(false)
	for page: Control in _pages.values(): MenuAssembly.cancel(page)
	for tab: Control in _tab_buttons.values(): MenuAssembly.cancel(tab)
	for control: Node in find_children("*", "OptionButton", true, false): (control as OptionButton).get_popup().hide()
	var focused: = get_viewport().gui_get_focus_owner()
	if focused != null and is_ancestor_of(focused): focused.release_focus()
	if _motion != null and _motion.is_valid(): _motion.kill()
	is_open = false
	visible = false
	if voice != null: voice.set_chat_blocked(false)
	closed.emit()
	if _return_focus != null:
		var previous: = _return_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()


func _input(event: InputEvent) -> void :
	if not is_open:
		return
	if _waiting_key:
		_capture_talk_key(event)
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("talk") and voice != null and voice.is_on():

		if voice.begin_talk(true):
			show_voice_test()
			_test_result.text = "[color=%s]ouvindo…[/color]" % COLOR_MUTED
		get_viewport().set_input_as_handled()
	elif event.is_action_released("talk") and voice != null and voice.is_private_talk():
		voice.end_talk()
		_test_result.text = "[color=%s]entendendo…[/color]" % COLOR_MUTED
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void :
	if not visible or voice == null:
		return
	_meter.level = voice.live_level
	_meter.threshold = voice.min_speech_level()




func _build_main_page(parent: Control) -> void :
	var logo: = TextureRect.new()
	logo.texture = load("res://assets/intro/logos/lavoice.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(66, 64)
	logo.size = Vector2(370, 90)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(logo)
	_label_at("AJUSTES", Rect2(70, 222, 420, 28), 21, ACCENT, true)
	_title = _label_at("CONFIGURAÇÕES", Rect2(66, 261, 458, 66), 41, INK, true)
	_context_hint = _label_at("PARTIDA PAUSADA", Rect2(70, 340, 440, 54), 20, MUTED)
	var index: = 0
	for id: String in SECTIONS:
		var button: = _button(str(SECTIONS[id][1]), func() -> void : _show_page(id))
		button.position = Vector2(66, 400 + index * 70)
		button.size = Vector2(420, 58)
		button.set("text_size", 24)
		parent.add_child(button)
		_tab_buttons[id] = button
		index += 1
	_back_button = _button("VOLTAR AO JOGO", close)
	_back_button.position = Vector2(66, 954)
	_back_button.size = Vector2(420, 66)
	parent.add_child(_back_button)
	_menu_button = _button("SAIR DA PARTIDA", func() -> void : menu_requested.emit())
	_menu_button.position = Vector2(66, 782)
	_menu_button.size = Vector2(420, 60)
	parent.add_child(_menu_button)
	_quit_button = _button("SAIR DO JOGO", func() -> void : get_tree().quit())
	_quit_button.position = Vector2(66, 856)
	_quit_button.size = Vector2(420, 60)
	parent.add_child(_quit_button)

	_page_title = _label_at("", Rect2(650, 100, 1160, 70), 48, INK, true)
	_save_hint = _label_at("ALTERAÇÕES SALVAS AUTOMATICAMENTE", Rect2(650, 968, 820, 30), 19, MUTED)
	_label_at("ESC  VOLTAR     TAB  NAVEGAR", Rect2(1390, 968, 450, 30), 19, MUTED)
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var build_label: = _label_at(str(config.menu.get("build_label", "Build H-1")), Rect2(1520, 1030, 320, 26), 18, MUTED)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_build_video(_new_page("video"))
	_build_sound(_new_page("sound"))
	_build_audio(_new_page("audio"))
	_build_controls(_new_page("controls"))
	_build_diagnostics(_new_page("diagnostics"))
	_show_page("video", false)


func _new_page(id: String) -> VBoxContainer:
	var scroll: = ScrollContainer.new()
	scroll.name = id.capitalize()
	scroll.position = Vector2(650, 300)
	scroll.size = Vector2(1170, 610)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(scroll)
	_pages[id] = scroll
	var content: = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 20)
	scroll.add_child(content)
	return content


func _grid(parent: Control) -> GridContainer:
	var grid: = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 32)
	grid.add_theme_constant_override("v_separation", 22)
	parent.add_child(grid)
	return grid


func _build_video(parent: VBoxContainer) -> void :
	var grid: = _grid(parent)
	var preset_row: = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 14)
	for id: String in VideoSettings.PRESET_ORDER:
		var button: = _button(String(VideoSettings.PRESET_NAMES[id]), func() -> void :
			VideoSettings.apply_preset(id)
			_refresh_video())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_row.add_child(button)
		_preset_buttons[id] = button
	_row(grid, "PREDEFINIÇÃO", preset_row)
	_video_choice(grid, "MODO DE TELA", "window_mode", VideoSettings.WINDOW_MODES)
	_video_choice(grid, "RESOLUÇÃO DA JANELA", "resolution", [])
	var vsync: = CheckButton.new()
	vsync.text = "Sincronia vertical"
	vsync.toggled.connect( func(on: bool) -> void : _set_video("vsync", on))
	_video["vsync"] = vsync
	_row(grid, "VSYNC", vsync)
	var limits: Array = []
	for fps: int in VideoSettings.FPS_LIMITS: limits.append([fps, "Sem limite" if fps == 0 else "%d FPS" % fps])
	_video_choice(grid, "LIMITE DE FPS", "max_fps", limits)
	parent.add_child(HSeparator.new())
	parent.add_child(_header("QUALIDADE DA IMAGEM"))
	var quality: = _grid(parent)
	_video_slider(quality, "ESCALA 3D", "render_scale", 0.5, 1.0, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	_video_choice(quality, "AMPLIAÇÃO", "upscaler", VideoSettings.UPSCALERS)
	_video_choice(quality, "SUAVIZAÇÃO", "antialias", VideoSettings.ANTIALIAS)
	_video_choice(quality, "SOMBRAS", "shadows", VideoSettings.SHADOWS)
	_video_choice(quality, "EFEITOS", "effects", VideoSettings.EFFECTS)
	_video_choice(quality, "DETALHE À DISTÂNCIA", "lod", VideoSettings.LODS)
	var post: = VBoxContainer.new()
	post.add_theme_constant_override("separation", 12)
	for entry: Array in [["glow", "Bloom"], ["ssao", "Oclusão de ambiente (SSAO)"]]:
		var key: String = entry[0]
		var check: = CheckButton.new()
		check.text = entry[1]
		check.toggled.connect( func(on: bool) -> void : _set_video(key, on))
		_video[key] = check
		post.add_child(check)
	_row(quality, "PÓS-PROCESSAMENTO", post)
	parent.add_child(HSeparator.new())
	parent.add_child(_header("VISUALIZAÇÃO"))
	var view: = _grid(parent)
	_video_slider(view, "CAMPO DE VISÃO", "fov", 60.0, 110.0, 1.0, func(v: float) -> String: return "%d°" % roundi(v))
	_video_slider(view, "BRILHO", "brightness", 0.5, 1.5, 0.05, func(v: float) -> String: return "%d%%" % roundi(v * 100.0))
	var fps_check: = CheckButton.new()
	fps_check.text = "Mostrar FPS"
	fps_check.toggled.connect( func(on: bool) -> void : _set_video("show_fps", on))
	_video["show_fps"] = fps_check
	_row(view, "DESEMPENHO", fps_check)



func _video_choice(grid: GridContainer, label_text: String, key: String, entries: Array) -> void :
	var choice: = OptionButton.new()
	choice.custom_minimum_size.y = 60
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.set_meta("entries", entries)
	choice.item_selected.connect( func(index: int) -> void : _set_video(key, choice.get_item_metadata(index)))
	_video[key] = choice
	_row(grid, label_text, choice)


func _video_slider(grid: GridContainer, label_text: String, key: String, low: float, high: float, step: float, 
		format: Callable) -> void :
	var line: = HBoxContainer.new()
	line.add_theme_constant_override("separation", 20)
	var slider: = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.y = 50
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown: = Label.new()
	shown.custom_minimum_size.x = 100
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.set_meta("label", shown)
	slider.set_meta("format", format)
	slider.value_changed.connect( func(v: float) -> void :
		shown.text = format.call(v)
		_set_video(key, snappedf(v, step)))
	line.add_child(slider)
	line.add_child(shown)
	_video[key] = slider
	_row(grid, label_text, line)


func _set_video(key: String, new_value: Variant) -> void :
	VideoSettings.set_value(key, new_value)
	if key == "fov" and player != null:
		player.apply_user_settings()
	_refresh_video()



func _refresh_video() -> void :
	for key: String in _video:
		var control: Control = _video[key]
		var current: Variant = VideoSettings.value(key)
		if control is OptionButton:
			var choice: = control as OptionButton
			var entries: Array = choice.get_meta("entries")
			if key == "resolution":
				entries = []
				for entry: String in VideoSettings.resolutions(): entries.append([entry, entry.replace("x", " × ")])
			choice.clear()
			for entry: Array in entries:
				choice.add_item(String(entry[1]))
				choice.set_item_metadata(choice.item_count - 1, entry[0])
				if entry[0] == current: choice.select(choice.item_count - 1)
			if key == "resolution":
				choice.disabled = String(VideoSettings.value("window_mode")) != "windowed"
		elif control is CheckButton:
			(control as CheckButton).set_pressed_no_signal(bool(current))
		elif control is HSlider:
			var slider: = control as HSlider
			slider.set_value_no_signal(float(current))
			(slider.get_meta("label") as Label).text = (slider.get_meta("format") as Callable).call(slider.value)
	var preset: = VideoSettings.current_preset()
	for id: String in _preset_buttons:
		(_preset_buttons[id] as Button).set("primary", id == preset)


func _build_sound(parent: VBoxContainer) -> void :
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	var grid: = _grid(parent)
	for channel: Array in AudioMix.CHANNELS:
		var key: String = channel[0]
		var bus: StringName = channel[1]
		var line: = HBoxContainer.new()
		line.add_theme_constant_override("separation", 20)
		var slider: = HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size.y = 50
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shown: = Label.new()
		shown.custom_minimum_size.x = 100
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slider.set_meta("label", shown)
		slider.value_changed.connect( func(v: float) -> void :
			AudioMix.set_volume(key, v)
			shown.text = _percent(v))
		slider.drag_ended.connect( func(_changed: bool) -> void : _play_preview(bus))
		line.add_child(slider)
		line.add_child(shown)
		_volumes[key] = slider
		_row(grid, String(channel[2]), line)
	parent.add_child(HSeparator.new())
	var other: = _grid(parent)
	_mute_unfocused = CheckButton.new()
	_mute_unfocused.text = "Silenciar em segundo plano"
	_mute_unfocused.toggled.connect( func(on: bool) -> void : AudioMix.set_mute_unfocused(on))
	_row(other, "FORA DO JOGO", _mute_unfocused)


func _refresh_sound() -> void :
	for key: String in _volumes:
		var slider: = _volumes[key] as HSlider
		slider.set_value_no_signal(AudioMix.volume(key))
		(slider.get_meta("label") as Label).text = _percent(slider.value)
	_mute_unfocused.set_pressed_no_signal(AudioMix.mute_unfocused())


func _play_preview(bus: StringName) -> void :
	if not is_open: return
	_preview.bus = AudioMix.bus(bus)
	_preview.stream = BuildSounds.thunk()
	_preview.volume_db = -14.0
	_preview.pitch_scale = 1.2
	_preview.play()


static func _percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


func _build_audio(parent: VBoxContainer) -> void :
	_main_page = parent
	_voice_off = _dim("")
	_voice_off.add_theme_color_override("font_color", Color("#ffb28d"))
	parent.add_child(_voice_off)
	var grid: = _grid(parent)
	_device = OptionButton.new()
	_device.custom_minimum_size.y = 60
	_device.fit_to_longest_item = false
	_device.clip_text = true
	_device.item_selected.connect(_on_device_selected)
	_row(grid, "MICROFONE", _device)
	var level_box: = VBoxContainer.new()
	level_box.add_theme_constant_override("separation", 14)
	_meter = LevelMeter.new()
	level_box.add_child(_meter)
	_meter.custom_minimum_size.y = 26
	_row(grid, "NÍVEL DE ENTRADA", level_box)
	var gate_box: = HBoxContainer.new()
	gate_box.add_theme_constant_override("separation", 20)
	_gate = HSlider.new()
	_gate.min_value = MIN_GATE_DB
	_gate.max_value = MAX_GATE_DB
	_gate.step = 1.0
	_gate.custom_minimum_size.y = 50
	_gate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gate.value_changed.connect(_on_gate_changed)
	gate_box.add_child(_gate)
	_gate_label = Label.new()
	_gate_label.custom_minimum_size.x = 100
	_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gate_box.add_child(_gate_label)
	_row(grid, "VOLUME MÍNIMO", gate_box)
	var test_box: = VBoxContainer.new()
	test_box.add_theme_constant_override("separation", 12)
	_test_hint = _dim("")
	test_box.add_child(_test_hint)
	_test_result = RichTextLabel.new()
	_test_result.bbcode_enabled = true
	_test_result.fit_content = true
	_test_result.scroll_active = false
	_test_result.custom_minimum_size.y = 28
	test_box.add_child(_test_result)
	_row(grid, "TESTE PARTICULAR", test_box)
	var feedback: = VBoxContainer.new()
	feedback.add_theme_constant_override("separation", 14)
	_playback = CheckButton.new()
	_playback.text = "Ouvir minha fala depois de cada pedido"
	_playback.toggled.connect( func(on: bool) -> void :
		if voice != null: voice.set_playback_enabled(on))
	feedback.add_child(_playback)
	_history = CheckButton.new()
	_history.text = "Mostrar histórico de voz na tela"
	_history.button_pressed = bool(UserSettings.get_value("voice", "history", false))
	_history.toggled.connect( func(on: bool) -> void :
		UserSettings.set_value("voice", "history", on)
		voice_history_toggled.emit(on))
	feedback.add_child(_history)
	_row(grid, "RETORNO", feedback)


func _build_controls(parent: VBoxContainer) -> void :
	var grid: = _grid(parent)
	var sens_box: = HBoxContainer.new()
	sens_box.add_theme_constant_override("separation", 20)
	_sensitivity = HSlider.new()
	_sensitivity.min_value = 0.2
	_sensitivity.max_value = 3.0
	_sensitivity.step = 0.05
	_sensitivity.value = 1.0
	_sensitivity.custom_minimum_size.y = 50
	_sensitivity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sensitivity.value_changed.connect(_on_sensitivity_changed)
	sens_box.add_child(_sensitivity)
	_sensitivity_label = Label.new()
	_sensitivity_label.custom_minimum_size.x = 100
	_sensitivity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sens_box.add_child(_sensitivity_label)
	_row(grid, "SENSIBILIDADE", sens_box)
	var talk_box: = VBoxContainer.new()
	talk_box.add_theme_constant_override("separation", 14)
	_talk_button = _button("V", func() -> void : _set_waiting_key(true))
	talk_box.add_child(_talk_button)
	_talk_note = _dim("")
	talk_box.add_child(_talk_note)
	_row(grid, "PEDIR POR VOZ", talk_box)
	var chat_box: = VBoxContainer.new()
	chat_box.add_theme_constant_override("separation", 14)
	chat_box.add_child(_header("CAPS LOCK (SEGURAR)"))
	_row(grid, "CONVERSAR ONLINE", chat_box)
	parent.add_child(HSeparator.new())
	parent.add_child(_header("ATALHOS DA PARTIDA"))
	var shortcuts: = _grid(parent)
	_row(shortcuts, "MOVIMENTO", _dim("WASD  andar   ·   ESPAÇO  pular / escalar   ·   SHIFT  correr   ·   C  agachar / escorregar"))
	_row(shortcuts, "EQUIPAMENTO", _dim("1–3  equipamento   ·   BOTÃO DIREITO  mirar   ·   SCROLL  câmera   ·   F  sair da pilotagem"))
	_row(shortcuts, "PEDIDOS E MENU", _dim("T  abrir console de texto   ·   ESC  voltar / opções"))


func _build_diagnostics(parent: VBoxContainer) -> void :
	var grid: = _grid(parent)
	var network_logs: = VBoxContainer.new()
	network_logs.add_theme_constant_override("separation", 18)
	var save_network_log: = CheckButton.new()
	save_network_log.text = "Salvar diagnóstico do multiplayer"
	save_network_log.button_pressed = Session.diagnostics.is_enabled()
	save_network_log.toggled.connect( func(on: bool) -> void : Session.diagnostics.set_enabled(on))
	network_logs.add_child(save_network_log)
	network_logs.add_child(_button("ABRIR LOGS DO MULTIPLAYER", func() -> void :
		if Session.diagnostics.open_folder() != OK: _save_hint.text = "Não foi possível abrir a pasta dos logs."))
	_row(grid, "MULTIPLAYER", network_logs)
	var logs: = VBoxContainer.new()
	logs.add_theme_constant_override("separation", 18)
	var save_log: = CheckButton.new()
	save_log.text = "Salvar minhas falas reconhecidas em TXT"
	save_log.button_pressed = VoiceFeedback.enabled()
	save_log.toggled.connect( func(on: bool) -> void : UserSettings.set_value("voice", "save_text_log", on))
	logs.add_child(save_log)
	logs.add_child(_button("ABRIR PASTA DOS REGISTROS", func() -> void :
		if OS.shell_open(VoiceFeedback.folder_path()) != OK: _save_hint.text = "Não foi possível abrir a pasta dos registros."))
	_row(grid, "PEDIDOS POR VOZ", logs)


func _show_page(id: String, animate: = true) -> void :
	if not _pages.has(id): return
	var focused: = get_viewport().gui_get_focus_owner()
	var move_focus: = focused != null and _page_id != id and (_pages[_page_id] as Control).is_ancestor_of(focused)
	_set_waiting_key(false)
	for key: String in _pages:
		var page: = _pages[key] as ScrollContainer
		MenuAssembly.cancel(page)
		page.visible = key == id
		(_tab_buttons[key] as Button).set("primary", key == id)
	_page_id = id
	_page_title.text = str(SECTIONS[id][0]) + "  /  " + str(SECTIONS[id][1])
	if animate and is_open:
		MenuAssembly.piece(_pages[id], 0)
		_sound(false)
	_wire_focus()
	if move_focus and is_open: (_tab_buttons[id] as Button).grab_focus()


func _wire_focus() -> void :
	var controls: Array[Control] = []
	for tab: Control in _tab_buttons.values(): controls.append(tab)
	for node: Node in (_pages[_page_id] as Control).find_children("*", "Control", true, false):
		var control: = node as Control
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			if control is BaseButton and (control as BaseButton).disabled: continue
			if control is Slider and not (control as Slider).editable: continue
			controls.append(control)
	for button: Control in [_menu_button, _quit_button, _back_button]:
		if button.visible: controls.append(button)
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])


func _fit() -> void :
	_fit_scale = minf(size.x / PAPER.x, size.y / PAPER.y)
	_origin = (size - PAPER * _fit_scale) * 0.5
	_canvas.position = _origin
	_canvas.scale = Vector2.ONE * _fit_scale
	queue_redraw()


func _draw() -> void :
	draw_rect(Rect2(Vector2.ZERO, size), Color("#161619"))
	draw_set_transform(_origin, 0.0, Vector2.ONE * _fit_scale)
	var panel: = PackedVector2Array([Vector2(0, 0), Vector2(590, 0), Vector2(540, 50), Vector2(540, 340), Vector2(514, 366), Vector2(514, 930), Vector2(474, 970), Vector2(474, 1080), Vector2(0, 1080)])
	var colors: = PackedColorArray()
	for point in panel: colors.append(Color("#2a2a2d").lerp(Color("#19191b"), point.y / PAPER.y))
	draw_polygon(panel, colors)
	draw_polyline(PackedVector2Array([Vector2(605, 0), Vector2(552, 53), Vector2(552, 183)]), ACCENT, 6, true)
	draw_polyline(PackedVector2Array([Vector2(525, 391), Vector2(525, 620), Vector2(511, 634)]), ACCENT, 4, true)
	draw_line(Vector2(66, 748), Vector2(478, 748), Color("#454449"), 1)
	var card: = PackedVector2Array([Vector2(622, 268), Vector2(1814, 268), Vector2(1844, 298), Vector2(1844, 914), Vector2(1820, 938), Vector2(622, 938), Vector2(602, 918), Vector2(602, 288)])
	draw_colored_polygon(card, Color("#202023"))
	card.append(card[0])
	draw_polyline(card, Color("#3d3c40"), 1, true)
	draw_line(Vector2(650, 267), Vector2(790, 267), ACCENT, 4, true)
	draw_line(Vector2(650, 952), Vector2(1840, 952), Color("#454449"), 1)
	draw_set_transform(Vector2.ZERO)


func _label_at(value: String, rect: Rect2, fs: int, color: Color, bold: = false) -> Label:
	var label: = Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", _bold if bold else _font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(label)
	return label


func _sound(pressed: bool) -> void :
	if _ui_sound == null or not is_open: return
	UiSound.play(_ui_sound, "confirm" if pressed else "navigate")


func _refresh_voice_section() -> void :
	var on: = voice != null and voice.is_on()
	_voice_off.visible = not on
	_voice_off.text = "Reconhecimento de pedidos desligado: %s" % (voice.off_reason if voice != null and not voice.off_reason.is_empty()\
	else "nesta partida")
	_device.clear()
	var current: = AudioServer.input_device
	for device in VoiceInput.input_devices():
		_device.add_item("Padrão do sistema" if device == "Default" else device)
		_device.set_item_metadata(_device.item_count - 1, device)
		if device == current:
			_device.select(_device.item_count - 1)
	_device.disabled = voice == null or not voice.capture_available()
	_gate.set_value_no_signal(clampf(linear_to_db(maxf(voice.min_speech_level(), 0.0001)), MIN_GATE_DB, MAX_GATE_DB)\
	if voice != null else MIN_GATE_DB)
	_gate.editable = on
	_refresh_gate_label()
	_talk_button.text = UserSettings.talk_key_name()
	_playback.set_pressed_no_signal(voice != null and voice.playback_enabled)
	_playback.disabled = not on
	_test_hint.text = "Segure %s e fale." % UserSettings.talk_key_name()


func _on_device_selected(index: int) -> void :
	if voice == null:
		return
	var device: = String(_device.get_item_metadata(index))
	_test_result.text = "[color=%s]trocando o microfone…[/color]" % COLOR_MUTED
	if await voice.set_input_device(device):
		_test_result.text = "[color=%s]Microfone: %s. Fale e veja o medidor mexer.[/color]" % [COLOR_OK, _escape(_device.get_item_text(index))]
	else:
		_test_result.text = "[color=%s]Não consegui abrir esse microfone. Escolha \"Padrão do sistema\" e defina o microfone no Windows.[/color]" % COLOR_FAIL


func _on_gate_changed(value: float) -> void :
	if voice != null:
		voice.set_min_speech_level(db_to_linear(value))
	_refresh_gate_label()


func _refresh_gate_label() -> void :
	_gate_label.text = "%d dB" % roundi(_gate.value)


func _on_sensitivity_changed(value: float) -> void :
	UserSettings.set_value("controls", "mouse_scale", value)
	if player != null:
		player.apply_user_settings()
	_refresh_sensitivity_label()


func _refresh_sensitivity_label() -> void :
	_sensitivity_label.text = "%s×" % Lexicon.data.format_number(snappedf(_sensitivity.value, 0.05))




func _set_waiting_key(waiting: bool) -> void :
	_waiting_key = waiting
	if waiting:
		_talk_button.text = "APERTE A TECLA… (ESC CANCELA)"
	else:
		_talk_button.text = UserSettings.talk_key_name()


func _capture_talk_key(event: InputEvent) -> void :
	var key: = event as InputEventKey
	var mouse: = event as InputEventMouseButton
	if (key == null or not key.pressed or key.echo) and (mouse == null or not mouse.pressed):
		return
	get_viewport().set_input_as_handled()
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_set_waiting_key(false)
		return
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:

		_set_waiting_key(false)
		return
	var problem: = UserSettings.set_talk_event(event)
	if not problem.is_empty():
		_talk_note.text = "Não deu: %s. Tente outra." % problem
		return
	_talk_note.text = "Pronto: segure %s pra falar." % UserSettings.talk_key_name()
	_set_waiting_key(false)
	_refresh_voice_section()
	talk_key_changed.emit()




func _on_utterance(info: Dictionary) -> void :
	if not is_open or not info.get("private", false):
		return
	_reveal_voice_test.call_deferred()
	var samples: PackedFloat32Array = info["samples"]
	voice.play_back(samples)
	var level: = "volume %d dB" % roundi(linear_to_db(maxf(float(info["level"]), 0.0001)))
	var reason: = String(info["ignored"])
	if not reason.is_empty():
		_test_result.text = "[color=%s]%s[/color] [color=%s](%s)[/color]" % [COLOR_FAIL, reason, COLOR_MUTED, level]
		return
	var text: = String(info["text"])
	var result: = PhraseParser.parse(text, Lexicon.data)
	var lines: = PackedStringArray(["Ouvi: “%s”  [color=%s](%s s, %s)[/color]" % [_escape(text), COLOR_MUTED, 
		Lexicon.data.format_number(snappedf(float(info["seconds"]), 0.1)), level]])
	if result["ok"]:
		lines.append("[color=%s]Entenderia: %s[/color]" % [COLOR_OK, _escape(String(result["pretty"]))])
	else:
		lines.append("[color=%s]Não viraria pedido.[/color]" % COLOR_FAIL)
	for fix: Dictionary in result.get("corrections", []):
		lines.append("[color=%s]o ouvido trocou \"%s\" por \"%s\"[/color]" % [COLOR_MUTED, _escape(str(fix["from"])), _escape(str(fix["to"]))])
	var unknown: = PackedStringArray(result.get("unknown_words", []))
	if not unknown.is_empty():
		lines.append("[color=%s]não conheço: %s[/color]" % [COLOR_MUTED, _escape(", ".join(unknown))])
	_test_result.text = "\n".join(lines)




func _row(grid: GridContainer, label_text: String, control: Control) -> void :
	var label: = Label.new()
	label.text = label_text
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.custom_minimum_size = Vector2(290, 0)
	label.add_theme_font_override("font", _bold)
	label.add_theme_font_size_override("font_size", 22)
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _header(text: String) -> Label:
	var label: = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_HEADER)
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_font_override("font", _bold)
	return label


func _dim(text: String) -> Label:
	var label: = Label.new()
	label.theme_type_variation = &"DimLabel"
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _button(text: String, action: Callable) -> Button:
	var button: = BUTTON.new() as Button
	button.text = text
	button.custom_minimum_size.y = 60
	button.set("ui_font", _bold)
	button.set("text_size", 24)
	button.pressed.connect( func() -> void :
		if not is_open: return
		_sound(true)
		action.call())
	return button


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
