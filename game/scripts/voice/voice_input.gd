class_name VoiceInput
extends Node











signal state_changed(state: String)

signal transcribed(text: String, seconds: float)
signal command_transcribed(text: String, seconds: float)

signal heard(samples: PackedFloat32Array)

signal ignored(reason: String)


signal utterance_done(info: Dictionary)

signal tapped

signal voip_started

signal voip_frames(samples: PackedFloat32Array)

signal voip_ended

signal chat_started
signal chat_ended

const CAPTURE_BUFFER_S: = 0.5

const DEVICE_SWITCH_PAUSE_S: = 0.15
const PLAYBACK_BUS: = AudioMix.VOICES


var state: String = "off"

var off_reason: String = ""
var player: Player

var last_level: float = 0.0

var live_level: float = 0.0

var playback_enabled: bool = false

var capture_opens: int = 0

var last_ready_delay: float = 0.0
var _native_started_ms: int = 0

var _engine: SpeechEngine
var _lex: LexiconData
var _config: Dictionary = {}
var _min_speech_rms: float = 0.0
var _capture: AudioEffectCapture


var _mic_source: = false
var _mic: AudioStreamPlayer
var _playback: AudioStreamPlayer
var _frames: = PackedVector2Array()

var _pre_roll: = PackedVector2Array()

var _tail_until: int = 0

var _private: bool = false
var _samples: = PackedFloat32Array()
var _task: int = -1
var _task_text: String = ""
var _task_started: int = 0

var _task_samples: = PackedFloat32Array()
var _task_level: float = 0.0
var _task_peak: = 0.0
var _task_clip: = 0.0
var _task_gated: bool = false

var _pressed_ms: int = -1
var _command_only := false
var _active_talk_action: StringName = &"talk"

var _voip_waiting_tap: bool = false
var _voip_streaming: bool = false
var _voip_only_active: bool = false
var _voip_pending_frames: = PackedVector2Array()
var _voip_source_frames: = PackedVector2Array()
var _voip_source_pos: float = 0.0
var _injected_capture: = PackedVector2Array()
var _injected_mix_rate: float = 0.0
var _chat_active: = false

var _listen_started_ms: = 0
var _diag_utterance: = ""
var _warm_started_ms: = 0
var _chat_blocked: = false
var _chat_key_down: = false
var _talk_suppressed: = false


func _ready() -> void :

	process_mode = Node.PROCESS_MODE_ALWAYS
	playback_enabled = bool(UserSettings.get_value("voice", "playback", false))
	Session.changed.connect(_on_session_changed)


func setup(local_player: Player, lex: LexiconData, custom_engine: SpeechEngine = null) -> void :
	player = local_player
	_lex = lex
	_config = SpeechEngines.load_config()
	_min_speech_rms = float(UserSettings.get_value("voice", "min_speech_rms", float(_config.get("min_speech_rms", 0.0))))
	if not ProjectSettings.get_setting("audio/driver/enable_input", false):
		_turn_off(tr("microfone desligado no projeto (audio/driver/enable_input)"))
		return
	var device: = String(UserSettings.get_value("voice", "input_device", ""))
	if not device.is_empty() and device in AudioServer.get_input_device_list():
		AudioServer.input_device = device
	VoiceDiagnostics.note("voz", "setup · motor %s · microfone salvo '%s' (%s) · volume mínimo %.4f" % [engine_id(), device, 
		"existe" if device.is_empty() or device in AudioServer.get_input_device_list() else "NÃO EXISTE MAIS", 
		_min_speech_rms])
	_start_engine(custom_engine)



func engine_id() -> String:
	return String(_config.get("engine", ""))




func _start_engine(custom_engine: SpeechEngine = null) -> bool:
	_engine = custom_engine if custom_engine != null else SpeechEngines.create(String(_config.get("engine", "")))
	if _engine == null:
		if not OS.has_feature("android"):

			_open_microphone()
		_turn_off(tr("motor de voz desconhecido: %s") % _config.get("engine"))
		return false
	if _engine.owns_microphone():
		_engine.availability_changed.connect(_on_native_availability)
		_engine.listening_ready.connect(_on_native_ready)
		_engine.recognition_finished.connect(_on_native_result)
		_set_state("warming")
	else:

		_open_microphone()
	if not _engine.setup(_config, _lex, self):
		_turn_off(_engine.error)
		return false
	if _engine.owns_microphone():
		return true
	_set_state("warming")
	_warm_started_ms = Time.get_ticks_msec()
	var silence: = PackedFloat32Array()
	silence.resize(SpeechEngine.SAMPLE_RATE >> 1)
	_start_task(PackedVector2Array(), 0.0, silence, false)
	return true


