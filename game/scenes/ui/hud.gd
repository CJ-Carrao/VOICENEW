class_name Hud
extends CanvasLayer






const COLOR_UNKNOWN: = "#ffc65c"
const COLOR_FIX: = "#9fd3ff"
const COLOR_MUTED: = "#aaa69f"
const COLOR_WARN: = "#ffa45c"
const COLOR_FAIL: = "#ff6a5a"

const VOICE_NOTE_MS: = 4000
const TOAST_S: = 3.5

const VOICE_HISTORY_SIZE: = 5
const COLOR_MATTER: = Color(1.0, 0.776, 0.36)
const COLOR_CHALK: = Color(0.953, 0.937, 0.886)

const SCOPE_SHADER: = "\nshader_type canvas_item;\nuniform float radius = 0.44;\nvoid fragment() {\n\tvec2 size = 1.0 / SCREEN_PIXEL_SIZE;\n\tvec2 p = (FRAGCOORD.xy - size * 0.5) / size.y;\n\tfloat d = length(p);\n\tfloat outside = smoothstep(radius - 0.004, radius, d);\n\tfloat ring = smoothstep(radius - 0.014, radius - 0.004, d) * (1.0 - outside);\n\tfloat cross_line = (abs(p.x) < 0.0011 || abs(p.y) < 0.0011) ? 0.85 : 0.0;\n\tCOLOR = vec4(0.0, 0.0, 0.0, max(outside, max(ring, cross_line)));\n}\n"













const VIGNETTE_SHADER: = "\nshader_type canvas_item;\nuniform float hurt = 0.0;\nuniform float low = 0.0;\nvoid fragment() {\n\tvec2 p = (SCREEN_UV - 0.5) * vec2(1.0, 0.8);\n\tfloat edge = smoothstep(0.22, 0.72, length(p));\n\tCOLOR = vec4(1.0, 0.16, 0.1, edge * clamp(hurt * 0.8 + low * 0.5, 0.0, 0.9));\n}\n"










var _player: Player
var _match: Match
var _voice: VoiceInput

var _voice_pending: bool = false
var _voice_seconds: float = 0.0

var _voice_note: String = ""
var _voice_note_until: int = 0

var _was_reloading: bool = false
var _scope: ColorRect
var _vignette: ColorRect
var _hurt: float = 0.0
var _clock: float = 0.0

var options: OptionsMenu
var _voice_log: PanelContainer
var _voice_log_text: RichTextLabel
var _voice_log_lines: PackedStringArray = []
var _slot_panels: Array[PanelContainer] = []

var _slot_labels: Array[Label] = []
var _slot_details: Array[Label] = []
var _slot_bars: Array[HudBar] = []

var _ammo_panel: PanelContainer
var _ammo_name: Label
var _ammo_count: Label
var _ammo_total: Label
var _ammo_bar: HudBar
var _last_ammo: int = -1
var _damage: DamageIndicator
var _current_slot: int = -1
var _last_result: Dictionary = {}

var _extract_banner: Label

var _shape_banner: Label

var _toast: RichTextLabel
var _toast_left: float = 0.0
var _banner_text: String = ""
var _last_count: int = -1
var _last_state: String = ""
var _extract_sound: AudioStreamPlayer
var _loops: Array[AudioStreamPlayer] = []

@onready var console: TextConsole = %Console
var _hit_sound: AudioStreamPlayer
@onready var _health_label: Label = %HealthLabel
@onready var _health_bar: HudBar = %HealthBar
@onready var _matter_label: Label = %MatterLabel
@onready var _matter_bar: HudBar = %MatterBar
@onready var _slots_box: HBoxContainer = %Slots
@onready var _creations_panel: PanelContainer = %CreationsPanel
@onready var _creations_list: VBoxContainer = %CreationsList
@onready var _creations_empty: Label = %CreationsEmpty
@onready var _debug_panel: PanelContainer = %DebugPanel
@onready var _debug_text: Label = %DebugText
@onready var _status: Label = %Status
@onready var _round_label: Label = %RoundLabel
@onready var _scoreboard: Label = %Scoreboard
@onready var _opponent_bar: HudBar = %OpponentBar
@onready var _opponent_label: Label = %OpponentLabel
@onready var _banner: Label = %Banner
@onready var _voice_prompt: Label = %VoicePrompt


