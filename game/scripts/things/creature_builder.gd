extends Node

var thing: Thing
var kind := ""
var running := false
var progress := 0.0
var completed := 0
var dug_total := 0
var state := "parado"
var work_point := Vector3.ZERO
var heading := Vector3.FORWARD
var cooldown_until := 0
var tick_left := 0.0
var volume_ref: WeakRef
var cells := []
var cell_cursor := 0
var caption: Label3D
static var work_frame := -1
static var work_count := 0
static var team_digs := {}
static var dig_world := 0

func setup(owner_thing: Thing, builder_kind: String) -> void:
	thing = owner_thing
	kind = builder_kind
	tick_left = float(thing.get_instance_id() % 13) * .017

func begin(at: Vector3, direction: Vector3) -> Dictionary:
	if running: return {"blocked": true, "warnings": ["Esse animal já está trabalhando."]}
	if Time.get_ticks_msec() < cooldown_until: return {"blocked": true, "warnings": ["Aguarde a recarga de construção desse animal."]}
	if not _within_cap(): return {"blocked": true, "warnings": ["Limite de construções desse animal ou da equipe atingido."]}
	var up := thing.up()
	var query := PhysicsRayQueryParameters3D.create(at + up * 3.0, at - up * 6.0, PhysicsLayers.WORLD)
	var hit := thing.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return {"blocked": true, "warnings": ["Escolha um chão próximo para construir."]}
	work_point = hit.position
	heading = Gravity.flat(direction, up).normalized()
	if heading.length_squared() < .01: heading = Gravity.flat(-thing.global_basis.z, up).normalized()
	if kind == "tunnel":
		var volume := hit.collider as BlockVolume
		if volume == null or not volume.is_in_group("terrain"): return {"blocked": true, "warnings": ["Formigas escavam terra do terreno; não casas nem blocos protegidos."]}
		volume_ref = weakref(volume)
		cells = _dig_plan(volume, work_point, heading, up)
		if cells.is_empty(): return {"blocked": true, "warnings": ["Não há terra escavável aqui, ou o limite de escavação foi atingido."]}
	else:
		if not _site_clear(): return {"blocked": true, "warnings": ["Esse local está ocupado. Escolha um espaço livre."]}
	running = true
	progress = 0.0
	cell_cursor = 0
	state = "indo ao local"
	return {"builder_started": kind}

func cancel() -> void:
	running = false
	progress = 0.0
	state = "parado"
	cells.clear()
	volume_ref = null

func requirements() -> String:
	if kind == "tunnel": return "0,3 de matéria por bloco de terra, até 96 por túnel"
	return "32 de matéria · 4 s de trabalho" if kind == "dam" else "16 de matéria · 2,5 s de trabalho"

func _process(_delta: float) -> void:
	if not running or thing.is_dead or thing.is_captured:
		if caption != null: caption.hide()
		return
	if caption == null:
		caption = Label3D.new()
		caption.name = "BuilderProgress"
		caption.font_size = 22
		caption.pixel_size = .004
		caption.outline_size = 5
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		thing.add_child(caption)
	caption.show()
	caption.position = thing.bounds.get_center() + Vector3.UP * (thing.bounds.size.y * .5 + .35)
	caption.text = "%s · %d%%" % [state.capitalize(), roundi(progress * 100)]

func _within_cap() -> bool:
	if kind == "tunnel": return dug_total < 192 and _team_dug() < int(Lexicon.balf("creature_builders.dig_team_cell_cap"))
	var owned := 0
	var team_count := 0
	for item in get_tree().get_nodes_in_group("creature_builder_products"):
		if item.thing.is_dead or item.kind != kind: continue
		if item.thing.spawner == thing: owned += 1
		if item.thing.team == thing.team: team_count += 1
	return owned < (2 if kind == "dam" else 3) and team_count < (6 if kind == "dam" else 8)

func _team_dug() -> int:
	var id := Forge.world.get_instance_id()
	if dig_world != id:
		dig_world = id
		team_digs.clear()
	return int(team_digs.get(thing.team, 0))

func _dig_plan(volume: BlockVolume, at: Vector3, forward: Vector3, up: Vector3) -> Array:
	var plan := []
	var seen := {}
	var limit := mini(int(Lexicon.balf("creature_builders.dig_cells_per_job")), mini(192 - dug_total, int(Lexicon.balf("creature_builders.dig_team_cell_cap")) - _team_dug()))
	for step in 16:
		var center := volume.cell_of(volume.to_local(at + forward * step * .25 - up * (.25 + minf(step * .04, .45))))
		for x in range(-2, 3):
			for y in range(-2, 3):
				for z in range(-2, 3):
					var cell := center + Vector3i(x, y, z)
					if Vector3(x, y, z).length() > 2.1 or not volume.inside(cell): continue
					var index := volume.index_of(cell)
					if seen.has(index) or not _diggable(volume, index): continue
					seen[index] = true
					plan.append(index)
					if plan.size() >= limit: return plan
	return plan

