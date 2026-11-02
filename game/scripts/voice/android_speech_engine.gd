class_name AndroidSpeechEngine
extends SpeechEngine





const SINGLETON: = "LavoiceAndroidSpeech"
var _plugin: Object
var _available: = false
var _active: = false
var _generation: = 0


func owns_microphone() -> bool:
	return true


func is_available(_config: Dictionary) -> bool:
	if not Engine.has_singleton(SINGLETON):
		error = tr("voz offline do Android indisponível nesta build; use DIGITAR")
		return false
	return true


func setup(_config: Dictionary, lex: LexiconData, _parent: Node) -> bool:
	if not is_available(_config):
		return false
	_plugin = Engine.get_singleton(SINGLETON)
	_plugin.connect("speech_availability", _on_availability, CONNECT_DEFERRED)
	_plugin.connect("speech_ready", _on_ready, CONNECT_DEFERRED)
	_plugin.connect("speech_result", _on_result, CONNECT_DEFERRED)



	_plugin.call("setLanguage", Lexicon.speech_tag())
	if OS.is_debug_build():
		var tag: = Lexicon.speech_tag()
		for argument: String in MobileDev.args():
			if argument.begins_with("--voz-idioma="):
				tag = argument.trim_prefix("--voz-idioma=")
		if tag != Lexicon.speech_tag() or MobileDev.args().has("--voz-online"):
			_plugin.call("configure", tag, not MobileDev.args().has("--voz-online"))
	_plugin.call("prepare", VoiceVocabulary.hotwords(lex))
	return true




static func android_api() -> int:
	if Engine.has_singleton(SINGLETON):
		return int(Engine.get_singleton(SINGLETON).call("sdkInt"))
	return 0


func start_listening() -> bool:
	if not _available or _plugin == null or _active:
		return false
	_generation += 1
	_active = true
	_plugin.call("startListening", _generation)
	return true


func stop_listening() -> void :
	if _plugin != null and _active:
		_plugin.call("stopListening", _generation)


func cancel_listening() -> void :
	_active = false
	_generation += 1
	if _plugin != null:
		_plugin.call("cancelListening")


func microphone_permission() -> bool:
	return not OS.has_feature("android") or "android.permission.RECORD_AUDIO" in OS.get_granted_permissions()


func request_microphone_permission() -> void :
	if _plugin != null:
		_plugin.call("requestMicrophonePermission")
	elif OS.has_feature("android"):

		OS.request_permission("android.permission.RECORD_AUDIO")


func open_offline_settings() -> void :
	if _plugin != null:
		_plugin.call("openOfflineSettings")



func note_diagnostics(why: String) -> void :
	if _plugin != null:
		VoiceDiagnostics.note("android", """%s
%s""" %[why, String(_plugin.call("diagnostics"))])


func _on_availability(available: bool, reason: String) -> void :
	note_diagnostics("disponível" if available else "indisponível: " + reason)
	_available = available
	error = tr(reason)
	availability_changed.emit(available, reason)


func _on_ready(generation: int, delay_ms: int) -> void :
	if _active and generation == _generation:
		listening_ready.emit(delay_ms / 1000.0)


func _on_result(generation: int, text: String, elapsed_ms: int, reason: String) -> void :
	if not _active or generation != _generation:
		return
	_active = false
	if not reason.is_empty():
		note_diagnostics("fala sem texto: " + reason)
	recognition_finished.emit(clean(text), elapsed_ms / 1000.0, tr(reason))


func shutdown() -> void :
	cancel_listening()
	if _plugin == null:
		return
	for pair in [["speech_availability", _on_availability], ["speech_ready", _on_ready], ["speech_result", _on_result]]:
		if _plugin.is_connected(pair[0], pair[1]):
			_plugin.disconnect(pair[0], pair[1])
	_plugin.call("shutdown")
	_plugin = null