func _ready() -> void :
	($Root as Control).theme = HudSkin.create_theme()
	_vignette = _overlay("Vignette", VIGNETTE_SHADER)
	_scope = _overlay("Scope", SCOPE_SHADER)
	_extract_banner = _make_banner("ExtractBanner", COLOR_MATTER, -132.0, -108.0)
	_shape_banner = _make_banner("ShapeBanner", COLOR_CHALK, -160.0, -134.0)
	_build_toast()
	_build_ammo_panel()
	_damage = DamageIndicator.new()
	_damage.name = "DamageIndicator"
	$Root.add_child(_damage)
	$Root.move_child(_damage, 0)
	_debug_panel.hide()
	_build_voice_log()
	options = OptionsMenu.new()
	options.name = "Options"
	$Root.add_child(options)
	options.voice_history_toggled.connect( func(on: bool) -> void : _voice_log.visible = on and not _voice_log_lines.is_empty())
	_extract_sound = AudioStreamPlayer.new()
	_extract_sound.name = "ExtractSound"
	_extract_sound.bus = AudioMix.bus(AudioMix.EFFECTS)
	add_child(_extract_sound)


func _overlay(overlay_name: String, code: String) -> ColorRect:
	var rect: = ColorRect.new()
	rect.name = overlay_name
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: = Shader.new()
	shader.code = code
	var material: = ShaderMaterial.new()
	material.shader = shader
	rect.material = material
	rect.visible = false
	add_child(rect)
	move_child(rect, 0)
	return rect


func bind_player(player: Player) -> void :
	_player = player
	player.health_changed.connect(_on_health_changed)
	player.matter_changed.connect(_on_matter_changed)
	player.extracting_changed.connect( func(_on: bool) -> void : _refresh_extract_banner())
	player.shaper.changed.connect(_refresh_shape_banner)
	player.hands.items_changed.connect(_refresh_slots)
	player.hands.items_changed.connect(_refresh_status)
	player.piloting_changed.connect(_on_piloting_changed)
	player.abilities_changed.connect(_refresh_status)
	_damage.player = player
	player.damaged.connect( func(amount: float, source: Node) -> void :
		_hurt = minf(1.0, _hurt + 0.35 + amount / 40.0)
		_damage.add_hit(amount, source)
		SoundBank.play_flat(self, "player/hurt", Lexicon.balf("feel.sound.hurt_db")))
	player.died.connect( func(_who: Player) -> void : SoundBank.play_flat(self, "player/death", Lexicon.balf("feel.sound.match_db")))
	player.revived.connect( func() -> void : SoundBank.play_flat(self, "player/respawn", Lexicon.balf("feel.sound.match_db")))
	Forge.build_started.connect(_on_build_changed)
	Forge.build_finished.connect(_on_build_changed)
	Forge.live_things_changed.connect(_on_live_things_changed)

	var crosshair: = $Root / Crosshair
	crosshair.call("bind", player)
	_hit_sound = AudioStreamPlayer.new()
	_hit_sound.name = "HitSound"
	_hit_sound.bus = AudioMix.bus(AudioMix.EFFECTS)
	add_child(_hit_sound)
	player.hands.used.connect( func(_item: Thing, kind: String) -> void :
		if kind == "fire": _refresh_ammo(true))
	Forge.hit_landed.connect( func(player_id: int, _target: Node, _amount: float, killed: bool) -> void :
		if player_id != player.player_id:
			return
		crosshair.call("hit", killed)
		if killed and _target is Player and _target != player:
			_show_toast("[b][color=#f2601a]ELIMINOU[/color] %s[/b]" % _escape((_target as Player).display_name))
		_hit_sound.stream = FeelSounds.kill() if killed else FeelSounds.hit()
		_hit_sound.volume_db = Lexicon.balf("feel.sound.hit_db") + SoundBank.gain(_hit_sound.stream)
		_hit_sound.play())
	_build_slots(player.hands.slot_count())
	_on_health_changed(player.health, player.max_health)
	_on_matter_changed(player.matter, player.max_matter)
	_refresh_extract_banner()
	_refresh_slots()
	_refresh_status()



func bind_voice(voice: VoiceInput) -> void :
	_voice = voice
	voice.state_changed.connect( func(state: String) -> void :
		if state == "listening" and not voice.is_private_talk():
			SoundBank.play_flat(self, "voice/talk_start", Lexicon.balf("feel.sound.talk_db"), null, AudioMix.INTERFACE)
		elif state == "thinking":
			SoundBank.play_flat(self, "voice/talk_end", Lexicon.balf("feel.sound.talk_db"), null, AudioMix.INTERFACE)
		_refresh_status())
	voice.chat_started.connect(_refresh_status)
	voice.chat_ended.connect(_refresh_status)
	voice.transcribed.connect( func(_text: String, seconds: float) -> void :
		_voice_pending = true
		_voice_seconds = seconds)
	voice.ignored.connect( func(reason: String) -> void :
		_show_voice_note(reason.to_upper())
		_log_voice("[color=%s](%s)[/color]" % [COLOR_MUTED, _escape(reason)]))
	options.bind(voice, _player)



func refresh_controls_help() -> void :
	_refresh_extract_banner()



