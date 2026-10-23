class_name Hands
extends Node3D









signal items_changed

signal used(item: Thing, kind: String)

const KICK_DISTANCE: = 0.05
const KICK_TIME: = 0.05


const OWN_WEAPON_LAYER: = 3

const SWING_HIT_S: = 0.09
const SWING_BACK_MAX_S: = 0.4
const POSE_SMOOTH: = 22.0

const POSES: = {
	"slash": {
		"rest": [Vector3(55, -8, -18), Vector3(0.04, -0.02, 0.02)], 
		"windup": [Vector3(80, -65, -45), Vector3(0.14, 0.06, 0.06)], 
		"follow": [Vector3(15, 75, 35), Vector3(-0.16, -0.06, -0.12)], 
	}, 
	"overhead": {
		"rest": [Vector3(60, -5, -10), Vector3(0.04, -0.02, 0.02)], 
		"windup": [Vector3(125, -5, -5), Vector3(0.03, 0.12, 0.1)], 
		"follow": [Vector3(-40, 0, 0), Vector3(0.0, -0.1, -0.16)], 
	}, 
	"thrust": {
		"rest": [Vector3(12, -4, 0), Vector3(0.04, -0.04, 0.05)], 
		"windup": [Vector3(8, -4, 0), Vector3(0.05, -0.03, 0.2)], 
		"follow": [Vector3(2, 0, 0), Vector3(0.0, -0.02, -0.38)], 
	}, 
	"saw": {
		"rest": [Vector3(8, -6, 0), Vector3(0.03, -0.05, 0.0)], 
		"windup": [Vector3(8, -6, 0), Vector3(0.03, -0.05, 0.0)], 
		"follow": [Vector3(6, -6, 0), Vector3(0.03, -0.05, -0.05)], 
	}, 
	"block": [Vector3(15, 80, 0), Vector3(-0.02, 0.1, -0.05)], 
}

var player: Player
var current: int = 0

var _slots: Array = []
var _throwable: Array[bool] = []
var _holding_use: bool = false
var _cooldown: float = 0.0

var _burst_left: int = 0
var _burst_timer: float = 0.0

var _spin_hold: float = 0.0

var _charging: bool = false
var _charge_time: float = 0.0

var _queued_charge: float = -1.0

var _swing_t: float = -1.0
var _swing_from: float = 0.0
var _anim_time: float = 0.0

var _queued_use: bool = false
var _queued_use_charge: float = 0.0

var _melee_pose: = Transform3D.IDENTITY

var _network_state: Dictionary = {}
var _network_visuals: Array[EquipmentVisual] = []


func setup(owner_player: Player, slots: int) -> void :
	player = owner_player
	_slots.resize(slots)
	_throwable.resize(slots)


func slot_count() -> int:
	return _slots.size()


func item_at(index: int) -> Thing:
	return _slots[index] as Thing if index >= 0 and index < _slots.size() and is_instance_valid(_slots[index]) else null


func current_item() -> Thing:
	return item_at(current) if not _slots.is_empty() else null



func is_current(thing: Node) -> bool:
	var item: = current_item()
	return item != null and thing != null and (thing == item or item.is_ancestor_of(thing))



func give(item: Thing, throwable: bool) -> void :
	var index: = current if _slots[current] == null else _slots.find(null)
	if index < 0:

		index = current
		player.store_or_spill(dissolve(index))
	_slots[index] = item
	_throwable[index] = throwable
	item.removed.connect(_on_item_removed)
	item.ammo_changed.connect(items_changed.emit)
	add_child(item)
	item.transform = rest_transform(item)
	item.set_held(true)
	if player.is_local:
		_set_layers(item, 1 << (OWN_WEAPON_LAYER - 1))
	select(index)



static func rest_transform(item: Thing) -> Transform3D:
	var grip: Variant = item.grip_local("main")
	return Transform3D(Basis.IDENTITY, - Vector3(grip) if grip != null else Vector3.ZERO)


static func _set_layers(node: Node, layers: int) -> void :
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).layers = layers
	for child in node.get_children():
		_set_layers(child, layers)


