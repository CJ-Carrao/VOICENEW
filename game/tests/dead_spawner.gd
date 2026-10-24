extends SceneTree
func _initialize():
	_run.call_deferred()
func _run():
	await process_frame
	var thing_type = load("res://scripts/things/thing.gd")
	var rules = load("res://scripts/things/innovation_rules.gd")
	var contexts = load("res://scripts/things/action_context.gd")
	var parent = thing_type.new()
	parent.thing_id = "nuclear_bomb"
	parent.category = "projectile"
	root.add_child(parent)
	var child = thing_type.new()
	child.thing_id = "nuclear_bomb"
	child.category = "projectile"
	child.spawner = parent
	root.add_child(child)
	var aim = contexts.make(Vector3.ZERO, Vector3.FORWARD, parent)
	parent.free()
	print("DEAD_SPAWNER_BEFORE")
	var result: String = rules.target_diet(child)
	assert(result.is_empty(), "Freed spawner must end target inheritance")
	child.target_filter = "species:dragon"
	assert(rules.target_diet(child) == "species:dragon", "Copied target restriction must survive the spawner")
	assert(not rules.allows_target(child, parent), "A freed target must be rejected before any script type test")
	assert(aim.target == null, "Pending shot retained a freed target")
	print("DEAD_SPAWNER_PASS")
	child.free()
	quit(0)
