extends Node

var thing: Thing
var kind := ""
var tick_left := 0.0

func setup(owner_thing: Thing, product_kind: String) -> void:
	thing = owner_thing
	kind = product_kind
func _ready() -> void: add_to_group("creature_builder_products")
func _physics_process(delta: float) -> void:
	if kind != "web" or not thing.can_act() or not thing.has_simulation_authority(): return
	tick_left -= delta
	if tick_left > 0: return
	tick_left = .3
	for target in Combat.in_radius(thing, thing.center(), 1.8):
		if target == thing or not (target is Thing or target is Player) or not Combat.affects(thing, target): continue
		if target is Thing and (target.is_dead or target.is_captured or target.is_held): continue
		if JujutsuRules.field(target, "infinity") != null: continue
		var web_box := AABB(Vector3(-1.4, -.3, -.85), Vector3(2.8, 2.3, 1.7))
		var target_box: AABB = target.global_transform * target.bounds if target is Thing else AABB(target.global_position - Vector3(.4, 0, .4), Vector3(.8, 1.8, .8))
		if web_box.intersects(thing.global_transform.affine_inverse() * target_box): Status.apply(target, "webbed", thing)
