class_name SpeechEngine
extends RefCounted




const SAMPLE_RATE: = 16000


const REPEAT_MAX_WORDS: = 10

const LOOP_MIN_WORDS: = 2


var error: String = ""


func is_available(_config: Dictionary) -> bool:
	return false



func setup(_config: Dictionary, _lex: LexiconData, _parent: Node) -> bool:
	return false



func transcribe(_samples: PackedFloat32Array) -> String:
	return ""



func shutdown() -> void :
	pass




static func clean(text: String) -> String:
	var out: = text
	for pair in [["[", "]"], ["<", ">"], ["(", ")"]]:
		var start: = out.find(pair[0])
		while start >= 0:
			var end: = out.find(pair[1], start + 1)
			if end < 0:
				break
			out = out.substr(0, start) + out.substr(end + 1)
			start = out.find(pair[0])
	var words: = Array(out.strip_edges().split(" ", false))
	for size in range(1, REPEAT_MAX_WORDS + 1):
		var i: = 0
		while i + 2 * size <= words.size():
			if Normalizer.fold(" ".join(words.slice(i, i + size))) == Normalizer.fold(" ".join(words.slice(i + size, i + 2 * size))):
				for k in size:
					words.remove_at(i + size)
			else:
				i += 1



	var whole: = Normalizer.fold(" ".join(words))
	for i in range(LOOP_MIN_WORDS, words.size() - LOOP_MIN_WORDS + 1):
		if whole.begins_with(Normalizer.fold(" ".join(words.slice(i)))):
			words = words.slice(0, i)
			break
	return " ".join(words).strip_edges()



static func loudest_rms(samples: PackedFloat32Array, window_s: float) -> float:
	var window: = maxi(1, int(SAMPLE_RATE * window_s))
	var best: = 0.0
	var start: = 0
	while start < samples.size():
		var stop: = mini(start + window, samples.size())
		var sum: = 0.0
		for i in range(start, stop):
			sum += samples[i] * samples[i]
		best = maxf(best, sqrt(sum / (stop - start)))
		start = stop
	return best



static func to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var wav: = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav



static func to_mono_16k(frames: PackedVector2Array, mix_rate: float) -> PackedFloat32Array:
	var count: = frames.size()
	var out: = PackedFloat32Array()
	if count == 0:
		return out
	var ratio: = mix_rate / SAMPLE_RATE
	var total: = int(count / ratio)
	out.resize(total)
	for i in total:
		var src: = i * ratio
		var a: = int(src)
		var b: = mini(a + 1, count - 1)
		var left: = (frames[a].x + frames[a].y) * 0.5
		var right: = (frames[b].x + frames[b].y) * 0.5
		out[i] = lerpf(left, right, src - a)
	return out