func select(index: int) -> void :
	if _slots.is_empty():
		return
	current = wrapi(index, 0, _slots.size())
	_burst_left = 0
	_spin_hold = 0.0
	_charging = false
	_queued_charge = -1.0
	_swing_t = -1.0
	for i in _slots.size():
		if _slots[i] != null:
			(_slots[i] as Thing).visible = i == current
	items_changed.emit()




func dissolve(index: int) -> float:
	var item: Thing = null
	if index >= 0 and index < _slots.size():
		item = _slots[index] as Thing
	if item == null or not is_instance_valid(item):
		return 0.0
	var matter: = _collect_dissolve_matter(item)
	var orb: = player.robot.orb if player.robot != null else null
	if orb != null and matter > 0.0:
		for i in mini(ceili(matter / Lexicon.balf("matter.orb.bit_matter")), int(Lexicon.balf("matter.orb.bits_max"))):
			orb.absorb(item.center(), Color(String(Lexicon.bal("matter.orb.default_color", "#ffb347"))))
	item.remove()
	return matter


static func _collect_dissolve_matter(node: Thing) -> float:
	var total: = node.matter if node.matter_returns else 0.0
	node.matter = 0.0
	for child in node.get_children():
		if child is Thing and not (child as Thing).is_dead:
			total += _collect_dissolve_matter(child as Thing)
	return total



func dissolve_current() -> float:
	return dissolve(current)



func dissolve_all() -> float:
	var total: = 0.0
	for i in _slots.size():
		total += dissolve(i)
	return total



func clear() -> void :
	for item in _slots.duplicate():
		if is_instance_valid(item):
			(item as Thing).remove()
	_slots.fill(null)
	_network_state.clear()
	for visual in _network_visuals:
		visual.queue_free()
	_network_visuals.clear()
	items_changed.emit()


func use_pressed() -> void :
	_holding_use = true
	if not player.has_simulation_authority():
		return
	if player.extracting:
		return
	var item: = current_item()
	if item != null and item.melee and not item.automatic:

		_charging = true
		_charge_time = 0.0
		return
	_try_use()


func use_released() -> void :
	_holding_use = false
	if not player.has_simulation_authority():
		return
	player.extractor.stop()
	if not _charging:
		return
	_charging = false
	var item: = current_item()
	if item == null or not item.melee:
		return
	var charge: = charge_level()
	if _cooldown > 0.0:
		_queued_charge = charge
	else:
		_try_use(charge)



func cancel_use() -> void :
	_holding_use = false
	_queued_use = false
	_charging = false
	_charge_time = 0.0
	_queued_charge = -1.0
	_burst_left = 0
	if player.extractor != null:
		player.extractor.stop()



func is_using() -> bool:
	return _holding_use or _queued_use



func is_charging() -> bool:
	if not player.has_simulation_authority():
		return bool(_network_state.get("charging", false))
	return _charging and current_item() != null and current_item().melee



func charge_level() -> float:
	if not player.has_simulation_authority():
		return float(_network_state.get("charge", 0.0))
	var min_s: = Lexicon.balf("actions.strike.charge_min_s")
	var full_s: = Lexicon.balf("actions.strike.charge_s")
	if _charge_time < min_s:
		return 0.0
	return clampf((_charge_time - min_s) / maxf(full_s - min_s, 0.01), 0.0, 1.0)


func _physics_process(delta: float) -> void :
	if player == null or not player.has_simulation_authority() or (Session.is_online() and not player.network_active):
		return
	_cooldown -= delta
	if _queued_use and player.move.weapon_ready():
		_queued_use = false
		_try_use(_queued_use_charge)
	if player.extracting:
		if _holding_use and player.can_act() and player.piloting == null:
			player.extractor.pull(delta)
		else:
			player.extractor.stop()
		return
	var item: = current_item()
	if item == null:
		return
	if item.melee:
		if _charging and _cooldown <= 0.0 and player.can_act():
			_charge_time += delta
		if _queued_charge >= 0.0 and _cooldown <= 0.0:
			var charge: = _queued_charge
			_queued_charge = -1.0
			_try_use(charge)
		_animate_melee(item, delta)

	if item.spin_up > 0.0:
		if _holding_use and player.can_act():
			_spin_hold += delta
			item.spin_speed = maxf(item.spin_speed, Lexicon.balf("weapons._spin_rad_s") * clampf(_spin_hold / item.spin_up, 0.0, 1.0))
		else:
			_spin_hold = 0.0

	if _burst_left > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left -= 1
			_burst_timer = item.burst_interval
			if not _shoot(item):
				_burst_left = 0
	if _holding_use and item.automatic:
		_try_use()


