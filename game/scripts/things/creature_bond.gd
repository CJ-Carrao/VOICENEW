extends Node

var thing: Thing
var trust = 35.0
var fear = 0.0
var care_cooldown = 0.0
var tick = 0.0
var previous_hp = 0.0
var mood = "tranquilo"
var label: Label3D

func setup(owner_thing: Thing) -> void:
	thing = owner_thing
	previous_hp = thing.hp
func _ready() -> void: add_to_group("creature_bonds")
func _physics_process(delta: float) -> void:
	if not thing.has_simulation_authority() or not thing.is_active or thing.is_held or thing.is_building: return
	care_cooldown = maxf(0.0,care_cooldown-delta)
	tick -= delta
	if tick > 0: return
	tick = .5
	var lost = maxf(0.0,previous_hp-thing.hp)
	previous_hp = thing.hp
	fear = clampf(fear+lost/maxf(thing.max_hp,1.0)*160.0-1.0,0.0,100.0)
	mood = "assustado" if fear >= 60.0 else "confiante" if trust >= 60.0 else "tranquilo"
func care(player: Player) -> Dictionary:
	if care_cooldown > 0.0: return {"blocked":true,"warnings":["Aguarde %.0f s antes de cuidar novamente." % care_cooldown]}
	if not player.try_spend(8.0): return {"blocked":true,"warnings":["Cuidar custa 8 de matéria."]}
	care_cooldown = 4.0
	trust = minf(100.0,trust+10.0)
	fear = maxf(0.0,fear-25.0)
	thing.hp = minf(thing.max_hp,thing.hp+5.0)
	previous_hp = thing.hp
	ExpansionFx.burst(Forge.fx_root(thing),thing.center(),.7,Color("e5bdcf"),"care")
	return {"creature_cared":thing.network_id,"warnings":[description()]}
func description() -> String:
	return "%s · %s · vínculo %.0f/100 · medo %.0f/100" % [Lexicon.data.thing_name(thing.thing_id),mood,trust,fear]
func refuses_danger() -> bool: return trust < 50.0 and fear >= 70.0 and thing.hp < thing.max_hp*.15
static func select(player: Player, species: String = "") -> Node:
	var best = INF
	var result: Node
	var ray = player.look_ray()
	for bond in player.get_tree().get_nodes_in_group("creature_bonds"):
		var animal: Thing = bond.thing
		if animal.owner_id != player.player_id or animal.team != player.team or animal.is_dead or animal.is_captured or animal.is_building or animal.is_held: continue
		if not species.is_empty() and animal.thing_id != species: continue
		var offset: Vector3 = animal.center()-ray.origin
		if offset.length() > 15.0 or offset.normalized().dot(ray.direction) < .5: continue
		var query = PhysicsRayQueryParameters3D.create(ray.origin,animal.center(),PhysicsLayers.WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var rank: float = offset.length()+(1.0-offset.normalized().dot(ray.direction))*15.0
		if rank < best: best = rank; result = bond
	return result
static func request(player: Player, settings: Dictionary) -> Dictionary:
	if not player.can_act(): return {"blocked":true,"warnings":["Você não pode cuidar agora."]}
	var bond = select(player,String(settings.get("species","")))
	if bond == null: return {"blocked":true,"warnings":["Mire numa criatura sua a até 15 m."]}
	if settings.bond == "care": return bond.care(player)
	if settings.bond == "pack":
		if bond.trust < 60.0: return {"blocked":true,"warnings":["Ganhe vínculo 60 para proteger companheiros. Diga: cuidar da criatura."]}
		bond.thing.get_node("AnimalOrders").set_order("guard_pack",bond.thing.global_position)
		return {"warnings":["Protegendo companheiros; dieta e outras ordens continuam valendo."]}
	return {"warnings":[bond.description()]}
func snapshot() -> Dictionary: return {"trust":trust,"fear":fear,"cooldown":care_cooldown,"mood":mood}
func apply_snapshot(data: Dictionary) -> void:
	trust = float(data.get("trust",35.0))
	fear = float(data.get("fear",0.0))
	care_cooldown = float(data.get("cooldown",0.0))
	mood = String(data.get("mood","tranquilo"))
