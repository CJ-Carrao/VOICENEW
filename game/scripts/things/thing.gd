class_name Thing
extends CharacterBody3D






signal fired(ctx: ActionContext)

signal hit(ctx: ActionContext)

signal died(ctx: ActionContext)

signal removed(thing: Thing)

signal commanded(ctx: ActionContext)

signal ammo_changed

const DEATH_SHRINK_TIME: = 0.12
const PUNCH_SCALE: = 1.12


var node_data: Dictionary = {}
var thing_id: String = ""

var network_id: int = 0
var build_seed: int = 0
var network_replica: bool = false
var network_pose: = Transform3D.IDENTITY
var network_pose_valid: = false
var category: String = ""

var role: String = "head"
var owner_id: int = 0
var team: int = 0

var owner_player: Node3D = null

var _spawner_ref: WeakRef
var spawner: Node3D:
	get:
		if _spawner_ref == null: return null
		var value = _spawner_ref.get_ref()
		return value as Node3D if is_instance_valid(value) else null
	set(value):
		_spawner_ref = weakref(value) if is_instance_valid(value) else null
var target_filter: String = ""
var _effect_jobs := 0
var _effect_cleanup := false

func hold_effect_job() -> void:
	_effect_jobs += 1

func release_effect_job() -> void:
	_effect_jobs = maxi(0, _effect_jobs - 1)
	if _effect_jobs == 0 and _effect_cleanup: queue_free()

func _finish_vanish() -> void:
	if _effect_jobs > 0:
		_effect_cleanup = true
		hide()
	else:
		queue_free()

var generation: int = 0
var is_captured := false
var ground_item := false
var pickup_after_ms := 0
var _capture_was_active := false

var age: float = 0.0

var max_hp: float = 0.0
var hp: float = 0.0
var scale_factor: float = 1.0

var weight: float = 0.0

var grafts: Array[Thing] = []
var mount_host: Thing = null
var mount_socket: String = ""
var surface_friction: float = 1.0
var explosion_spent: bool = false
var mechanics: Dictionary = {}
var mechanical_failures: int = 0
var shot_pellets_min: int = 1
var mechanical_recoil: float = 0.0
var _contact_frames: Dictionary = {}
var _impact_frames: Dictionary = {}
var speed: float = 0.0

var lifetime: float = 0.0

var impact: String = "stop"
var impact_damage: float = 0.0
var damage_type: String = "kinetic"
var explosion_damage: float = 0.0
var explosion_radius: float = 0.0
var element: String = ""
var upright: bool = false

var _last_up: Vector3 = Vector3.UP

var charges: int = 1
var fire_cooldown: float = 0.3
var automatic: bool = false

var magazine: int = 0
var ammo: int = 0
var reload_time: float = 0.0

var reload_left: float = 0.0

var power: float = 1.0

var shot_speed_mult: float = 1.0
var shot_lifetime_s: float = 0.0

var spread_deg: float = 0.0

var barrels: int = 1

var fire_mode: String = "volley"

var burst: int = 1
var burst_interval: float = 0.06

var spin_up: float = 0.0

var zoom: float = 1.0
var recoil_deg: float = 0.0

var inaccuracy_deg: float = 0.0
var ads_inaccuracy: float = 1.0

var muzzle_flash: bool = true
var laser_sight: bool = false
var flashlight: bool = false

var mounts: Dictionary = {}

var sight_y: float = 0.0

var grips: Dictionary = {}
var _laser_dot: MeshInstance3D
var _def: Dictionary = {}

var shots_fired: int = 0
var _next_barrel: int = 0

var capacity: int = 0
var ammo_override: Dictionary = {}

var loading: bool = false

var spin_speed: float = 0.0
var _spinner: Node3D

var auto_aim: bool = false



var matter: float = 0.0
var matter_returns: bool = false

var _dissolve_left: float = -1.0


var melee: bool = false

var knockback: float = 1.0

var strike_arc: float = 90.0
var strike_style: String = "slash"

var is_active: bool = false
var is_held: bool = false
var is_dead: bool = false
var is_anchored: bool = false

