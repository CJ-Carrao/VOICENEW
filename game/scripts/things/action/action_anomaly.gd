extends ThingAction

static var executed: Dictionary = {}
var _waiting_for_effect := false


func run(ctx: ActionContext) -> void:
	if not thing.has_simulation_authority() or thing.is_dead or not thing.is_inside_tree():
		return
	var mode := String(spec.get("mode", "gravity"))
	if mode == "rift":
		_note(mode)
		_cut_space(ctx)
		return
	if thing.is_held and bool(spec.get("weapon_pulse", false)):
		_note("weapon_" + mode)
		var holder := thing.owner_player as Player
		var point := holder.head.global_position - holder.camera.global_basis.z * 2.0 if holder != null else ctx.point
		var radius := float(spec.get("radius", 4.0))
		ExpansionFx.burst(Forge.fx_root(thing), point, radius, Color.from_string(String(spec.get("color", "#a855f7")), Color.WHITE), mode)
		match mode:
			"repulsion": Combat.impulse(thing, point, radius, 20.0, 0.5)
			"frost": Combat.area_status(thing, point, radius, "frozen")
			"inferno": Combat.area_status(thing, point, radius, "burning")
			_: _damage_area(point, radius, float(spec.get("damage", 25.0)), "electric")
		return
	if thing.is_held or thing.explosion_spent:
		return
	if _waiting_for_effect: return
	_waiting_for_effect = true
	while not Forge.reserve_anomaly_effect():
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(thing) or thing.is_dead or not thing.is_inside_tree(): return
	thing.explosion_spent = true
	_note(mode)
	var at := thing.center()
	var radius := clampf(float(spec.get("radius", 8.0)) * thing.scale_factor, 0.5, 18.0)
	var damage := clampf(float(spec.get("damage", 50.0)) * thing.scale_factor, 0.0, 240.0)
	var color := Color.from_string(String(spec.get("color", "#a855f7")), Color.MEDIUM_PURPLE)
	var parent := Forge.fx_root(thing)
	ExpansionFx.burst(parent, at, minf(radius, 5.0), color, mode)
	match mode:
		"nuclear":
			ExpansionFx.burst(parent, at, radius, Color("ffca52"), "nuclear")
			Combat.explode(thing, at, radius, damage)
		"neutron":
			ExpansionFx.burst(parent, at, radius * 0.9, Color("bce8ef"), "neutron")
			Fx.explosion(parent, at, radius * 0.65, Color("86c3d1"))
			Combat.explode(thing, at, minf(radius * 0.32, 3.2), damage * 0.30)
			for target in Combat.in_radius(thing, at, radius):
				if Combat.affects(thing, target) and (target is Player or target.is_in_group(Combat.COMBATANTS_GROUP) or target.get("category") == "creature" or target.has_node("ProtectionEmitter")):
					Combat.apply_damage(target, damage, "neutron", thing)
		"gravity", "hypothetical", "singularity", "repulsion":
			await _gravity_field(at, radius, damage, mode, color)
		"frost":
			Combat.area_status(thing, at, radius, "frozen")
			_damage_area(at, radius, damage, "cold")
		"inferno":
			Combat.area_status(thing, at, radius, "burning")
			Combat.explode(thing, at, radius, damage)
		"storm":
			for target in Combat.in_radius(thing, at, radius):
				if Combat.affects(thing, target):
					var direction := Combat.center_of(target) - at
					ExpansionFx.rift(parent, at, direction.normalized(), maxf(direction.length(), 0.1), color)
					Combat.apply_damage(target, damage, "electric", thing)
		"emp":
			Combat.area_status(thing, at, radius, "frozen")
			Combat.impulse(thing, at, radius, 8.0, 0.0)
		"meteor", "cluster":
			var up := thing.up()
			var frame := Gravity.frame_for(up)
			for i in 6:
				var angle := TAU * float(i) / 6.0
				var spread := frame * Vector3(cos(angle), 0.0, sin(angle))
				var child_id := "meteor_fragment" if mode == "meteor" else "cluster_fragment"
				var position := at + spread * (radius * 0.45 if mode == "meteor" else 0.35) + up * (9.0 if mode == "meteor" else 0.7)
				Forge.spawn_child({"thing": child_id}, "projectile", position, - up if mode == "meteor" else (spread + up).normalized(), thing, 16.0 if mode == "meteor" else 6.0)
		_:
			Combat.explode(thing, at, radius, damage)
	if is_instance_valid(thing) and not thing.is_dead:
		thing.die()