func _diggable(volume: BlockVolume, index: int) -> bool:
	if index < 0 or index >= volume.blocks.size(): return false
	var type := int(volume.blocks[index])
	return type != BlockVolume.AIR and volume.type_material(type) in ["soil", "sand"] and (volume._pal_flags[type] & BlockVolume.FLAG_FOREVER) == 0

func _site_clear() -> bool:
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 1.3, .36) if kind == "dam" else Vector3(2.2, 1.2, .10)
	var frame := Gravity.frame_for(thing.up())
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(frame, work_point + thing.up() * .78)
	query.collision_mask = PhysicsLayers.WORLD | PhysicsLayers.THINGS | PhysicsLayers.TRAPS
	query.exclude = [thing.get_rid()]
	if thing.owner_player is PhysicsBody3D: query.exclude.append(thing.owner_player.get_rid())
	return thing.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _physics_process(delta: float) -> void:
	if not running or not thing.has_simulation_authority() or not thing.can_act() or thing.is_captured: return
	var orders := thing.get_node_or_null("AnimalOrders")
	if orders == null or orders.mode != "build": cancel(); return
	if not is_instance_valid(thing.owner_player) or not thing.owner_player.is_alive(): cancel(); return
	tick_left -= delta
	if tick_left > 0: return
	tick_left = Lexicon.balf("creature_builders.work_tick_s")
	if thing.global_position.distance_to(work_point) > 3.5:
		state = "indo ao local"
		return
	var frame := Engine.get_process_frames()
	if frame != work_frame: work_frame = frame; work_count = 0
	if work_count >= 4: return
	work_count += 1
	state = "construindo"
	if kind == "tunnel":
		_dig_step()
		return
	var seconds := Lexicon.balf("creature_builders.dam_seconds" if kind == "dam" else "creature_builders.web_seconds")
	progress = minf(1.0, progress + tick_left / seconds)
	if progress < 1.0: return
	if not _within_cap() or not _site_clear(): state = "local ocupado ou limite atingido"; return
	var id := "beaver_dam" if kind == "dam" else "spider_web"
	var cost := Lexicon.data.thing_statf(id, "cost")
	var player := thing.owner_player as Player
	if not player.try_spend(cost): state = "sem matéria"; return
	var product := Forge.spawn_child(Recipe.new_node(id), "spawned", work_point + thing.up() * .03, heading, thing, 0.0, Vector3.ZERO, true)
	if product == null:
		player.add_matter(cost)
		state = "aguardando criação"
		return
	product.matter = cost
	_finish()

func _dig_step() -> void:
	var volume = volume_ref.get_ref() if volume_ref != null else null
	if not is_instance_valid(volume): cancel(); return
	var price := Lexicon.balf("creature_builders.dig_cell_cost")
	for step in 4:
		if cell_cursor >= cells.size() or dug_total >= 192 or _team_dug() >= int(Lexicon.balf("creature_builders.dig_team_cell_cap")): _finish(); return
		var index: int = cells[cell_cursor]
		if not _diggable(volume, index): cell_cursor += 1; continue
		if not thing.owner_player.try_spend(price): state = "sem matéria"; return
		volume.remove_cells([index], false)
		dug_total += 1
		team_digs[thing.team] = _team_dug() + 1
		cell_cursor += 1
	progress = float(cell_cursor) / maxf(1.0, cells.size())
	if cell_cursor >= cells.size(): _finish()

func _finish() -> void:
	running = false
	completed += 1
	progress = 1.0
	state = "concluído"
	cooldown_until = Time.get_ticks_msec() + int(Lexicon.balf("creature_builders.cooldown_s") * 1000)
	var orders := thing.get_node_or_null("AnimalOrders")
	orders.mode = "stay"
	orders.point = thing.global_position
	orders.goal = thing.global_position
	ExpansionFx.burst(Forge.fx_root(thing), thing.center(), .6, Color("c0be8b"), "builder_done")

func snapshot() -> Dictionary:
	return {"kind": kind, "running": running, "progress": progress, "completed": completed, "dug": dug_total, "state": state}
func apply_snapshot(values: Dictionary) -> void:
	running = bool(values.get("running", false))
	progress = float(values.get("progress", 0.0))
	completed = int(values.get("completed", 0))
	dug_total = int(values.get("dug", 0))
	state = String(values.get("state", "parado"))
