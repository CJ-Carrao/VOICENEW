extends Node

var thing: Thing
var advanced = false
var energy = 20.0
var converted = 0
var visual: Node3D
var visual_left = 0.0
static var last_butterfly_ms = 0

func setup(owner_thing: Thing) -> void:
	thing = owner_thing
	advanced = bool(thing._def.get("butterfly_shield_advanced",false))
	energy = 32.0 if advanced else 20.0
func _ready() -> void: add_to_group("butterfly_shields")
func center() -> Vector3: return thing.owner_player.center() if thing.is_held and is_instance_valid(thing.owner_player) else thing.center()
func usable() -> bool: return thing.is_active and not thing.is_dead and not thing.is_captured and not thing.is_building and thing.can_act()
func accepts(shot: Thing) -> bool:
	if not usable() or shot.team == thing.team or load("res://scripts/things/coop_encounter.gd").allied(thing.team,shot.team): return false
	if shot.get_node_or_null("Do_explode") != null or shot.get_node_or_null("Jujutsu") != null or shot.get_node_or_null("Do_anomaly") != null or not shot.grafts.is_empty(): return false
	var common = shot.thing_id in ["bullet","arrow","dart","pellet","nail"] and shot.element.is_empty()
	var enhanced = advanced and shot.thing_id in ["bullet","arrow","dart","pellet","nail","sphere","ice_shard"]
	return (common or enhanced) and shot.impact_damage <= (45.0 if advanced else 25.0) and energy >= (2.0 if shot.impact_damage > 25.0 else 1.0)
static func intercept(shot: Thing, start: Vector3, finish: Vector3) -> bool:
	if shot.role != "projectile" or shot.category != "projectile" or shot.is_dead: return false
	var step = finish-start
	var length = step.length()
	if length < .0001: return false
	var selected: Node
	var nearest = INF
	for shield in shot.get_tree().get_nodes_in_group("butterfly_shields"):
		if not shield.accepts(shot): continue
		var offset: Vector3 = start-shield.center()
		var along: float = offset.dot(step/length)
		var discriminant: float = along*along-offset.length_squared()+9.0
		if discriminant < 0.0: continue
		var entry = maxf(0.0,-along-sqrt(discriminant))
		if entry > length or -along+sqrt(discriminant) < 0.0 or entry >= nearest: continue
		nearest = entry
		selected = shield
	if selected == null: return false
	var at = start+step/length*nearest
	var query = PhysicsRayQueryParameters3D.create(start,at,PhysicsLayers.WORLD)
	if not shot.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	selected.energy -= 2.0 if shot.impact_damage > 25.0 else 1.0
	selected.converted += 1
	selected.visual_left = .25
	shot.remove()
	selected.butterfly(at,step.normalized())
	return true
func butterfly(at: Vector3, direction: Vector3) -> void:
	# Cosmetic creatures have no matter return, combat abilities, or long-lived population.
	if Time.get_ticks_msec()-last_butterfly_ms < 120: return
	last_butterfly_ms = Time.get_ticks_msec()
	var count = get_tree().get_nodes_in_group("shield_butterflies").size()
	if count >= 24: return
	var child = Forge.spawn_child({"thing":"shield_butterfly"},"spawned",at,-direction,thing,2.0)
	if child != null:
		child.matter = 0.0
		child.matter_returns = false
func _physics_process(delta: float) -> void:
	if thing.has_simulation_authority() and usable(): energy = minf(32.0 if advanced else 20.0,energy+4.0*delta)
func _process(delta: float) -> void:
	visual_left = maxf(0.0,visual_left-delta)
	if visual == null:
		visual = Node3D.new()
		visual.name = "OpenButterflyBarrier"
		thing.add_child(visual)
		visual.top_level = true
		var cube = BoxMesh.new()
		var material = StandardMaterial3D.new()
		material.albedo_color = Color("b7c8db") if advanced else Color("c7abcf")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for i in 20:
			var bit = MeshInstance3D.new()
			bit.mesh = cube
			bit.material_override = material
			visual.add_child(bit)
			var a = i*TAU/20.0
			bit.position = Vector3(cos(a)*3.0,sin(a*2.0)*.3,sin(a)*3.0)
			bit.scale = Vector3(.07,.12,.07)
	visual.global_position = center()
	visual.visible = thing.is_active and not thing.is_captured and energy >= 1.0 and not thing.is_dead
	visual.rotation.y += delta*.25
func snapshot() -> Dictionary: return {"energy":energy,"converted":converted}
func apply_snapshot(data: Dictionary) -> void:
	energy = float(data.get("energy",0.0))
	converted = int(data.get("converted",0))