var unsupported: Array[String] = []

var model: Node3D
var model_base_scale: Vector3 = Vector3.ONE

var model_pieces: Array[MeshInstance3D] = []
var model_anchor: Vector3 = Vector3.ZERO

var is_building: bool = false
var collision: CollisionShape3D
var collisions: Array[CollisionShape3D] = []
var move: ThingMove

var control: Node

var bounds: AABB = AABB()

var _muzzles: Array[Marker3D] = []
var _arena_limit: float = INF
var _kill_y: float = - INF



func configure(node: Dictionary, as_role: String, def: Dictionary, lex: LexiconData) -> void :
	node_data = node
	_def = def
	thing_id = String(node.get("thing", ""))
	category = String(def.get("category", ""))
	role = as_role
	var mods: Dictionary = node.get("mods", {})
	scale_factor = float(mods.get("scale", 1.0))

	max_hp = lex.thing_statf(thing_id, "hp") * scale_factor * float(mods.get("width", 1.0))\
	* float(mods.get("height", 1.0)) * float(mods.get("length", 1.0))
	weight = lex.thing_statf(thing_id, "weight_kg") * Shape.volume_factor(mods, lex.balf("carry.weight_exponent"))
	surface_friction = float(lex.material_pack(node).get("friction", 1.0))
	hp = max_hp
	speed = lex.thing_statf(thing_id, "speed") * float(mods.get("speed", 1.0))
	if role == "projectile" and category not in ["creature", "vehicle"]:
		lifetime = minf(lex.thing_statf(thing_id, "lifetime"), lex.balf("caps.projectile_max_life_s"))
	impact = String(def.get("impact", "stop"))
	impact_damage = lex.thing_statf(thing_id, "impact_damage") * scale_factor
	damage_type = String(def.get("damage_type", "kinetic"))
	explosion_damage = lex.thing_statf(thing_id, "explosion_damage") * scale_factor
	explosion_radius = lex.thing_statf(thing_id, "explosion_radius") * scale_factor
	element = String(mods.get("element", ""))
	upright = bool(mods.get("upright", false))
	charges = maxi(1, int(mods.get("count", 1)))
	fire_cooldown = lex.thing_statf(thing_id, "fire_cooldown")
	automatic = bool(lex.thing_stat(thing_id, "automatic"))
	spread_deg = lex.balf("actions.shoot.spread_deg")
	barrels = lex.barrels_of(thing_id, mods)
	strike_arc = lex.balf("actions.strike.arc_deg")
	if lex.is_weapon(thing_id):
		var rear: = lex.weapon_part(thing_id, mods, "rear")
		var front: = lex.weapon_part(thing_id, mods, "front")
		var muzzle: = lex.weapon_part(thing_id, mods, "muzzle")
		fire_cooldown = float(rear.get("fire_interval_s", fire_cooldown))
		automatic = bool(rear.get("automatic", automatic))
		magazine = int(rear.get("magazine", 0))
		reload_time = float(rear.get("reload_s", 0.0))
		burst = maxi(1, int(rear.get("burst", 1)))
		burst_interval = float(rear.get("burst_interval_s", burst_interval))
		spin_up = float(rear.get("spin_up_s", 0.0))
		power = float(front.get("power", 1.0))
		zoom = float(front.get("zoom", 1.0))
		recoil_deg = float(front.get("recoil_deg", 0.0))
		shot_speed_mult = float(muzzle.get("speed_mult", 1.0))
		shot_lifetime_s = float(muzzle.get("lifetime_s", 0.0))
		spread_deg = float(muzzle.get("spread_deg", spread_deg))
		inaccuracy_deg = float(muzzle.get("inaccuracy_deg", 0.0))
		fire_mode = String(muzzle.get("fire_mode", "volley"))
		knockback = float(front.get("knockback", 1.0))
		strike_arc = float(muzzle.get("arc_deg", strike_arc))
		strike_style = String(muzzle.get("style", strike_style))
	ads_inaccuracy = lex.balf("aim.ads_inaccuracy_mult")
	if lex.is_weapon(thing_id):
		ads_inaccuracy *= float(lex.weapon_part(thing_id, mods, "front").get("ads_inaccuracy_mult", 1.0))
	mechanics = lex.mechanics_of(thing_id, mods)
	shot_pellets_min = 1
	mechanical_recoil = 0.0
	for profile: String in mechanics["profiles"]:
		var config: Dictionary = lex.bal("mechanics.profiles." + profile, {})
		spread_deg = maxf(spread_deg, float(config.get("spread_deg", 0.0)))
		shot_speed_mult *= float(config.get("speed_mult", 1.0))
		shot_pellets_min = maxi(shot_pellets_min, int(config.get("pellets_min", 1)))
		mechanical_recoil += float(config.get("recoil_impulse", 0.0))
	muzzle_flash = true
	laser_sight = false
	flashlight = false
	for id: Variant in mods.get("attachments", []):
		var stats: Dictionary = lex.bal("attachments." + String(id), {})
		zoom = float(stats.get("zoom", zoom))
		recoil_deg *= float(stats.get("recoil_mult", 1.0))
		inaccuracy_deg *= float(stats.get("inaccuracy_mult", 1.0))
		ads_inaccuracy *= float(stats.get("ads_inaccuracy_mult", 1.0))
		power *= float(stats.get("power_mult", 1.0))
		shot_speed_mult *= float(stats.get("speed_mult", 1.0))
		muzzle_flash = muzzle_flash and bool(stats.get("flash", true))
		laser_sight = laser_sight or bool(stats.get("laser", false))
		flashlight = flashlight or bool(stats.get("light", false))

	shot_speed_mult *= pow(float(mods.get("length", 1.0)), lex.balf("shaping.length_shot_speed_exponent"))
	ammo = magazine
	capacity = magazine
	if mods.get("mag") is Dictionary:
		load_magazine(mods["mag"])
	if magazine > 0 and get_node_or_null("AmmoVisual") == null:
		var ammo_visual: = AmmoVisual.new()
		ammo_visual.setup(self)
		add_child(ammo_visual)
	_arena_limit = lex.balf("arena.size") * 0.5 + lex.balf("arena.out_of_bounds_margin")
	_kill_y = lex.balf("arena.kill_y")
	_apply_role_layers()


