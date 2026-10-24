extends Node

var thing: Thing
var powers := {}
var exposure := {}
var observed_at := {}
var clock := 0.0
var tick_left := 0.0
var next_attack := 0.0
var next_cast := 0.0
var fx_left := 0.0
var domain_until := 0.0
var domain_mode := ""
var jobs: Node
var terrain_jobs: Node
var wheel: Node3D
var outline: Node3D

func setup(owner_thing: Thing, settings: Dictionary) -> void:
	thing = owner_thing
	powers = settings
	process_physics_priority = -25

func _ready() -> void:
	add_to_group("jujutsu_users")
	if powers.has("infinity") or powers.has("simple_domain") or powers.has("amplification"):
		outline = Node3D.new()
		add_child(outline)
		var cube := BoxMesh.new()
		cube.size = Vector3(.10, .10, .10)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("9ce9f1") if powers.has("infinity") else Color("f8d694")
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		for i in 24:
			var bit := MeshInstance3D.new()
			bit.mesh = cube
			bit.material_override = mat
			var angle := TAU * (i % 12) / 12.0
			bit.position = Vector3(cos(angle), .2 if i < 12 else -.6, sin(angle)) * 2.5
			outline.add_child(bit)
	if powers.has("adaptation"):
		wheel = Node3D.new()
		wheel.name = "AdaptationWheel"
		add_child(wheel)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.14, .14, .14)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("f5d98d")
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		for i in 8:
			var bit := MeshInstance3D.new()
			bit.mesh = mesh
			bit.material_override = mat
			bit.position = Vector3(cos(i * TAU / 8.0), 0, sin(i * TAU / 8.0)) * .6
			wheel.add_child(bit)
		wheel.position = thing.bounds.get_center() + thing.up() * (thing.bounds.size.y * .5 + .4)

func enabled(key: String) -> bool:
	if not is_instance_valid(thing) or thing.is_dead or thing.is_building or not thing.is_active: return false
	if not powers.get(key, false): return false
	if key == "infinity" and powers.has("amplification") and fmod(clock, 24.0) < 16.0: return false
	# Protective techniques cycle, leaving a visible window to counterattack.
	if key in ["infinity", "simple_domain", "amplification"]: return fmod(clock, 24.0) < 16.0
	return true

func protects(target: Object) -> bool:
	return target == thing or (thing.is_held and target == thing.owner_player)

func center() -> Vector3:
	return Combat.center_of(thing.owner_player) if thing.is_held and is_instance_valid(thing.owner_player) else thing.center()

func adapted(kind: String) -> bool:
	return enabled("adaptation") and int(exposure.get(kind, 0)) >= 3

func observe(kind: String) -> void:
	if not enabled("adaptation") or clock - float(observed_at.get(kind, -100.0)) < 0.8: return
	observed_at[kind] = clock
	exposure[kind] = mini(int(exposure.get(kind, 0)) + 1, 3)
	if wheel != null: wheel.rotate_y(PI * .25)
	feedback("adaptation", Color("f9d881"))

func feedback(kind: String, color: Color, radius: float = 1.5) -> void:
	if fx_left > 0.0: return
	fx_left = .35
	ExpansionFx.burst(Forge.fx_root(thing), center(), radius, color, kind)

func _process(delta: float) -> void:
	if not is_instance_valid(thing): return
	if thing.network_replica: clock += delta
	if outline != null:
		outline.visible = enabled("infinity") or enabled("simple_domain") or enabled("amplification")
		outline.global_position = center()
		outline.rotate_y(delta * .5)
	if wheel != null:
		var turns := 0
		for value in exposure.values(): turns += int(value)
		wheel.rotation.y = turns * PI * .25

func _physics_process(delta: float) -> void:
	if not is_instance_valid(thing) or thing.is_dead or thing.is_building or not thing.is_active or not thing.has_simulation_authority(): return
	clock += delta
	fx_left -= delta
	tick_left -= delta
	if tick_left > 0.0: return
	tick_left = .15
	if enabled("infinity"): _infinity()
	if domain_until > clock: _domain()
	if enabled("reverse") and clock >= next_attack:
		next_attack = clock + 1.5
		_heal()
	if thing.category == "creature" and clock >= next_cast:
		var target := Combat.nearest_target(thing, center(), get_tree())
		if target != null and center().distance_to(Combat.center_of(target)) < 24.0:
			cast(ActionContext.make(center(), Combat.center_of(target) - center(), target))

func _infinity() -> void:
	for target in JujutsuRules.candidates(get_tree()):
		if not is_instance_valid(target) or not target is Thing or target == thing or target.is_dead or target.is_held or target.team == thing.team: continue
		var offset: Vector3 = target.center() - center()
		if offset.length() > 2.6 or JujutsuRules.bypasses(target, "contact"): continue
		var attacker = JujutsuRules.of(target)
		if attacker != null: attacker.observe("infinity")
		# Move the incoming body back outside the boundary; no growing collision meshes.
		if offset.length_squared() > .001:
			target.global_position += offset.normalized() * minf(2.6 - offset.length(), .4)
			target.velocity = Vector3.ZERO
		feedback("infinity", Color("b2e9ff"))

func _heal() -> void:
	var target: Node3D = thing.owner_player if thing.is_held and is_instance_valid(thing.owner_player) else thing
	if target is Thing:
		if target.hp >= target.max_hp: return
		target.hp = minf(target.max_hp, target.hp + 6.0)
	elif target is Player:
		if not target.is_alive() or target.health >= target.max_health: return
		target.health = minf(target.max_health, target.health + 6.0)
		target.health_changed.emit(target.health, target.max_health)
	feedback("reverse", Color("a4ffbf"))