func _try_use(charge: float = 0.0) -> void :
	if not player.has_simulation_authority():
		return
	var item: = current_item()
	if item == null or _cooldown > 0.0 or _burst_left > 0 or not player.can_act() or player.piloting != null:
		return

	if item.is_building or Forge.is_assembling(player.player_id):
		return
	if item.spin_up > 0.0 and _spin_hold < item.spin_up:
		return

	if not player.move.weapon_ready():
		_queued_use = true
		_queued_use_charge = charge
		return
	_cooldown = item.fire_cooldown
	if _throwable[current]:
		var aim: = player.aim()
		var muzzle: Vector3 = item.muzzle_points()[0]
		var to_target: Vector3 = aim["point"] - muzzle
		_throw(item, muzzle, to_target.normalized() if to_target.length() > 1.0 else aim["direction"])
	elif _shoot(item, charge) and item.burst > 1:
		_burst_left = item.burst - 1
		_burst_timer = item.burst_interval




func _shoot(item: Thing, charge: float = 0.0) -> bool:
	var aim: = player.aim()
	var muzzle: Vector3 = item.muzzle_points()[0]
	var to_target: Vector3 = aim["point"] - muzzle
	var direction: Vector3 = to_target.normalized() if to_target.length() > 1.0 else aim["direction"]
	var ctx: = ActionContext.make(muzzle, direction, aim["collider"])
	ctx.charge = charge
	if not item.fire(ctx):
		return false
	if Session.is_online():
		Session.creations.notify_fx("use", [player.player_id, item.network_id, "strike" if item.melee else "fire"])
	used.emit(item, "strike" if item.melee else "fire")
	if item.melee:
		_swing_t = 0.0
		_swing_from = clampf(_charge_time / maxf(Lexicon.balf("actions.strike.charge_s"), 0.01), 0.0, 1.0)\
		if charge > 0.0 else 0.0
		_charge_time = 0.0
		return true
	_kick(item)
	player.add_recoil(item.recoil_deg)
	return true



func present_network_use(item: Thing, kind: String) -> void :
	if Session.has_authority() or item != current_item():
		return
	used.emit(item, kind)
	if kind == "throw":
		return
	if item.melee:
		_swing_t = 0.0
		_swing_from = 0.0
	else:
		_kick(item)
		if player.is_local:
			player.add_recoil(item.recoil_deg)



func reload() -> void :
	if not player.has_simulation_authority():
		return
	var item: = current_item()
	if item != null and player.can_act() and bool(Lexicon.bal("weapons._reload.manual_key", false)):
		item.reload()


func _throw(item: Thing, origin: Vector3, direction: Vector3) -> void :
	if Session.is_online():
		Session.creations.notify_fx("use", [player.player_id, item.network_id, "throw"])
	used.emit(item, "throw")
	Forge.spawn_child(item.node_data, "projectile", origin, direction, item, -1.0, Vector3.ZERO, true)
	item.charges -= 1
	if item.charges <= 0:
		item.remove()
	items_changed.emit()



func _on_item_removed(item: Thing) -> void :
	var index: = _slots.find(item)
	if index >= 0:
		_slots[index] = null
		items_changed.emit()