func attach_model(built: Dictionary) -> void :
	model = built["root"]
	model_base_scale = model.scale
	add_child(model)
	bounds = built["bounds"]
	model_pieces.assign(built["pieces"])
	model_anchor = built["anchor"]
	mounts = built.get("mounts", {})
	sight_y = float(built.get("sight_y", 0.0))
	grips = built.get("grips", {})
	_spinner = model.get_node_or_null("Spinner") as Node3D
	if flashlight and mounts.has("side"):
		var light: = SpotLight3D.new()
		light.name = "Flashlight"
		light.position = mounts["side"]
		light.spot_range = Lexicon.balf("attachments_fx.light_range")
		light.spot_angle = Lexicon.balf("attachments_fx.light_angle_deg")
		light.light_energy = Lexicon.balf("attachments_fx.light_energy")
		light.shadow_enabled = true
		model.add_child(light)
	for point: Vector3 in built["muzzles"]:
		var marker: = Marker3D.new()
		marker.position = point
		model.add_child(marker)
		_muzzles.append(marker)
	var solids: Array = built.get("solids", [])
	var minimum: = 0.05 if solids.is_empty() else 0.01
	if solids.is_empty():
		solids = [bounds]
	for solid: AABB in solids:
		var shape_node: = CollisionShape3D.new()
		var box: = BoxShape3D.new()
		box.size = solid.size.max(Vector3.ONE * minimum)
		shape_node.shape = box
		shape_node.position = solid.get_center()
		add_child(shape_node)
		collisions.append(shape_node)
	collision = collisions[0]


func set_collision_disabled(disabled: bool, deferred: bool = false) -> void :
	for shape_node in collisions:
		if deferred:
			shape_node.set_deferred("disabled", disabled)
		else:
			shape_node.disabled = disabled