func show_voice_prompt(text: String) -> void :
	_voice_prompt.text = text
	_voice_prompt.visible = not text.is_empty()




func bind_match(match_node: Match) -> void :
	_match = match_node
	match_node.state_changed.connect(_refresh_match)
	for fighter: Player in match_node.get_players():
		fighter.health_changed.connect(_on_opponent_health)
	_start_loop("music/match_loop", AudioMix.MUSIC)
	_refresh_match()


func _start_loop(id: String, bus: StringName) -> void :
	var audio: = SoundBank.stream(id)
	if audio == null:
		return
	if "loop" in audio:
		audio.set("loop", true)
	elif audio is AudioStreamWAV:
		(audio as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	var player: = AudioStreamPlayer.new()
	player.bus = AudioMix.bus(bus)
	player.stream = audio
	player.volume_db = SoundBank.gain(audio)
	add_child(player)
	player.play()
	_loops.append(player)


func toggle_debug() -> void :
	_debug_panel.visible = not _debug_panel.visible



func show_request(player_id: int, text: String, result: Dictionary) -> void :
	if _player == null or player_id != _player.player_id:
		return
	_last_result = result
	if _voice_pending:
		_voice_pending = false
		var outcome: = "[color=%s]→ %s[/color]" % [COLOR_FIX, _escape(str(result.get("pretty", "")))] if result.get("ok", false)\
		else "[color=%s]→ não entendi[/color]" % COLOR_FAIL
		var unknown_words: = PackedStringArray(result.get("unknown_words", []))
		var extra: = " [color=%s](não conheço: %s)[/color]" % [COLOR_UNKNOWN, _escape(", ".join(unknown_words))]\
		if not unknown_words.is_empty() else ""
		_log_voice("“%s” %s%s  [color=%s]%s s[/color]" % [_escape(text), outcome, extra, COLOR_MUTED, 
			Lexicon.data.format_number(snappedf(_voice_seconds, 0.1))])
	var unknown: = PackedStringArray(result.get("unknown_words", []))
	var unsupported: = PackedStringArray(result.get("unsupported", []))
	var title: = ""
	if result.get("blocked", false):
		title = "PEDIDO RECUSADO"
	elif not result.get("ok", false):
		title = "NÃO ENTENDI"
	elif not unsupported.is_empty():
		title = "AINDA NÃO FUNCIONA: %s" % ", ".join(unsupported).to_upper()
	if title.is_empty():
		return
	var line: = "[b][color=%s]%s[/color][/b]" % [COLOR_FAIL, _escape(title)]
	if not result.get("ok", false):
		line += "\n[color=%s]“%s”[/color]" % [COLOR_MUTED, _escape(text)]
	if not unknown.is_empty():
		line += "  [color=%s]%s?[/color]" % [COLOR_UNKNOWN, _escape(", ".join(unknown))]
	_show_toast(line)


func _process(delta: float) -> void :
	_clock += delta
	if _player != null:
		_scope.visible = _player.is_scoped()
		_update_vignette(delta)
		_update_extract_sound()
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0
	if _debug_panel.visible:
		_debug_text.text = _debug_lines()
	var held: = _player.hands.network_item_state() if _player != null else {}
	var reloading: = float(held.get("reload_left", 0.0)) > 0.0
	if _player != null and (Forge.is_building(_player.player_id) or not _player.pending_ability().is_empty()\
	or _player.extracting or (_voice != null and _voice.state == "listening") or _player.shaper.active\
	or _player.carry_speed_mult() < 1.0\
	or Status.of(_player) != null or reloading or _was_reloading\
	or bool(held.get("melee", false))):
		_was_reloading = reloading
		_refresh_status()
		if Forge.is_building(_player.player_id) or reloading:

			_refresh_slots()
	if _match != null and _match.state == "countdown":
		_refresh_match()
	if _voice_note_until > 0 and Time.get_ticks_msec() >= _voice_note_until:
		_voice_note_until = 0
		_refresh_status()


func _update_vignette(delta: float) -> void :
	_hurt = maxf(0.0, _hurt - delta * 1.8)
	var fraction: = _player.health / maxf(_player.max_health, 1.0)
	var low: = 0.0
	if _player.is_alive() and fraction < 0.3:
		low = (1.0 - fraction / 0.3) * (0.65 + 0.35 * sin(_clock * 5.0))
	_vignette.visible = _hurt > 0.01 or low > 0.01
	if _vignette.visible:
		var material: = _vignette.material as ShaderMaterial
		material.set_shader_parameter("hurt", _hurt)
		material.set_shader_parameter("low", low)



func _update_extract_sound() -> void :
	var pulling: = _player.extracting and _player.extractor.pulling
	if pulling and not _extract_sound.playing:
		_extract_sound.stream = FeelSounds.extract_loop()
		_extract_sound.volume_db = Lexicon.balf("feel.sound.extract_db") + SoundBank.gain(_extract_sound.stream)
		_extract_sound.play()
	elif not pulling and _extract_sound.playing:
		_extract_sound.stop()
	if pulling:
		var seconds: = float(_player.extractor.network_state().get("seconds", 0.0))
		_extract_sound.pitch_scale = 1.0 + clampf(seconds / 3.0, 0.0, 1.0) * 0.35


func _show_voice_note(text: String) -> void :
	_voice_note = text
	_voice_note_until = Time.get_ticks_msec() + VOICE_NOTE_MS
	_refresh_status()


func _build_toast() -> void :
	_toast = RichTextLabel.new()
	_toast.name = "Toast"
	_toast.bbcode_enabled = true
	_toast.fit_content = true
	_toast.scroll_active = false
	_toast.autowrap_mode = TextServer.AUTOWRAP_OFF
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -420.0
	_toast.offset_right = 420.0
	_toast.offset_top = -214.0
	_toast.offset_bottom = -166.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_toast.visible = false
	$Root.add_child(_toast)


func _show_toast(bbcode: String) -> void :
	_toast.text = "[center]%s[/center]" % bbcode
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_left = TOAST_S
	_pop(_toast, 1.12)



func _pop(control: Control, from: float) -> void :
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE * from
	var tween: = control.create_tween()
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _debug_lines() -> String:
	var lines: = PackedStringArray()
	lines.append("FPS %d" % Engine.get_frames_per_second())
	if _player != null:
		var p: = _player.global_position
		var v: = _player.velocity
		lines.append("pos (%.1f, %.1f, %.1f)  vel %.1f m/s  chão %s" % [p.x, p.y, p.z, Vector2(v.x, v.z).length(), _player.is_on_floor()])
	lines.append("léxico %s · versão %s · %d expressões" % [Lexicon.data.lang, Lexicon.data.version, Lexicon.data.phrases.size()])
	if _voice != null:
		lines.append("voz: %s · volume da última fala %.3f (mínimo %.3f em data/voice.json)" % [_voice.state, _voice.last_level, 
			_voice.min_speech_level()] if _voice.is_on() else "voz: desligada (%s)" % _voice.off_reason)
	if Session.is_online() and Session.voice_sync != null:
		var vs: = Session.voice_sync.stats
		lines.append("voip (canal 3): tx %d · rx %d · perdas %d · rms %.3f" % [int(vs.sent_packets), int(vs.received_packets), 
			int(vs.lost_packets), Session.voice_sync.last_received_rms])
	if not _last_result.is_empty():
		lines.append("último pedido: %s" % _last_result.get("pretty", "—"))
		lines.append("normalizado: %s" % _last_result.get("normalized", "—"))
		lines.append("árvore:")
		lines.append(JSON.stringify(Recipe.compact(_last_result.get("recipe")), "", false))
	return "\n".join(lines)


func _build_slots(count: int) -> void :
	for child in _slots_box.get_children():
		child.queue_free()
	_slot_panels.clear()
	_slot_labels.clear()
	_slot_details.clear()
	_slot_bars.clear()
	for i in count:
		var panel: = PanelContainer.new()
		panel.theme_type_variation = &"SlotPanel"
		panel.custom_minimum_size = Vector2(150, 50)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row: = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var key: = Label.new()
		key.text = str(i + 1)
		key.theme_type_variation = &"BigLabel"
		key.add_theme_font_size_override("font_size", 20)
		key.add_theme_color_override("font_color", HudSkin.ACCENT)
		key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(key)
		var column: = VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(column)
		var label: = Label.new()
		label.add_theme_font_override("font", HudSkin.font(800))
		label.add_theme_font_size_override("font_size", 14)
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.text = "VAZIO"
		column.add_child(label)
		var detail: = Label.new()
		detail.theme_type_variation = &"DimLabel"
		column.add_child(detail)
		var bar: = HudBar.new()
		bar.custom_minimum_size = Vector2(0, 3)
		bar.fill = HudSkin.MATTER
		bar.chamfer = 2.0
		bar.visible = false
		column.add_child(bar)
		_slots_box.add_child(panel)
		_slot_panels.append(panel)
		_slot_labels.append(label)
		_slot_details.append(detail)
		_slot_bars.append(bar)


func _build_ammo_panel() -> void :
	_ammo_panel = PanelContainer.new()
	_ammo_panel.name = "AmmoPanel"
	_ammo_panel.theme_type_variation = &"AccentPanel"
	_ammo_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ammo_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_panel.offset_left = -240.0
	_ammo_panel.offset_top = -104.0
	_ammo_panel.offset_right = -20.0
	_ammo_panel.offset_bottom = -20.0
	_ammo_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ammo_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box: = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_ammo_panel.add_child(box)
	_ammo_name = Label.new()
	_ammo_name.theme_type_variation = &"TagLabel"
	_ammo_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_ammo_name)
	var row: = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	_ammo_count = Label.new()
	_ammo_count.theme_type_variation = &"BigLabel"
	_ammo_count.add_theme_font_size_override("font_size", 40)
	_ammo_count.add_theme_constant_override("line_spacing", -8)
	row.add_child(_ammo_count)
	_ammo_total = Label.new()
	_ammo_total.theme_type_variation = &"DimLabel"
	_ammo_total.add_theme_font_size_override("font_size", 18)
	_ammo_total.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_ammo_total)
	_ammo_bar = HudBar.new()
	_ammo_bar.custom_minimum_size = Vector2(0, 5)
	_ammo_bar.fill = HudSkin.INK
	_ammo_bar.chamfer = 3.0
	box.add_child(_ammo_bar)
	_ammo_panel.visible = false
	$Root.add_child(_ammo_panel)




