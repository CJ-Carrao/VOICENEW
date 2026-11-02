class_name MicSource
extends RefCounted

















const STANDARD_RATES: Array[float] = [8000.0, 11025.0, 16000.0, 22050.0, 24000.0, 32000.0, 44100.0, 48000.0, 88200.0, 
	96000.0, 176400.0, 192000.0]

const SNAP_TOLERANCE: = 0.03

const MEASURE_WARMUP_S: = 0.4
const MEASURE_MIN_S: = 1.0


const STALL_S: = 0.75

const QUEUE_MAX_S: = 2.0

const DIGITAL_SILENCE_S: = 1.5

const RETRY_S: = 1.0

static var _users: Dictionary = {}
static var _active: = false
static var _polled_frame: = -1
static var _last_poll_us: = 0
static var _measure_start_us: = 0
static var _measure_frames: = 0
static var _rate: = 0.0
static var _zero_run: = 0

static var _fallback_rate: = 0.0
static var _last_try_us: = 0

static var _noted_rate: = 0.0
static var _noted_silence: = false
static var _noted_output: = ""
static var _noted_mix_rate: = 0
static var _noted_input: = ""
static var _last_watch_us: = 0




static func acquire(user: int) -> bool:
	if not _users.has(user):
		_users[user] = PackedVector2Array()
		VoiceDiagnostics.note("mic", "usuário %d pediu o microfone (%d ouvindo)" % [user, _users.size()])
	if not _active:
		_try_activate()
	return _active



static func release(user: int) -> void :
	if not _users.has(user):
		return
	_users.erase(user)
	VoiceDiagnostics.note("mic", "usuário %d soltou o microfone (%d ouvindo)" % [user, _users.size()])
	if _users.is_empty() and _active:
		AudioServer.set_input_device_active(false)
		_active = false
		VoiceDiagnostics.note("mic", "ninguém ouvindo: microfone desligado")



static func is_wanted(user: int) -> bool:
	return _users.has(user)


static func is_active() -> bool:
	return _active



static func read(user: int) -> PackedVector2Array:
	poll()
	if not _users.has(user):
		return PackedVector2Array()
	var frames: PackedVector2Array = _users[user]
	_users[user] = PackedVector2Array()
	return frames



static func clear(user: int) -> void :
	if _users.has(user):
		_users[user] = PackedVector2Array()



static func poll() -> void :
	var frame: = Engine.get_process_frames()
	if frame == _polled_frame or _users.is_empty():
		return
	_polled_frame = frame
	var now: = Time.get_ticks_usec()
	if now - _last_watch_us >= 1000000:
		_last_watch_us = now
		_watch_devices()
	if not _active:
		if now - _last_try_us >= int(RETRY_S * 1000000.0):
			_try_activate()
		return
	var gap_us: = now - _last_poll_us if _last_poll_us > 0 else 0
	var stalled: = gap_us > int(STALL_S * 1000000.0)
	_last_poll_us = now
	var available: = AudioServer.get_input_frames_available()
	if available <= 0:
		return
	var frames: = AudioServer.get_input_frames(available)
	if stalled:

		VoiceDiagnostics.note("mic", "travada de %d ms: descartei %d quadros velhos" % [gap_us / 1000, frames.size()])
		_restart_measure()
		return
	_measure(frames.size(), now)
	_watch_silence(frames)
	if digital_silence() != _noted_silence:
		_noted_silence = not _noted_silence
		VoiceDiagnostics.note("mic", "silêncio digital (só zeros exatos)" if _noted_silence else "o microfone voltou a mandar som")
	var keep: = int(sample_rate() * QUEUE_MAX_S)
	for user: int in _users:
		var queue: PackedVector2Array = _users[user]
		queue.append_array(frames)
		if queue.size() > keep:
			queue = queue.slice(queue.size() - keep)
		_users[user] = queue



static func sample_rate() -> float:
	if _rate > 0.0:
		return _rate
	if _fallback_rate <= 0.0:
		_fallback_rate = AudioServer.get_input_mix_rate()
	return _fallback_rate



static func rate_measured() -> bool:
	return _rate > 0.0



static func snap_rate(measured: float) -> float:
	var best: = measured
	var best_error: = SNAP_TOLERANCE
	for rate in STANDARD_RATES:
		var error: = absf(measured / rate - 1.0)
		if error < best_error:
			best_error = error
			best = rate
	return best



static func digital_silence() -> bool:
	return _active and _zero_run >= int(sample_rate() * DIGITAL_SILENCE_S)



static func switch_device(device: String) -> void :
	var was_active: = _active
	if was_active:
		AudioServer.set_input_device_active(false)
		_active = false
	AudioServer.input_device = device
	VoiceDiagnostics.note("mic", "troca de microfone pedida: %s" % device)
	for user: int in _users:
		_users[user] = PackedVector2Array()
	_rate = 0.0
	if was_active or not _users.is_empty():
		_try_activate()
	else:
		_restart_measure()


static func _try_activate() -> void :
	_last_try_us = Time.get_ticks_usec()
	var err: = AudioServer.set_input_device_active(true)
	_active = err == OK
	if not _active:

		AudioServer.set_input_device_active(false)
		VoiceDiagnostics.note_repeat("mic_fail", "mic", "não ligou: %s · aparelho %s" % [error_string(err), AudioServer.input_device])
	else:

		VoiceDiagnostics.note("mic", "ligado · buffer %d quadros · Godot diz %d Hz" % [AudioServer.get_input_buffer_length_frames(), 
			AudioServer.get_input_mix_rate()])
	_restart_measure()


static func _restart_measure() -> void :
	_measure_start_us = 0
	_measure_frames = 0
	_last_poll_us = 0
	_zero_run = 0
	_fallback_rate = 0.0



static func _measure(count: int, now: int) -> void :
	if _measure_start_us == 0:
		_measure_start_us = now
		_measure_frames = -1
		return
	if _measure_frames < 0:
		if (now - _measure_start_us) / 1000000.0 >= MEASURE_WARMUP_S:
			_measure_start_us = now
			_measure_frames = 0
		return
	_measure_frames += count
	var window: = (now - _measure_start_us) / 1000000.0
	if window >= MEASURE_MIN_S:
		var raw: = _measure_frames / window
		_rate = snap_rate(raw)
		if _rate != _noted_rate:
			_noted_rate = _rate
			VoiceDiagnostics.note("mic", "taxa medida %.0f Hz (bruto %.0f em %.1f s; o Godot diz %d)" % [_rate, raw, window, 
				AudioServer.get_input_mix_rate()])




static func _watch_devices() -> void :
	var output: = AudioServer.output_device
	var mix: = AudioServer.get_mix_rate()
	var input: = AudioServer.input_device
	if output != _noted_output or mix != _noted_mix_rate or input != _noted_input:
		var first: = _noted_output.is_empty()
		VoiceDiagnostics.note("audio", "%s saída %s · mix_rate %d · microfone %s" % ["agora:" if first else "MUDOU:", output, 
			mix, input])
		_noted_output = output
		_noted_mix_rate = mix
		_noted_input = input


static func _watch_silence(frames: PackedVector2Array) -> void :
	for f in frames:
		if f.x == 0.0 and f.y == 0.0:
			_zero_run += 1
		else:
			_zero_run = 0
