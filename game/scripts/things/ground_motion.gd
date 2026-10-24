extends Node

var thing: Thing

func _physics_process(delta: float) -> void:
	if not is_instance_valid(thing) or not thing.has_simulation_authority() or thing.is_dead or thing.is_held or not thing.ground_item: return
	# The original movement component pauses while an item is loose on the ground.
	thing.velocity += Gravity.direction_at(thing.global_position) * float(ProjectSettings.get_setting("physics/3d/default_gravity")) * delta
	var hit := thing.move_and_collide(thing.velocity * delta)
	if hit == null: return
	thing.report_hit(hit)
	if thing.is_dead: return
	if hit.get_normal().dot(thing.up()) > .55:
		thing.velocity = Vector3.ZERO
	else:
		thing.velocity = thing.velocity.slide(hit.get_normal()) * .45
