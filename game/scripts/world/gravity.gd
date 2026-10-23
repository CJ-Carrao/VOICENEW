class_name Gravity
extends RefCounted








static var sources: Array[Dictionary] = []


static func active() -> bool:
	return not sources.is_empty()


static func clear() -> void :
	sources.clear()


static func add(source: Dictionary) -> void :
	sources.append(source)



static func direction_at(point: Vector3) -> Vector3:
	if sources.is_empty():
		return Vector3.DOWN
	var best: = Vector3.ZERO
	var best_distance: = INF
	for source: Dictionary in sources:
		var hit: = _pull(source, point)
		if hit.is_empty():
			continue
		var distance: = float(hit[1])
		if distance <= float(source.get("reach", 0.0)) and distance < best_distance:
			best_distance = distance
			best = hit[0]
	return best




static func up_at(point: Vector3, fallback: Vector3 = Vector3.UP) -> Vector3:
	var pull: = direction_at(point)
	return fallback if pull == Vector3.ZERO else - pull



static func flat(v: Vector3, up: Vector3) -> Vector3:
	return v - up * v.dot(up)



static func altitude(point: Vector3) -> float:
	if sources.is_empty():
		return point.y
	var best_distance: = INF
	for source: Dictionary in sources:
		var hit: = _pull(source, point)
		if hit.is_empty():
			continue
		var distance: = float(hit[1])
		if distance <= float(source.get("reach", 0.0)) and distance < best_distance:
			best_distance = distance
	return best_distance



static func frame_for(up: Vector3) -> Basis:
	var u: = up.normalized()
	if u.is_equal_approx(Vector3.UP) or u == Vector3.ZERO:
		return Basis.IDENTITY
	if u.dot(Vector3.UP) < -0.9999:
		return Basis(Vector3.RIGHT, PI)
	return Basis(Quaternion(Vector3.UP, u)).orthonormalized()



static func source_index(point: Vector3) -> int:
	var best: = -1
	var best_distance: = INF
	for i in sources.size():
		var hit: = _pull(sources[i], point)
		if hit.is_empty():
			continue
		var distance: = float(hit[1])
		if distance <= float(sources[i].get("reach", 0.0)) and distance < best_distance:
			best_distance = distance
			best = i
	return best




static func pull_of(index: int, point: Vector3) -> Vector3:
	if index < 0 or index >= sources.size():
		return Vector3.ZERO
	var hit: = _pull(sources[index], point)
	return hit[0] if not hit.is_empty() else Vector3.ZERO




static func along_surface(from: Vector3, up: Vector3, offset: Vector3) -> Vector3:
	var index: = source_index(from + up * 0.9)
	var distance: = offset.length()
	if index < 0 or distance < 0.001 or String(sources[index].kind) != "planet":
		return from + offset
	var center: Vector3 = sources[index].center
	var arm: = from - center
	var radius: = arm.length()
	var axis: = arm.cross(offset)
	if radius < 0.001 or axis.length_squared() < 1e-08:
		return from + offset
	return center + arm.rotated(axis.normalized(), distance / radius)



static func world_half() -> Vector3:
	for source: Dictionary in sources:
		if source.kind == "box_inside":
			return source.half
	return Vector3.ZERO



static func escape_height(point: Vector3) -> float:
	var best: = 0.0
	var best_distance: = INF
	for source: Dictionary in sources:
		var hit: = _pull(source, point)
		if hit.is_empty():
			continue
		var distance: = float(hit[1])
		if distance <= float(source.get("reach", 0.0)) and distance < best_distance:
			best_distance = distance
			best = float(source.get("reach", 0.0)) - distance
	return best



static func inside_world(point: Vector3, margin: float) -> bool:
	for source: Dictionary in sources:
		if source.kind == "box_inside":
			var half: Vector3 = source.half
			var d: Vector3 = (point - (source.center as Vector3)).abs()
			return d.x <= half.x + margin and d.y <= half.y + margin and d.z <= half.z + margin
	return true



static func _pull(source: Dictionary, point: Vector3) -> Array:
	var center: Vector3 = source.center
	match String(source.kind):
		"planet":
			var offset: = point - center
			var length: = offset.length()
			if length < 0.001:
				return [Vector3.DOWN, 0.0]


			return [ - offset / length, maxf(0.0, length - float(source.radius))]
		"box_outside":

			var round_m: = float(source.get("round", 0.0))
			var half: Vector3 = (source.half as Vector3) - Vector3.ONE * round_m
			var local: = point - center
			var closest: = local.clamp( - half, half)
			var gap: = local - closest
			var length: = gap.length()
			if length < 0.0001:

				var depth: = half - local.abs()
				var axis: = 0 if depth.x <= depth.y and depth.x <= depth.z else (1 if depth.y <= depth.z else 2)
				var dir: = Vector3.ZERO
				dir[axis] = - signf(local[axis]) if local[axis] != 0.0 else -1.0
				return [dir, 0.0]
			return [ - gap / length, maxf(0.0, length - round_m)]
		"box_inside":
			var half: Vector3 = source.half
			var local: = point - center
			var best_axis: = 0
			var best_gap: = INF
			for axis in 3:
				var gap: = half[axis] - absf(local[axis])
				if gap < best_gap:
					best_gap = gap
					best_axis = axis
			var dir: = Vector3.ZERO
			dir[best_axis] = signf(local[best_axis]) if local[best_axis] != 0.0 else 1.0
			return [dir, maxf(0.0, best_gap)]
	return []