func attach_move(component: ThingMove) -> void :
	move = component
	add_child(component)


func set_owner_info(player_id: int, owner_team: int, player: Node3D, created_by: Node3D) -> void :
	var orders := get_node_or_null("AnimalOrders")
	if orders != null and owner_id != player_id: orders.set_order("aggressive" if orders.mode == "aggressive" or bool(node_data.get("mods", {}).get("aggressive", false)) else "free", global_position if is_inside_tree() else Vector3.ZERO)
	owner_id = player_id
	team = owner_team
	owner_player = player
	spawner = created_by
	var parent: = created_by as Thing
	generation = parent.generation + 1 if parent != null else 0
	for graft in grafts:
		graft.set_owner_info(player_id, owner_team, player, created_by)
		graft.set_generation(generation)


func has_simulation_authority() -> bool:
	return not is_captured and not network_replica and Session.has_authority() and ( not Session.is_online() or (Session.replication.is_active() and (Forge.world == null or Forge.world.gameplay_available())))



func configure_network_replica(id: int, construction_seed: int) -> void :
	network_id = id
	build_seed = construction_seed
	network_replica = true
	for index in grafts.size():
		grafts[index].configure_network_replica(0, construction_seed + index + 1)
	_freeze_gameplay_components()


func _freeze_gameplay_components() -> void :
	for child in get_children():
		if child is Thing:
			(child as Thing)._freeze_gameplay_components()
		elif child is ThingMove or child is ThingTrigger or child is ThingAction or child == control\
		or child.has_meta("thing_gameplay_component"):
			child.process_mode = Node.PROCESS_MODE_DISABLED



func activate() -> void :
	if is_active:
		return
	is_active = true

	if network_replica:
		_freeze_gameplay_components()
		return
	for child in get_children():
		if child.has_method("activate"):
			child.activate()



func set_held(held: bool) -> void :
	is_held = held
	if is_dead:
		collision_layer = 0
		collision_mask = 0
		set_collision_disabled(true)
		return

	if network_replica or Session.is_online():
		for graft in grafts:
			graft.set_held(held)
	if held:
		var protection: = bool(_def.get("held_protection", false))
		if protection and owner_player is PhysicsBody3D:
			add_collision_exception_with(owner_player)
		collision_layer = PhysicsLayers.THINGS if protection and not is_building else 0
		collision_mask = 0
		set_collision_disabled( not protection or is_building)
	else:
		set_collision_disabled(false)
		_apply_role_layers()

func set_captured(captured: bool) -> void:
	if is_captured == captured: return
	var orders := get_node_or_null("AnimalOrders")
	if orders != null:
		if captured: orders.on_capture()
		else: orders.on_release()
	is_captured = captured
	if captured:
		_capture_was_active = is_active
		is_active = false
		set_held(true)
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		process_mode = Node.PROCESS_MODE_INHERIT
		if not network_replica: is_active = _capture_was_active
		set_held(false)
		visible = true
	for graft in grafts:
		if is_instance_valid(graft):
			graft.set_captured(captured)
			if not captured: graft.set_held(is_held)



func set_building(building: bool) -> void :
	is_building = building
	for graft in grafts:
		graft.set_building(building)
	if building:
		collision_layer = 0
		collision_mask = 0
		set_collision_disabled(true)
	else:
		set_held(is_held)





