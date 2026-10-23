class_name VoiceCalibration
extends Control








signal finished

const PHRASES_PATH: = "res://tests/voice_calibration.json"
const DATASET_ROOT: = "user://voice_dataset"
const PANEL_WIDTH: = 820.0

const AUTO_NEXT_MS: = 1100

const MAX_ATTEMPTS: = 3
const COLOR_OK: = "#7be08f"
const COLOR_BAD: = "#ff7070"
const COLOR_MUTED: = "#9aa3b2"
const COLOR_EXTRA: = "#ffa45c"

var voice: VoiceInput

var folder: String = ""

var _phrases: Array = []
var _index: int = 0
var _attempts: Array[Dictionary] = []

var _phrase_attempts: int = 0

var _auto_next_at: int = 0
var _finished_all: bool = false
var _last_samples: = PackedFloat32Array()

var _counter: Label
var _phrase: Label
var _status: Label
var _heard: RichTextLabel
var _verdict: RichTextLabel
var _help: Label
var _buttons: HBoxContainer
var _summary_buttons: HBoxContainer
var _replay: Button


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade: = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center: = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	center.add_child(panel)
	var box: = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title: = Label.new()
	title.text = "CALIBRAÇÃO DA VOZ (ferramenta de desenvolvimento)"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_counter = _dim("")
	box.add_child(_counter)
	_phrase = Label.new()
	_phrase.add_theme_font_size_override("font_size", 30)
	_phrase.add_theme_color_override("font_color", Color(1, 0.86, 0.45))
	_phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phrase.custom_minimum_size = Vector2(0, 84)
	_phrase.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(_phrase)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 18)
	box.add_child(_status)
	_heard = _rich()
	box.add_child(_heard)
	_verdict = _rich()
	box.add_child(_verdict)
	_help = _dim("")
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_help)

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_buttons)
	_buttons.add_child(_button("Próxima frase (Enter)", next_phrase))
	_buttons.add_child(_button("Li errado, apagar (Backspace)", discard_last))
	_replay = _button("Ouvir o que o jogo ouviu", func() -> void : voice.play_back(_last_samples))
	_buttons.add_child(_replay)
	_buttons.add_child(_button("Terminar (Esc)", stop))

	_summary_buttons = HBoxContainer.new()
	_summary_buttons.add_theme_constant_override("separation", 8)
	box.add_child(_summary_buttons)
	_summary_buttons.add_child(_button("Abrir a pasta", func() -> void :
		OS.shell_open(ProjectSettings.globalize_path(_dir()))))
	_summary_buttons.add_child(_button("Calibrar de novo", func() -> void : start(voice)))
	_summary_buttons.add_child(_button("Voltar ao jogo", stop))


func start(voice_input: VoiceInput) -> void :
	if voice != null and voice.utterance_done.is_connected(_on_utterance):
		voice.utterance_done.disconnect(_on_utterance)
	voice = voice_input
	voice.utterance_done.connect(_on_utterance)
	_phrases = (JSON.parse_string(FileAccess.get_file_as_string(PHRASES_PATH)) as Dictionary)["phrases"]
	var stamp: = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	folder = "cal_" + stamp
	_index = 0
	_attempts.clear()
	_phrase_attempts = 0
	_auto_next_at = 0
	_finished_all = false
	_last_samples = PackedFloat32Array()
	_show_phrase()



func stop() -> void :
	if voice != null and voice.utterance_done.is_connected(_on_utterance):
		voice.utterance_done.disconnect(_on_utterance)
	if voice != null and voice.is_private_talk() and voice.state == "listening":
		voice.end_talk()
	if not _attempts.is_empty():
		print("[Voz] calibração salva em ", ProjectSettings.globalize_path(_dir()))
	finished.emit()


func _input(event: InputEvent) -> void :
	if voice == null:
		return
	if event.is_action_pressed("ui_cancel"):
		stop()
	elif _finished_all:
		return
	elif event.is_action_pressed("talk"):
		if voice.begin_talk(true):
			_auto_next_at = 0
	elif event.is_action_released("talk"):
		if voice.is_private_talk():
			voice.end_talk()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo()\
	and (event as InputEventKey).physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		next_phrase()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo()\
	and (event as InputEventKey).physical_keycode == KEY_BACKSPACE:
		discard_last()
	else:
		return
	get_viewport().set_input_as_handled()


func next_phrase() -> void :
	if _finished_all or voice.state in ["listening", "thinking"]:
		return
	_auto_next_at = 0
	_index += 1
	_phrase_attempts = 0
	_last_samples = PackedFloat32Array()
	if _index >= _phrases.size():
		_show_summary()
	else:
		_show_phrase()



