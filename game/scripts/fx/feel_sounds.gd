class_name FeelSounds
extends RefCounted






const MIX_RATE: = 22050
const STEP_VARIANTS: = 3
const FIRE_IDS: = ["weapons/fire_light", "weapons/fire_medium", "weapons/fire_heavy"]

static var _cache: Dictionary = {}


static func step(variant: int) -> AudioStream:
	return SoundBank.pick("player/step", _stream("step%d" % posmod(variant, STEP_VARIANTS)))


static func land() -> AudioStream:
	return SoundBank.pick("player/land", _stream("land"))


static func slide() -> AudioStream:
	return SoundBank.pick("player/slide_loop", _stream("slide"))


static func jump() -> AudioStream:
	return SoundBank.pick("player/jump", _stream("jump"))


static func hit() -> AudioStream:
	return SoundBank.pick("impacts/hit_marker", _stream("hit"))


static func kill() -> AudioStream:
	return SoundBank.pick("impacts/kill_marker", _stream("kill"))


static func metal_hit() -> AudioStream:
	return SoundBank.pick("impacts/metal", _stream("metal"))


static func extract_loop() -> AudioStream:
	return SoundBank.pick("matter/extract_loop", _stream("extract"))



static func fallback_for(id: String) -> AudioStream:
	match id:
		"impacts/metal": return _stream("metal")
		"impacts/hit_marker": return _stream("hit")
		"impacts/kill_marker": return _stream("kill")
		"player/jump": return _stream("jump")
		"player/land": return _stream("land")
	return fallback(id)



static func fallback(id: String) -> AudioStream:
	match id:
		"weapons/fire_light": return _stream("fire0")
		"weapons/fire_medium": return _stream("fire1")
		"weapons/fire_heavy": return _stream("fire2")
		"impacts/explosion": return _stream("explosion")
		"weapons/swing": return _stream("swing")
		"impacts/break": return _stream("break")
		"match/countdown": return _stream("beep")
		"match/go": return _stream("go")
	return null



static func play_at(parent: Node, stream: AudioStream, at: Vector3, volume_db: float, pitch: float = 1.0) -> void :
	if parent == null or not parent.is_inside_tree() or stream == null:
		return
	var player: = AudioStreamPlayer3D.new()
	player.bus = AudioMix.bus(AudioMix.EFFECTS)
	player.stream = stream
	player.volume_db = volume_db + SoundBank.gain(stream)
	player.pitch_scale = pitch
	player.unit_size = 6.0
	parent.add_child(player)
	player.global_position = at
	player.finished.connect(player.queue_free)
	player.play()


static func _stream(id: String) -> AudioStreamWAV:
	if not _cache.has(id):
		_cache[id] = _synth(id)
	return _cache[id]


