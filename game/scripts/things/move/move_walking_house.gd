extends MoveChaseEnemy

var heading := Vector3.ZERO
var turn_left := 0.0

# A walking home keeps strolling, even when no opponent is alive or nearby.
func step(delta: float) -> void:
 var up := thing.up()
 if heading.length_squared() < 0.01:
  heading = Gravity.flat(-thing.global_basis.z, up).normalized()
 turn_left -= delta
 if turn_left <= 0.0:
  turn_left = 4.0
  heading = heading.rotated(up, 0.5).normalized()
 heading = Gravity.flat(heading, up).normalized()
 thing.velocity = heading * _speed + up * thing.velocity.dot(up)
 steering = true
 super.step(delta)
 steering = false
 thing.face(heading, true)

func _react(hit: KinematicCollision3D) -> void:
 super._react(hit)
 if hit.get_normal().dot(thing.up()) < _floor_min_y:
  # Turn away from walls/creatures instead of pushing into them forever.
  var away := Gravity.flat(hit.get_normal(), thing.up()).normalized()
  if away.length_squared() > 0.01:
   heading = away.rotated(thing.up(), 0.65).normalized()
   turn_left = 2.0