func _animate_melee(item: Thing, delta: float) -> void :
	_anim_time += delta
	var style: = item.strike_style if POSES.has(item.strike_style) else "slash"
	var rest: = _pose(style, "rest")
	var windup: = _pose(style, "windup")
	var follow: = _pose(style, "follow")
	if _swing_t >= 0.0 and not item.automatic:
		_swing_t += delta
		var prep: = Lexicon.balf("actions.strike.windup_s")
		var back: = clampf(item.fire_cooldown * 0.6, 0.12, SWING_BACK_MAX_S)
		var start: = rest.interpolate_with(windup, _swing_from)
		if _swing_t < prep:
			_melee_pose = start.interpolate_with(windup, _ease(_swing_t / prep))
		elif _swing_t < prep + SWING_HIT_S:
			_melee_pose = windup.interpolate_with(follow, _ease((_swing_t - prep) / SWING_HIT_S))
		elif _swing_t < prep + SWING_HIT_S + back:
			_melee_pose = follow.interpolate_with(rest, _ease((_swing_t - prep - SWING_HIT_S) / back))
		else:
			_swing_t = -1.0
		item.transform = _melee_pose * rest_transform(item)
		return
	var target: = rest
	if _charging:
		target = rest.interpolate_with(windup, clampf(_charge_time / maxf(Lexicon.balf("actions.strike.charge_s"), 0.01), 0.0, 1.0))
	elif player.is_blocking():
		target = _pose_block()
	elif item.automatic and _holding_use and player.can_act():
		target = follow.translated_local(Vector3(sin(_anim_time * 90.0), cos(_anim_time * 77.0), 0.0) * 0.004)
	_melee_pose = _melee_pose.interpolate_with(target, 1.0 - exp( - POSE_SMOOTH * delta))

	item.transform = _melee_pose * rest_transform(item)


static func _pose(style: String, which: String) -> Transform3D:
	var entry: Array = (POSES[style] as Dictionary)[which]
	return _to_transform(entry)


static func _pose_block() -> Transform3D:
	return _to_transform(POSES["block"])


static func _to_transform(entry: Array) -> Transform3D:
	var degrees: Vector3 = entry[0]
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))), entry[1])


static func _ease(t: float) -> float:
	var x: = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _kick(item: Thing) -> void :
	var rest_z: = rest_transform(item).origin.z
	var tween: = item.create_tween()
	tween.tween_property(item, "position:z", rest_z + KICK_DISTANCE, KICK_TIME)
	tween.tween_property(item, "position:z", rest_z, KICK_TIME * 2.0)




func apply_network_commands(frame: PlayerInputFrame, authoritative: bool) -> void :
	if frame.slot >= 0 and frame.slot < slot_count() and frame.slot != current:
		select(frame.slot)
		_refresh_network_visibility()
	if not authoritative:
		_holding_use = frame.use_held
		return


	if player.extracting:
		_holding_use = frame.use_held
	if frame.use_pressed:
		use_pressed()
	if frame.use_released:
		use_released()

	if not frame.use_held and not frame.use_pressed and not frame.use_released:
		cancel_use()
	if frame.reload:
		reload()


func export_network_state() -> Dictionary:
	if player != null and not player.has_simulation_authority():
		return _network_state.duplicate(true)
	var slots: Array = []
	var weight: = 0.0
	for index in slot_count():
		var item: = network_item_state(index, true)
		slots.append(item)
		weight += float(item.get("weight", 0.0))
	return {"slot": current, "slots": slots, "weight": weight, 
		"use_held": is_using(), "charging": is_charging(), "charge": charge_level()}


func apply_network_state(state: Dictionary) -> void :
	if player == null or player.has_simulation_authority() or state.is_empty():
		return
	var changed: = state != _network_state
	_network_state = state.duplicate(true)
	current = clampi(int(state.get("slot", 0)), 0, maxi(slot_count() - 1, 0))
	_holding_use = bool(state.get("use_held", false))
	_refresh_creation_slots()
	while _network_visuals.size() < slot_count():
		var visual: = EquipmentVisual.new()
		visual.name = "ReplicaSlot%d" % _network_visuals.size()
		visual.visible = false
		add_child(visual)
		_network_visuals.append(visual)
	var layers: = 1 << (OWN_WEAPON_LAYER - 1) if player.is_local else 1
	for index in slot_count():
		var metadata: = network_item_state(index)


		_network_visuals[index].apply_item({} if int(metadata.get("network_id", 0)) > 0 else metadata, layers)
	_refresh_network_visibility()
	if changed:
		items_changed.emit()


