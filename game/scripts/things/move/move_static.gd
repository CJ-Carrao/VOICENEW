class_name MoveStatic
extends ThingMove



func _configure(_lex: LexiconData) -> void :
	landed = true


func launch(_direction: Vector3, _launch_speed: float) -> void :
	thing.velocity = Vector3.ZERO