func _refresh_ammo(fired: bool = false) -> void :
	if _player == null:
		return
	var held: = _player.hands.network_item_state()
	var item: = _player.hands.current_item()
	var id: = str(held.get("id", item.thing_id if item != null else ""))
	_ammo_panel.visible = not id.is_empty()
	if id.is_empty():
		_last_ammo = -1
		return
	_ammo_name.text = Lexicon.data.thing_name(id).to_upper()
	var magazine: = int(held.get("magazine", item.magazine if item != null else 0))
	var capacity: = int(held.get("capacity", item.capacity if item != null else 0))
	var ammo: = int(held.get("ammo", item.ammo if item != null else 0))
	var reload_left: = float(held.get("reload_left", 0.0))
	if bool(held.get("building", item != null and item.is_building)):
		var progress: = Forge.build_progress(item) if item != null else 0.0
		_ammo_count.text = "%d%%" % roundi(progress * 100.0)
		_ammo_total.text = " MONTANDO"
		_ammo_count.add_theme_color_override("font_color", HudSkin.MATTER)
		_ammo_bar.fill = HudSkin.MATTER
		_ammo_bar.max_value = 1.0
		_ammo_bar.value = progress
		return
	if magazine <= 0:
		var charges: = int(held.get("charges", item.charges if item != null else 1))
		_ammo_count.text = "×%d" % charges if charges > 1 else "∞"
		_ammo_total.text = ""
		_ammo_count.add_theme_color_override("font_color", HudSkin.INK)
		_ammo_bar.visible = false
		return
	_ammo_bar.visible = true
	_ammo_count.text = str(ammo)
	_ammo_total.text = " / %d" % capacity
	var color: = HudSkin.INK
	if ammo <= 0:
		color = HudSkin.DANGER
	elif ammo <= maxi(1, capacity / 4):
		color = HudSkin.MATTER
	_ammo_count.add_theme_color_override("font_color", color)
	if reload_left > 0.0:
		_ammo_total.text = " RECARREGANDO"
		_ammo_bar.fill = HudSkin.ACCENT
		_ammo_bar.max_value = maxf(item.reload_time if item != null else reload_left, reload_left)
		_ammo_bar.value = _ammo_bar.max_value - reload_left
	else:
		_ammo_bar.fill = color
		_ammo_bar.max_value = maxf(capacity, 1)
		_ammo_bar.value = ammo
	if fired or (ammo < _last_ammo and _last_ammo >= 0):
		_pop(_ammo_count, 1.18)
	_last_ammo = ammo


