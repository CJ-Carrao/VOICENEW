class_name LobbyMenu
extends Control


signal closed
signal offline_requested(mode: String)

const MAPS_PATH: = "res://data/world/maps.json"
signal match_requested

const BUTTON = preload("res://scenes/menu/menu_chamfer_button.gd")
const COLOR_BUTTON = preload("res://scenes/menu/lobby_color_button.gd")
const ASSEMBLY = preload("res://scenes/menu/menu_assembly.gd")
const PAPER: = Vector2(1920, 1080)
const ACCENT: = Color("#f2601a")
const INK: = Color("#f5f1e8")
const MUTED: = Color("#aaa69f")
const VERSUS_S: = 1.65

var _map_index: = 0
var _map_mode: = "practice"
var _map_list: Array = []
var page: = "home"
var is_open: = false
var stage: Control
var _canvas: Control
var _chrome: Control
var _page_root: Control
var _font: Font
var _bold: Font
var _title: Label
var _eyebrow: Label
var _note: Label
var _status: Label
var _address: LineEdit
var _port: LineEdit
var _addresses: OptionButton
var _ready_button: Button
var _start_button: Button
var _retry_button: Button
var _back: Button
var _logo: TextureRect
var _tagline: Label
var _build_label: Label
var _mode_label: Label
var _key_hint: Label
var _names: Array[Label] = []
var _player_states: Array[Label] = []
var _color_buttons: Array[Button] = []
var _color_hint: Label
var _color_request_pending: = -2
var _release_color_button: Button
var _paint_choice: OptionButton
var _paint_sent_generation: = -1
var _room_port: = NetworkSession.DEFAULT_PORT
var _last_target: = ""
var _host_intent: = false
var _locked: = false
var _scale: = 1.0
var _origin: = Vector2.ZERO
var _elapsed: = 0.0
var _feedback_left: = 0.0
var _ui_sound: AudioStreamPlayer
var _assembly_sound: AudioStreamPlayer
var _presentation_age: = 0.0
var _launch_generation: = -1
var _launch_epoch: = -1
var _launch_emitted: = false
var _closing: = false
var _visibility_tween: Tween
var _shell_tween: Tween
var _shell_amount: = 0.0
var _rebuild_age: = 1.0
var _retired_page: Control
var _panel_pieces: Array[PackedVector2Array] = []


func _ready() -> void :
	name = "LobbyMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var source_font: = load(str(config.font)) as Font
	_font = MainMenu._variation(source_font, 500, 0)
	_bold = MainMenu._variation(source_font, 800, 0)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = PAPER
	add_child(_canvas)
	_prepare_panel_pieces()
	var stage_script: = load("res://scenes/menu/lobby_stage.gd") as GDScript
	if stage_script != null:
		stage = stage_script.new() as Control
		stage.position = Vector2(580, 170)
		stage.size = Vector2(1280, 730)
		_canvas.add_child(stage)
	_build_chrome()
	_ui_sound = AudioStreamPlayer.new()
	_ui_sound.bus = AudioMix.bus(AudioMix.INTERFACE)
	_ui_sound.volume_db = -22.0
	add_child(_ui_sound)
	_assembly_sound = AudioStreamPlayer.new()
	_assembly_sound.bus = AudioMix.bus(AudioMix.INTERFACE)
	_assembly_sound.stream = BuildSounds.click()
	_assembly_sound.volume_db = -34.0
	add_child(_assembly_sound)
	Session.changed.connect(_on_session_changed)
	Session.lobby.changed.connect(_refresh_room)
	Session.lobby.match_requested.connect(_on_match_requested)
	Session.lobby.paints_changed.connect(_update_paints)
	resized.connect(_fit)
	_fit()
	visible = false
	set_process_unhandled_input(false)



func open_maps(mode: String) -> void :
	_map_mode = mode
	open("maps")