static func _synth(id: String) -> AudioStreamWAV:
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(id)
	var variant: = int(id.trim_prefix("step")) if id.begins_with("step") else 0
	var weight: = int(id.trim_prefix("fire")) if id.begins_with("fire") else 0
	var seconds: float = {"land": 0.4, "slide": 0.8, "jump": 0.11, "hit": 0.06, "kill": 0.2, "fire0": 0.2, "fire1": 0.32, 
		"fire2": 0.75, "explosion": 1.6, "swing": 0.22, "break": 0.3, "beep": 0.14, "go": 0.42, "extract": 1.0}.get(id, 0.2)
	var count: = int(seconds * MIX_RATE)
	var bytes: = PackedByteArray()
	bytes.resize(count * 2)
	var low: = 0.0
	var lower: = 0.0
	var band: = 0.0
	var phase_thump: = 0.0
	for i in count:
		var t: = float(i) / MIX_RATE
		var noise: = rng.randf_range(-1.0, 1.0)
		low += 0.08 * (noise - low)
		lower += 0.02 * (noise - lower)
		band += 0.35 * (noise - band)
		var value: = 0.0
		if id.begins_with("step"):

			phase_thump += TAU * (95.0 - 40.0 * minf(t / 0.05, 1.0)) / MIX_RATE
			var thump: = sin(phase_thump) * exp( - t * 38.0)
			var click: = band * exp( - t * 160.0)
			var ping: = (sin(TAU * (1250.0 + variant * 110.0) * t) * 0.6 + sin(TAU * (1890.0 + variant * 70.0) * t) * 0.4) * exp( - t * 34.0)
			value = thump * 0.7 + click * 0.45 + ping * 0.18
		elif id == "land":
			phase_thump += TAU * (70.0 - 30.0 * minf(t / 0.08, 1.0)) / MIX_RATE
			var thump: = sin(phase_thump) * exp( - t * 16.0)
			var crunch: = low * 2.2 * exp( - t * 18.0)
			var clank: = sin(TAU * 980.0 * t) * sin(TAU * 1460.0 * t) * exp( - t * 22.0)
			value = thump * 0.8 + crunch * 0.35 + clank * 0.25
		elif id == "slide":

			value = (low * 1.6 + band * 0.25) * (0.85 + 0.15 * sin(TAU * 13.0 * t))
		elif id == "jump":

			phase_thump += TAU * (85.0 + 60.0 * minf(t / 0.06, 1.0)) / MIX_RATE
			var push: = sin(phase_thump) * exp( - t * 34.0)
			var servo: = sin(TAU * (420.0 + 900.0 * t) * t) * exp( - t * 45.0)
			value = push * 0.65 + servo * 0.16 + low * 0.25 * exp( - t * 60.0)
		elif id == "hit":
			value = (sin(TAU * 3400.0 * t) * 0.7 + noise * 0.3) * exp( - t * 90.0)
		elif id == "metal":
			value = (sin(TAU * 620.0 * t) * 0.45 + sin(TAU * 1037.0 * t) * 0.3 + sin(TAU * 1811.0 * t) * 0.2) * exp( - t * 18.0)
		elif id == "kill":
			var tick1: = sin(TAU * 3400.0 * t) * exp( - t * 90.0)
			var tick2: = sin(TAU * 4200.0 * (t - 0.05)) * exp( - (t - 0.05) * 90.0) if t > 0.05 else 0.0
			var body: = sin(TAU * 520.0 * t) * exp( - t * 14.0)
			value = tick1 * 0.6 + tick2 * 0.6 + body * 0.35
		elif id.begins_with("fire"):

			var decay: float = [42.0, 24.0, 8.0][weight]
			var from_hz: float = [190.0, 140.0, 90.0][weight]
			phase_thump += TAU * (from_hz - from_hz * 0.6 * minf(t / 0.06, 1.0)) / MIX_RATE
			var punch: = sin(phase_thump) * exp( - t * decay * 0.9)
			var crack: = noise * exp( - t * 400.0)
			var body: = (band * 0.7 + low * 0.9) * exp( - t * decay)
			var tail: = lower * 3.0 * exp( - t * decay * 0.35) * (0.4 + 0.3 * weight)
			value = punch * 0.75 + crack * 0.6 + body * 0.8 + tail * 0.5
		elif id == "explosion":

			phase_thump += TAU * (62.0 - 34.0 * minf(t / 0.3, 1.0)) / MIX_RATE
			var boom: = sin(phase_thump) * exp( - t * 4.5)
			var rumble: = lower * 5.0 * exp( - t * 2.6)
			var crack: = noise * exp( - t * 60.0)
			value = boom * 0.85 + rumble * 0.7 + crack * 0.45 + low * 0.6 * exp( - t * 9.0)
		elif id == "swing":

			var shape: = sin(PI * t / seconds)
			value = (band * 0.6 + sin(TAU * (700.0 + 500.0 * t / seconds) * t) * 0.08) * shape * shape
		elif id == "break":

			phase_thump += TAU * 130.0 / MIX_RATE
			var crunch: = band * exp( - t * 16.0) * (0.6 + 0.4 * signf(sin(TAU * 37.0 * t)))
			value = crunch * 0.7 + sin(phase_thump) * exp( - t * 30.0) * 0.5
		elif id == "beep":
			value = (sin(TAU * 880.0 * t) * 0.6 + sin(TAU * 1760.0 * t) * 0.15) * minf(t / 0.005, 1.0) * exp( - t * 14.0)
		elif id == "go":
			value = (sin(TAU * 1320.0 * t) * 0.5 + sin(TAU * 660.0 * t) * 0.35) * minf(t / 0.005, 1.0) * exp( - t * 6.0)
		elif id == "extract":

			var hum: = sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 220.0 * t) * 0.25 + sin(TAU * 333.0 * t) * 0.1
			value = (hum * (0.75 + 0.25 * sin(TAU * 6.0 * t)) + band * 0.12) * 0.6
		value *= minf(t / 0.002, 1.0)
		bytes.encode_s16(i * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if id in ["slide", "extract"]:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = count
	return wav
