extends Node

const GROUP := "spatial_orbs"
static var annihilations := 0
static var purple_fusions := 0

var thing: Thing
var config: Dictionary
var mode := ""
var resolved := false
var previous := Vector3.ZERO
var elapsed := 0.0
var pulse_left := 0.0
var fx_left := 0.0
var terrain_left := 0.0
var scan_cursor := 0
var struck := {}
var damage_work: Node
var terrain_work: Node
var terrain_from := Vector3.ZERO
var aura: Node3D

func _ready() -> void:
	add_to_group(GROUP)
	if mode == "purple":
		aura = Node3D.new()
		thing.model.add_child(aura)
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("bc6bff")
		material.emission_enabled = true
		material.emission = Color("923bff")
		material.emission_energy_multiplier = 3.0
		for i in 36:
			var bit := MeshInstance3D.new()
			bit.mesh = cube
			bit.material_override = material
			var angle := TAU * (i % 12) / 12.0
			var point := Vector3(cos(angle), sin(angle), 0) * 1.25
			if i >= 24: point = Vector3(point.x, 0, point.y)
			elif i >= 12: point = Vector3(0, point.x, point.y)
			bit.position = point
			bit.scale = Vector3.ONE * (.24 if i % 3 == 0 else .13)
			aura.add_child(bit)

func setup(owner_thing: Thing, settings: Dictionary) -> void:
	thing = owner_thing
	config = settings
	mode = String(config.mode)
	process_physics_priority = -30

func activate() -> void:
	previous = thing.center()
	terrain_from = previous
	thing.lifetime = float(config.get("life", 6.0))
	thing.collision_mask = 0

func _process(delta: float) -> void:
	if is_instance_valid(thing) and not thing.is_dead and thing.model != null:
		thing.model.rotate_y(delta * 2.0)
		thing.model.rotate_z(delta * 0.7)
		if aura != null:
			aura.rotation.y -= delta * 3.5
			aura.scale = Vector3.ONE * (1.0 + sin(Time.get_ticks_msec() * .012) * .1)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(thing) or thing.is_dead or not thing.is_active or thing.is_held or resolved or not thing.has_simulation_authority(): return
	elapsed += delta
	var point := thing.center()
	if _collide(point): return
	if mode == "red":
		_red(point)
		previous = point
		return
	fx_left -= delta
	if fx_left <= 0.0:
		fx_left = 0.18 if mode == "purple" else .45
		ExpansionFx.burst(Forge.fx_root(thing), point, 2.4 if mode == "purple" else 1.5, _color(), mode)
	if mode == "purple":
		_purple(previous, point)
		terrain_left -= delta
		if terrain_left <= 0.0:
			terrain_left = 0.10
			if not is_instance_valid(terrain_work) or terrain_work.is_queued_for_deletion():
				terrain_work = load("res://scripts/things/spatial_cut_work.gd").new()
				terrain_work.setup(thing)
				get_tree().root.add_child(terrain_work)
			terrain_work.add_segment(terrain_from, point, clampf(2.2 * thing.scale_factor, 1.0, 4.0))
			terrain_from = point
	else:
		pulse_left -= delta
		if pulse_left <= 0.0:
			pulse_left = 0.20
			_field(point)
	previous = point
	if elapsed >= float(config.get("life", 6.0)) - delta:
		resolved = true
		if mode != "purple": Combat.explode(thing, point, 3.0 if _pulls() else 4.0, 50.0 if _pulls() else 100.0)
		thing.remove()

func _pulls() -> bool:
	return mode in ["black", "blue"]

func _color() -> Color:
	return Color(String(config.get("color", "#a879ff")))

func _opposite(other: String) -> bool:
	return (mode == "black" and other == "white") or (mode == "white" and other == "black") or (mode == "blue" and other == "red") or (mode == "red" and other == "blue")

func _collide(point: Vector3) -> bool:
	for other in get_tree().get_nodes_in_group(GROUP):
		if other == self or not is_instance_valid(other) or other.resolved or not _opposite(other.mode): continue
		var peer: Thing = other.thing
		if not is_instance_valid(peer) or peer.is_dead or peer.is_held or not peer.is_active: continue
		var start: Vector3 = previous - other.previous
		var finish := point - peer.center()
		var travel := finish - start
		var t := clampf(-start.dot(travel) / travel.length_squared(), 0.0, 1.0) if travel.length_squared() > 0.00001 else 0.0
		if (start + travel * t).length() > 0.60 * (thing.scale_factor + peer.scale_factor): continue
		resolved = true
		other.resolved = true
		var at := (point + peer.center()) * 0.5
		if mode in ["black", "white"]:
			annihilations += 1
			ExpansionFx.burst(Forge.fx_root(thing), at, 6.0, Color("fff1d1"), "annihilation")
			Combat.explode(thing, at, 8.0, 160.0)
		else:
			purple_fusions += 1
			var red: Thing = thing if mode == "red" else peer
			var heading := red.velocity.normalized() if red.velocity.length_squared() > 0.01 else -red.global_basis.z
			# The two claimed orbs are replaced with one; this cannot multiply actors.
			Forge.spawn_child(Recipe.new_node("hollow_purple"), "projectile", at, heading, red, 20.0, Vector3.ZERO, true, 1.0, true)
			ExpansionFx.burst(Forge.fx_root(thing), at, 3.0, Color("ba7dff"), "purple")
		peer.remove()
		thing.remove()
		return true
	return false