func fire(ctx: ActionContext) -> bool:
	if not can_act() or loading:
		return false
	if not Forge.production_available(self):
		return false
	if magazine > 0:
		if reload_left > 0.0:
			return false
		if ammo <= 0:
			if bool(Lexicon.bal("weapons._reload.auto", false)):
				reload()
			return false
		ctx.shots = 1 if fire_mode == "rotate" else mini(barrels, ammo)
		ammo -= ctx.shots
		ammo_changed.emit()
		if ammo <= 0 and bool(Lexicon.bal("weapons._reload.auto", false)):
			reload()
	if fire_mode == "rotate":
		ctx.barrel = _next_barrel % maxi(barrels, 1)
		_next_barrel += 1
		ctx.shots = 1
	shots_fired += 1
	if _spinner != null:
		spin_speed = Lexicon.balf("weapons._spin_rad_s")
	var outcome: = String(mechanics.get("outcome", "standard"))
	if outcome == "dud" or outcome == "backfire":
		mechanical_failures += 1
		if Session.is_online():
			Session.creations.notify_fx("fail", [center()])
		_punch()
		FeelSounds.play_at(Forge.fx_root(self), BuildSounds.fail(), center(), Lexicon.balf("mechanics.failure_db"))
		if outcome == "backfire" and not explosion_spent:
			explosion_spent = true
			var source: = String(mechanics["source"])
			Combat.explode(self, center(), Lexicon.data.thing_statf(source, "explosion_radius") * scale_factor, 
				Lexicon.data.thing_statf(source, "explosion_damage") * scale_factor)
			die()
		return true
	if mechanical_recoil > 0.0:
		if is_held and is_instance_valid(owner_player) and owner_player.has_method("apply_knockback"):
			owner_player.call("apply_knockback", - ctx.direction.normalized() * mechanical_recoil)
		else:
			nudge( - ctx.direction.normalized() * mechanical_recoil)
	fired.emit(ctx)
	return true






func load_magazine(recipe: Dictionary) -> bool:
	if network_replica or magazine <= 0 or is_dead:
		return false
	var mods: Dictionary = recipe.get("mods", {})
	var contents: Variant = mods.get("ammo")
	ammo_override = {}
	var size: = float(magazine) * float(mods.get("scale", 1.0))
	if mods.has("count"):
		size = float(mods["count"])
	if contents is Dictionary:
		ammo_override = (contents as Dictionary).duplicate(true)
		var inner: Dictionary = ammo_override.get("mods", {})
		if inner.has("count"):
			size = float(inner["count"])
			inner.erase("count")
	var carried: = {}
	for key: String in mods:
		if not key in ["ammo", "scale", "count", "color"]:
			carried[key] = mods[key]
	if recipe.get("movement") != null:
		carried["_movement"] = recipe["movement"]
	if not carried.is_empty():
		ammo_override["_mods"] = carried
	capacity = maxi(1, roundi(size))
	ammo = capacity
	reload_left = 0.0
	loading = false
	ammo_changed.emit()
	return true




func add_attachment(id: String) -> void :
	if not has_simulation_authority():
		return
	var mods: Dictionary = node_data.get_or_add("mods", {})
	var gear: Array = mods.get_or_add("attachments", [])
	var slot: = Lexicon.data.attachment_slot(id)
	for other: Variant in gear.duplicate():
		if Lexicon.data.attachment_slot(String(other)) == slot:
			gear.erase(other)
	gear.append(id)
	rebuild_equipment_model()



func rebuild_equipment_model() -> void :
	var mods: Dictionary = node_data.get("mods", {})
	var visual_layers: = model_pieces[0].layers if not model_pieces.is_empty() else 1
	var keep: = [ammo, capacity, ammo_override, reload_left, shots_fired, charges, hp]
	configure(node_data, role, _def, Lexicon.data)
	ammo = keep[0]
	capacity = keep[1]
	ammo_override = keep[2]
	reload_left = keep[3]
	shots_fired = keep[4]
	charges = keep[5]
	hp = keep[6]
	for marker in _muzzles:
		marker.queue_free()
	_muzzles.clear()
	for shape_node in collisions:
		shape_node.queue_free()
	collisions.clear()
	model.queue_free()
	attach_model(ModelBuilder.build(thing_id, mods, Lexicon.data))
	Hands._set_layers(model, visual_layers)
	for graft in grafts:
		if is_instance_valid(graft) and not graft.is_dead:
			model_pieces.append_array(graft.model_pieces)
			weight += graft.weight
	set_held(is_held)
	ammo_changed.emit()



func reload() -> void :
	if not has_simulation_authority() or magazine <= 0 or reload_left > 0.0 or ammo >= capacity:
		return
	reload_left = maxf(reload_time, 0.001)
	ammo_changed.emit()