func _on_health_changed(current: float, maximum: float) -> void :
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d" % ceili(current)
	var low: = current / maxf(maximum, 1.0) < 0.3
	_health_label.add_theme_color_override("font_color", HudSkin.DANGER if low else HudSkin.INK)


func _on_matter_changed(current: float, maximum: float) -> void :
	_matter_bar.max_value = maximum
	_matter_bar.value = current
	_matter_label.text = "%d / %d" % [floori(current), roundi(maximum)]

	if _player != null and _player.matter_credit > 0.05:
		_matter_label.text = "+%d  ·  " % ceili(_player.matter_credit) + _matter_label.text



func _make_banner(banner_name: String, color: Color, top: float, bottom: float) -> Label:
	var banner: = Label.new()
	banner.name = banner_name
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	banner.offset_left = -420.0
	banner.offset_right = 420.0
	banner.offset_top = top
	banner.offset_bottom = bottom
	banner.add_theme_color_override("font_color", color)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("outline_size", 5)
	banner.add_theme_font_size_override("font_size", 15)
	banner.add_theme_font_override("font", HudSkin.font(800))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	$Root.add_child(banner)
	return banner



func _refresh_shape_banner() -> void :
	if _shape_banner == null or _player == null:
		return
	var shaper: = _player.shaper
	_shape_banner.visible = shaper.active
	if not shaper.active:
		return
	var dim: = shaper.focus
	var value: = Lexicon.data.format_number(snappedf(shaper.measure_m(dim), 0.1)) + " m"
	if dim == "scale":
		value = "×%s (%s m)" % [Lexicon.data.format_number(snappedf(float(shaper.dims[dim]), 0.05)), value.trim_suffix(" m")]
	var cost: = shaper.cost()

	var have: = Forge.matter_for(_player.player_id, Forge.draft_of(_player.player_id).get("recipe", {}))
	var line: = "%s  ·  %s %s  ·  %s / %d" % [Lexicon.data.thing_name(shaper.thing_id).to_upper(), 
		Lexicon.data.label("dims", dim).to_upper(), value, Lexicon.data.format_number(snappedf(cost, 0.1)), floori(have)]
	if shaper.in_hand():
		line += "  ·  %s kg" % Lexicon.data.format_number(snappedf(shaper.weight_kg(), 0.1))
	_shape_banner.text = line
	_shape_banner.add_theme_color_override("font_color", COLOR_CHALK if cost <= have + 0.001 else Color(COLOR_WARN))



