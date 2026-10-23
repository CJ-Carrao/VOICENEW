class_name DamageIndicator
extends Control



const LIFE_S: = 1.2
const RADIUS: = 118.0
const ARC_DEG: = 46.0

var player: Player
var _hits: Array[Dictionary] = []


func _ready() -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func add_hit(amount: float, source: Node) -> void :
	var from: = Vector3.INF
	if source is Node3D and is_instance_valid(source):
		from = (source as Node3D).global_position
	_hits.append({"from": from, "life": LIFE_S, "strength": clampf(0.45 + amount / 30.0, 0.45, 1.0)})
	if _hits.size() > 6:
		_hits.pop_front()


func _process(delta: float) -> void :
	for hit: Dictionary in _hits:
		hit.life = float(hit.life) - delta
	_hits = _hits.filter( func(h: Dictionary) -> bool: return float(h.life) > 0.0)
	queue_redraw()


func _draw() -> void :
	if player == null or _hits.is_empty():
		return
	var center: = size * 0.5
	var camera: = player.camera
	for hit: Dictionary in _hits:
		var k: = clampf(float(hit.life) / LIFE_S, 0.0, 1.0)
		var alpha: = k * k * float(hit.strength)
		var from: Vector3 = hit.from
		if from == Vector3.INF:
			draw_arc(center, RADIUS, 0.0, TAU, 64, Color(1, 0.2, 0.12, alpha * 0.4), 4.0, true)
			continue

		var to: = from - camera.global_position
		var forward: = - camera.global_basis.z
		var right: = camera.global_basis.x
		var angle: = atan2(to.dot(right), to.dot(Vector3(forward.x, 0, forward.z).normalized())) - PI * 0.5
		var half: = deg_to_rad(ARC_DEG * 0.5)
		draw_arc(center, RADIUS, angle - half, angle + half, 24, Color(0, 0, 0, alpha * 0.5), 10.0, true)
		draw_arc(center, RADIUS, angle - half, angle + half, 24, Color(1, 0.24, 0.14, alpha), 6.0, true)
		var tip: = center + Vector2.from_angle(angle) * (RADIUS + 12.0)
		var side: = Vector2.from_angle(angle + PI * 0.5) * 7.0
		var back: = Vector2.from_angle(angle) * 9.0
		draw_colored_polygon(PackedVector2Array([tip, tip - back + side, tip - back - side]), Color(1, 0.24, 0.14, alpha))
