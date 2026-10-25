extends Node

var thing: Thing
var elapsed := 0.0
var check_left := 0.0
var eyes := []
var base_position := Vector3.ZERO

func setup(body: Thing) -> void: thing = body
func _ready() -> void:
	base_position = thing.model.position
	for piece in thing.model_pieces:
		if piece.get_meta("tag", "") == "eye": eyes.append({"piece": piece, "scale": piece.scale})

func _process(delta: float) -> void:
	if not is_instance_valid(thing) or thing.is_dead or thing.is_captured or not thing.is_active: return
	elapsed += delta
	thing.model.position = base_position + Vector3.UP * sin(elapsed * 2.5) * .045
	var blink := .12 if fmod(elapsed + thing.get_instance_id() % 7, 4.5) > 4.35 else 1.0
	for eye in eyes:
		if is_instance_valid(eye.piece): eye.piece.scale = eye.scale * Vector3(1, blink, 1)

func _physics_process(delta: float) -> void:
	if not thing.can_act() or thing.is_captured or thing.is_held: return
	check_left -= delta
	if check_left > 0.0: return
	check_left = .25
	var owner = thing.owner_player
	if not is_instance_valid(owner) or not owner.is_alive() or owner.health >= owner.max_health * .6 or thing.center().distance_to(owner.center()) > 5.0: return
	var now := Time.get_ticks_msec()
	if now < int(owner.get_meta("verity_next_heal", 0)): return
	owner.set_meta("verity_next_heal", now + 4000)
	owner.health = minf(owner.max_health * .6, owner.health + 4.0)
	owner.health_changed.emit(owner.health, owner.max_health)
	ExpansionFx.burst(Forge.fx_root(thing), owner.center(), .6, Color("ffe57d"), "verity_help")
