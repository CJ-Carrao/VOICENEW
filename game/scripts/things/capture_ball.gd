extends Node

var thing: Thing
var occupant_ref: WeakRef
var occupant_id := 0
var occupant_name := ""
var attempted := true
var flying := false
var flight_time := 0.0
var shake_left := 0.0
var result := "empty"

func setup(owner_thing: Thing) -> void:
	thing = owner_thing

func _ready() -> void:
	thing.hit.connect(_on_hit)
	thing.removed.connect(_on_removed)
	for piece in thing.model_pieces:
		if piece.get_meta("tag", "") == "button" and piece.material_override != null:
			piece.material_override = piece.material_override.duplicate()

func occupant() -> Thing:
	if occupant_ref == null: return null
	var value = occupant_ref.get_ref()
	return value as Thing if is_instance_valid(value) and not value.is_dead else null

func activate() -> void:
	if thing.role == "projectile" and not thing.is_held and not thing.ground_item and thing.has_simulation_authority():
		_arm_projectile.call_deferred()

func _arm_projectile() -> void:
	if not is_instance_valid(thing) or thing.is_dead: return
	GroundItems.drop(thing, thing.global_position, thing.velocity)
	begin_throw()

func begin_throw() -> void:
	attempted = occupant() != null
	flying = true
	flight_time = 0.0
	shake_left = 0.0
	thing.activate()

func _on_hit(ctx: ActionContext) -> void:
	if not flying or not thing.has_simulation_authority(): return
	if occupant() != null:
		release.call_deferred()
		return
	if attempted: return
	var target: Variant = ctx.target
	while is_instance_valid(target) and target is Thing and is_instance_valid(target.mount_host): target = target.mount_host
	if is_instance_valid(target) and target is Thing and target.category == "creature":
		attempted = true
		_attempt.call_deferred(weakref(target))

func _attempt(reference: WeakRef, roll: float = -1.0) -> bool:
	if not is_instance_valid(thing) or thing.is_dead or not thing.has_simulation_authority() or occupant() != null: return false
	var target = reference.get_ref()
	if not is_instance_valid(target) or not target is Thing or target.is_dead or target.is_captured or target.is_held or target.is_building or target.category != "creature": return false
	attempted = true
	var life := clampf(target.hp / maxf(target.max_hp, 1.0), 0.0, 1.0)
	var chance := clampf(.22 + (1.0 - life) * .55 + clampf(1.0 - target.bounds.size.length() / 8.0, 0.0, .20) + (.10 if target.team == thing.team else 0.0), .15, .90)
	var blocked := JujutsuRules.field(target, "infinity") != null and not JujutsuRules.bypasses(thing, "capture")
	if blocked or (randf() if roll < 0.0 else roll) >= chance:
		result = "rejected"
		flying = false
		thing.velocity = thing.up() * 2.5
		ExpansionFx.burst(Forge.fx_root(thing), target.center(), .9, Color("ff7064"), "capture_rejected")
		return false
	occupant_ref = weakref(target)
	occupant_id = target.network_id
	occupant_name = Lexicon.data.thing_name(target.thing_id)
	Forge.transfer_owner(target, thing.owner_player as Player, thing)
	target.set_captured(true)
	result = "captured"
	flying = false
	shake_left = 1.1
	thing.pickup_after_ms = Time.get_ticks_msec() + 1200
	ExpansionFx.burst(Forge.fx_root(thing), thing.center(), 1.5, Color("8de4be"), "capture")
	return true

func release() -> Thing:
	var animal := occupant()
	if animal == null or not Session.has_authority() or Forge.world == null: return null
	occupant_ref = null
	occupant_id = 0
	occupant_name = ""
	flying = false
	attempted = true
	shake_left = 0.0
	var ahead := Gravity.flat(thing.velocity, thing.up()).normalized()
	if ahead.length_squared() < .01: ahead = Gravity.flat(-thing.global_basis.z, thing.up()).normalized()
	var spot := Forge.ground_point(thing.global_position + ahead * (1.5 + animal.bounds.size.length() * .15), thing.up())
	Forge.transfer_owner(animal, thing.owner_player as Player, thing)
	animal.global_position = spot + thing.up() * maxf(.08, -animal.bounds.position.y + .05)
	animal.set_captured(false)
	animal.velocity = Vector3.ZERO
	if animal.move != null: animal.move.landed = false
	result = "released"
	ExpansionFx.burst(Forge.fx_root(thing), animal.center(), 1.6, Color("b1e9ff"), "release")
	return animal

func _on_removed(_ball: Thing) -> void:
	# Recycling or destroying a full ball releases its original living occupant.
	if occupant() != null: release()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(thing) or thing.is_dead or not thing.has_simulation_authority(): return
	if occupant_ref != null and occupant() == null:
		occupant_ref = null
		occupant_id = 0
		occupant_name = ""
		result = "empty"
	if flying and not thing.is_held:
		flight_time += delta
		if occupant() != null and flight_time >= .65: release()
	shake_left = maxf(0.0, shake_left - delta)

func _process(_delta: float) -> void:
	if not is_instance_valid(thing) or thing.model == null or thing.is_dead: return
	thing.model.rotation.z = sin(Time.get_ticks_msec() * .025) * .20 if shake_left > 0.0 else 0.0
	for piece in thing.model_pieces:
		if piece.get_meta("tag", "") != "button": continue
		var mat := piece.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color("87e3aa") if not occupant_name.is_empty() else Color("f3eac9")