func is_on() -> bool:
	return state != "off"


func capture_available() -> bool:
	return _capture != null or _mic_source


func capture_effect() -> AudioEffectCapture:
	return _capture



func min_speech_level() -> float:
	return _min_speech_rms


func set_min_speech_level(level: float) -> void :
	_min_speech_rms = maxf(level, 0.0)
	UserSettings.set_value("voice", "min_speech_rms", _min_speech_rms)



static func input_devices() -> PackedStringArray:
	return AudioServer.get_input_device_list()





func set_input_device(device: String) -> bool:
	UserSettings.set_value("voice", "input_device", device)
	if not device in AudioServer.get_input_device_list():
		return false
	if _mic_source:
		MicSource.switch_device(device)
		_pre_roll.clear()
		await get_tree().create_timer(DEVICE_SWITCH_PAUSE_S, true, false, true).timeout
		return AudioServer.input_device == device
	if _mic == null:
		AudioServer.input_device = device
		return AudioServer.input_device == device
	_mic.stop()
	await get_tree().create_timer(DEVICE_SWITCH_PAUSE_S, true, false, true).timeout
	AudioServer.input_device = device
	await get_tree().create_timer(DEVICE_SWITCH_PAUSE_S, true, false, true).timeout
	_mic.play()
	_pre_roll.clear()
	return AudioServer.input_device == device


func set_playback_enabled(enabled: bool) -> void :
	playback_enabled = enabled
	UserSettings.set_value("voice", "playback", enabled)



func begin_talk(private: bool = false, commands_only: bool = false) -> bool:
	if state != "idle" or _chat_active or ( not private and (_chat_key_down or _talk_suppressed)):
		return false
	_private = private
	_command_only = commands_only and not private
	_active_talk_action = &"command_talk" if _command_only else &"talk"
	if _native_capture():

		if not private and _pressed_ms >= 0:
			_set_state("arming")
			return true
		return _begin_native()
	_frames = _pre_roll.duplicate()
	_pre_roll.clear()
	_begin_voip_session(private, _pressed_ms >= 0)
	_listen_started_ms = Time.get_ticks_msec()
	_set_state("listening")
	return true



func end_talk() -> void :
	if _native_capture():
		if state == "listening":
			_set_state("thinking")
			_engine.stop_listening()
		elif state in ["arming", "starting"]:
			_engine.cancel_listening()
			_set_state("idle")
			_done("", 0.0, tr("aguarde PODE FALAR antes de falar; tente novamente"))
		return
	if state != "listening":
		return
	if not _private and _voip_waiting_tap:
		_promote_voip_pending()
	_tail_until = Time.get_ticks_msec() + int(1000.0 * float(_config.get("post_roll_s", 0.0)))
	_set_state("thinking")



func held_seconds() -> float:
	return (Time.get_ticks_msec() - _pressed_ms) / 1000.0 if _pressed_ms >= 0 else 0.0


func is_private_talk() -> bool:
	return _private and state in ["arming", "starting", "listening", "thinking"]

func is_command_talk() -> bool:
	return _command_only and not _private and state in ["arming", "starting", "listening", "thinking"]


func is_chat_talk() -> bool:
	return _chat_active


func set_chat_blocked(blocked: bool) -> void :
	_chat_blocked = blocked
	if blocked: cancel_chat()




func begin_chat() -> bool:
	if _native_capture():
		if not _chat_allowed() or _chat_active:
			return false
		if state in ["starting", "listening", "thinking"]:
			ignored.emit(tr("aguarde o pedido terminar para conversar"))
			return false
		if not _ensure_native_permission():
			return false
		_open_microphone()
	if _chat_active or not capture_available() or not _chat_allowed():
		return false
	_talk_suppressed = _talk_suppressed or _pressed_ms >= 0 or Input.is_action_pressed("talk") or Input.is_action_pressed("command_talk")
	_pressed_ms = -1
	_discard_creation_recording()
	_cancel_voip()
	_clear_chat_capture()
	_private = false
	_chat_active = true
	_begin_voip_session(false, false)
	chat_started.emit()
	return true