func _refresh_extract_banner() -> void :
	if _extract_banner == null or _player == null:
		return
	_extract_banner.visible = _player.extracting
	if not _player.extracting:
		return
	var line: = "◆ EXTRAÇÃO"
	match _player.extractor.problem:
		"full":
			line = "◆ CARGA CHEIA"
		"nothing":
			line = "◆ NADA AO ALCANCE"
	if _player.extractor.pulling:
		line = "◆ EXTRAINDO"
	_extract_banner.text = line


func _refresh_slots() -> void :
	var hands: = _player.hands
	for i in _slot_panels.size():
		var item: = hands.item_at(i)
		var replica: = hands.network_item_state(i) if item == null else {}
		var name: = "VAZIO"
		var detail: = ""
		var progress: = -1.0
		if item != null:
			name = Lexicon.data.thing_name(item.thing_id).to_upper()
			if item.is_building:

				progress = Forge.build_progress(item)
				detail = "MONTANDO %d%%" % roundi(progress * 100.0) if i == hands.current else "GUARDADA %d%%" % roundi(progress * 100.0)
			elif item.magazine > 0:
				detail = "CARREGANDO" if item.loading else ("RECARREGANDO" if item.is_reloading() else "%d / %d" % [item.ammo, item.capacity])
			elif item.charges > 1:
				detail = "×%d" % item.charges
		elif not replica.is_empty():
			name = Lexicon.data.thing_name(str(replica.get("id", ""))).to_upper()
			if bool(replica.get("building", false)):
				detail = "MONTANDO"
			elif int(replica.get("magazine", 0)) > 0:
				detail = "%d / %d" % [int(replica.get("ammo", 0)), int(replica.get("capacity", 0))]
			elif int(replica.get("charges", 0)) > 1:
				detail = "×%d" % int(replica["charges"])
		var empty: = item == null and replica.is_empty()
		_slot_labels[i].text = name
		_slot_labels[i].modulate.a = 0.4 if empty else 1.0
		_slot_details[i].text = detail
		_slot_details[i].visible = not detail.is_empty()
		_slot_bars[i].visible = progress >= 0.0
		if progress >= 0.0:
			_slot_bars[i].max_value = 1.0
			_slot_bars[i].value = progress
		_slot_panels[i].theme_type_variation = &"SlotPanelActive" if i == hands.current else &"SlotPanel"
	if hands.current != _current_slot:
		if _current_slot >= 0 and hands.current >= 0 and hands.current < _slot_panels.size():
			_pop(_slot_panels[hands.current], 1.1)
		_current_slot = hands.current
		_last_ammo = -1
	_refresh_ammo()


func _on_piloting_changed(_thing: Thing) -> void :
	_refresh_status()


func _on_build_changed(player_id: int, _thing: Thing) -> void :
	if _player != null and player_id == _player.player_id:
		_refresh_slots.call_deferred()
		_refresh_status()



