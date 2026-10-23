class_name IntroSound
extends RefCounted


static func make_bank(cfg: Dictionary) -> Dictionary:
	var bank: Dictionary = {}
	var rate: = int(cfg["sample_rate"])
	for kind: String in ["whoosh", "rise", "impact"]:
		var duration: = float(cfg[kind + "_s"])
		var samples: = roundi(duration * rate)
		var bytes: = PackedByteArray()
		bytes.resize(samples * 2)
		var rng: = RandomNumberGenerator.new()
		rng.seed = int(cfg["seed"])
		var filtered: = 0.0
		var phase: = 0.0
		for i in samples:
			var t: = float(i) / rate
			var u: = t / duration
			var white: = rng.randf_range(-1.0, 1.0)
			filtered = lerpf(filtered, white, 0.12)
			var value: = 0.0
			if kind == "impact":
				phase += TAU * lerpf(float(cfg["low_hz"]) * 1.8, float(cfg["low_hz"]), u) / rate
				value = (sin(phase) * 0.7 + filtered * 0.3) * exp( - u * 8.0) * minf(t * 1000.0, 1.0)
			else:
				var envelope: = pow(sin(PI * u), 2.0) if kind == "whoosh" else u * u * (1.0 - pow(u, 12.0))
				phase += TAU * lerpf(float(cfg["low_hz"]) * 2.0, float(cfg["high_hz"]), u * u) / rate
				value = (filtered * 0.85 + sin(phase) * 0.06) * envelope
			bytes.encode_s16(i * 2, clampi(roundi(value * 32767.0), -32768, 32767))
		var stream: = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = bytes
		bank[kind] = stream
	return bank