func discard_last() -> void :
	if _attempts.is_empty() or voice.state in ["listening", "thinking"]:
		return
	var last: Dictionary = _attempts.back()
	if int(last["phrase"]) != _index or last.get("discarded", false):
		return
	last["discarded"] = true
	if String(last["ignored"]).is_empty():
		_phrase_attempts = maxi(_phrase_attempts - 1, 0)
	_auto_next_at = 0
	_write()
	_heard.text = "[color=%s]Apaguei a última tentativa. Leia de novo.[/color]" % COLOR_MUTED
	_verdict.text = ""


func _process(_delta: float) -> void :
	if voice == null or _finished_all:
		return
	match voice.state:
		"listening":
			_status.text = "🎤 OUVINDO… solte quando terminar"
		"thinking":
			_status.text = "🎤 ENTENDENDO…"
		"warming":
			_status.text = "preparando a voz…"
		"off":
			_status.text = "voz desligada: " + voice.off_reason
		_:
			_status.text = "Segure %s e leia a frase em voz normal, como no jogo." % UserSettings.talk_key_name()
	if _auto_next_at > 0 and Time.get_ticks_msec() >= _auto_next_at:
		next_phrase()


func _show_phrase() -> void :
	var entry: Dictionary = _phrases[_index]
	_counter.text = "Frase %d de %d · leia do seu jeito normal de falar (sem caprichar)" % [_index + 1, _phrases.size()]
	_phrase.text = String(entry["text"])
	_heard.text = ""
	_verdict.text = ""
	_help.text = "Errou? Fale de novo a mesma frase (até %d vezes) ou Enter pra seguir. Gaguejou ou leu outra coisa? Backspace apaga." % MAX_ATTEMPTS
	_buttons.visible = true
	_summary_buttons.visible = false
	_replay.disabled = true


func _on_utterance(info: Dictionary) -> void :
	if not info.get("private", false) or _finished_all:
		return
	var samples: PackedFloat32Array = info["samples"]
	var reason: = String(info["ignored"])
	if samples.is_empty():
		_heard.text = "[color=%s]%s[/color]" % [COLOR_BAD, reason]
		_verdict.text = ""
		return
	_last_samples = samples
	_replay.disabled = false
	var entry: Dictionary = _phrases[_index]
	var expected: = String(entry["text"])
	var heard: = String(info["text"])
	var attempt_number: = _attempts.filter( func(a: Dictionary) -> bool: return int(a["phrase"]) == _index).size() + 1
	var file: = "%02d_%d.wav" % [_index, attempt_number]
	DirAccess.make_dir_recursive_absolute(_dir())
	SpeechEngine.to_wav(samples).save_to_wav(_dir().path_join(file))
	var got: = PhraseParser.parse(heard, Lexicon.data)
	var want: = PhraseParser.parse(expected, Lexicon.data)
	var right: = reason.is_empty() and VoiceScore.same_tree(expected, heard, Lexicon.data)
	_attempts.append({
		"phrase": _index, "group": entry.get("group", ""), "focus": entry.get("focus", []), "expected": expected, 
		"attempt": attempt_number, "file": file, "heard": heard, "ignored": reason, 
		"level": snappedf(float(info["level"]), 0.0001), "seconds": snappedf(float(info["seconds"]), 0.01), 
		"audio_s": snappedf(samples.size() / float(SpeechEngine.SAMPLE_RATE), 0.01), "same_tree": right, 
		"heard_pretty": String(got.get("pretty", "")), "expected_pretty": String(want.get("pretty", "")), 
		"corrections": got.get("corrections", []), "unknown": got.get("unknown_words", []), "discarded": false, 
	})
	_write()
	if not reason.is_empty():
		_heard.text = "[color=%s]%s[/color]" % [COLOR_BAD, reason]
		_verdict.text = ""
		return
	_phrase_attempts += 1
	_heard.text = "Ouvi: “%s”\n%s" % [_escape(heard), _diff(expected, heard)]
	if right:
		_verdict.text = "[color=%s][b]✓ Entendi certo:[/b] %s[/color]" % [COLOR_OK, _escape(String(got["pretty"]))]
		_auto_next_at = Time.get_ticks_msec() + AUTO_NEXT_MS
		return
	var understood: = _escape(String(got["pretty"])) if got["ok"] else "nada"
	var lines: = PackedStringArray(["[color=%s][b]✗ Entendi:[/b] %s[/color]" % [COLOR_BAD, understood], 
		"[color=%s]era pra ser: %s[/color]" % [COLOR_MUTED, _escape(String(want["pretty"]))]])
	for fix: Dictionary in got.get("corrections", []):
		lines.append("[color=%s]o ouvido trocou \"%s\" por \"%s\"[/color]" % [COLOR_MUTED, _escape(str(fix["from"])), _escape(str(fix["to"]))])
	_verdict.text = "\n".join(lines)
	if _phrase_attempts >= MAX_ATTEMPTS:
		_auto_next_at = Time.get_ticks_msec() + AUTO_NEXT_MS * 2