func _refresh_status() -> void :
	var parts: = PackedStringArray()

	var building: = {}
	for thing: Thing in Forge.builds(_player.player_id):
		var entry: Array = building.get_or_add(thing.thing_id, [0, 1.0])
		entry[0] = int(entry[0]) + 1
		entry[1] = minf(float(entry[1]), Forge.build_progress(thing))
	var waiting: = false
	var stored: = 0
	for thing: Thing in Forge.builds(_player.player_id):
		waiting = waiting or Forge.build_waiting_matter(thing)
		if Forge.build_stored(thing):
			stored += 1
			(building[thing.thing_id] as Array)[0] = int(building[thing.thing_id][0]) - 1
	for id: String in building:
		var count: = int(building[id][0])
		if count <= 0:
			continue
		var name: = Lexicon.data.thing_name(id).to_upper()
		parts.append("MONTANDO %s%s %d%%" % ["%d× " % count if count > 1 else "", name, roundi(float(building[id][1]) * 100.0)])
	if waiting:
		parts.append("FALTA MATÉRIA")
	if stored > 0:
		parts.append("%d GUARDADA%s" % [stored, "S" if stored > 1 else ""])
	if _voice != null:
		if _voice.is_chat_talk():
			parts.append("● CONVERSANDO")
		match _voice.state:
			"listening":

				if _voice.held_seconds() > Lexicon.balf("extraction.tap_max_s") or _voice.is_private_talk():
					parts.append("● OUVINDO")
			"thinking":
				parts.append("● ENTENDENDO…")
			"warming":
				parts.append("PREPARANDO A VOZ…")
	if _voice_note_until > 0:
		parts.append(_voice_note)
	var held: = _player.hands.network_item_state()
	if _player.hands.is_charging():
		var charge: = _player.hands.charge_level()
		parts.append("GOLPE FORTE %d%%" % roundi(charge * 100.0) if charge > 0.0 else "CARREGANDO GOLPE")
	elif _player.is_blocking():
		parts.append("DEFENDENDO")
	var carry: = _player.carry_speed_mult()
	if carry < 1.0:
		parts.append("CARGA %s kg −%d%%" % [Lexicon.data.format_number(snappedf(_player.carried_weight(), 1.0)), 
			roundi((1.0 - carry) * 100.0)])
	var status: = Status.of(_player)
	if status != null:
		for kind: String in status.remaining:
			parts.append("%s %s s" % [Lexicon.data.label("status", kind).to_upper(), 
				Lexicon.data.format_number(snappedf(float(status.remaining[kind]), 0.1))])
	var pending: = _player.pending_ability()
	if not pending.is_empty():
		parts.append("%s · FALTA MATÉRIA" % Lexicon.data.label("abilities", String(pending["id"])).to_upper())
	if _player.piloting != null:
		parts.append("PILOTANDO %s" % Lexicon.data.thing_name(_player.piloting.thing_id).to_upper())
	var abilities: = _player.active_abilities()
	for id: String in abilities:
		parts.append("%s %s s" % [Lexicon.data.label("abilities", id).to_upper(), Lexicon.data.format_number(snappedf(float(abilities[id]), 0.1))])
	_status.text = "   ·   ".join(parts)
	_refresh_extract_banner()
	_refresh_shape_banner()



func _on_live_things_changed(player_id: int) -> void :
	if _player == null or player_id != _player.player_id:
		return
	var counts: = {}
	for thing: Thing in Forge.live_things(player_id):
		if not thing.is_dead:
			counts[thing.thing_id] = int(counts.get(thing.thing_id, 0)) + 1
	for child in _creations_list.get_children():
		if child != _creations_empty:
			child.queue_free()
	_creations_panel.visible = not counts.is_empty()
	for id: String in counts:
		var label: = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		label.add_theme_font_size_override("font_size", 14)
		label.text = "%s ×%d" % [Lexicon.data.thing_name(id).to_upper(), counts[id]]
		_creations_list.add_child(label)


func _on_opponent_health(_current: float, _maximum: float) -> void :
	_refresh_match()