func end_chat() -> void :
	if not _chat_active: return
	if not _chat_allowed():
		cancel_chat()
		return
	_push_voip_capture(_read_capture())
	_finish_voip()
	_chat_active = false
	_clear_chat_capture()
	_stop_native_chat_microphone()
	chat_ended.emit()



func cancel_chat() -> void :
	if not _chat_active: return
	_chat_active = false
	_cancel_voip()
	_clear_chat_capture()
	_stop_native_chat_microphone()
	chat_ended.emit()


func _clear_chat_capture() -> void :
	_pre_roll.clear()
	_injected_capture.clear()
	if _capture != null: _capture.clear_buffer()
	if _mic_source: MicSource.clear(get_instance_id())


func _chat_allowed() -> bool:
	if _chat_blocked or get_tree().paused or is_private_talk(): return false
	if not is_instance_valid(player) or not player.input_enabled: return false
	var focused: = get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: return false
	return _network_chat_available()


func _network_chat_available() -> bool:
	return Session.voice_sync != null and Session.voice_sync.can_transmit()


func _on_session_changed() -> void :
	if _chat_active and not _network_chat_available(): cancel_chat()


func _discard_creation_recording() -> void :
	if _native_capture() and state in ["arming", "starting", "listening", "thinking"]:
		_engine.cancel_listening()
		_set_state("idle")
		return
	if state == "listening" or _tail_until > 0:
		_tail_until = 0
		_frames.clear()
		_set_state("idle")


func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_chat()
		if not is_private_talk() or _native_capture():
			_discard_creation_recording()
			_cancel_voip()
			_clear_chat_capture()

		_pressed_ms = -1
		_talk_suppressed = false
		_chat_key_down = false



func _input(event: InputEvent) -> void :
	if event.is_action_released("voice_chat"):
		_chat_key_down = false
		end_chat()
	elif event.is_action_released(_active_talk_action) and not is_private_talk():
		if event.get_meta("touch_cancelled", false):
			_pressed_ms = -1
			_discard_creation_recording()
			_cancel_voip()
			get_viewport().set_input_as_handled()
			return
		if _release_creation(): get_viewport().set_input_as_handled()




func inject(samples: PackedFloat32Array) -> void :
	if _native_capture():
		ignored.emit("o reconhecedor do Android captura o microfone; use a calibração no aparelho")
		return
	if _chat_active: return
	while state == "warming":
		await state_changed
	if state != "idle" and state != "off":
		return
	_private = false
	_command_only = false
	if not samples.is_empty():
		voip_started.emit()
		voip_frames.emit(samples)
		voip_ended.emit()
	if state != "idle":
		return
	_set_state("thinking")
	_start_task(PackedVector2Array(), 0.0, samples, true)



func push_capture_frames(frames: PackedVector2Array, mix_rate: float = 0.0) -> void :
	if frames.is_empty():
		return
	if mix_rate > 0.0:
		_injected_mix_rate = mix_rate
	_injected_capture.append_array(frames)



func play_back(samples: PackedFloat32Array) -> void :
	if samples.is_empty():
		return
	if _playback == null:
		_playback = AudioStreamPlayer.new()
		_playback.name = "Playback"
		_playback.bus = AudioMix.bus(PLAYBACK_BUS)
		add_child(_playback)
	_playback.stream = SpeechEngine.to_wav(samples)
	_playback.play()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("voice_chat") and not event.is_echo():
		_chat_key_down = true
		begin_chat()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_released("voice_chat"):
		_chat_key_down = false
		end_chat()
		return
	if event.is_action_released(_active_talk_action):
		if not is_private_talk() and _release_creation(): get_viewport().set_input_as_handled()
		return
	var commands_only := event.is_action_pressed("command_talk")
	if (not event.is_action_pressed("talk") and not commands_only) or event.is_echo(): return
	if _chat_active or _chat_key_down or _talk_suppressed:
		_talk_suppressed = true
		get_viewport().set_input_as_handled()
		return
	if not is_instance_valid(player) or not player.input_enabled or get_tree().paused or not player.can_act(): return
	if state not in ["idle", "off"]: return
	_pressed_ms = Time.get_ticks_msec()
	_active_talk_action = &"command_talk" if commands_only else &"talk"
	_command_only = commands_only
	if state == "off" and capture_available() and not _native_capture():
		_private = false
		_voip_only_active = true
		_begin_voip_session(false, true)
	elif state == "idle":
		begin_talk(false, commands_only)
	get_viewport().set_input_as_handled()