func _diff(expected: String, heard: String) -> String:
	var parts: = PackedStringArray()
	for step: Dictionary in VoiceScore.align_text(expected, heard, Lexicon.data):
		match String(step["op"]):
			"ok":
				parts.append(String(step["hyp"]))
			"sub":
				parts.append("[color=%s]%s[/color] [color=%s][s]%s[/s][/color]" % [COLOR_BAD, step["hyp"], COLOR_MUTED, step["ref"]])
			"del":
				parts.append("[color=%s][s]%s[/s][/color]" % [COLOR_MUTED, step["ref"]])
			"ins":
				parts.append("[color=%s]+%s[/color]" % [COLOR_EXTRA, step["hyp"]])
	return " ".join(parts)


func _show_summary() -> void :
	_finished_all = true
	_auto_next_at = 0
	var firsts: = {}
	var any_right: = {}
	var misses: = {}
	for a: Dictionary in _attempts:
		if a.get("discarded", false) or not String(a["ignored"]).is_empty():
			continue
		var index: = int(a["phrase"])
		if not firsts.has(index):
			firsts[index] = bool(a["same_tree"])
		if a["same_tree"]:
			any_right[index] = true
		for step: Dictionary in VoiceScore.align_text(String(a["expected"]), String(a["heard"]), Lexicon.data):
			if step["op"] == "sub" or step["op"] == "del":
				var key: = "%s → %s" % [step["ref"], step["hyp"] if step["op"] == "sub" else "(sumiu)"]
				misses[key] = int(misses.get(key, 0)) + 1
	var first_right: = firsts.values().count(true)
	var keys: = misses.keys()
	keys.sort_custom( func(x: String, y: String) -> bool: return int(misses[x]) > int(misses[y]))
	_counter.text = "Pronto! %d frases gravadas." % firsts.size()
	_phrase.text = "Certas de primeira: %d de %d (%d%%)" % [first_right, firsts.size(), 
		roundi(100.0 * first_right / maxi(firsts.size(), 1))]
	_status.text = "Certas em alguma tentativa: %d de %d" % [any_right.size(), firsts.size()]
	var lines: = PackedStringArray()
	if not keys.is_empty():
		lines.append("[b]Palavras que mais trocaram:[/b]")
		for key: String in keys.slice(0, 8):
			lines.append("  %s  (%d×)" % [_escape(key), misses[key]])
	_heard.text = "\n".join(lines)
	_verdict.text = "[color=%s]Salvo em %s[/color]" % [COLOR_MUTED, _escape(ProjectSettings.globalize_path(_dir()))]
	_help.text = "Relatório completo e casos pro banco do ouvido: godot --headless --path . -s res://tests/voice_calibration_report.gd"
	_buttons.visible = false
	_summary_buttons.visible = true



func _write() -> void :
	var samples: Array = []
	for a: Dictionary in _attempts:
		if not a.get("discarded", false):
			samples.append({"file": a["file"], "text": a["expected"]})
	_save_json("index.json", {"voice": "microfone (calibração)", "samples": samples})
	var config: = SpeechEngines.load_config()
	_save_json("results.json", {
		"created": Time.get_datetime_string_from_system(), 
		"device": AudioServer.input_device, 
		"mix_rate": AudioServer.get_mix_rate(), 
		"engine": config.get("engine", ""), 
		"input_device": AudioServer.input_device, 
		"model": config.get("model", ""), 
		"hotwords": config.get("hotwords", false), 
		"pre_roll_s": config.get("pre_roll_s", 0.0), 
		"post_roll_s": config.get("post_roll_s", 0.0), 
		"min_speech_rms": voice.min_speech_level(), 
		"lexicon_version": Lexicon.data.version, 
		"talk_key": UserSettings.talk_key_name(), 
		"phrases": _phrases.size(), 
		"attempts": _attempts, 
	})


func _save_json(file: String, data: Dictionary) -> void :
	var out: = FileAccess.open(_dir().path_join(file), FileAccess.WRITE)
	out.store_string(JSON.stringify(data, "  "))
	out.close()


func _dir() -> String:
	return DATASET_ROOT.path_join(folder)


func _button(text: String, action: Callable) -> Button:
	var button: = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _dim(text: String) -> Label:
	var label: = Label.new()
	label.theme_type_variation = &"DimLabel"
	label.text = text
	return label


func _rich() -> RichTextLabel:
	var label: = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_font_size_override("bold_font_size", 18)
	return label


static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
