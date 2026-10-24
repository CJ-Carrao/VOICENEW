extends Node

static var frame := -1
static var processed := 0
var source: Thing
var rows := []
var cursor := 0

func setup(owner_thing: Thing) -> void:
	source = owner_thing
	source.hold_effect_job()

func add_segment(from: Vector3, to: Vector3, radius: float, damage: float = -1.0) -> void:
	var steps := clampi(ceili(from.distance_to(to) / maxf(radius * .65, .4)), 1, 32)
	for i in steps:
		var at := from.lerp(to, float(i + 1) / steps)
		for node in get_tree().get_nodes_in_group(BlockVolume.GROUP):
			var volume := node as BlockVolume
			var box := AABB(volume.to_global(volume.origin), Vector3(volume.dims) * volume.size_m)
			if at.distance_to(at.clamp(box.position, box.end)) <= radius:
				rows.append({"volume": weakref(volume), "at": at, "radius": radius, "damage": damage})

func _process(_delta: float) -> void:
	if frame != Engine.get_process_frames():
		frame = Engine.get_process_frames()
		processed = 0
	var until := Time.get_ticks_usec() + 2500
	while cursor < rows.size() and processed < 2:
		var row: Dictionary = rows[cursor]
		cursor += 1
		processed += 1
		var volume = row.volume.get_ref()
		if is_instance_valid(volume):
			if row.damage < 0.0: volume.erase_sphere(row.at, row.radius)
			else: volume.explode(row.at, row.radius, row.damage)
		if Time.get_ticks_usec() >= until: break
	if cursor >= rows.size():
		if is_instance_valid(source): source.release_effect_job()
		queue_free()