func _release_creation() -> bool:
	if _talk_suppressed:
		_talk_suppressed = false
		_pressed_ms = -1
		return true
	if _pressed_ms < 0: return false
	var held_s: = (Time.get_ticks_msec() - _pressed_ms) / 1000.0
	_pressed_ms = -1
	if held_s <= _tap_max_s() and not _private and not _command_only:
		_cancel_voip()
		if state in ["arming", "starting", "listening"]:
			if _native_capture(): _engine.cancel_listening()
			_frames.clear()
			_set_state("idle")
		tapped.emit()
	elif state == "off":
		if _voip_only_active:
			_voip_only_active = false
			_finish_voip()
		ignored.emit(tr("voz desligada: ") + off_reason if not off_reason.is_empty() else tr("voz desligada nesta partida"))
	elif state in ["arming", "starting", "listening"] and not _private:
		end_talk()
	return true


func _process(_delta: float) -> void :
	if _native_capture():
		_process_native()
		return
	if _chat_active:
		if _chat_allowed(): _push_voip_capture(_read_capture())
		else: cancel_chat()
	match state:
		"listening":
			var captured: = _read_capture()
			_frames.append_array(captured)
			_push_voip_capture(captured)
			if _frames.size() >= _current_mix_rate() * float(_config.get("max_record_s", 8.0)):
				_tail_until = Time.get_ticks_msec()
				_set_state("thinking")
		"idle":
			if not _chat_active: _keep_pre_roll()
		"off":
			if not _chat_active and (capture_available() or not _injected_capture.is_empty()):
				var captured: = _read_capture()
				if _voip_only_active:
					_push_voip_capture(captured)
		"thinking", "warming":
			if _tail_until > 0:
				var captured: = _read_capture()
				_frames.append_array(captured)
				_push_voip_capture(captured)
				if Time.get_ticks_msec() >= _tail_until:
					_tail_until = 0
					_finish_listening()
				return
			if not _chat_active and (capture_available() or not _injected_capture.is_empty()):
				_read_capture()
			if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
				WorkerThreadPool.wait_for_task_completion(_task)
				_task = -1

				var text: = _task_text
				var seconds: = (Time.get_ticks_msec() - _task_started) / 1000.0
				var was_warming: = state == "warming"
				_set_state("idle")
				if was_warming:
					var problem: = _engine.error if _engine != null else ""
					VoiceDiagnostics.note("motor", "aquecido em %.1f s%s" % [(Time.get_ticks_msec() - _warm_started_ms) / 1000.0, 
						"" if problem.is_empty() else " · erro: " + problem])
				else:
					_finish_task(text, seconds)



func _read_capture() -> PackedVector2Array:
	var frames: = PackedVector2Array()
	if _mic_source:
		frames = MicSource.read(get_instance_id())
	elif _capture != null:
		frames = _capture.get_buffer(_capture.get_frames_available())
	if not _injected_capture.is_empty():
		frames.append_array(_injected_capture)
		_injected_capture.clear()
	if frames.is_empty():
		return frames
	var sum: = 0.0
	for frame in frames:
		var mono: = (frame.x + frame.y) * 0.5
		sum += mono * mono
	live_level = sqrt(sum / frames.size())
	return frames


func _current_mix_rate() -> float:
	if _injected_mix_rate > 0.0:
		return _injected_mix_rate

	if _mic_source:
		return MicSource.sample_rate()
	return maxf(AudioServer.get_mix_rate(), float(SpeechEngine.SAMPLE_RATE))


func _tap_max_s() -> float:
	return Lexicon.balf("extraction.tap_max_s") if _lex != null or is_instance_valid(Lexicon) else 0.22


func _begin_voip_session(private: bool, wait_tap: bool) -> void :
	_voip_pending_frames.clear()
	_voip_source_frames.clear()
	_voip_source_pos = 0.0
	if private:
		_voip_waiting_tap = false
		_voip_streaming = false
		return
	_voip_waiting_tap = wait_tap
	_voip_streaming = not wait_tap
	if _voip_streaming:
		voip_started.emit()


