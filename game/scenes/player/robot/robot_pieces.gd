class_name RobotPieces
extends Node3D







signal assembled

var mode: String = ""
var _pieces: Array[Dictionary] = []
var _cfg: Dictionary
var _clock: float = 0.0
var _floor_y: float = 0.0




func start(kind: String, infos: Array[Dictionary], center: Vector3, layer_mask: int, seed_value: int) -> void :
	mode = kind
	_cfg = Lexicon.bal("robot.pieces", {})
	_floor_y = center.y
	var spread: = float(_cfg.get("assemble_spread_m", 1.0))


	var ordered: Array[Dictionary] = []
	for info: Dictionary in infos:
		var source: = info["mesh"] as MeshInstance3D
		var c: = source.mesh.get_aabb().get_center()
		var xf: Transform3D = info["xf"]
		ordered.append({"mesh": source, "center": c, "xf": Transform3D(xf.basis, xf * c)})
	ordered.sort_custom( func(a: Dictionary, b: Dictionary) -> bool:
		return (a["xf"] as Transform3D).origin.y < (b["xf"] as Transform3D).origin.y)
	for i in ordered.size():
		var info: Dictionary = ordered[i]
		var source: = info["mesh"] as MeshInstance3D
		var copy: = Node3D.new()
		var shape: = MeshInstance3D.new()
		shape.mesh = source.mesh
		shape.material_override = source.material_override
		shape.layers = layer_mask
		shape.cast_shadow = source.cast_shadow
		shape.position = - (info["center"] as Vector3)
		copy.add_child(shape)
		add_child(copy)
		var final: Transform3D = info["xf"]
		var h: = _hash(i, seed_value)
		var out: = (final.origin - center)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(cos(h * TAU), 0.0, sin(h * TAU))
		var piece: = {"node": copy, "final": final, "delay": 0.0}
		if kind == "burst":
			copy.transform = final
			var speed: = lerpf(_r("burst_speed_ms", 0), _r("burst_speed_ms", 1), h)
			piece["vel"] = out * speed + Vector3.UP * lerpf(_r("burst_up_ms", 0), _r("burst_up_ms", 1), _hash(i + 77, seed_value))
			piece["spin_axis"] = Vector3(h - 0.5, 0.6, _hash(i + 13, seed_value) - 0.5).normalized()
			piece["spin"] = float(_cfg.get("burst_spin_rad_s", 8.0)) * (0.5 + h)
		else:
			var ratio: = float(i) / maxf(1.0, ordered.size() - 1.0)
			piece["delay"] = ratio * float(_cfg.get("assemble_s", 0.9)) * 0.6
			piece["from"] = final.origin + out * spread * (0.6 + 0.4 * h) + Vector3.UP * spread * 0.5 * _hash(i + 5, seed_value)
			copy.transform = Transform3D(final.basis.scaled(Vector3.ONE * 0.001), piece["from"])
		_pieces.append(piece)


func _process(delta: float) -> void :
	_clock += delta
	if mode == "burst":
		_burst(delta)
	elif mode == "assemble":
		_assemble()


func _burst(delta: float) -> void :
	var gravity: = float(_cfg.get("gravity", 14.0))
	var linger: = float(_cfg.get("linger_s", 5.0))
	var fade: = float(_cfg.get("fade_s", 0.5))
	for piece: Dictionary in _pieces:
		var node: = piece["node"] as Node3D
		var vel: Vector3 = piece["vel"]
		vel.y -= gravity * delta
		var at: = node.position + vel * delta
		if at.y < _floor_y + 0.06:
			at.y = _floor_y + 0.06
			vel.y = - vel.y * float(_cfg.get("bounce", 0.35))
			vel.x *= 1.0 - minf(1.0, float(_cfg.get("friction", 4.0)) * delta)
			vel.z *= 1.0 - minf(1.0, float(_cfg.get("friction", 4.0)) * delta)
			piece["spin"] = float(piece["spin"]) * 0.8
		piece["vel"] = vel
		var basis: = node.transform.basis.orthonormalized().rotated(piece["spin_axis"], float(piece["spin"]) * delta)
		var shrink: = 1.0 - smoothstep(linger, linger + fade, _clock)
		node.transform = Transform3D(basis.scaled(Vector3.ONE * maxf(shrink, 0.001)), at)
	if _clock > linger + fade:
		queue_free()


func _assemble() -> void :
	var flight: = float(_cfg.get("assemble_s", 0.9)) * 0.4
	var done: = true
	for piece: Dictionary in _pieces:
		var node: = piece["node"] as Node3D
		var final: Transform3D = piece["final"]
		var k: = clampf((_clock - float(piece["delay"])) / flight, 0.0, 1.0)
		done = done and k >= 1.0
		var ease_k: = 1.0 - pow(1.0 - k, 3.0)

		var s: = lerpf(0.0, 1.12, smoothstep(0.0, 0.75, k)) if k < 0.75 else lerpf(1.12, 1.0, (k - 0.75) / 0.25)
		node.transform = Transform3D(final.basis.scaled(Vector3.ONE * maxf(s, 0.001)), 
			(piece["from"] as Vector3).lerp(final.origin, ease_k))
	if done:
		assembled.emit()
		queue_free()


func _r(key: String, index: int) -> float:
	var pair: Array = _cfg.get(key, [1.0, 2.0])
	return float(pair[index])


static func _hash(index: int, seed_value: int) -> float:
	var x: = (index * 374761393 + seed_value * 668265263) & 2147483647
	x = ((x ^ (x >> 13)) * 1274126177) & 2147483647
	return float(x) / 2147483647.0
