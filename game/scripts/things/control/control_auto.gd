class_name ControlAuto
extends Node





var thing: Thing

var _fire_range: float = 0.0
var _fire_interval: float = 0.0
var _approach: float = 0.0
var _climb_gain: float = 0.0
var _climb_deadband: float = 0.0
var _cooldown: float = 0.0


func setup(owner_thing: Thing, lex: LexiconData) -> void :
	thing = owner_thing
	thing.automatic = true
	thing.auto_aim = true
	_fire_range = lex.balf("control.auto.fire_range")
	_fire_interval = lex.balf("control.auto.fire_interval_s")
	_approach = lex.balf("control.auto.approach_distance")
	_climb_gain = lex.balf("control.auto.climb_gain")
	_climb_deadband = lex.balf("control.auto.climb_deadband")


func _physics_process(delta: float) -> void :
	if not thing.can_act() or thing.is_held:
		return
	var from: = thing.center()
	var enemy: = Combat.nearest_target(thing, from, get_tree())
	if enemy == null:
		return
	var to_enemy: = Combat.center_of(enemy) - from
	var distance: = to_enemy.length()

	var frame: = Gravity.frame_for(thing.up())
	var local: = frame.transposed() * to_enemy
	var yaw: = atan2( - local.x, - local.z)
	var flat: = Vector2(local.x, local.z).length()
	var wish: = Vector3.ZERO
	if distance > _approach:
		wish.z = -1.0
	if absf(local.y) > _climb_deadband:
		wish.y = clampf(local.y * _climb_gain, -1.0, 1.0)
	if thing.move.landed:
		thing.face(to_enemy, true)
	else:
		thing.move.pilot(to_enemy, yaw, wish, delta, frame)
		if flat > 0.01:
			thing.face(to_enemy, thing.move.hovers())
	_cooldown -= delta
	if _cooldown <= 0.0 and distance <= _fire_range:
		_cooldown = _fire_interval
		var muzzle: Vector3 = thing.muzzle_points()[0]
		thing.fire(ActionContext.make(muzzle, Combat.center_of(enemy) - muzzle, enemy))
