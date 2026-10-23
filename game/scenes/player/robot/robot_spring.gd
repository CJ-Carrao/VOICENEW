class_name RobotSpring
extends RefCounted




const LN2: = 0.6931471805599453

const MAX_STEP: = 1.0 / 120.0


static func damp(x: float, goal: float, halflife: float, dt: float) -> float:
	if halflife <= 0.0:
		return goal
	return lerpf(x, goal, 1.0 - exp( - LN2 * dt / halflife))


static func damp_v3(x: Vector3, goal: Vector3, halflife: float, dt: float) -> Vector3:
	if halflife <= 0.0:
		return goal
	return x.lerp(goal, 1.0 - exp( - LN2 * dt / halflife))


static func damp_angle(x: float, goal: float, halflife: float, dt: float) -> float:
	if halflife <= 0.0:
		return goal
	return lerp_angle(x, goal, 1.0 - exp( - LN2 * dt / halflife))


static func damp_quat(x: Quaternion, goal: Quaternion, halflife: float, dt: float) -> Quaternion:
	if halflife <= 0.0:
		return goal
	return x.slerp(goal, 1.0 - exp( - LN2 * dt / halflife))



static func critical(state: Vector2, goal: float, halflife: float, dt: float) -> Vector2:
	var y: = 2.0 * LN2 / maxf(halflife, 1e-05)
	var j0: = state.x - goal
	var j1: = state.y + j0 * y
	var e: = exp( - y * dt)
	return Vector2(e * (j0 + j1 * dt) + goal, e * (state.y - j1 * y * dt))



static func bouncy(state: Vector2, goal: float, frequency: float, damping: float, dt: float) -> Vector2:
	var w: = TAU * frequency
	var left: = dt
	var s: = state
	while left > 0.0:
		var h: = minf(left, MAX_STEP)
		var v: = s.y + ( - w * w * (s.x - goal) - 2.0 * damping * w * s.y) * h
		s = Vector2(s.x + v * h, v)
		left -= h
	return s



static func bouncy_kick(depth: float, frequency: float, damping: float) -> float:
	var z: = clampf(damping, 0.0, 0.99)
	var r: = sqrt(1.0 - z * z)
	return depth * TAU * frequency / exp( - z / r * atan2(r, z))