func _refresh_network_visibility() -> void :
	for index in _network_visuals.size():
		var metadata: = network_item_state(index)
		_network_visuals[index].visible = index == current and not metadata.is_empty()\
		and int(metadata.get("network_id", 0)) == 0 and not player.shaper.active and not player.extracting
	if player != null and not player.has_simulation_authority():
		for index in slot_count():
			var item: = item_at(index)
			if is_instance_valid(item):
				item.visible = index == current and not player.shaper.active and not player.extracting


func _refresh_creation_slots() -> void :
	for index in slot_count():
		var metadata: = network_item_state(index)
		var id: = int(metadata.get("network_id", 0))
		var replica: Thing = Session.creations.replica_for_id(id) if id > 0 else null
		var previous: = item_at(index)
		if previous == replica:
			continue
		if is_instance_valid(previous):
			previous.visible = false
		_slots[index] = replica
		if not is_instance_valid(replica):
			continue
		if replica.get_parent() == null:
			add_child(replica)
		elif replica.get_parent() != self:
			replica.reparent(self)
		replica.transform = metadata.get("pose", rest_transform(replica))
		replica.set_held(true)
		_set_layers(replica, 1 << (OWN_WEAPON_LAYER - 1) if player.is_local else 1)
		if not replica.removed.is_connected(_on_item_removed):
			replica.removed.connect(_on_item_removed)


func _process(delta: float) -> void :
	if player == null or player.has_simulation_authority():
		return
	for index in slot_count():
		var item: = item_at(index)
		if is_instance_valid(item):
			var pose: Transform3D = network_item_state(index).get("pose", item.transform)
			item.transform = item.transform.interpolate_with(pose, 1.0 - exp( - POSE_SMOOTH * delta))



func network_item_state(index: int = -1, include_geometry: bool = false) -> Dictionary:
	index = current if index < 0 else index
	if index < 0 or index >= slot_count():
		return {}
	if player != null and not player.has_simulation_authority():
		var slots: Array = _network_state.get("slots", [])
		return slots[index] if index < slots.size() and slots[index] is Dictionary else {}
	var item: = item_at(index)
	if item == null or not is_instance_valid(item):
		return {}
	var grip: Variant = item.grip_local("main")
	var data: = {"id": item.thing_id, "network_id": item.network_id, "weight": item.weight, 
		"zoom": item.zoom, "melee": item.melee, "automatic": item.automatic, "building": item.is_building, 
		"hold_class": RobotBody.hold_class(item), "hold_clip": RobotBody.hold_clip(item), 
		"grip_main": Vector3(grip) if grip != null else Vector3.ZERO, 
		"sight": item.model.transform * Vector3(0.0, item.sight_y, 0.0) if item.model != null else Vector3.ZERO, 
		"ammo": item.ammo, "capacity": item.capacity, "magazine": item.magazine, "charges": item.charges, 
		"loading": item.loading, "reload_left": item.reload_left, "pose": item.transform}


	if include_geometry and item.network_id == 0:
		data["recipe"] = item.node_data.duplicate(true)
		data["geometry"] = _equipment_geometry(item)
	return data


func network_carry_weight() -> float:
	return float(_network_state.get("weight", 0.0))


func network_item_world() -> Transform3D:
	var item: = current_item()
	if is_instance_valid(item):
		return item.global_transform
	return _network_visuals[current].global_transform if current < _network_visuals.size() else global_transform


static func _equipment_geometry(item: Thing, depth: int = 0) -> Dictionary:
	var children: Array = []
	if depth < int(Lexicon.balf("caps.graft_depth")):
		for graft: Thing in item.grafts:
			if is_instance_valid(graft):
				children.append(_equipment_geometry(graft, depth + 1))
	return {"id": item.thing_id, "mods": (item.node_data.get("mods", {}) as Dictionary).duplicate(true), 
		"at": item.transform if depth > 0 else Transform3D.IDENTITY, 
		"model": item.model.transform if item.model != null else Transform3D.IDENTITY, "children": children}
