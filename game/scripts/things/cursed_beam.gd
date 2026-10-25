extends Node3D

const GROUP := "cursed_beams"
static var clashes := 0
var thing: Thing
var config := {}
var direction := Vector3.FORWARD
var origin := Vector3.ZERO
var endpoint := Vector3.ZERO
var elapsed := 0.0
var pulse_left := 0.0
var terrain_left := 0.0
var charge := .4
var live := true
var clashing := false
var has_clashed := false
var contact := Vector3.ZERO
var clash_time := 0.0
var peer_ref: WeakRef
var needs_holder := false
var source_ref: WeakRef
var visual: Node3D
var outer: MeshInstance3D
var core: MeshInstance3D
var knot: MeshInstance3D
var motes: Array[MeshInstance3D] = []
var damage_work: Node
var terrain_work: Node
var scan_cursor := 0
var initialized := false

func setup(body: Thing, settings: Dictionary) -> void:
	thing = body
	config = settings
	charge = float(config.get("charge", .4))
	process_physics_priority = -10

func _ready() -> void:
	add_to_group(GROUP)
	visual = Node3D.new()
	add_child(visual)
	var tint := Color(String(config.color))
	outer = _cube(tint, 2.5, .32)
	core = _cube(Color("fff8ef"), 4.0)
	knot = _cube(tint.lightened(.4), 4.0)
	for i in 12: motes.append(_cube(tint, 2.0))

func _cube(color: Color, glow: float, alpha: float = 1.0) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = glow
	piece.material_override = mat
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(piece)
	return piece

func activate() -> void:
	initialized = true
	direction = -thing.global_basis.z.normalized()
	origin = thing.global_position
	endpoint = origin
	thing.collision_layer = 0
	thing.collision_mask = 0
	thing.set_collision_disabled(true)
	thing.model.hide()
	if is_instance_valid(thing.spawner):
		source_ref = weakref(thing.spawner)
		needs_holder = thing.spawner.is_held

func strength() -> float:
	return float(config.output) * clampf(thing.power, .5, 2.0)

func _source_alive() -> bool:
	var source = source_ref.get_ref() if source_ref != null else null
	if not is_instance_valid(source) or source.is_dead or source.is_captured or not source.can_act(): return false
	if needs_holder:
		if not source.is_held or not is_instance_valid(source.owner_player) or not source.owner_player.is_alive(): return false
		origin = source.owner_player.head.global_position + direction * 1.1
	else: origin = source.center() + direction * maxf(1.0, source.bounds.size.length() * .25)
	return true

func _physics_process(delta: float) -> void:
	if not live or not thing.is_active or thing.is_dead or not thing.has_simulation_authority(): return
	if not _source_alive(): finish(); return
	elapsed += delta
	if elapsed >= float(config.life): finish(); return
	var reach := minf(float(config.range), maxf(0.0, elapsed - charge) * 60.0)
	endpoint = origin + direction * reach
	if reach <= .01: return
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, PhysicsLayers.WORLD)
	var hit := thing.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): endpoint = hit.position
	var peer = peer_ref.get_ref() if peer_ref != null else null
	if clashing:
		var on_path := Geometry3D.get_closest_point_to_segment(contact, origin, endpoint).distance_to(contact) < 1.2
		if not is_instance_valid(peer) or not peer.live or not on_path:
			if is_instance_valid(peer): peer.clashing = false; peer.peer_ref = null
			clashing = false
			peer_ref = null
		else:
			if get_instance_id() < peer.get_instance_id(): _dispute(peer, delta)
			if not live: return
			endpoint = contact
	if not clashing and not has_clashed: _find_clash()
	pulse_left -= delta
	if pulse_left <= 0.0:
		pulse_left = .2
		_damage()
	terrain_left -= delta
	if terrain_left <= 0.0:
		terrain_left = .35
		if not is_instance_valid(terrain_work) or terrain_work.is_queued_for_deletion():
			terrain_work = load("res://scripts/things/spatial_cut_work.gd").new()
			terrain_work.setup(thing)
			get_tree().root.add_child(terrain_work)
			terrain_work.add_segment(endpoint, endpoint, 1.1, 35.0 * strength())

func _find_clash() -> void:
	for peer in get_tree().get_nodes_in_group(GROUP):
		if peer == self or not peer.live or peer.clashing or peer.has_clashed or peer.thing.is_dead or not peer.thing.is_active or peer.thing.team == thing.team: continue
		if elapsed <= charge or peer.elapsed <= peer.charge or direction.dot(peer.direction) > -.6: continue
		var points := Geometry3D.get_closest_points_between_segments(origin, endpoint, peer.origin, peer.endpoint)
		if points[0].distance_to(points[1]) > 1.1: continue
		var meeting := (points[0] + points[1]) * .5
		if (meeting - origin).dot(direction) < .5 or (meeting - peer.origin).dot(peer.direction) < .5: continue
		clashing = true
		peer.clashing = true
		has_clashed = true
		peer.has_clashed = true
		peer_ref = weakref(peer)
		peer.peer_ref = weakref(self)
		contact = meeting
		peer.contact = meeting
		endpoint = meeting
		peer.endpoint = meeting
		elapsed = minf(elapsed, float(config.life) - 1.3)
		peer.elapsed = minf(peer.elapsed, float(peer.config.life) - 1.3)
		clashes += 1
		return

