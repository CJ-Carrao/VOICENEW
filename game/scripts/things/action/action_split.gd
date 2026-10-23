class_name ActionSplit
extends ThingAction






func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var n: = clampi(int(spec.get("n", Lexicon.balf("actions.split.n"))), 1, int(Lexicon.balf("caps.split_max")))
	var copy: = _copy_recipe()
	var role: = "projectile" if thing.role == "projectile" else "spawned"
	var forward: = thing.travel_direction()
	var up: = thing.up()
	if role != "projectile":
		forward = Gravity.flat(forward, up)
		forward = forward.normalized() if forward.length_squared() > 0.0001 else ctx.direction
	var fan: = deg_to_rad(Lexicon.balf("actions.split.fan_deg"))
	var gap: = maxf(thing.bounds.size.x, thing.bounds.size.z) * Lexicon.balf("actions.split.scale")\
	+ Lexicon.balf("actions.split.gap")
	var center: = thing.center()
	var pieces: Array[Thing] = []
	for i in n:
		var angle: = 0.0 if n == 1 else - fan * 0.5 + fan * float(i) / float(n - 1)
		var dir: = forward.rotated(up, angle)
		var side: = up.cross(dir).normalized() * gap * (float(i) - (n - 1) * 0.5)
		var piece: = Forge.spawn_child(copy, role, center + side, dir, thing, -1.0, Vector3.ZERO, true)
		if piece != null:
			pieces.append(piece)

	for a in pieces:
		for b in pieces:
			if a != b:
				a.add_collision_exception_with(b)
	if not thing.is_dead:
		thing.remove()



func _copy_recipe() -> Dictionary:
	var copy: Dictionary = thing.node_data.duplicate(true)
	var mods: Dictionary = copy.get("mods", {})
	mods["scale"] = float(mods.get("scale", 1.0)) * Lexicon.balf("actions.split.scale")
	mods.erase("count")
	copy["mods"] = mods
	var kept: Array = []
	for behavior: Dictionary in copy.get("behaviors", []):
		if String((behavior.get("do", {}) as Dictionary).get("type", "")) != "split":
			kept.append(behavior)
	copy["behaviors"] = kept
	return copy
