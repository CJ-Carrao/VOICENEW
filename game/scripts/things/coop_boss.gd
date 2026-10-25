extends Node

var thing: Thing
var damage_scale = 1.0
var phase = "approach"
var clock = 0.0
var deadline = 3.0
var attack_point = Vector3.ZERO
var attack_index = 0
var label: Label3D

func setup(owner_thing: Thing) -> void: thing = owner_thing
func _ready() -> void:
	thing.move.steering = true
	thing.move.set_physics_process(false)
func target() -> Node3D:
	var selected: Node3D
	var distance = INF
	for player in Forge.world.get_players():
		if not player.is_alive() or (Session.is_online() and Session.peer_for_player(player.player_id) <= 0): continue
		var value: float = thing.center().distance_squared_to(player.center())
		if value < distance: distance = value; selected = player
	return selected
func damage_multiplier() -> float: return 1.5 if phase == "recover" else 1.0
func _physics_process(delta: float) -> void:
	if not thing.has_simulation_authority() or not thing.can_act() or thing.is_building or not thing.is_active: return
	clock += delta
	var enemy = target()
	if enemy == null: return
	if clock >= deadline:
		match phase:
			"recover":
				phase = "approach"
				deadline = clock+1.8
			"approach":
				attack_index += 1
				phase = "warning"
				attack_point = thing.global_position+(enemy.global_position-thing.global_position).limit_length(18.0)
				deadline = clock+1.1
				Fx.ring(Forge.fx_root(thing),attack_point,4.0,Color("ee775b"),1.1)
			"warning":
				phase = "recover"
				deadline = clock+1.6
				if attack_index%2 == 0: thing.move.travel((attack_point+thing.up()-thing.global_position).limit_length(8.0))
				var rows = []
				for candidate in Combat.in_radius(thing,attack_point,4.0):
					if not candidate.has_method("take_damage") or not Combat.affects(thing,candidate): continue
					rows.append({"target":weakref(candidate),"damage":(30.0 if attack_index%2 == 1 else 38.0)*damage_scale,"type":"melee","push":(Combat.center_of(candidate)-attack_point).normalized()*5.0})
					if rows.size() >= 24: break
				var work = load("res://scripts/things/blast_work.gd").new()
				work.setup(thing,rows)
				get_tree().root.add_child(work)
				ExpansionFx.burst(Forge.fx_root(thing),attack_point,3.5,Color("d99c66"),"boss_slam")
	if phase == "approach":
		var offset: Vector3 = enemy.global_position+thing.up()*2.0-thing.global_position
		thing.velocity = offset.normalized()*minf(thing.speed,offset.length())*Status.speed_mult(thing)
		thing.move.travel(thing.velocity*delta)
		thing.face(offset,true)
	else: thing.velocity = Vector3.ZERO
func snapshot() -> Dictionary: return {"phase":phase,"deadline":deadline,"clock":clock,"point":attack_point,"index":attack_index,"scale":damage_scale}
func apply_snapshot(data: Dictionary) -> void:
	phase = String(data.get("phase","approach"))
	deadline = float(data.get("deadline",0.0))
	clock = float(data.get("clock",0.0))
	attack_point = data.get("point",Vector3.ZERO)
	attack_index = int(data.get("index",0))
	damage_scale = float(data.get("scale",1.0))
func _process(_delta: float) -> void:
	if label == null:
		label = Label3D.new()
		label.font_size = 26
		label.pixel_size = .006
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		thing.add_child(label)
	label.position = thing.bounds.get_center()+Vector3.UP*(thing.bounds.size.y*.5+.6)
	label.text = "QUIMERA ADAPTATIVA · %.0f/%.0f\n%s" % [thing.hp,thing.max_hp,"SAIA DO CÍRCULO!" if phase == "warning" else "VULNERÁVEL!" if phase == "recover" else "PREPAREM-SE"]
