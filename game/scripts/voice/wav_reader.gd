class_name WavReader
extends RefCounted




static func read_16k_mono(path: String) -> PackedFloat32Array:
	var bytes: = FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44:
		return PackedFloat32Array()
	var channels: = bytes.decode_u16(22)
	var rate: = float(bytes.decode_u32(24))
	var pos: = 12
	while pos < bytes.size() - 8:
		var id: = bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size: = bytes.decode_u32(pos + 4)
		if id == "data":
			var count: = size / (2 * channels)
			var frames: = PackedVector2Array()
			frames.resize(count)
			for i in count:
				var left: = bytes.decode_s16(pos + 8 + i * channels * 2) / 32768.0
				var right: = bytes.decode_s16(pos + 8 + (i * channels + channels - 1) * 2) / 32768.0
				frames[i] = Vector2(left, right)
			return SpeechEngine.to_mono_16k(frames, rate)
		pos += 8 + size + (size % 2)
	return PackedFloat32Array()