func _refresh_match() -> void :
	if _match == null or _player == null:
		return
	if Session.is_online() and not Session.replication.is_active():
		_round_label.text = "ONLINE"
		_scoreboard.text = "PREPARANDO"
		_opponent_bar.visible = false
		_opponent_label.visible = false
		_set_banner("")
		return
	var duel: = _match.mode in ["duel", "online"]
	var ffa: = Session.is_online() and _match.player_ids().size() > 2
	_opponent_bar.visible = duel and not ffa
	_opponent_label.visible = duel
	if not duel:
		_round_label.text = ""
		_scoreboard.text = "TREINO"
		_set_banner("")
		return
	var opponent: = _match.opponent
	var you: = int(_match.score.get(_player.player_id, 0))
	var them: = int(_match.score.get(opponent.player_id, 0))
	_round_label.text = "ROUND %d" % _match.round_number
	_scoreboard.text = "%s  %d × %d  %s" % [_player.display_name, you, them, opponent.display_name]
	_opponent_bar.max_value = opponent.max_health
	_opponent_bar.value = opponent.health
	_opponent_label.text = "%s %d" % [opponent.display_name, ceili(opponent.health)]
	if ffa:
		var scores: = PackedStringArray()
		var survivors: = 0
		for fighter: Player in _match.get_players():
			scores.append("%s %d" % [fighter.display_name, int(_match.score.get(fighter.player_id, 0))])
			if fighter.is_alive() and Session.peer_for_player(fighter.player_id) > 0: survivors += 1
		_round_label.text = "FFA · ROUND %d" % _match.round_number
		_scoreboard.text = "  ·  ".join(scores)
		_opponent_label.text = "%d SOBREVIVENTES" % survivors
	var won: = _match.last_winner == _player
	var winner_name: = _match.last_winner.display_name if is_instance_valid(_match.last_winner) else "NINGUÉM"
	var state: = String(_match.state)
	match state:
		"countdown":
			var count: = maxi(1, ceili(_match.countdown_left / maxf(_match.countdown_total, 0.001) * 3.0))
			_set_banner(str(count))
			if count != _last_count:
				_last_count = count
				SoundBank.play_flat(self, "match/countdown", Lexicon.balf("feel.sound.countdown_db"), 
					FeelSounds.fallback("match/countdown"), AudioMix.EFFECTS)
		"round_over":
			_set_banner("VOCÊ VENCEU O ROUND" if won else ("EMPATE" if not is_instance_valid(_match.last_winner) else "%s VENCEU O ROUND" % winner_name))
			if _last_state != state:
				SoundBank.play_flat(self, "match/round_win" if won else "match/round_lose", Lexicon.balf("feel.sound.match_db"))
		"match_over":
			_set_banner(("VOCÊ VENCEU!" if won else "%s VENCEU" % winner_name) + "\n[ESPAÇO]")
			if _last_state != state:
				SoundBank.play_flat(self, "match/match_win" if won else "match/match_lose", Lexicon.balf("feel.sound.match_db"))
		_:
			if _last_state == "countdown":
				SoundBank.play_flat(self, "match/go", Lexicon.balf("feel.sound.countdown_db"), FeelSounds.fallback("match/go"))
				_set_banner("LUTE!")
				get_tree().create_timer(0.7).timeout.connect( func() -> void :
					if _match != null and _match.state not in ["countdown", "round_over", "match_over"] and _banner_text == "LUTE!":
						_set_banner("ELIMINADO" if ffa and not _player.is_alive() else ""))
			elif _banner_text != "LUTE!":
				_set_banner("ELIMINADO" if ffa and not _player.is_alive() else "")
	if state != "countdown":
		_last_count = -1
	_last_state = state




func set_cinematic(on: bool) -> void :
	for child in $Root.get_children():
		if child == _banner or child == options or child == console or child == _toast:
			continue
		var item: = child as CanvasItem
		if item == null:
			continue
		if on:
			item.modulate.a = 0.0
		else:
			item.create_tween().tween_property(item, "modulate:a", 1.0, 0.45)



func _set_banner(text: String) -> void :
	if text == _banner_text:
		return
	_banner_text = text
	_banner.text = text
	_banner.add_theme_color_override("font_color", HudSkin.ACCENT if text.is_valid_int() or text == "LUTE!" else HudSkin.INK)
	_banner.add_theme_font_size_override("font_size", 96 if text.is_valid_int() else 46)
	if not text.is_empty():
		_pop(_banner, 1.6 if text.is_valid_int() else 1.15)




func _build_voice_log() -> void :
	_voice_log = PanelContainer.new()
	_voice_log.name = "VoiceLog"
	_voice_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_log.anchor_top = 1.0
	_voice_log.anchor_bottom = 1.0
	_voice_log.offset_left = 20.0
	_voice_log.offset_right = 560.0
	_voice_log.offset_top = -116.0
	_voice_log.offset_bottom = -116.0
	_voice_log.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var box: = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_log.add_child(box)
	var title: = Label.new()
	title.theme_type_variation = &"TagLabel"
	title.text = "VOZ"
	box.add_child(title)
	_voice_log_text = RichTextLabel.new()
	_voice_log_text.bbcode_enabled = true
	_voice_log_text.fit_content = true
	_voice_log_text.scroll_active = false
	_voice_log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_voice_log_text.add_theme_font_size_override("normal_font_size", 14)
	box.add_child(_voice_log_text)
	_voice_log.visible = false
	$Root.add_child(_voice_log)


func _log_voice(line: String) -> void :
	_voice_log_lines.append(line)
	if _voice_log_lines.size() > VOICE_HISTORY_SIZE:
		_voice_log_lines = _voice_log_lines.slice(_voice_log_lines.size() - VOICE_HISTORY_SIZE)
	_voice_log_text.text = "\n".join(_voice_log_lines)
	_voice_log.visible = bool(UserSettings.get_value("voice", "history", false))



static func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