func _promote_voip_pending() -> void :
	if _private or not _voip_waiting_tap:
		return
	_voip_waiting_tap = false
	_voip_streaming = true
	voip_started.emit()
	if not _voip_pending_frames.is_empty():
		var pending: = _voip_pending_frames
		_voip_pending_frames = PackedVector2Array()
		_emit_voip_resampled(pending, false)


func _push_voip_capture(captured: PackedVector2Array) -> void :
	if _private:
		return
	if _voip_waiting_tap:
		if not captured.is_empty():
			_voip_pending_frames.append_array(captured)
		if _pressed_ms < 0 or held_seconds() > _tap_max_s():
			_promote_voip_pending()
		return
	if _voip_streaming and not captured.is_empty():
		_emit_voip_resampled(captured, false)


func _emit_voip_resampled(frames: PackedVector2Array, flush_tail: bool) -> void :
	if not frames.is_empty():
		_voip_source_frames.append_array(frames)
	var count: = _voip_source_frames.size()
	if count == 0:
		return
	var ratio: = _current_mix_rate() / float(SpeechEngine.SAMPLE_RATE)
	var out: = PackedFloat32Array()
	while int(_voip_source_pos) + 1 < count:
		var a: = int(_voip_source_pos)
		var frac: = _voip_source_pos - float(a)
		var fa: = _voip_source_frames[a]
		var fb: = _voip_source_frames[a + 1]
		var left: = (fa.x + fa.y) * 0.5
		var right: = (fb.x + fb.y) * 0.5
		out.append(lerpf(left, right, frac))
		_voip_source_pos += ratio
	if flush_tail and int(_voip_source_pos) < count:
		var last: = _voip_source_frames[int(_voip_source_pos)]
		out.append((last.x + last.y) * 0.5)
		_voip_source_frames.clear()
		_voip_source_pos = 0.0
	else:
		var consumed: = mini(int(_voip_source_pos), maxi(0, count - 1))
		if consumed > 0:
			_voip_source_frames = _voip_source_frames.slice(consumed)
			_voip_source_pos -= float(consumed)
	if not out.is_empty():
		voip_frames.emit(out)


func _finish_voip() -> void :
	if _private:
		_cancel_voip()
		return
	if _voip_waiting_tap:
		_promote_voip_pending()
	if _voip_streaming:
		_emit_voip_resampled(PackedVector2Array(), true)
		_voip_streaming = false
		voip_ended.emit()
	_voip_pending_frames.clear()
	_voip_source_frames.clear()
	_voip_source_pos = 0.0


func _cancel_voip() -> void :
	var was_streaming: = _voip_streaming
	_voip_waiting_tap = false
	_voip_streaming = false
	_voip_only_active = false
	_voip_pending_frames.clear()
	_voip_source_frames.clear()
	_voip_source_pos = 0.0
	if was_streaming:
		voip_ended.emit()



func _keep_pre_roll() -> void :
	if not capture_available() and _injected_capture.is_empty():
		return
	_pre_roll.append_array(_read_capture())
	var keep: = int(_current_mix_rate() * float(_config.get("pre_roll_s", 0.0)))
	if _pre_roll.size() > keep:
		_pre_roll = _pre_roll.slice(_pre_roll.size() - keep)


func _finish_listening() -> void :
	_finish_voip()
	var mix_rate: = _current_mix_rate()


	var wall_s: = (Time.get_ticks_msec() - _listen_started_ms) / 1000.0 + float(_config.get("pre_roll_s", 0.0))
	var audio_s: = _frames.size() / maxf(mix_rate, 1.0)
	_diag_utterance = "%s · %.2f s de áudio em %.2f s de relógio (%.0f%%) · %d quadros a %.0f Hz%s" % [
		"particular" if _private else "pedido", audio_s, wall_s, 100.0 * audio_s / maxf(wall_s, 0.001), _frames.size(), 
		mix_rate, "" if not _mic_source or MicSource.rate_measured() else " (taxa ainda não medida)"]
	if _frames.size() < mix_rate * float(_config.get("min_record_s", 0.35)):
		VoiceDiagnostics.note("fala", _diag_utterance + " · curta demais")
		_set_state("idle")
		_samples = PackedFloat32Array()
		last_level = 0.0
		utterance_done.emit(_info("", 0.0, tr("segurou pouco (segure enquanto fala)")))
		return


	_start_task(_frames, mix_rate, PackedFloat32Array(), true)
	_frames = PackedVector2Array()