func _note(mode: String) -> void:
	executed[mode] = int(executed.get(mode, 0)) + 1


func _damage_area(at: Vector3, radius: float, damage: float, kind: String) -> void:
	for target in Combat.in_radius(thing, at, radius):
		if Combat.affects(thing, target):
			Combat.apply_damage(target, damage, kind, thing)


func _gravity_field(at: Vector3, radius: float, damage: float, mode: String, color: Color) -> void:
	thing.velocity = Vector3.ZERO
	thing.set_physics_process(false)
	thing.collision_layer = 0
	thing.collision_mask = 0
	thing.model.hide()
	var pulses := 1 if mode == "repulsion" else (16 if mode == "singularity" else 12)
	for pulse in pulses:
		if not is_instance_valid(thing) or thing.is_dead or not thing.has_simulation_authority():
			return
		if pulse % 3 == 0:
			ExpansionFx.burst(Forge.fx_root(thing), at, radius * 0.5, color, mode)
		for target in Combat.in_radius(thing, at, radius):
			if not Combat.affects(thing, target):
				continue
			var offset := Combat.center_of(target) - at
			var weight := 1.0 - clampf(offset.length() / radius, 0.0, 0.9)
			var up := Gravity.up_at(Combat.center_of(target), thing.up())
			var impulse := - offset.normalized() * 4.5 * weight
			if mode == "singularity":
				impulse *= 1.5
			elif mode == "hypothetical":
				impulse = (up * 4.0 if pulse < 8 else offset.normalized() * 7.0) * weight
			elif mode == "repulsion":
				impulse = (offset.normalized() + up * 0.5) * 32.0 * weight
			impulse *= InnovationRules.force_multiplier(target, thing)
			if target.has_method("apply_knockback"):
				target.call("apply_knockback", impulse)
			elif target is Thing:
				(target as Thing).nudge(impulse)
		if pulses > 1:
			await get_tree().create_timer(0.25, false).timeout
	if is_instance_valid(thing) and not thing.is_dead:
		_damage_area(at, radius, damage, "gravity")
		ExpansionFx.burst(Forge.fx_root(thing), at, radius, color, mode)


func _cut_space(ctx: ActionContext) -> void:
	var was_held := thing.is_held
	await get_tree().create_timer(.10, false).timeout
	if not is_instance_valid(thing) or not thing.can_act() or thing.is_captured or thing.is_held != was_held: return
	var holder := thing.owner_player as Player
	var origin := holder.head.global_position if thing.is_held and holder != null else thing.center()
	var direction := - holder.camera.global_basis.z if thing.is_held and holder != null else ctx.direction
	if direction.length_squared() < 0.001:
		direction = - thing.global_basis.z
	direction = direction.normalized()
	var reach := clampf(float(spec.get("reach", 4.2)) * thing.scale_factor, 2.0, 7.0)
	var damage := float(spec.get("damage", 48.0)) * thing.power * lerpf(1.0, 1.5, clampf(ctx.charge, 0.0, 1.0))
	var effect = load("res://scripts/fx/space_sword.gd")
	var curve: PackedVector3Array = effect.points(origin, direction, thing.up(), reach)
	effect.play(Forge.fx_root(thing), origin, direction, thing.up(), reach)
	var rows := []
	for target in JujutsuRules.candidates(get_tree()):
		if not is_instance_valid(target) or target == thing or target == thing.owner_player or not target.has_method("take_damage") or not Combat.affects(thing, target): continue
		if target is Thing and (target.is_dead or target.is_captured or target.is_held): continue
		var at := Combat.center_of(target)
		if (at - origin).dot(direction) < 0: continue
		var radius: float = minf(1.5, target.bounds.size.length() * .25) if target is Thing else .6
		var touched := false
		for i in 8:
			if Geometry3D.get_closest_point_to_segment(at, curve[i], curve[i+1]).distance_to(at) <= radius + .3: touched = true; break
		if not touched: continue
		rows.append({"target": weakref(target), "damage": damage, "push": Vector3.ZERO, "type": "world_cut"})
		if rows.size() >= 8: break
	if not rows.is_empty():
		var work = load("res://scripts/things/blast_work.gd").new()
		work.setup(thing, rows)
		get_tree().root.add_child(work)
	var terrain = load("res://scripts/things/spatial_cut_work.gd").new()
	terrain.setup(thing)
	get_tree().root.add_child(terrain)
	for i in 8: terrain.add_segment(curve[i], curve[i+1], .28)
