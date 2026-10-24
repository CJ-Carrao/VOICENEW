extends CanvasLayer

var panel: PanelContainer
var entries: VBoxContainer
var catalog: Dictionary = {}
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var saved_player: Node
var previous_input := true
var previous_paused := false
var active_group := "Animais"


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/chaos_catalog.json"))
	_build()
	for argument in OS.get_cmdline_user_args():
		if argument == "--catalogo":
			while Forge.world == null or _world_loading():
				await get_tree().create_timer(0.1).timeout
			toggle()


func _style(color: Color, border: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	if border:
		style.border_width_left = 3
		style.border_color = Color("#ed782f")
	return style


func _text(value: String, size: int, color: Color = Color("#e6e0ce")) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _build() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/oxanium/Oxanium-Variable.ttf")
	theme.default_font_size = 18
	theme.set_stylebox("normal", "Button", _style(Color("#3e4a53")))
	theme.set_stylebox("hover", "Button", _style(Color("#76513a")))
	theme.set_stylebox("pressed", "Button", _style(Color("#ba6532")))
	panel = PanelContainer.new()
	panel.theme = theme
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_top = 32
	panel.offset_right = -40
	panel.offset_bottom = -32
	panel.add_theme_stylebox_override("panel", _style(Color("#202a35"), true))
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _text("PACOTE CAOS  /  %d CRIAÇÕES" % catalog.creations.size(), 30)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "FECHAR  [F2 / ESC]"
	close.pressed.connect(toggle)
	header.add_child(close)
	var help := _text("Tenha matéria. Segure V, fale o pedido e solte. T abre o console de texto.", 18, Color("#c6bda8"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)
	var tabs := GridContainer.new()
	tabs.columns = 6
	content.add_child(tabs)
	for pair in [["ANIMAIS", "Animais"], ["DINOS", "Dinossauros"], ["GRANADAS", "Granadas de criaturas"], ["BOMBAS", "Bombas especiais"], ["ARMAS", "Armas especiais"], ["ESPAÇO", "Espaço"], ["JUJUTSU", "Jujutsu"], ["DEFESAS", "Defesas"], ["ECOLOGIA", "Ecologia"], ["COMBINAR", "Combinações"]]:
		var tab := Button.new()
		tab.text = pair[0]
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_populate.bind(pair[1]))
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 9)
	scroll.add_child(entries)
	_populate(active_group)
	panel.hide()


func _populate(group: String) -> void:
	active_group = group
	for child in entries.get_children():
		entries.remove_child(child)
		child.queue_free()
	var list: Array = catalog.get("combinations", []) if group == "Combinações" else catalog.creations
	for entry in list:
		if group != "Combinações" and entry.group != group:
			continue
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(Color("#2c3945"), true))
		entries.add_child(card)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		card.add_child(row)
		row.add_child(_text(String(entry.name).to_upper(), 22))
		if entry.has("base_cost"):
			row.add_child(_text("Matéria base: %.0f  /  combinações e repetição alteram o custo" % float(entry.base_cost), 16, Color("#b3c1c7")))
		var description := _text(entry.effect, 17, Color("#c5c9c5"))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(description)
		row.add_child(_text("Diga: “%s”" % entry.phrase, 17, Color("#e8ab70")))


func _world_loading() -> bool:
	return Forge.world != null and (bool(Forge.world.get("_waiting_world")) or not Forge.world.arena.is_world_ready() or String(Forge.world.state) == "map_intro")


func toggle() -> void:
	if not panel.visible and _world_loading():
		return
	if panel.visible:
		panel.hide()
		get_tree().paused = previous_paused
		Input.mouse_mode = previous_mouse
		if is_instance_valid(saved_player):
			saved_player.set("input_enabled", previous_input)
		saved_player = null
	else:
		previous_mouse = Input.mouse_mode
		previous_paused = get_tree().paused
		panel.show()
		if not Session.is_online():
			get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if Forge.world != null and is_instance_valid(Forge.world.player):
			saved_player = Forge.world.player
			previous_input = bool(saved_player.get("input_enabled"))
			saved_player.set("input_enabled", false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2 or (panel.visible and event.keycode == KEY_ESCAPE):
			toggle()
			get_viewport().set_input_as_handled()
		elif panel.visible and event.keycode not in [KEY_TAB, KEY_ENTER, KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
