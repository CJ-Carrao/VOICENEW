extends ThingAction

var cooldown := 0.0
func _physics_process(delta: float) -> void:
	if thing.has_simulation_authority(): cooldown = maxf(0.0,cooldown-delta)
func run(ctx: ActionContext) -> void:
	if not thing.has_simulation_authority() or not thing.can_act() or cooldown > 0.0: return
	var mode := String(spec.get("mode","age"))
	var origin := ctx.point
	var direction := ctx.direction
	if thing.is_held and thing.owner_player is Player:
		origin = thing.owner_player.head.global_position
		direction = -thing.owner_player.camera.global_basis.z
	var candidates := []
	for target in Combat.in_radius(thing,origin,24.0 if mode != "charm" else 5.0):
		if not target is Thing or target.category != "creature" or not Combat.affects(thing,target): continue
		var effects := target.get_node_or_null("CreativeEffects")
		if effects == null or not effects.available(): continue
		var offset: Vector3 = target.center()-origin
		if mode != "charm" and offset.normalized().dot(direction) < .92: continue
		var ray := PhysicsRayQueryParameters3D.create(origin,target.center(),PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		candidates.append(effects)
	candidates.sort_custom(func(a,b): return a.thing.center().distance_squared_to(origin) < b.thing.center().distance_squared_to(origin))
	var success := false
	if mode == "swap" and candidates.size() >= 2:
		success = load("res://scripts/things/creative_effects.gd").swap(candidates[0],candidates[1],thing)
	elif mode == "age" and not candidates.is_empty(): success = candidates[0].age(thing)
	elif mode == "charm":
		for effect in candidates.slice(0,8): success = effect.charm(thing) or success
	if not success and mode != "charm": return
	cooldown = 12.0 if mode == "swap" else 5.0 if mode == "age" else 18.0
	if mode != "charm":
		var at: Vector3 = candidates[0].thing.center()
		load("res://scripts/fx/pokemon_fx.gd").play(Forge.fx_root(thing),origin,at,"vine" if mode == "age" else "electric","Envelhecimento · 6 s" if mode == "age" else "Troca de cabeças · 8 s")
	else:
		ExpansionFx.burst(Forge.fx_root(thing),origin,5.0,Color("ec94df"),"team_charm")
		thing.die()