func _finish_task(text: String, seconds: float) -> void :
	_samples = _task_samples
	last_level = _task_level
	heard.emit(_samples)
	if playback_enabled and not _private:
		play_back(_samples)
	if _task_gated:
		print("[Voz] ignorei: volume %.4f < mínimo %.4f" % [last_level, _min_speech_rms])
		VoiceDiagnostics.note("fala", "%s · volume %.4f < mínimo %.4f · barrada: %s" % [_diag_utterance, last_level, 
			_min_speech_rms, _silence_reason()])
		_done("", 0.0, _silence_reason())
		return
	var problem: = _engine.error if _engine != null else ""
	var clip_note: = ""
	if _task_clip >= 0.5:
		clip_note = " · MICROFONE ESTOURANDO (%.1f%% no teto): baixe o volume/ganho do microfone no sistema" % _task_clip
	VoiceDiagnostics.note("fala", "%s · volume %.4f · pico %.2f · motor %.2f s · %s%s%s" % [_diag_utterance, last_level, _task_peak, seconds, 
		"virou texto (%d letras)" % text.length() if not text.is_empty() else "SEM TEXTO", "" if problem.is_empty() else
		" · erro do motor: " + problem, clip_note])
	_done(text, seconds, "" if not text.is_empty() else tr("não entendi o áudio"))




func _silence_reason() -> String:
	if _mic_source and _injected_capture.is_empty():
		if not MicSource.is_active():
			return tr("o microfone não ligou (outro programa usando ou desconectado); escolha outro em Esc > VOZ")
		if MicSource.digital_silence():
			return tr("o microfone só manda silêncio (microfone virtual como Voicemod fechado, ou com 3+ canais); escolha outro em Esc > VOZ")
	return tr("não ouvi nada (fale mais alto ou baixe o volume mínimo no Esc)")



func _done(text: String, seconds: float, reason: String) -> void :
	if not _private:
		if reason.is_empty():
			if _command_only: command_transcribed.emit(text, seconds)
			else: transcribed.emit(text, seconds)
		else:
			ignored.emit(reason)
	utterance_done.emit(_info(text, seconds, reason))


func _info(text: String, seconds: float, reason: String) -> Dictionary:
	var info: = {"text": text, "seconds": seconds, "samples": _samples, "level": last_level, "private": _private, 
		"ignored": reason, "commands_only": _command_only}
	if _native_capture():
		info["native_capture"] = true
		info["ready_delay_s"] = last_ready_delay
	return info


func _native_capture() -> bool:
	return _engine != null and _engine.owns_microphone()


func _ensure_native_permission() -> bool:
	if _engine.microphone_permission():
		return true
	ignored.emit(tr("O microfone permite pedidos offline e conversa com a sala. Você pode continuar usando DIGITAR."))
	_engine.request_microphone_permission()
	return false


func _begin_native() -> bool:
	if not _ensure_native_permission():
		_set_state("idle")
		return false
	_stop_native_chat_microphone()
	_samples.clear()
	last_level = 0.0
	last_ready_delay = 0.0
	_native_started_ms = Time.get_ticks_msec()
	_set_state("starting")
	if not _engine.start_listening():
		_set_state("idle")
		ignored.emit(tr("voz offline indisponível; use DIGITAR"))
		return false
	return true


func _process_native() -> void :
	if _chat_active:
		if _chat_allowed(): _push_voip_capture(_read_capture())
		else: cancel_chat()
	if state == "arming" and held_seconds() > _tap_max_s():
		_begin_native()
	elif state in ["starting", "listening", "thinking"]:
		var elapsed: = (Time.get_ticks_msec() - _native_started_ms) / 1000.0
		if state == "listening" and elapsed > float(_config.get("max_record_s", 8.0)) + last_ready_delay:
			end_talk()
		elif elapsed > float(_config.get("max_record_s", 8.0)) + 15.0:
			_engine.cancel_listening()
			_set_state("idle")
			_done("", elapsed, tr("o reconhecedor offline demorou; tente novamente ou use DIGITAR"))


