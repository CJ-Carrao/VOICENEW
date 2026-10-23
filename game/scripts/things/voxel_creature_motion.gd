extends Node

var thing: Thing
var parts: Array[Dictionary] = []
var last_position := Vector3.ZERO
var phase := 0.0
var flying := false


func setup(owner_thing: Thing, aerial: bool) -> void:
	thing = owner_thing
	flying = aerial
	for piece in thing.model_pieces:
		var tag := String(piece.get_meta("tag", ""))
		if tag in ["leg", "wing", "antenna", "tail"]:
			parts.append({"node": piece, "tag": tag, "rotation": piece.rotation, "side": -1.0 if piece.position.x < 0.0 else 1.0, "offset": piece.position.z * 13.0})


func _ready() -> void:
	last_position = thing.global_position


func _process(delta: float) -> void:
	if not is_instance_valid(thing) or thing.is_dead or thing.is_building:
		if is_instance_valid(thing):
			last_position = thing.global_position
		return
	var speed := thing.global_position.distance_to(last_position) / maxf(delta, 0.001)
	last_position = thing.global_position
	var moving := clampf(speed / maxf(thing.speed, 0.3), 0.0, 1.0)
	phase += delta * (12.0 if flying else clampf(speed * 11.0, 1.0, 18.0))
	for part in parts:
		var piece := part.node as MeshInstance3D
		if not is_instance_valid(piece):
			continue
		piece.rotation = part.rotation
		match String(part.tag):
			"leg": piece.rotation.x += sin(phase + float(part.offset) + (PI if float(part.side) < 0.0 else 0.0)) * 0.28 * moving
			"wing": piece.rotation.z += sin(phase) * float(part.side) * 0.50 * (1.0 if flying else moving)
			"antenna": piece.rotation.y += sin(phase * 0.35) * 0.10
			"tail": piece.rotation.y += sin(phase * 0.55) * 0.14 * moving
