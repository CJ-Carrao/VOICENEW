class_name RobotFace
extends RefCounted







var material: ShaderMaterial
var current: String = "Neutral"
var _data: Dictionary
var _clock: float = 0.0
var _from: Dictionary = {}
var _to: Dictionary = {}
var _start: float = 0.0
var _duration: float = 0.18
var _talking: bool = false
var _seed: int = 1701
var _fix_index: int = 0
var _fix_start: float = 0.0
var _fix_end: float = 0.0


func _init(face_material: ShaderMaterial, data: Dictionary, seed_value: int) -> void :
	material = face_material
	_data = data
	_seed = int(data.get("seed", 1701)) + seed_value * 7919
	_to = (data["expressions"]["Neutral"] as Dictionary).duplicate(true)
	_from = _to.duplicate(true)
	var g: Dictionary = data["globals"]
	material.set_shader_parameter("eye_color", _vec3(g["color"]))
	material.set_shader_parameter("background_color", _vec3(g["background"]))
	material.set_shader_parameter("brightness", float(g["brightness"]))
	material.set_shader_parameter("separation", float(g["separation"]))
	_fix_end = _fixation_length(0)
	advance(0.0)


func set_expression(expression: String) -> void :
	if expression == current or not (_data["expressions"] as Dictionary).has(expression):
		return
	_from = _blended()
	_to = (_data["expressions"][expression] as Dictionary).duplicate(true)
	current = expression
	_start = _clock
	_duration = float(_to.get("transition_s", 0.18))
	_talking = expression == "Talking"



func head_tilt() -> float:
	var f: = _progress()
	return deg_to_rad(lerpf(float(_from.get("head_tilt_deg", 0.0)), float(_to.get("head_tilt_deg", 0.0)), f))


func advance(delta: float) -> void :
	_clock += delta
	var blink: Dictionary = _data["blink"]
	var gaze: Dictionary = _data["gaze"]
	var openness: = _auto_blink(blink)

	while _clock >= _fix_end:
		_fix_index += 1
		_fix_start = _fix_end
		_fix_end = _fix_start + _fixation_length(_fix_index)
	var before: = _gaze_point(maxi(0, _fix_index - 1))
	var next: = _gaze_point(_fix_index)
	var degrees: = before.distance_to(next) / float(gaze["uv_per_degree"])
	var range_s: Array = gaze["duration_range_s"]
	var saccade: = clampf(float(gaze["duration_intercept_s"]) + degrees * float(gaze["duration_per_degree_s"]), 
		float(range_s[0]), float(range_s[1]))
	var look: = before.lerp(next, smoothstep(0.0, saccade, _clock - _fix_start))
	look += Vector2(sin(_clock * 2.7), sin(_clock * 3.3)) * float(gaze["micro_uv"])
	if before.distance_to(next) > float(gaze["large_change_blink_threshold_uv"]):
		openness = minf(openness, _blink_open(_clock - _fix_start, blink))
	material.set_shader_parameter("gaze", look)
	var expr: = _blended()
	for side: String in ["L", "R"]:
		var e: Dictionary = expr[side]
		var h: = float(e["height"]) * (1.0 + 0.05 * sin(_clock * 12.0) if _talking else 1.0)
		var center: Array = e["center"]
		material.set_shader_parameter("rect_" + side, Vector4(float(center[0]), float(center[1]), float(e["width"]), h))
		material.set_shader_parameter("shape_" + side, Vector4(float(e["rounding"]), float(e["rotation"]), float(e["arc"]), openness))
		for lid: String in ["top", "bottom"]:
			material.set_shader_parameter(lid + "_" + side, _vec3(e[lid]))


func _auto_blink(blink: Dictionary) -> float:
	var rate: = float(blink["talk_per_minute"] if _talking else blink["rest_per_minute"])
	var period: = 60.0 / rate
	var cycle: = floori(_clock / period)
	var open: = 1.0
	for k in range(maxi(0, cycle - 1), cycle + 1):
		var event: = k * period + 0.4 + _noise(k, 12) * (period - 0.9)
		open = minf(open, _blink_open(_clock - event, blink))
		if _noise(k, 22) < float(blink["double_probability"]):
			open = minf(open, _blink_open(_clock - event - float(blink["duration_s"]) - float(blink["double_gap_s"]), blink))
	return open


static func _blink_open(age: float, blink: Dictionary) -> float:
	var close_s: = float(blink["close_s"])
	var hold_s: = float(blink["hold_s"])
	var open_s: = float(blink["open_s"])
	if age < 0.0 or age > close_s + hold_s + open_s:
		return 1.0
	if age < close_s:
		return 1.0 - smoothstep(0.0, close_s, age)
	if age < close_s + hold_s:
		return 0.0
	return smoothstep(0.0, open_s, age - close_s - hold_s)


func _blended() -> Dictionary:
	var f: = _progress()
	var out: = _to.duplicate(true)
	for side: String in ["L", "R"]:
		var a: Dictionary = _from[side]
		var b: Dictionary = _to[side]
		for key: String in b:
			if b[key] is Array:
				var values: Array = []
				for i in (b[key] as Array).size():
					values.append(lerpf(float(a[key][i]), float(b[key][i]), f))
				out[side][key] = values
			else:
				out[side][key] = lerpf(float(a[key]), float(b[key]), f)
	return out


func _progress() -> float:
	var f: = clampf((_clock - _start) / maxf(0.001, _duration), 0.0, 1.0)
	return 1.0 - pow(1.0 - f, 3.0)


func _fixation_length(index: int) -> float:
	var span: Array = _data["gaze"]["fixation_s"]
	return lerpf(float(span[0]), float(span[1]), _noise(index, 33))


func _gaze_point(index: int) -> Vector2:
	var max_uv: Array = _data["gaze"]["max_uv"]
	return Vector2((_noise(index, 51) * 2.0 - 1.0) * float(max_uv[0]), (_noise(index, 92) * 2.0 - 1.0) * float(max_uv[1]))



func _noise(index: int, salt: int) -> float:
	var x: = (index * 374761393 + (_seed + salt) * 668265263) & 2147483647
	x = ((x ^ (x >> 13)) * 1274126177) & 2147483647
	return float(x) / 2147483647.0


static func _vec3(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