func _on_native_availability(available: bool, reason: String) -> void :
	if available:
		off_reason = ""
		if state in ["off", "warming"]: _set_state("idle")
	else:
		_turn_off(reason)


func _on_native_ready(delay_seconds: float) -> void :
	if state != "starting": return
	last_ready_delay = delay_seconds
	_set_state("listening")


func _on_native_result(text: String, seconds: float, reason: String) -> void :
	if state not in ["starting", "listening", "thinking"]: return

	_done(text, seconds, reason)
	_set_state("idle")


func _stop_native_chat_microphone() -> void :
	if _native_capture() and _mic != null:
		_mic.stop()
		_clear_chat_capture()


func open_offline_settings() -> void :
	if _engine != null: _engine.open_offline_settings()



func share_diagnostics() -> void :
	if _engine is AndroidSpeechEngine:
		(_engine as AndroidSpeechEngine).note_diagnostics("compartilhado pelo jogador")
	if Engine.has_singleton(AndroidSpeechEngine.SINGLETON):
		Engine.get_singleton(AndroidSpeechEngine.SINGLETON).call("shareText", "LAVOICE - diagnóstico da voz", 
			VoiceDiagnostics.current_text())




func _start_task(frames: PackedVector2Array, mix_rate: float, samples: PackedFloat32Array, gate: bool) -> void :
	_task_text = ""
	_task_gated = false
	_task_started = Time.get_ticks_msec()
	_task = WorkerThreadPool.add_task(_run_engine.bind(frames, mix_rate, samples, gate), true, "voz")


func _run_engine(frames: PackedVector2Array, mix_rate: float, samples: PackedFloat32Array, gate: bool) -> void :
	var audio: = samples if frames.is_empty() else SpeechEngine.to_mono_16k(frames, mix_rate)
	_task_samples = audio
	_task_level = SpeechEngine.loudest_rms(audio, float(_config.get("speech_window_s", 0.03)))

	var clipped: = 0
	_task_peak = 0.0
	for sample in audio:
		var a: = absf(sample)
		_task_peak = maxf(_task_peak, a)
		if a >= 0.98:
			clipped += 1
	_task_clip = 100.0 * clipped / maxf(audio.size(), 1.0)
	if gate and _task_level < _min_speech_rms:
		_task_gated = true
		return
	_task_text = _engine.transcribe(audio)




func _open_microphone() -> void :
	if not _native_capture():
		if not _mic_source:
			_mic_source = true
			capture_opens += 1
			if not MicSource.acquire(get_instance_id()):
				push_warning("[Voz] o microfone não ligou agora; tentando de novo sozinho")
		return
	if _capture != null and _mic != null:
		if _native_capture() and not _mic.playing: _mic.play()
		return
	var bus_name: = String(_config.get("capture_bus", "VoiceCapture"))
	var bus: = AudioServer.get_bus_index(bus_name)
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, bus_name)
	AudioServer.set_bus_mute(bus, true)
	_capture = null
	for i in AudioServer.get_bus_effect_count(bus):
		var effect: = AudioServer.get_bus_effect(bus, i)
		if effect is AudioEffectCapture:
			_capture = effect as AudioEffectCapture
			_capture.clear_buffer()
			break
	if _capture == null:
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = CAPTURE_BUFFER_S
		AudioServer.add_bus_effect(bus, _capture)
	if _mic == null:
		_mic = AudioStreamPlayer.new()
		_mic.name = "Microphone"
		_mic.stream = AudioStreamMicrophone.new()
		_mic.bus = bus_name
		add_child(_mic)
	if not _mic.playing:
		_mic.play()
	capture_opens += 1



func _exit_tree() -> void :
	cancel_chat()
	_cancel_voip()
	if _mic != null and _mic.playing:
		_mic.stop()
	if _mic_source:
		MicSource.release(get_instance_id())
		_mic_source = false
	if _engine != null:
		_engine.shutdown()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _turn_off(reason: String) -> void :
	off_reason = reason
	VoiceDiagnostics.note("voz", "DESLIGADA: " + reason)
	push_warning("[Voz] desligada: " + reason)
	_set_state("off")


func _set_state(new_state: String) -> void :
	state = new_state
	state_changed.emit(state)
