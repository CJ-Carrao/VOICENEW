class_name Rubble
extends StaticBody3D





const GROUP: = "rubble"

const MATTER_PER_BIT: = 1.5
const MAX_BITS: = 16

var network_id: = 0
var matter: float = 0.0

var _mix: Dictionary = {}
var _bits: Array[MeshInstance3D] = []
var _shape: CollisionShape3D



static func deposit(parent: Node, point: Vector3, amount: float, material: String) -> Rubble:
	if not Session.has_authority() or not is_instance_valid(parent) or not parent.is_inside_tree() or amount <= 0.0:
		return null
	var merge: = Lexicon.balf("matter.rubble_merge_m")
	var up: = Gravity.up_at(point)
	var best: Rubble = null
	var best_d: = merge * merge
	for node in parent.get_tree().get_nodes_in_group(GROUP):
		var pile: = node as Rubble
		if pile == null or pile.is_queued_for_deletion():
			continue

		var gap: = pile.global_position - point
		if Gravity.active() and absf(gap.dot(up)) > merge:
			continue
		var d: = Gravity.flat(gap, up).length_squared()
		if d <= best_d:
			best_d = d
			best = pile
	if best == null:
		best = Rubble.new()
		best.name = "Rubble"
		parent.add_child(best)
		best.global_transform = Transform3D(Gravity.frame_for(up), point)
	best.add(amount, material)
	return best


func _init() -> void :
	collision_layer = PhysicsLayers.DEBRIS
	collision_mask = 0
	add_to_group(GROUP)
	_shape = CollisionShape3D.new()
	_shape.shape = BoxShape3D.new()
	add_child(_shape)


func add(amount: float, material: String) -> void :
	if not Session.has_authority():
		return
	matter += amount
	_mix[material] = float(_mix.get(material, 0.0)) + amount
	_refresh()



func extract_from(_shape_index: int, _point: Vector3, amount: float) -> float:
	if not Session.has_authority():
		return 0.0
	var taken: = minf(maxf(amount, 0.0), matter)
	matter -= taken
	if matter <= 0.0001:
		queue_free()
	else:
		_refresh()
	return taken


func extract_color(_shape_index: int, _point: Vector3) -> Color:
	return _mixed_color()


func extract_point(_shape_index: int, _point: Vector3) -> Vector3:
	return global_position + global_basis.y * 0.15


func matter_left() -> float:
	return matter



func _refresh() -> void :
	var count: = clampi(ceili(matter / MATTER_PER_BIT), 1, MAX_BITS)
	var radius: = clampf(0.25 + sqrt(matter) * 0.08, 0.3, 1.4)
	var color: = _mixed_color()
	while _bits.size() < count:
		var bit: = MeshInstance3D.new()
		bit.mesh = BoxMesh.new()
		add_child(bit)
		_bits.append(bit)
	while _bits.size() > count:
		_bits.pop_back().queue_free()
	var surface: = StandardMaterial3D.new()
	surface.albedo_color = color
	surface.roughness = 0.95
	for i in _bits.size():
		var angle: = i * 2.39996
		var spread: = radius * sqrt((i + 0.5) / float(MAX_BITS))
		var size: = 0.18 + 0.1 * fposmod(i * 0.618, 1.0)
		var bit: = _bits[i]
		(bit.mesh as BoxMesh).size = Vector3(size, size * 0.7, size * 1.2)
		bit.position = Vector3(cos(angle) * spread, size * 0.3, sin(angle) * spread)
		bit.rotation = Vector3(0.3 * sin(i), angle, 0.25 * cos(i * 1.7))
		bit.material_override = surface
	(_shape.shape as BoxShape3D).size = Vector3(radius * 2.0, 0.3, radius * 2.0)
	_shape.position = Vector3(0, 0.15, 0)


func _mixed_color() -> Color:
	var total: = 0.0
	var color: = Color(0, 0, 0)
	for material: String in _mix:
		var weight: = float(_mix[material])
		var c: = Color.from_string(String(Lexicon.bal("materials.%s.color" % material, "#8a8580")), Color.GRAY)
		color += c * weight
		total += weight
	if total <= 0.0:
		return Color(0.55, 0.52, 0.5)
	color /= total
	return Color(color.r, color.g, color.b).darkened(0.15)


func network_state() -> Array:
	return [network_id, global_position, matter, _mix.duplicate()]


func apply_network_state(row: Array) -> void :
	if Session.has_authority():
		return
	network_id = int(row[0])

	global_transform = Transform3D(Gravity.frame_for(Gravity.up_at(row[1])), row[1])
	matter = float(row[2])
	_mix = row[3].duplicate()
	_refresh()