func is_reloading() -> bool:
	return reload_left > 0.0


func command(ctx: ActionContext) -> void :
	if can_act():
		commanded.emit(ctx)



func report_hit(collision_info: KinematicCollision3D) -> void :
	if not has_simulation_authority():
		return
	var who: = collision_info.get_collider() as Node3D
	var ctx: = ActionContext.make(collision_info.get_position(), velocity, who)
	ctx.normal = collision_info.get_normal()
	hit.emit(ctx)
	if category in ["creature", "vehicle"]:
		if collision_info.get_normal().dot(up()) > 0.5 or not Combat.affects(self, who):
			return
		var key := who.get_instance_id() if who != null else 0
		var frame := Engine.get_physics_frames()
		if frame - int(_impact_frames.get(key, -100000)) < Engine.physics_ticks_per_second * 0.7:
			return
		_impact_frames[key] = frame
	if impact_damage > 0.0 and who != null and not Combat.hit_structure(who, collision_info.get_position(), 
			collision_info.get_collider_shape_index(), impact_damage, "impact"):
		Combat.apply_damage(who, impact_damage, damage_type, self)


func take_damage(amount: float, _type: String, _source: Node) -> void :
	if not has_simulation_authority():
		return
	impact_feedback(center())
	if is_dead or (is_held and mount_host == null) or max_hp <= 0.0:
		return
	hp -= amount
	_punch()
	if hp <= 0.0:
		die()



func impact_feedback(at: Vector3) -> void :
	if not is_dead and String(_def.get("impact_sound", "")) == "metal" and is_inside_tree():
		FeelSounds.play_at(Forge.fx_root(self), FeelSounds.metal_hit(), at, Lexicon.balf("mechanics.metal_db"))
		_punch()



func die() -> void :


	if network_replica or not Session.has_authority() or is_dead:
		return
	is_dead = true
	_cancel_build()
	died.emit(context_here())
	_leave_rubble()
	_vanish()




func extract_from(_shape_index: int, _point: Vector3, amount: float) -> float:
	if not has_simulation_authority() or is_dead or is_held or role == "projectile":
		return 0.0
	if matter_returns:
		var taken: = minf(amount, matter)
		matter -= taken
		if matter <= 0.0001:
			remove()
		return taken
	if _dissolve_left < 0.0:
		_dissolve_left = maxf(max_hp * Lexicon.balf("matter.dissolve_per_hp"), 0.5)
	_dissolve_left -= amount
	if _dissolve_left <= 0.0:
		remove()
	return 0.0


func extract_point(_shape_index: int, _point: Vector3) -> Vector3:
	return center()


func _leave_rubble() -> void :
	if network_replica or not Session.has_authority() or not is_inside_tree():
		return
	var total: = Hands._collect_dissolve_matter(self)
	if total <= 0.0:
		return
	var spot: = Forge.ground_point(global_position, up())
	Rubble.deposit(Forge.debris_root(), spot, total * Lexicon.balf("matter.debris_fraction"), "scrap")



func remove() -> void :
	if is_dead:
		return
	is_dead = true
	_cancel_build()
	_vanish()


func _cancel_build() -> void :
	var animator: = get_node_or_null("BuildAnimator") as BuildAnimator
	if animator != null:
		animator.cancel()

	for child in get_children():
		if child is Thing:
			(child as Thing)._cancel_build()



func anchor_at(ground_point: Vector3, facing: Vector3) -> void :
	if not has_simulation_authority():
		return
	velocity = Vector3.ZERO
	is_anchored = true
	lifetime = 0.0
	if move != null:
		move.landed = true
	global_position = ground_point
	face(facing, true)
	collision_layer = PhysicsLayers.THINGS




func nudge(impulse: Vector3) -> void :
	if not has_simulation_authority():
		return
	if is_dead or is_held or is_anchored or move == null or move is MoveStatic:
		return
	velocity += impulse
	move.landed = false




