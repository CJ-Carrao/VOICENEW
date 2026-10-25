extends Node

var thing: Thing
var config := {}
var previous := Vector3.ZERO
var resolved := false
func setup(body: Thing, settings: Dictionary) -> void:
	thing = body
	config = settings
func _ready() -> void: add_to_group("cursed_projectiles")
func activate() -> void:
	previous = thing.center()
	thing.collision_mask = 0
	thing.collision_layer = 0
	thing.set_collision_disabled(true)
func _process(_delta: float) -> void:
	if thing.is_dead or not thing.is_active: return
	if String(config.mode) == "dismantle": thing.model.rotation.z += .1
func _physics_process(_delta: float) -> void:
	if resolved or not thing.is_active or thing.is_dead or not thing.has_simulation_authority(): return
	var point := thing.center()
	var query := PhysicsRayQueryParameters3D.create(previous, point, PhysicsLayers.WORLD)
	var hit := thing.get_world_3d().direct_space_state.intersect_ray(query) if previous.distance_squared_to(point) > .00001 else {}
	if not hit.is_empty(): point = hit.position
	var selected: Node3D
	var best := INF
	for target in JujutsuRules.candidates(get_tree()):
		if not is_instance_valid(target) or target == thing or target == thing.spawner or target == thing.owner_player or not target.has_method("take_damage") or not Combat.affects(thing, target): continue
		if target is Thing and (target.is_dead or target.is_captured or target.is_held or target.category == "projectile"): continue
		var at := Combat.center_of(target)
		var radius: float = clampf(target.bounds.size.length() * .25, .3, 1.5) if target is Thing else .6
		var closest := Geometry3D.get_closest_point_to_segment(at, previous, point)
		if at.distance_to(closest) > radius + .25: continue
		var wall := PhysicsRayQueryParameters3D.create(previous, at, PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(wall).is_empty(): continue
		var distance := previous.distance_squared_to(closest)
		if distance < best: best = distance; selected = target; point = closest
	previous = thing.center()
	if selected == null and hit.is_empty(): return
	resolved = true
	var fx = load("res://scripts/fx/jujutsu_impact.gd")
	if String(config.mode) == "fuga":
		# Impact is a fire detonation; it is not an instantaneous line of damage.
		Combat.explode(thing, point, 3.5, 65.0 * thing.power, "fire")
		Combat.area_status(thing, point, 3.5, "burning")
		ExpansionFx.burst(Forge.fx_root(thing), point, 3.5, Color("ff9d43"), "fuga")
	else:
		if selected != null: Combat.apply_damage(selected, 32.0 * thing.power, "slash", thing)
		var cut = load("res://scripts/things/spatial_cut_work.gd").new()
		cut.setup(thing)
		get_tree().root.add_child(cut)
		cut.add_segment(point, point, .6, 50.0)
		fx.play(Forge.fx_root(thing), point, thing.travel_direction(), "dismantle")
	thing.remove()
