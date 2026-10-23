class_name MoveBounce
extends MoveBallistic





var _restitution: float = 0.0
var _hop_speed: float = 0.0
var _rest_speed: float = 0.0


func _configure(lex: LexiconData) -> void :
	super._configure(lex)
	_restitution = lex.balf("movement.bounce_restitution")
	_hop_speed = lex.balf("movement.bounce_hop_speed")
	_rest_speed = lex.balf("movement.bounce_rest_speed")
	var pack: = lex.material_pack(thing.node_data)
	_restitution = float(pack.get("restitution", _restitution))
	_hop_speed *= float(pack.get("hop_mult", 1.0))


func _react(collision_info: KinematicCollision3D) -> void :
	var normal: = collision_info.get_normal()
	thing.velocity = thing.velocity.bounce(normal) * _restitution
	var up: = thing.up()
	var vertical: = thing.velocity.dot(up)
	if normal.dot(up) >= _floor_min_y and absf(vertical) < _rest_speed:
		thing.velocity += up * (_hop_speed * pow(thing.scale_factor, 0.25) - vertical)
