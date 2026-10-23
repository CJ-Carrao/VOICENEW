class_name MoveBallistic
extends ThingMove



var _lift: float = 0.0
var _drop_height: float = 0.0


func _configure(lex: LexiconData) -> void :
	_lift = deg_to_rad(float(lex.bal("things." + thing.thing_id + ".launch_lift_deg", lex.balf("movement.ballistic_lift_deg"))))
	_drop_height = lex.balf("movement.arrival_drop_height")


func arrive(target: Vector3, _heading: Vector3) -> void :
	thing.global_position = target + Gravity.up_at(target, thing.up()) * _drop_height
	thing.velocity = Vector3.ZERO


func launch(direction: Vector3, launch_speed: float) -> void :
	var dir: = direction.normalized()
	var side: = dir.cross(thing.up())
	if launch_speed > 0.0 and side.length_squared() > 0.0001:
		dir = dir.rotated(side.normalized(), _lift)
	thing.velocity = dir * launch_speed


func step(delta: float) -> void :
	thing.velocity += gravity_accel() * delta
	travel(thing.velocity * delta)
	orient()