func up() -> Vector3:
	_last_up = Gravity.up_at(global_position, _last_up)
	return _last_up



func face(direction: Vector3, keep_upright: bool = false) -> void :
	var local_up: = up()
	var dir: = direction
	if keep_upright:
		dir = Gravity.flat(dir, local_up)
	if dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var other: = local_up if absf(dir.dot(local_up)) < 0.98 else local_up.cross(Vector3.RIGHT if absf(local_up.x) < 0.9 else Vector3.FORWARD).normalized()
	look_at(global_position + dir, other)


func center() -> Vector3:
	return global_transform * bounds.get_center()





func grip_local(which: String) -> Variant:
	var point: Variant = grips.get(which, null)
	if point == null or model == null:
		return null
	return model.transform * Vector3(point)


func muzzle_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for marker in _muzzles:
		points.append(marker.global_position)
	if points.is_empty():
		var c: = bounds.get_center()
		points.append(global_transform * Vector3(c.x, c.y, bounds.position.z))
	return points




func strike_reach() -> float:
	return maxf( - bounds.position.z, 0.0) + Lexicon.balf("actions.strike.reach_base")


func travel_direction() -> Vector3:
	if velocity.length_squared() > 0.01:
		return velocity.normalized()
	return - global_basis.z



func context_here() -> ActionContext:
	return ActionContext.make(center(), travel_direction(), Combat.nearest_target(self, center(), get_tree()))


func is_alive() -> bool:
	return not is_dead


func receive_network_pose(pose: Transform3D, immediate: bool = false) -> void :
	network_pose = pose
	if immediate or not network_pose_valid:
		global_transform = pose
	network_pose_valid = true


func _process(_delta: float) -> void :
	if network_replica and is_instance_valid(_spinner) and spin_speed > 0.0 and Session.creations.is_active():
		_spinner.rotate_z(spin_speed * _delta)
	if network_replica and network_pose_valid and not is_held and not is_dead and Session.creations.is_active():
		global_transform = global_transform.interpolate_with(network_pose, 1.0 - exp(-20.0 * _delta))
	if laser_sight:
		_update_laser()



func _update_laser() -> void :
	var holder: = owner_player as Player
	var showing: = is_held and visible and not is_dead and holder != null and is_inside_tree()
	if not showing:
		if is_instance_valid(_laser_dot):
			_laser_dot.visible = false
		return
	if not is_instance_valid(_laser_dot):
		_laser_dot = MeshInstance3D.new()
		var sphere: = SphereMesh.new()
		sphere.radius = Lexicon.balf("attachments_fx.laser_dot_radius")
		sphere.height = sphere.radius * 2.0
		_laser_dot.mesh = sphere
		var material: = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.1, 0.08)
		_laser_dot.material_override = material
		_laser_dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Forge.fx_root(self).add_child(_laser_dot)
	_laser_dot.visible = true
	_laser_dot.global_position = holder.aim()["point"]


func _exit_tree() -> void :
	if is_instance_valid(_laser_dot):
		_laser_dot.queue_free()


func _physics_process(delta: float) -> void :
	if not has_simulation_authority():
		return
	if is_held and bool(_def.get("held_protection", false)):
		collision_layer = PhysicsLayers.THINGS if can_act() and is_visible_in_tree() else 0
	if reload_left > 0.0 and is_active and not is_dead:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left <= 0.0:
			capacity = magazine
			ammo = magazine
			ammo_override = {}
			ammo_changed.emit()
	if _spinner != null and spin_speed > 0.0:
		_spinner.rotate_z(spin_speed * delta)
		spin_speed = maxf(0.0, spin_speed - Lexicon.balf("weapons._spin_rad_s") * delta)
	if not is_active or is_held or is_dead or mount_host != null:
		return
	age += delta
	if lifetime > 0.0 and age >= lifetime:
		die()
		return
	var p: = global_position
	if category in ["creature", "vehicle"]:
		var half := Gravity.world_half() - Vector3.ONE * 2.0 if Gravity.active() else Vector3(_arena_limit - 2.0, 1000.0, _arena_limit - 2.0)
		if half.x > 0.0 and half.z > 0.0 and (absf(p.x) > half.x or absf(p.z) > half.z or (Gravity.active() and absf(p.y) > half.y)):
			global_position = p.clamp(-half, half)
			var home := owner_player.global_position if is_instance_valid(owner_player) else Vector3.ZERO
			var direction := Gravity.flat(home - global_position, up()).normalized()
			velocity = direction * maxf(speed, 1.0)
			face(direction, true)
			if move != null: move.landed = false
		if not Gravity.active() and p.y < _kill_y:
			global_position = Forge.ground_point(owner_player.global_position if is_instance_valid(owner_player) else Vector3.ZERO) + up() * 0.2
			velocity = Vector3.ZERO
		return
	if Gravity.active():
		if not Gravity.inside_world(p, _arena_limit - _arena_half_size()):
			remove()
	elif p.y < _kill_y or absf(p.x) > _arena_limit or absf(p.z) > _arena_limit:
		remove()