func _candidates() -> Array:
	var out := get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP)
	if Forge.world != null: out.append_array(Forge.world.get_node("Things").get_children())
	return out

func _allowed(target: Node) -> bool:
	if not is_instance_valid(target) or target == thing or target == thing.spawner or target == thing.owner_player: return false
	if not target.has_method("take_damage"): return false
	if target is Thing and (target.is_dead or target.is_held or target.get_node_or_null("SpatialOrb") != null): return false
	return InnovationRules.allows_target(thing, target)

func _red(point: Vector3) -> void:
	var query := PhysicsRayQueryParameters3D.create(previous, point, PhysicsLayers.WORLD)
	var hit := thing.get_world_3d().direct_space_state.intersect_ray(query) if previous.distance_squared_to(point) > .00001 else {}
	var detonates := not hit.is_empty() or elapsed >= 1.8
	if not hit.is_empty(): point = hit.position
	for target in _candidates():
		if not _allowed(target): continue
		var at := Combat.center_of(target)
		var near := Geometry3D.get_closest_point_to_segment(at, previous, point)
		var radius: float = minf(1.5, target.bounds.size.length() * .25) if target is Thing else .6
		if at.distance_to(near) <= .5 + radius: detonates = true; break
	if not detonates: return
	resolved = true
	_field(point)
	var count := 0
	var rows := []
	for target in _candidates():
		if not _allowed(target) or Combat.center_of(target).distance_to(point) > 4.0: continue
		rows.append({"target": weakref(target), "damage": 80.0 * (1.0 - .7 * Combat.center_of(target).distance_to(point) / 4.0), "push": Vector3.ZERO, "type": "gravity"})
		count += 1
		if count >= 16: break
	if not rows.is_empty():
		var work = load("res://scripts/things/blast_work.gd").new()
		work.setup(thing, rows)
		get_tree().root.add_child(work)
	Combat._crater(thing, point, 3.0, 80.0)
	load("res://scripts/fx/jujutsu_impact.gd").play(Forge.fx_root(thing), point, thing.travel_direction(), "red_burst")
	thing.remove()

func _field(at: Vector3) -> void:
	var candidates := _candidates()
	if candidates.is_empty(): return
	var radius := clampf(float(config.get("radius", 7.0)) * thing.scale_factor, 1.0, 10.0)
	var applied := 0
	for i in candidates.size():
		var index := (scan_cursor + i) % candidates.size()
		var target = candidates[index]
		if not _allowed(target): continue
		var offset := Combat.center_of(target) - at
		if offset.length() > radius: continue
		var weight := 1.0 - clampf(offset.length() / radius, 0.0, 0.9)
		var direction := offset.normalized() if offset.length_squared() > 0.001 else thing.up()
		var force := direction * float(config.get("force", 18.0)) * weight * (-1.0 if _pulls() else 1.0)
		force *= InnovationRules.force_multiplier(target, thing)
		if target.has_method("apply_knockback"): target.call("apply_knockback", force)
		elif target is Thing: target.nudge(force)
		Combat.apply_damage(target, float(config.get("damage", 5.0)) * weight, "gravity", thing)
		applied += 1
		if applied >= 16:
			scan_cursor = (index + 1) % candidates.size()
			break
	if _pulls(): Combat._crater(thing, at, 1.2, 25.0)

func _purple(from: Vector3, to: Vector3) -> void:
	var segment := to - from
	for target in _candidates():
		if not _allowed(target) or struck.has(target.get_instance_id()): continue
		var center := Combat.center_of(target)
		var t := clampf((center - from).dot(segment) / segment.length_squared(), 0.0, 1.0) if segment.length_squared() > 0.00001 else 0.0
		var reach := 1.1 * thing.scale_factor
		if target is Thing: reach += minf(target.bounds.size.length() * 0.35, 2.0)
		if center.distance_to(from + segment * t) > reach: continue
		struck[target.get_instance_id()] = true
		if not is_instance_valid(damage_work) or damage_work.is_queued_for_deletion():
			damage_work = load("res://scripts/things/blast_work.gd").new()
			damage_work.setup(thing, [])
			get_tree().root.add_child(damage_work)
		damage_work.rows.append({"target": weakref(target), "damage": 220.0, "push": Vector3.ZERO, "type": "spatial"})