func cast(ctx: ActionContext) -> void:
	if clock < next_cast or not thing.has_simulation_authority(): return
	var origin := center()
	var direction := ctx.direction
	if thing.is_held and thing.owner_player is Player:
		origin = thing.owner_player.head.global_position
		direction = -thing.owner_player.camera.global_basis.z
	if enabled("amplification"): return # Neutralizing aura cannot cast other techniques simultaneously.
	for key in ["purple", "red", "blue"]:
		if powers.has(key):
			var id := "hollow_purple" if key == "purple" else "reversal_red" if key == "red" else "cursed_blue"
			var shot := Forge.spawn_child(Recipe.new_node(id), "projectile", origin + direction * 1.5, direction, thing, 20.0 if key == "purple" else 12.0, Vector3.ZERO, true)
			if shot != null: next_cast = clock + (7.0 if key == "purple" else 4.0)
			return
	if powers.has("shrine") or powers.has("void"):
		domain_mode = "shrine" if powers.has("shrine") else "void"
		domain_until = clock + 6.0
		next_cast = clock + 18.0
		feedback(domain_mode, Color("ef6e7d") if domain_mode == "shrine" else Color("7489ff"))
		return
	var mode := "world_cut" if powers.has("world_cut") else "cleave" if powers.has("cleave") else "fuga" if powers.has("fuga") else "black_flash" if powers.has("black_flash") else "adaptation"
	if mode == "adaptation" and not powers.has("adaptation"): return
	var reach := 24.0 if mode in ["world_cut", "cleave", "fuga"] else 3.8
	next_cast = clock + (4.5 if mode == "world_cut" else 3.0 if mode in ["fuga", "black_flash"] else 1.0)
	var kind := "world_cut" if mode == "world_cut" else "fire" if mode == "fuga" else "melee" if mode in ["black_flash", "adaptation"] else "slash"
	var amount := 100.0 if mode == "world_cut" else 65.0 if mode == "fuga" else 55.0 if mode == "black_flash" else 32.0 if mode == "cleave" else maxf(14.0, thing.impact_damage * 2.0)
	var color := Color("ff9542") if mode == "fuga" else Color("ff4667")
	ExpansionFx.rift(Forge.fx_root(thing), origin, direction, reach, color)
	for target in JujutsuRules.candidates(get_tree()):
		if not _enemy(target): continue
		var offset: Vector3 = Combat.center_of(target) - origin
		var along := offset.dot(direction)
		if along < -.5 or along > reach or (offset - direction * along).length() > (1.5 if mode == "black_flash" else 1.1): continue
		if mode != "world_cut":
			var query := PhysicsRayQueryParameters3D.create(origin, Combat.center_of(target), PhysicsLayers.WORLD)
			if not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		_queue(target, amount, kind)
		if mode == "black_flash": ExpansionFx.burst(Forge.fx_root(thing), Combat.center_of(target), 2.4, Color("e92547"), "black_flash")
	if mode in ["cleave", "world_cut", "fuga"]:
		_cut(origin, origin + direction * reach, 1.0 if mode != "fuga" else 1.8, -1.0 if mode == "world_cut" else amount * 2.0)
		if mode == "fuga": ExpansionFx.burst(Forge.fx_root(thing), origin + direction * reach, 4.0, color, "fuga")

func _enemy(target: Object) -> bool:
	if not is_instance_valid(target) or target == thing or target == thing.owner_player or not target.has_method("take_damage"): return false
	if target is Thing and (target.is_dead or target.is_held): return false
	return Combat.affects(thing, target)

func _queue(target: Node3D, amount: float, kind: String) -> void:
	if not is_instance_valid(jobs) or jobs.is_queued_for_deletion():
		jobs = load("res://scripts/things/blast_work.gd").new()
		jobs.setup(thing, [])
		get_tree().root.add_child(jobs)
	jobs.rows.append({"target": weakref(target), "damage": amount, "push": Vector3.ZERO, "type": kind})

func _domain() -> void:
	# Opposing domains cancel the sure-hit inside their overlap.
	for other in get_tree().get_nodes_in_group("jujutsu_users"):
		if other != self and other.domain_until > other.clock and other.thing.team != thing.team and center().distance_to(other.center()) < 18.0: return
	feedback(domain_mode, Color("f36f88") if domain_mode == "shrine" else Color("8e99ff"), 9.0)
	if fmod(clock, .75) > .16: return
	var applied := 0
	for target in JujutsuRules.candidates(get_tree()):
		if not _enemy(target) or center().distance_to(Combat.center_of(target)) > 9.0: continue
		if domain_mode == "shrine": _queue(target, 9.0, "domain_slash")
		elif JujutsuRules.field(target, "simple_domain") == null:
			var user = JujutsuRules.field(target, "adaptation")
			if user != null:
				user.observe("domain_void")
				if user.adapted("domain_void"): continue
			Status.apply(target, "frozen", thing, .3)
		applied += 1
		if applied >= 16: break
	if domain_mode == "shrine": _cut(center(), center(), 2.5, 35.0)

func _cut(from: Vector3, to: Vector3, radius: float, amount: float) -> void:
	if not is_instance_valid(terrain_jobs) or terrain_jobs.is_queued_for_deletion():
		terrain_jobs = load("res://scripts/things/spatial_cut_work.gd").new()
		terrain_jobs.setup(thing)
		get_tree().root.add_child(terrain_jobs)
	terrain_jobs.add_segment(from, to, radius, amount)
