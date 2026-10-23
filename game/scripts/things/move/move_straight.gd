class_name MoveStraight
extends ThingMove



var _arrival_altitude: float = 0.0


func _configure(lex: LexiconData) -> void :
	_arrival_altitude = lex.balf("movement.flyover_altitude")


func arrive(target: Vector3, heading: Vector3) -> void :
	var start: = edge_start(target, heading) + Gravity.up_at(target, thing.up()) * _arrival_altitude
	thing.global_position = start
	thing.velocity = (target - start).normalized() * thing.speed
	thing.face(thing.velocity)


func step(delta: float) -> void :
	travel(thing.velocity * delta)
	if steering and thing.velocity.length_squared() > 0.01:
		thing.face(thing.velocity)
	orient()