func _dispute(peer: Node, delta: float) -> void:
	clash_time += delta
	peer.clash_time = clash_time
	# Raw output pushes the visible contact point toward the weaker beam.
	var push := clampf(strength() - peer.strength(), -1.0, 1.0) * 6.0 * delta
	var candidate := contact + direction * push
	if (candidate - origin).dot(direction) > 1.0 and (candidate - peer.origin).dot(peer.direction) > 1.0:
		contact = candidate
	peer.contact = contact
	peer.endpoint = contact
	if clash_time < 1.2: return
	if absf(strength() - peer.strength()) < .03:
		ExpansionFx.burst(Forge.fx_root(thing), contact, 3.0, Color("f8e5ff"), "beam_clash")
		Combat.explode(thing, contact, 3.0, 40.0)
		peer.finish()
		finish()
	else:
		var winner: Node = self if strength() > peer.strength() else peer
		var loser: Node = peer if winner == self else self
		winner.clashing = false
		winner.peer_ref = null
		winner.elapsed = minf(winner.elapsed, float(winner.config.life) - .65)
		ExpansionFx.burst(Forge.fx_root(thing), contact, 2.0, Color("fff2ea"), "beam_break")
		loser.finish()

func _damage() -> void:
	if not live: return
	var candidates := get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP)
	if Forge.world != null: candidates.append_array(Forge.world.get_node("Things").get_children())
	if candidates.is_empty(): return
	var applied := 0
	var scanned := 0
	for i in candidates.size():
		var target = candidates[(scan_cursor + i) % candidates.size()]
		scanned += 1
		if not is_instance_valid(target) or target == thing or target == thing.owner_player or not target.has_method("take_damage") or not Combat.affects(thing, target): continue
		if target is Thing and (target.is_dead or target.is_captured or target.is_held or target.get_node_or_null("CursedBeam") != null): continue
		var at := Combat.center_of(target)
		var nearest := Geometry3D.get_closest_point_to_segment(at, origin, endpoint)
		var radius: float = minf(2.0, target.bounds.size.length() * .25) if target is Thing else .6
		if at.distance_to(nearest) > .65 + radius: continue
		var query := PhysicsRayQueryParameters3D.create(origin, at, PhysicsLayers.WORLD)
		if not thing.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		if not is_instance_valid(damage_work) or damage_work.is_queued_for_deletion():
			damage_work = load("res://scripts/things/blast_work.gd").new()
			damage_work.setup(thing, [])
			get_tree().root.add_child(damage_work)
		if damage_work.rows.size() - damage_work.cursor < 32:
			damage_work.rows.append({"target": weakref(target), "damage": float(config.damage) * clampf(thing.power, .5, 2.0), "push": Vector3.ZERO, "type": "cursed_beam"})
		applied += 1
		if applied >= 8: break
	scan_cursor = (scan_cursor + scanned) % candidates.size()

func finish() -> void:
	if not live: return
	live = false
	clashing = false
	visual.hide()
	thing.remove()

func _process(_delta: float) -> void:
	if visual == null: return
	thing.model.hide()
	visual.visible = initialized and live and thing.is_active and not thing.is_dead
	if not visual.visible: return
	var now := Time.get_ticks_msec() * .001
	var distance := origin.distance_to(endpoint)
	var middle := (origin + endpoint) * .5
	for beam in [outer, core]:
		beam.global_position = middle
		if distance > .001: beam.look_at(endpoint, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .98 else Vector3.UP)
		var width := (.8 if beam == outer else .3) * (1.0 + .08 * sin(now * 35.0))
		beam.scale = Vector3(width, width, maxf(.01, distance))
	var charging := elapsed < charge
	knot.visible = charging or clashing
	knot.global_position = origin if charging else contact
	knot.scale = Vector3.ONE * ((.35 + elapsed / charge * .55) if charging else 1.6 + .2 * sin(now * 25.0))
	knot.rotation += Vector3(.03, .04, .02)
	for i in motes.size():
		var mote := motes[i]
		var angle := now * 3.0 + i * TAU / motes.size()
		var frame := Basis.looking_at(direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > .98 else Vector3.UP)
		var center := contact if clashing else origin.lerp(endpoint, fposmod(i / 12.0 + now * .7, 1.0))
		mote.global_position = center + frame * Vector3(cos(angle), sin(angle), 0) * (1.3 if clashing else .65)
		mote.scale = Vector3.ONE * (.19 if clashing else .1)

func snapshot() -> Dictionary:
	return {"origin": origin, "endpoint": endpoint, "direction": direction, "elapsed": elapsed, "live": live, "clashing": clashing, "contact": contact}
func apply_snapshot(values: Dictionary) -> void:
	initialized = true
	origin = values.get("origin", thing.global_position)
	endpoint = values.get("endpoint", origin)
	direction = values.get("direction", Vector3.FORWARD)
	elapsed = float(values.get("elapsed", 0.0))
	live = bool(values.get("live", false))
	clashing = bool(values.get("clashing", false))
	contact = values.get("contact", endpoint)