func open(start_page: String = "home") -> void :
	if _visibility_tween != null and _visibility_tween.is_valid(): _visibility_tween.kill()
	_closing = false
	is_open = true
	visible = true
	_locked = false
	_back.disabled = false
	modulate = Color.WHITE
	set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_page(start_page)
	_animate_shell(1.0, 0.42)
	modulate.a = 0.0
	_visibility_tween = create_tween()
	_visibility_tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _build_chrome() -> void :
	_chrome = Control.new()
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chrome.size = PAPER
	_canvas.add_child(_chrome)
	_chrome.draw.connect(_draw_chrome)
	var logo: = TextureRect.new()
	_logo = logo
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var logo_path: = str(config.get("lavoice", {}).get("logo", ""))
	if not logo_path.is_empty() and ResourceLoader.exists(logo_path): logo.texture = load(logo_path)
	if logo.texture != null:
		logo.position = Vector2(78, 60)
		logo.size = Vector2(390, 78)
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_canvas.add_child(logo)
	else:
		_label(_canvas, "LAVOICE", Rect2(80, 64, 420, 70), 56, INK, true)
	_eyebrow = _label(_canvas, "MULTIPLAYER / CONEXÃO DIRETA", Rect2(80, 198, 480, 30), 18, ACCENT, true)
	_title = _label(_canvas, "JOGAR", Rect2(76, 239, 490, 74), 52, INK, true)
	_tagline = _label(_canvas, "Idealizado por SOMYST", Rect2(760, 85, 1090, 30), 20, MUTED, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_build_label = _label(_canvas, str(config["menu"].get("build_label", "Build H-1")), Rect2(1570, 1050, 280, 24), 17, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_mode_label = _label(_canvas, "FFA / ATÉ 4 JOGADORES", Rect2(1380, 139, 470, 34), 24, INK, true, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in NetworkSession.MAX_PLAYERS:
		_names.append(_label(_canvas, "VAGA LIVRE", Rect2(0, 840, 280, 36), 23, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
		_player_states.append(_label(_canvas, "AGUARDANDO", Rect2(0, 879, 280, 26), 16, MUTED, false, HORIZONTAL_ALIGNMENT_CENTER))
		for label: Label in [_names[i], _player_states[i]]:
			label.add_theme_color_override("font_outline_color", Color("#121215"))
			label.add_theme_constant_override("outline_size", 3)
	_back = _button(_canvas, "VOLTAR", Rect2(80, 976, 210, 58), _go_back, false, 22)
	_key_hint = _label(_canvas, "ESC  VOLTAR     TAB  NAVEGAR", Rect2(1120, 992, 730, 28), 17, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)


func _show_page(value: String) -> void :
	var was_full: = _in_room()
	_retire_page()
	page = value
	_presentation_age = 0.0
	_rebuild_age = 0.0
	_page_root = Control.new()
	_page_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_root.size = PAPER
	_canvas.add_child(_page_root)
	_note = null
	_status = null
	_ready_button = null
	_start_button = null
	_retry_button = null
	_address = null
	_port = null
	_addresses = null
	_color_buttons.clear()
	_color_hint = null
	_color_request_pending = -2
	_release_color_button = null
	_back.disabled = false
	_back.text = "VOLTAR"
	_eyebrow.text = "MULTIPLAYER / CONEXÃO DIRETA"
	match page:
		"home": _build_home()
		"host": _build_host()
		"join": _build_join()
		"room": _build_room()
		"arena": _build_arena()
		"versus": _build_versus()
		"maps": _build_maps()
	if stage != null and stage.has_method("set_presentation"):
		stage.call("set_presentation", "arena" if page == "maps" else (page if page in ["arena", "versus"] else "waiting"))
	_layout_chrome()
	_refresh_room()
	_update_players()
	if _in_room() and not was_full and stage != null:
		stage.call("play_arrival")

		if page == "maps": stage.call("set_presentation", "arena")
	if was_full != _in_room(): _animate_shell(0.0 if _in_room() else 1.0, 0.38)
	_assemble_page()
	queue_redraw()


func is_transitioning() -> bool:
	return _closing or _rebuild_age < 0.6


func _chrome_pieces() -> Array[Control]:
	return [_logo, _title, _eyebrow, _tagline, _mode_label, _back, _key_hint, _build_label]


func _retire_page() -> void :

	if is_instance_valid(_retired_page):
		_canvas.remove_child(_retired_page)
		_retired_page.queue_free()
	_retired_page = _page_root
	if not is_instance_valid(_retired_page): return
	ASSEMBLY.retire(_retired_page)
	var outgoing: = _retired_page
	var retire: = create_tween().bind_node(outgoing)
	retire.tween_interval(0.35)
	retire.tween_callback(outgoing.queue_free)


func _assemble_page() -> void :
	var index: = 0
	var points: = PackedVector2Array()
	for child in _page_root.get_children():
		if child is Control:
			if child is Button and points.size() < 4:
				points.append(child.position + Vector2(child.size.x, child.size.y * 0.5))
			ASSEMBLY.piece(child, index)
			index += 1
	for piece: Control in _chrome_pieces():
		if piece.visible: ASSEMBLY.piece(piece, 0 if piece == _logo else 2)
	var sparks: = ASSEMBLY.new() as Control
	sparks.setup(points)
	_page_root.add_child(sparks)


func _animate_shell(target: float, seconds: float) -> void :
	if _shell_tween != null and _shell_tween.is_valid(): _shell_tween.kill()
	_shell_tween = create_tween()
	_shell_tween.tween_property(self, "_shell_amount", target, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_home() -> void :
	_title.text = "JOGAR"
	var first: = _button(_page_root, "CRIAR SALA", Rect2(80, 424, 460, 86), func(): _show_page("host"), true, 32)
	_button(_page_root, "ENTRAR EM SALA", Rect2(80, 530, 460, 80), func(): _show_page("join"), false, 30)
	_label(_page_root, "Use alguma VPN como (RADMIN) ou conecte via P2P", Rect2(84, 644, 450, 115), 21, MUTED)
	_label(_page_root, "JOGAR SOZINHO", Rect2(84, 795, 445, 28), 17, MUTED, true)

	_button(_page_root, "DUELO CONTRA BOT", Rect2(80, 839, 460, 72), func():
		_map_mode = "duel"
		_show_page("maps"), false, 25)
	_queue_focus(first)


func _build_host() -> void :
	_title.text = "CRIAR SALA"
	_label(_page_root, "Abra uma sala e convide até três pessoas pelo endereço.", Rect2(80, 328, 460, 85), 23, MUTED)
	_label(_page_root, "PORTA", Rect2(84, 461, 450, 28), 18, INK, true)
	_port = _field(Rect2(80, 506, 460, 66), str(UserSettings.get_value("network", "port", NetworkSession.DEFAULT_PORT)))
	_port.max_length = 5
	_port.text_submitted.connect( func(_value: String): _create_room())
	_button(_page_root, "ABRIR SALA", Rect2(80, 608, 460, 86), _create_room, true, 30)
	_note = _label(_page_root, "", Rect2(84, 730, 450, 150), 21, MUTED)
	_queue_focus(_port)


func _build_join() -> void :
	_title.text = "ENTRAR EM SALA"
	_label(_page_root, "Peça o endereço a quem criou a sala.", Rect2(80, 328, 460, 72), 23, MUTED)
	_label(_page_root, "ENDEREÇO", Rect2(84, 426, 450, 28), 18, INK, true)
	_address = _field(Rect2(80, 467, 460, 66), str(UserSettings.get_value("network", "address", "")))
	_address.placeholder_text = "Ex.: 192.168.1.20"
	_address.max_length = 300
	_address.text_submitted.connect( func(_value: String): _join_room())
	_label(_page_root, "PORTA", Rect2(84, 557, 450, 28), 18, INK, true)
	_port = _field(Rect2(80, 598, 460, 66), str(UserSettings.get_value("network", "port", NetworkSession.DEFAULT_PORT)))
	_port.max_length = 5
	_port.text_submitted.connect( func(_value: String): _join_room())
	_button(_page_root, "CONECTAR", Rect2(80, 705, 460, 86), _join_room, true, 30)
	_note = _label(_page_root, "Pode colar o endereço completo, incluindo a porta.", Rect2(84, 822, 450, 98), 20, MUTED)
	_queue_focus(_address)


func _in_room() -> bool:
	return page in ["room", "arena", "versus", "maps"]


func _layout_chrome() -> void :
	var full: = _in_room()
	for piece: Control in _chrome_pieces(): ASSEMBLY.cancel(piece)
	if stage != null:
		stage.visible = full
		if not full and stage.has_method("cancel_arrival"): stage.call("cancel_arrival")
		stage.position = Vector2.ZERO if full else Vector2(580, 170)
		stage.size = PAPER if full else Vector2(1280, 730)
		if stage.has_method("set_compact"): stage.call("set_compact", not full)
		if stage.has_method("set_arena"):
			var map: = _current_map()
			stage.call("set_arena", String(map.get("name", "ARENA ORIGINAL")), String(map.get("image", "res://assets/menu/arena_original.png")))
	_logo.position = Vector2(58, 52) if full else Vector2(78, 60)
	_logo.size = Vector2(276, 58) if full else Vector2(390, 78)
	_title.position = Vector2(540, 45) if full else Vector2(76, 239)
	_title.size = Vector2(840, 64) if full else Vector2(490, 74)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if full else HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 42 if full else 52)
	_eyebrow.position = Vector2(540, 114) if full else Vector2(80, 198)
	_eyebrow.size = Vector2(840, 30) if full else Vector2(480, 30)
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if full else HORIZONTAL_ALIGNMENT_LEFT
	_tagline.visible = not full
	_mode_label.text = ("TREINO" if _map_mode == "practice" else "DUELO CONTRA BOT") if page == "maps" else "FFA / ATÉ 4 JOGADORES"
	_mode_label.position = Vector2(1420, 70) if full else Vector2(1380, 139)
	_mode_label.size.x = 430
	_mode_label.add_theme_font_size_override("font_size", 19 if full else 24)
	_back.position = Vector2(60, 978) if full else Vector2(80, 976)
	_back.size = Vector2(260, 64) if full else Vector2(210, 58)
	_key_hint.visible = not full
	for i in _names.size():

		_names[i].visible = full and (page != "maps" or i + 1 == Session.local_player_id)
		_player_states[i].visible = full and page != "maps"
		_names[i].add_theme_color_override("font_color", ACCENT if i + 1 == Session.local_player_id else INK)
	_chrome.queue_redraw()


func _build_room() -> void :
	_title.text = "ESCOLHA SUA COR"
	_eyebrow.text = "01 / PREPARE SEU ROBÔ"
	_build_color_picker()
	_status = _label(_page_root, "Abrindo sala…", Rect2(60, 925, 500, 32), 20, INK)
	_addresses = OptionButton.new()
	_addresses.position = Vector2(360, 990)
	_addresses.size = Vector2(410, 50)
	_style_input(_addresses)
	_addresses.add_theme_font_size_override("font_size", 20)
	_page_root.add_child(_addresses)
	_button(_page_root, "COPIAR", Rect2(785, 990, 150, 50), _copy_address, false, 18)
	_ready_button = _button(_page_root, "ESTOU PRONTO", Rect2(1410, 972, 450, 74), _toggle_ready, true, 27)
	_retry_button = _button(_page_root, "TENTAR NOVAMENTE", Rect2(1410, 972, 450, 74), _retry, true, 24)
	_retry_button.visible = false
	_note = _label(_page_root, "Escolha uma cor livre e confirme seu robô.", Rect2(610, 925, 1250, 32), 19, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_back.text = "SAIR DA SALA"
	_refresh_addresses()
	_focus_color_choice.call_deferred()


func _focus_color_choice() -> void :
	if page != "room": return
	var selected: = Session.lobby.color_for_player(Session.local_player_id)
	for button: Button in _color_buttons:
		if not button.disabled and int(button.get_meta("lobby_color_rgb24")) == selected:
			_focus_control(button)
			return
	for button: Button in _color_buttons:
		if not button.disabled:
			_focus_control(button)
			return
	_focus_control(_back)


func _build_color_picker() -> void :
	var config: = RobotBody.config()
	var palette: Array = config["player_colors"]
	var names: Array = config["player_color_names"]
	_color_hint = _label(_page_root, "ESCOLHA UMA COR", Rect2(700, 661, 520, 28), 18, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_color_hint.add_theme_color_override("font_outline_color", Color("#121215"))
	_color_hint.add_theme_constant_override("outline_size", 3)
	for index in palette.size():
		var button: = COLOR_BUTTON.new() as Button
		button.name = "ColorOption%d" % index
		button.set_meta("lobby_color_index", index)
		button.set_meta("lobby_color_rgb24", RobotColor.to_rgb24(Color(String(palette[index]))))
		button.position = Vector2(730 + (index % 8) * 58.0, 700 + (index / 8) * 56.0)
		button.size = Vector2(52, 50)
		button.set("swatch", Color(String(palette[index])))
		button.set("color_name", String(names[index]))
		button.set("ui_font", _bold)
		button.set("compact", true)
		_page_root.add_child(button)
		button.pressed.connect(_select_color.bind(index))
		button.mouse_entered.connect( func():
			if not button.disabled: button.grab_focus()
			button.queue_redraw())
		button.mouse_exited.connect(button.queue_redraw)
		button.focus_entered.connect( func():
			button.queue_redraw()
			_sound(false))
		button.focus_exited.connect(button.queue_redraw)
		_color_buttons.append(button)
	_release_color_button = _button(_page_root, "LIBERAR COR", Rect2(842, 824, 236, 52), _release_color, false, 19)
	_build_paint_choice()



func _build_paint_choice() -> void :
	var hint: = _label(_page_root, "SUA PINTURA", Rect2(1222, 672, 320, 28), 18, INK, true)
	hint.add_theme_color_override("font_outline_color", Color("#121215"))
	hint.add_theme_constant_override("outline_size", 3)
	_paint_choice = OptionButton.new()
	_paint_choice.name = "PaintChoice"
	_paint_choice.position = Vector2(1222, 704)
	_paint_choice.size = Vector2(320, 52)
	_style_input(_paint_choice)
	_paint_choice.add_theme_font_size_override("font_size", 20)
	_page_root.add_child(_paint_choice)
	var slots: = PaintSlots.load_from()
	_paint_choice.add_item("SEM PINTURA")
	for i in PaintSlots.count():
		_paint_choice.add_item(slots.names[i] if not slots.paints[i].is_empty() else "%s (VAZIO)" % slots.names[i])
		_paint_choice.set_item_disabled(i + 1, slots.paints[i].is_empty())
	var remembered: = int(UserSettings.get_value("paint", "lobby_slot", -1))
	if remembered < 0 or remembered >= PaintSlots.count() or slots.paints[remembered].is_empty(): remembered = -1
	_paint_choice.select(remembered + 1)
	_paint_choice.item_selected.connect( func(index: int) -> void :
		UserSettings.set_value("paint", "lobby_slot", index - 1)
		_sound(true)
		_send_paint_choice())



func _send_paint_choice() -> void :
	if not is_instance_valid(_paint_choice) or not Session.lobby.synchronized: return
	var index: = _paint_choice.selected - 1
	var bytes: = PackedByteArray()
	if index >= 0:
		bytes = PaintSlots.load_from().paints[index].encode()
	if Session.lobby.set_local_paint(bytes):
		_paint_sent_generation = Session.generation


func _update_paints() -> void :
	if stage == null: return
	var paints: = {}
	if _in_room():
		for id in range(1, NetworkSession.MAX_PLAYERS + 1): paints[id] = Session.lobby.paint_for_player(id)
	stage.call("set_player_paints", paints)


func _color_name(rgb24: int) -> String:
	if rgb24 < 0: return "SEM COR"
	var config: = RobotBody.config()
	for i in (config["player_colors"] as Array).size():
		if RobotColor.to_rgb24(Color(String(config["player_colors"][i]))) == rgb24:
			return String(config["player_color_names"][i])
	return "#%06X" % rgb24


func _select_color(index: int) -> void :
	var rgb24: = int(_color_buttons[index].get_meta("lobby_color_rgb24"))
	var requested: = -1 if Session.lobby.color_for_player(Session.local_player_id) == rgb24 else rgb24
	_request_color(requested)


func _release_color() -> void :
	_request_color(-1)


func _request_color(requested: int) -> bool:
	if Session.lobby.set_local_color(requested):
		_color_request_pending = requested
		_sound(true)
		_refresh_room()
		return true
	return false


func _refresh_color_options() -> void :
	var local_id: = Session.local_player_id
	var selected: = Session.lobby.color_for_player(local_id)
	var connected: = Session.is_online() and Session.state in ["hosting", "ready"] and Session.lobby.synchronized
	if not connected or selected == _color_request_pending:
		_color_request_pending = -2
	elif _color_request_pending >= 0 and Session.lobby.color_owner(_color_request_pending) > 0:
		_color_request_pending = -2
		_feedback_left = 3.0
		_error("Outro jogador escolheu essa cor primeiro. Escolha uma cor livre.")
	for index in _color_buttons.size():
		var button: = _color_buttons[index]
		var owner: = Session.lobby.color_owner(int(button.get_meta("lobby_color_rgb24")))
		button.set("owner_id", owner)
		button.set("local_id", local_id)
		button.disabled = not connected or _locked or Session.lobby.transition_locked or _color_request_pending != -2 or (owner > 0 and owner != local_id)
		var color_name: = String(button.get("color_name"))
		var state: = "Sua cor. Clique para liberar." if owner == local_id else ("Reservada por P%d." % owner if owner > 0 else "Livre. Clique para escolher.")
		button.text = "%s — %s" % [color_name, state]
		button.tooltip_text = button.text
		button.queue_redraw()
	if _color_hint != null:
		_color_hint.text = "SUA COR: " + _color_name(selected) if selected >= 0 else "ESCOLHA UMA COR"
		if _color_request_pending != -2: _color_hint.text = "Confirmando sua escolha…"
	var blocked: = not connected or _locked or Session.lobby.transition_locked or _color_request_pending != -2
	_release_color_button.disabled = blocked or selected < 0


func _build_arena() -> void :
	_title.text = "ESCOLHA A ARENA"
	_eyebrow.text = "02 / CONFIRME O DESTINO"
	_status = _label(_page_root, "", Rect2(60, 925, 500, 32), 21, INK, true)
	_note = _label(_page_root, "Todos confirmam para entrar na partida.", Rect2(620, 925, 1240, 32), 19, MUTED, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_ready_button = _button(_page_root, "CANCELAR PRONTO", Rect2(1035, 972, 345, 74), _toggle_ready, false, 25)
	_start_button = _button(_page_root, "CONFIRMAR ARENA", Rect2(1410, 972, 450, 74), _vote_arena, true, 27)
	_start_button.disabled = true
	_back.text = "VOLTAR À SALA"
	_queue_focus(_back)



func _build_maps() -> void :
	var maps: = _maps()
	_map_index = clampi(_map_index, 0, maxi(0, maps.size() - 1))
	_title.text = "ESCOLHA O MAPA"
	_eyebrow.text = "TREINO / QUALQUER MAPA" if _map_mode == "practice" else "JOGAR SOZINHO"

	_status = _label(_page_root, "", Rect2(60, 925, 620, 32), 21, INK, true)
	_start_button = _button(_page_root, "TREINAR NESTE MAPA" if _map_mode == "practice" else "JOGAR NESTE MAPA", 
		Rect2(1410, 972, 450, 74), _confirm_map, true, 25)
	_back.text = "VOLTAR"
	_refresh_map()
	_queue_focus(_start_button if maps.size() > 0 else _back)


func _step_map(delta: int) -> void :
	var maps: = _maps()
	if maps.is_empty() or page != "maps": return
	_map_index = posmod(_map_index + delta, maps.size())
	_sound(false)
	_refresh_map()


func _refresh_map() -> void :
	var map: = _current_map()
	if _status != null: _status.text = String(map.get("name", ""))
	if stage != null and stage.has_method("set_arena"):
		stage.call("set_arena", String(map.get("name", "")), String(map.get("image", "")))


func _confirm_map() -> void :
	if page != "maps" or _closing: return
	Arena.next_map = String(_current_map().get("id", "original"))
	Arena.play_intro = true
	_sound(true)
	offline_requested.emit(_map_mode)


func _maps() -> Array:
	if _map_list.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAPS_PATH))
		_map_list = (parsed as Dictionary).get("maps", []) if parsed is Dictionary else []
	return _map_list


func _current_map() -> Dictionary:
	var maps: = _maps()
	return maps[clampi(_map_index, 0, maps.size() - 1)] if not maps.is_empty() else {}



func _show_voted_map() -> void :
	var maps: = _maps()
	if maps.is_empty(): return
	_map_index = clampi(int(Session.lobby.map_votes.get(Session.local_player_id, 0)), 0, maps.size() - 1)
	_refresh_map()


func _build_versus() -> void :
	_title.text = "IMAGINAÇÃO EM JOGO"
	var chosen: = Session.lobby.chosen_map
	var maps: = _maps()
	_eyebrow.text = "03 / " + (String((maps[chosen] as Dictionary).get("name", "ARENA")) if chosen >= 0 and chosen < maps.size() else "ARENA ORIGINAL")
	_note = _label(_page_root, "Entrando na arena…", Rect2(560, 950, 800, 55), 27, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_back.disabled = true


func _create_room() -> void :
	var port: = _validated_port()
	if port == 0: return
	_room_port = port
	_host_intent = true
	UserSettings.set_value("network", "port", port)
	_show_page("room")
	Session.start_host(port, "0.0.0.0")
	_refresh_addresses()
	_refresh_room()


func _join_room() -> void :
	var target: = _address.text.strip_edges()
	var parts: = target.rsplit(":", true, 1)
	if parts.size() == 2 and parts[1].is_valid_int() and (target.count(":") == 1 or target.begins_with("[")):
		if parts[1].to_int() < 1 or parts[1].to_int() > 65535:
			_error("Use uma porta entre 1 e 65535.")
			_address.grab_focus()
			return
		target = parts[0].trim_prefix("[").trim_suffix("]")
		_port.text = parts[1]
	if target.is_empty() or target.length() > 253 or target.contains(" ") or target.contains("/"):
		_error("Informe o IP ou o nome do computador que abriu a sala.")
		_address.grab_focus()
		return
	var port: = _validated_port()
	if port == 0: return
	_last_target = target
	_room_port = port
	_host_intent = false
	UserSettings.set_value("network", "address", target)
	UserSettings.set_value("network", "port", port)
	_show_page("room")
	Session.start_client(target, port)
	_refresh_addresses()
	_refresh_room()


func _validated_port() -> int:
	var value: = _port.text.strip_edges()
	if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > 65535:
		_error("Use uma porta entre 1 e 65535.")
		_port.grab_focus()
		return 0
	return value.to_int()


func _refresh_addresses() -> void :
	if _addresses == null: return
	_addresses.clear()
	if _host_intent:
		var local_ips: = PackedStringArray()
		for ip: String in IP.get_local_addresses():
			if ip.count(".") == 3 and not ip.begins_with("127.") and not ip.begins_with("169.254."):
				local_ips.append(ip)
		if local_ips.is_empty(): local_ips.append("127.0.0.1")
		for ip in local_ips: _addresses.add_item("%s:%d" % [ip, _room_port])
	else:
		_addresses.add_item("%s:%d" % [_last_target, _room_port])
	_addresses.disabled = _addresses.item_count <= 1


func _copy_address() -> void :
	if _addresses == null or _addresses.item_count == 0: return
	DisplayServer.clipboard_set(_addresses.get_item_text(maxi(_addresses.selected, 0)))
	_note.text = "Endereço copiado. Envie para seus convidados."
	_note.add_theme_color_override("font_color", INK)
	_feedback_left = 3.0


func _toggle_ready() -> void :
	Session.lobby.set_local_ready( not bool(Session.lobby.ready_players.get(Session.local_player_id, false)))


func _vote_arena() -> void :
	Session.lobby.set_local_vote( not bool(Session.lobby.vote_players.get(Session.local_player_id, false)))


func _retry() -> void :
	if _host_intent: Session.start_host(_room_port, "0.0.0.0")
	else: Session.start_client(_last_target, _room_port)
	_refresh_room()


func _on_session_changed() -> void :
	if not is_open: return
	_refresh_room()
	_update_players()


func _refresh_room() -> void :
	if not is_open: return
	if _locked and page == "versus" and not _launch_valid():
		cancel_launch()
		return
	if _in_room() and not _locked:
		if Session.lobby.phase == "arena" and page != "arena":
			_show_page("arena")
			_sound(true)
			return
		if Session.lobby.phase == "characters" and page == "arena":
			_show_page("room")
			return
	_update_players()
	if page == "arena":
		var voted: = bool(Session.lobby.vote_players.get(Session.local_player_id, false))
		var was_locked: = _start_button.disabled
		_start_button.disabled = _locked or Session.lobby.transition_locked
		if was_locked and not _start_button.disabled: _queue_focus(_start_button)
		_start_button.text = "RETIRAR VOTO" if voted else "CONFIRMAR ARENA"
		_start_button.set("primary", not voted)
		_ready_button.disabled = _locked
		_back.disabled = _locked
		_back.text = "VOLTAR À SALA"
		_note.text = "Preparando a seleção…" if Session.lobby.transition_locked else ("Voto confirmado. Esperando os outros jogadores…" if voted else "Clique no mapa e confirme. O mais votado vence.")
		_show_voted_map()
		return
	if page != "room" or _status == null: return
	var failed: = Session.state in ["failed", "disconnected"]
	var connecting: = Session.state in ["connecting", "authenticating"]
	var local_ready: = bool(Session.lobby.ready_players.get(Session.local_player_id, false))
	var color_selected: = Session.lobby.color_for_player(Session.local_player_id) >= 0
	var count: = Session.player_ids().size()
	_refresh_color_options()
	if is_instance_valid(_paint_choice):
		_paint_choice.disabled = connecting or failed or _locked or local_ready or not Session.lobby.synchronized or Session.lobby.transition_locked
		if Session.lobby.synchronized and _paint_sent_generation != Session.generation and not local_ready: _send_paint_choice()
	_status.text = "%d / 4 CONECTADOS" % count if Session.state in ["hosting", "ready"] else Session.status_text()
	_status.add_theme_color_override("font_color", Color("#ffab83") if failed else INK)
	_ready_button.visible = not failed
	_ready_button.disabled = connecting or _locked or (Session.lobby.transition_locked and not local_ready) or not Session.lobby.synchronized or not color_selected or _color_request_pending != -2
	_ready_button.text = "CANCELAR PRONTO" if local_ready else "ESTOU PRONTO"
	_ready_button.set("primary", not local_ready)
	_retry_button.visible = failed
	_back.text = "CANCELAR" if connecting else "SAIR DA SALA"
	_back.disabled = _locked
	if _feedback_left <= 0:
		_note.add_theme_color_override("font_color", MUTED)
		if failed: _note.text = "A conexão terminou. Tente novamente ou volte."
		elif connecting: _note.text = "Conferindo conexão e versão do jogo…"
		elif Session.lobby.transition_locked: _note.text = "Voltando aos totens…"
		elif Session.lobby.all_ready(): _note.text = "Todos prontos! Abrindo a seleção da arena…"
		elif not color_selected: _note.text = "Escolha uma cor livre. Ela ficará reservada para você."
		elif count < 2: _note.text = "Aguardando alguém entrar. A sala comporta quatro jogadores."
		else: _note.text = "Quando todos estiverem prontos, a seleção da arena abrirá."


func _update_players() -> void :
	if stage == null: return
	var occupied: = {}
	var local_id: = Session.local_player_id if _in_room() else 1
	for id in range(1, NetworkSession.MAX_PLAYERS + 1):
		occupied[id] = _in_room() and Session.peer_for_player(id) > 0
	stage.call("set_occupancy", local_id, occupied)
	stage.call("set_readiness", Session.lobby.ready_players if _in_room() else {})
	stage.call("set_player_colors", Session.lobby.selected_colors if _in_room() else {})
	_update_paints()
	stage.call("set_presentation_seed", Session.lobby.presentation_seed if _in_room() else 0)
	for i in _names.size():
		var id: = i + 1
		var present: = bool(occupied.get(id, false))
		var ready: = _in_room() and bool(Session.lobby.ready_players.get(id, false))
		_names[i].text = ("VOCÊ" if id == local_id else ("ANFITRIÃO" if id == 1 else "JOGADOR %d" % id)) if present else "VAGA LIVRE"
		var rgb24: = Session.lobby.color_for_player(id) if _in_room() else -1
		var color_name: = _color_name(rgb24)
		_player_states[i].text = (("PRONTO · " if ready else "") + color_name) if present else "AGUARDANDO CONEXÃO"
		if page == "arena" and present:
			var vote_maps: = _maps()
			var picked: = int(Session.lobby.map_votes.get(id, 0))
			var map_name: = String((vote_maps[picked] as Dictionary).get("name", "")) if picked >= 0 and picked < vote_maps.size() else ""
			_player_states[i].text = ("VOTOU · " + map_name) if bool(Session.lobby.vote_players.get(id, false)) else "ESCOLHENDO ARENA"
		_player_states[i].add_theme_color_override("font_color", ACCENT if ready else MUTED)


func _on_match_requested() -> void :
	if not is_open or _locked: return
	_locked = true
	_launch_generation = Session.generation
	_launch_epoch = Session.lobby.epoch
	_launch_emitted = false
	_show_page("versus")
	_sound(true)


func _launch_valid() -> bool:
	return Session.is_online() and Session.state == "ready" and Session.lobby.launch_committed\
	and Session.generation == _launch_generation and Session.lobby.epoch == _launch_epoch


func cancel_launch() -> void :
	_locked = false
	_launch_emitted = false
	_launch_generation = -1
	_launch_epoch = -1
	_show_page("room")
	if _note != null:
		_note.text = "A conexão mudou. Confira a sala antes de iniciar de novo."


func _go_back() -> void :
	if _locked or _closing: return
	if page == "arena":
		Session.lobby.request_characters()
	elif page == "room":
		Session.start_offline()
		_show_page("home")
	elif page != "home" and (page != "maps" or _map_mode == "duel"): _show_page("home")
	else:
		_closing = true
		is_open = false
		set_process_unhandled_input(false)
		ASSEMBLY.retire(_page_root)
		for piece: Control in _chrome_pieces(): ASSEMBLY.piece(piece, 0, true)
		_back.disabled = true
		_animate_shell(0.0, 0.26)
		if _visibility_tween != null and _visibility_tween.is_valid(): _visibility_tween.kill()
		_visibility_tween = create_tween()
		_visibility_tween.tween_property(self, "modulate:a", 0.0, 0.27)
		_visibility_tween.tween_callback( func():
			if not _closing: return
			_closing = false
			visible = false
			closed.emit())




func _input(event: InputEvent) -> void :
	if not is_open or page not in ["maps", "arena"] or _closing or stage == null or not stage.has_method("map_at"):
		return
	if page == "arena" and (_locked or Session.lobby.transition_locked or bool(Session.lobby.vote_players.get(Session.local_player_id, false))):
		return
	if event is InputEventMouseMotion:
		stage.call("hover_map", int(stage.call("map_at", (event as InputEventMouse).position)))
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed\
	and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var index: = int(stage.call("map_at", (event as InputEventMouse).position))
		if index >= 0 and index < _maps().size():
			if index != _map_index:
				_map_index = index
				_sound(false)
				_refresh_map()

				if page == "arena": Session.lobby.set_local_map(index)
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void :
	if is_open and event.is_action_pressed("ui_cancel"):
		_go_back()
		get_viewport().set_input_as_handled()
	elif is_open and page == "maps" and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_step_map(-1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()



func _error(message: String) -> void :
	if _note != null:
		_note.text = message
		_note.add_theme_color_override("font_color", Color("#ffab83"))


func _focus_control(control: Control) -> void :
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree()\
	and control.focus_mode != Control.FOCUS_NONE and not (control is BaseButton and (control as BaseButton).disabled):
		control.grab_focus()


func _queue_focus(control: Control) -> void :


	_focus_instance.call_deferred(control.get_instance_id())


func _focus_instance(instance_id: int) -> void :
	var control: = instance_from_id(instance_id)
	if control is Control: _focus_control(control)


func _label(parent: Control, value: String, rect: Rect2, fs: int, color: Color, bold: = false, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label: = Label.new()
	label.text = value
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_override("font", _bold if bold else _font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Control, value: String, rect: Rect2, action: Callable, primary: = false, fs: = 28) -> Button:
	var button: = BUTTON.new() as Button
	button.text = value
	button.position = rect.position
	button.size = rect.size
	button.set("primary", primary)
	button.set("ui_font", _bold)
	button.set("text_size", fs)
	parent.add_child(button)
	button.pressed.connect( func():
		if not is_open or _closing: return
		_sound(true)
		action.call())
	button.mouse_entered.connect( func():
		if not button.disabled: button.grab_focus())
	button.focus_entered.connect( func(): _sound(false))
	return button


func _field(rect: Rect2, value: String) -> LineEdit:
	var field: = LineEdit.new()
	field.position = rect.position
	field.size = rect.size
	field.text = value
	field.select_all_on_focus = true
	_style_input(field)
	_page_root.add_child(field)
	return field


func _style_input(control: Control) -> void :
	control.add_theme_font_override("font", _font)
	control.add_theme_font_size_override("font_size", 24)
	control.add_theme_color_override("font_color", INK)
	control.add_theme_color_override("font_disabled_color", INK)
	control.add_theme_color_override("font_placeholder_color", Color("#77757a"))
	control.add_theme_color_override("caret_color", ACCENT)
	control.add_theme_color_override("selection_color", Color("#8a401e"))
	for state in ["normal", "hover", "pressed", "read_only", "disabled", "focus"]:
		var box: = StyleBoxFlat.new()
		box.bg_color = Color("#161619")
		box.border_color = ACCENT if state == "focus" else Color("#555258")
		box.set_border_width_all(2 if state == "focus" else 1)
		box.content_margin_left = 17
		box.content_margin_right = 17
		control.add_theme_stylebox_override(state, box)


func _sound(pressed: bool) -> void :
	if _ui_sound == null or not is_open: return
	UiSound.play(_ui_sound, "confirm" if pressed else "navigate")


func _fit() -> void :
	_scale = minf(size.x / PAPER.x, size.y / PAPER.y)
	_origin = (size - PAPER * _scale) * 0.5
	if _canvas != null:
		_canvas.scale = Vector2.ONE * _scale
		_canvas.position = _origin
	queue_redraw()


func _process(delta: float) -> void :
	var previous_age: = _rebuild_age
	_rebuild_age += delta
	if _closing: queue_redraw()
	if not is_open: return
	for landing in [0.18, 0.32]:
		if previous_age < landing and _rebuild_age >= landing:
			_assembly_sound.pitch_scale = 1.4 if landing < 0.2 else 1.8
			_assembly_sound.play()
	_elapsed += delta
	_presentation_age += delta
	if _in_room() and stage != null and stage.has_method("get_slot_screen_position"):
		for i in _names.size():
			var at: Vector2 = stage.call("get_slot_screen_position", i + 1)
			_names[i].position = Vector2(clampf(at.x - 140.0, 20.0, 1620.0), 849.0 if page == "room" else clampf(at.y, 170.0, 839.0))
			_player_states[i].position = _names[i].position + Vector2(0, 35)
	if page == "versus" and not _launch_emitted:
		if not _launch_valid():
			cancel_launch()
		elif _presentation_age >= VERSUS_S:
			_launch_emitted = true
			match_requested.emit()
	if _feedback_left > 0:
		_feedback_left -= delta
		if _feedback_left <= 0: _refresh_room()
	queue_redraw()


func _draw_chrome() -> void :
	if not _in_room(): return
	_chrome.draw_rect(Rect2(0, 0, 1920, 158), Color(0.075, 0.075, 0.085, 0.96))
	_chrome.draw_rect(Rect2(0, 912, 1920, 168), Color(0.075, 0.075, 0.085, 0.96))
	_chrome.draw_line(Vector2(60, 911), Vector2(1860, 911), Color("#555057"), 1.0)
	_chrome.draw_line(Vector2(60, 910), Vector2(320, 910), ACCENT, 3.0)
	_chrome.draw_polyline(PackedVector2Array([Vector2(0, 146), Vector2(352, 146), Vector2(378, 120)]), ACCENT, 4.0, true)


func _draw() -> void :
	if not is_open and not _closing: return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.028, 0.029, 0.035, 0.76))
	draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	if _shell_amount <= 0.001:
		draw_set_transform(Vector2.ZERO)
		return
	for index in _panel_pieces.size():
		var amount: = clampf((_shell_amount - index * 0.035) / (1.0 - index * 0.035), 0.0, 1.0)
		var offset: = Vector2(-700.0 * pow(1.0 - amount, 2.0), (index - 3) * 10.0 * (1.0 - amount))
		draw_set_transform(_origin + offset * _scale, 0, Vector2.ONE * _scale)
		var colors: = PackedColorArray()
		for p in _panel_pieces[index]: colors.append(Color("#2a2a2d").lerp(Color("#19191b"), p.y / 1080.0))
		draw_polygon(_panel_pieces[index], colors)
	draw_set_transform(_origin, 0, Vector2.ONE * _scale)
	var accent: = Color(ACCENT, _shell_amount)
	draw_polyline(PackedVector2Array([Vector2(666, 0), Vector2(620, 49), Vector2(620, 183)]), accent, 6, true)
	draw_polyline(PackedVector2Array([Vector2(592, 366), Vector2(592, 555), Vector2(582, 565)]), accent, 4, true)
	draw_line(Vector2(80, 954), Vector2(520, 954), Color(0.27, 0.26, 0.28, _shell_amount), 1.0)
	draw_line(Vector2(750, 970), Vector2(1850, 970), Color(1, 1, 1, 0.12 * _shell_amount), 1.0)
	draw_set_transform(Vector2.ZERO)


func _prepare_panel_pieces() -> void :
	var panel: = PackedVector2Array([Vector2(0, 0), Vector2(660, 0), Vector2(606, 54), Vector2(606, 330), Vector2(578, 358), Vector2(578, 940), Vector2(540, 978), Vector2(540, 1080), Vector2(0, 1080)])
	for index in 7:
		var top: = float(index) * 1080.0 / 7.0
		var bottom: = float(index + 1) * 1080.0 / 7.0
		var slice: = PackedVector2Array([Vector2(0, top), Vector2(700, top), Vector2(700, bottom), Vector2(0, bottom)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(panel, slice): _panel_pieces.append(piece)
