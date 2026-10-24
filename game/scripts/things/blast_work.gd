extends Node

static var frame := -1
static var processed := 0

var source: Thing
var rows: Array = []
var cursor := 0

func setup(bomb: Thing, hits: Array) -> void:
	source = bomb
	rows = hits
	source.hold_effect_job()

func _process(_delta: float) -> void:
	if frame != Engine.get_process_frames():
		frame = Engine.get_process_frames()
		processed = 0
	if not is_instance_valid(source):
		queue_free()
		return
	var until := Time.get_ticks_usec() + 2000
	var count := 0
	while cursor < rows.size() and count < 4 and processed < 4:
		var row: Dictionary = rows[cursor]
		cursor += 1
		count += 1
		processed += 1
		var target = row.target.get_ref()
		if is_instance_valid(target) and not (target is Thing and target.is_dead):
			Combat.apply_damage(target, row.damage, String(row.get("type", "explosive")), source)
			if is_instance_valid(target) and target.has_method("apply_knockback"):
				target.call("apply_knockback", row.push)
		if Time.get_ticks_usec() >= until: break
	if cursor >= rows.size():
		source.release_effect_job()
		queue_free()
