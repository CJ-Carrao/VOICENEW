class_name SherpaEngine
extends SpeechEngine








const READY_LINE: = "READY"
const ERROR_PREFIX: = "ERROR"

var _pid: int = -1
var _pipe: FileAccess
var _loaded: bool = false
var _mutex: = Mutex.new()


func is_available(config: Dictionary) -> bool:
	for key in ["sidecar", "model"]:
		var path: = String(config.get(key, ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			error = "motor de voz sem travar não instalado: falta %s (tools/voice/setup_voice.ps1)" % path
			return false
	return true


func setup(config: Dictionary, lex: LexiconData, _parent: Node) -> bool:
	if not is_available(config):
		return false
	var model_dir: = ProjectSettings.globalize_path(String(config["model_dir"]))
	var args: = PackedStringArray([
		"--tokens=" + model_dir.path_join("tokens.txt"), 
		"--encoder=" + model_dir.path_join(String(config.get("encoder", "encoder.int8.onnx"))), 
		"--decoder=" + model_dir.path_join(String(config.get("decoder", "decoder.int8.onnx"))), 
		"--joiner=" + model_dir.path_join(String(config.get("joiner", "joiner.int8.onnx"))), 
		"--model-type=" + String(config.get("model_type", "nemo_transducer")), 
		"--threads=%d" % int(config.get("threads", 3)), 
	])
	if config.get("hotwords", false):
		var file: = _write_hotwords(lex)
		if not file.is_empty():
			args.append("--hotwords=" + file)
			args.append("--hotwords-score=%s" % float(config.get("hotwords_score", 1.5)))
			args.append("--bpe-vocab=" + ProjectSettings.globalize_path("user://voice/%s.bpe.vocab" % String(config["model_dir"]).get_file()))
	var denoiser: = String(config.get("denoiser", ""))
	if not denoiser.is_empty():
		args.append("--denoiser-%s=%s" % [String(config.get("denoiser_kind", "gtcrn")), ProjectSettings.globalize_path(denoiser)])
	var started: = OS.execute_with_pipe(ProjectSettings.globalize_path(String(config["sidecar"])), args)
	if started.is_empty():
		error = "não consegui abrir o motor de voz (%s)" % config["sidecar"]
		return false
	_pipe = started["stdio"]
	_pid = int(started["pid"])
	return true




func transcribe(samples: PackedFloat32Array) -> String:
	_mutex.lock()
	var text: = _transcribe_locked(samples)
	_mutex.unlock()
	return text


func _transcribe_locked(samples: PackedFloat32Array) -> String:
	if _pipe == null or samples.is_empty():
		return ""
	if not _loaded and not _wait_ready():
		return ""
	var packet: = PackedByteArray()
	packet.resize(4)
	packet.encode_s32(0, samples.size())
	packet.append_array(samples.to_byte_array())
	_pipe.store_buffer(packet)
	var line: = _pipe.get_line()
	if line.is_empty():
		error = "o motor de voz parou"
		_loaded = false
		_pipe = null
		return ""
	var reply: Variant = JSON.parse_string(line)
	if not reply is Dictionary:
		return ""
	return clean(String((reply as Dictionary).get("text", "")))


func _wait_ready() -> bool:
	while true:
		var line: = _pipe.get_line().strip_edges()
		if line == READY_LINE:
			_loaded = true
			return true
		if line.begins_with(ERROR_PREFIX) or (line.is_empty() and _pipe.eof_reached()):
			error = "motor de voz: " + (line if not line.is_empty() else "fechou ao carregar")
			_pipe = null
			return false
	return false




func shutdown() -> void :
	if _mutex.try_lock():
		if _pipe != null:
			var stop: = PackedByteArray()
			stop.resize(4)
			stop.encode_s32(0, 0)
			_pipe.store_buffer(stop)
			_pipe.close()
			_pipe = null
		_mutex.unlock()
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_loaded = false



func _write_hotwords(lex: LexiconData) -> String:
	DirAccess.make_dir_recursive_absolute("user://voice")
	var path: = "user://voice/hotwords.txt"
	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string("\n".join(VoiceVocabulary.hotwords(lex)) + "\n")
	file.close()
	return ProjectSettings.globalize_path(path)
