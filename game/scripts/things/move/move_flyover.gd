class_name MoveFlyover
extends MoveFly



var _altitude: float = 0.0

func _autonomous() -> bool:
	# A flyover keeps its launch heading; it must not inherit hover pursuit.
	return false


func _configure(lex: LexiconData) -> void :
	super._configure(lex)
	_altitude = lex.balf("movement.flyover_altitude")
	_min_altitude = _altitude


func launch(direction: Vector3, launch_speed: float) -> void :
	var up: = thing.up()
	var flat: = Gravity.flat(direction, up)
	thing.velocity = (flat.normalized() if flat.length_squared() > 0.0001 else - thing.global_basis.z) * launch_speed


func arrive(target: Vector3, heading: Vector3) -> void :
	thing.global_position = edge_start(target, heading) + Gravity.up_at(target, thing.up()) * _altitude
	launch(heading, thing.speed)
	thing.face(thing.velocity, true)