func _arena_half_size() -> float:
	return Lexicon.balf("arena.size") * 0.5


func _apply_role_layers() -> void :
	collision_layer = PhysicsLayers.PROJECTILES if role == "projectile" and not is_anchored else PhysicsLayers.THINGS
	if String(_def.get("builder_product", "")) == "web": collision_layer = PhysicsLayers.TRAPS
	collision_mask = PhysicsLayers.SOLID & ~PhysicsLayers.TRAPS if category in ["creature", "vehicle", "structure"] else PhysicsLayers.SOLID


func _vanish() -> void :
	var builder := get_node_or_null("CreatureBuilder")
	if builder != null: builder.cancel()

	for child in get_children():
		if child is Thing and not (child as Thing).is_dead:
			(child as Thing).remove()
	removed.emit(self)
	collision_layer = 0
	collision_mask = 0
	set_collision_disabled(true, true)
	set_physics_process(false)


	if Session.is_online() and mount_host != null:
		visible = false
		return
	if model == null or not is_inside_tree():
		_finish_vanish()
		return
	var tween: = create_tween()
	tween.tween_property(model, "scale", model.scale * 0.01, DEATH_SHRINK_TIME).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_vanish)


func set_generation(value: int) -> void :
	generation = value
	for graft in grafts:
		graft.set_generation(value)


func fit_geometry(factor: float) -> void :
	model.scale *= factor
	model_base_scale *= factor
	bounds = AABB(bounds.position * factor, bounds.size * factor)
	for shape_node in collisions:
		(shape_node.shape as BoxShape3D).size *= factor
		shape_node.position *= factor
	for graft in grafts:
		graft.fit_geometry(factor)
		graft.position *= factor


func surface_touch(body: Node3D, at: Vector3, normal: Vector3) -> void :
	if not can_act() or body == self:
		return
	var frame: = Engine.get_physics_frames()
	var key: = body.get_instance_id()
	var cooldown: = int(Lexicon.balf("material_effects.contact_cooldown_s") * Engine.physics_ticks_per_second)
	if frame - int(_contact_frames.get(key, -100000)) < cooldown:
		return
	if _contact_frames.size() >= int(Lexicon.bal("material_effects.contact_cache", 64)):
		_contact_frames.clear()
	_contact_frames[key] = frame
	var ctx: = ActionContext.make(at, normal, body)
	ctx.normal = normal
	hit.emit(ctx)


func can_act() -> bool:
	if not has_simulation_authority() or not is_active or is_dead or is_building or Status.paralyzed(self):
		return false
	if is_held and is_instance_valid(owner_player) and Status.paralyzed(owner_player): return false
	if mount_host != null:
		return is_instance_valid(mount_host) and mount_host.can_act() and mount_host.is_visible_in_tree()
	return true


func _punch() -> void :
	if model == null or is_dead:
		return
	var base: = model_base_scale
	var tween: = create_tween()
	tween.tween_property(model, "scale", base * PUNCH_SCALE, 0.05)
	tween.tween_property(model, "scale", base, 0.08)
