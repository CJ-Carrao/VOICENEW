class_name ForgeReplication
extends Node



signal baseline_ready(epoch: int)

const CONFIG_PATH: = "res://data/network.json"

var epoch: int = 0
var entries: Dictionary = {}
var stats: Dictionary = {"requests": 0, "confirms": 0, "cancels": 0, "rejected": 0, 
	"spawns": 0, "states_sent": 0, "states_applied": 0}

var _session: NetworkSession
var _world: Match
var _spawner: MultiplayerSpawner
var _spawn_root: Node
var _config: Dictionary = {}
var _pending_host: Dictionary = {}
var _entity_serial: = 0
var _request_serial: = 0
var _draft_serial: = 0
var _draft_ids: Dictionary = {}
var _intent_context: Dictionary = {}
var _intent_peers: Dictionary = {}
var _last_reply: Dictionary = {}
var _generation: = -1
var _ready_epoch: = 0
var _state_serial: = 0
var _last_state_serial: = 0
var _expected_ids: Array = []
var _baseline_ended: = false
var _pending_states: Dictionary = {}
var _last_states: Dictionary = {}
var _last_builds: Dictionary = {}
var _elapsed: = 0.0
var _motion_elapsed: = 0.0
var _motion_sequence: = 0
var _motion_seen: Dictionary = {}
var _fx_budget_tick: = -1
var _fx_count: = 0
var _preflight_cache: Dictionary = {}


func _ready() -> void :
	_session = get_parent() as NetworkSession
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 50
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		_config = parsed.get("creations", {})
	if not _valid_config(_config):
		_config = {}
	_spawn_root = Node.new()
	_spawn_root.name = "Entities"
	add_child(_spawn_root)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	_spawner.spawn_path = NodePath("../Entities")
	_spawner.spawn_limit = int(_config.get("max_entities", 128))
	_spawner.spawn_function = _spawn_entry
	add_child(_spawner)
	_session.changed.connect(_on_session_changed)
	_session.replication.active_changed.connect(_on_activity_changed)
	Forge.request_processed.connect(_on_request_processed)
	Forge.draft_changed.connect(_on_draft_changed)
	Forge.draft_confirmed.connect(_on_draft_confirmed)
	Forge.build_finished.connect(_on_build_finished)
	_on_session_changed()


func bind_world(world: Match) -> void :
	if _world == world:
		return
	if is_instance_valid(_world):
		unbind_world()
	_world = world
	_world.state_changed.connect(_on_activity_changed)
	if _config.is_empty():
		_session.stop_online("Configuração de criação em rede indisponível.")
		return
	for id: int in entries:
		_attach_replica(entries[id])
	_check_baseline_ready()


func unbind_world(world: Match = null) -> void :
	if world != null and world != _world:
		return
	_ready_epoch = 0
	if is_instance_valid(_world) and _world.state_changed.is_connected(_on_activity_changed):
		_world.state_changed.disconnect(_on_activity_changed)
	_world = null
	_clear_entries()
	_pending_states.clear()
	_last_states.clear()
	_last_builds.clear()
	_draft_ids.clear()


func is_active() -> bool:
	return _session.is_online() and is_instance_valid(_world) and _session.replication.is_active() and is_ready_for_epoch(_session.replication.epoch)


func is_ready_for_epoch(value: int) -> bool:
	return value > 0 and value == epoch and _ready_epoch == value and is_instance_valid(_world)


func replica_for_id(id: int) -> Thing:
	var entry: = entries.get(id) as NetworkThingEntry
	return entry.thing if is_instance_valid(entry) and is_instance_valid(entry.thing) and not entry.thing.is_dead else null


func thing_reference(thing: Thing) -> Dictionary:
	if not is_instance_valid(thing):
		return {}
	var path: Array[int] = []
	while thing.network_id == 0 and is_instance_valid(thing.mount_host):
		path.push_front(thing.mount_host.grafts.find(thing))
		thing = thing.mount_host
	return {"id": thing.network_id, "path": path}


func resolve_reference(reference: Dictionary) -> Thing:
	var thing: = replica_for_id(int(reference.get("id", 0)))
	var path: Array = reference.get("path", [])
	if path.size() > int(Lexicon.balf("caps.graft_depth")):
		return null
	for index: int in path:
		if thing == null or index < 0 or index >= thing.grafts.size():
			return null
		thing = thing.grafts[index]
	return thing if is_instance_valid(thing) and not thing.is_dead else null


func _on_session_changed() -> void :
	if _generation != _session.generation:
		_generation = _session.generation
		epoch = 0
		_ready_epoch = 0
		_request_serial = 0
		_intent_peers.clear()
		_last_reply.clear()
		_pending_states.clear()
		_last_states.clear()
		_last_state_serial = 0
		_motion_seen.clear()
		_expected_ids.clear()
		_baseline_ended = false
		if not _session.has_authority():
			_clear_entries()
	if not _session.is_ready() or not _session.is_online():
		_ready_epoch = 0
		_baseline_ended = false
		_pending_states.clear()
		if not _session.is_online() or not _session.has_authority():
			_clear_entries()


func _clear_entries() -> void :
	for entry: NetworkThingEntry in entries.values():
		if is_instance_valid(entry):
			entry.queue_free()
	entries.clear()
	_pending_host.clear()
	if not _session.has_authority():
		Forge.clear_network_presentation()


static func _valid_config(config: Dictionary) -> bool:
	for key in ["max_text_bytes", "max_spawn_bytes", "max_batch_bytes", "max_intent_lead"]:
		var value: Variant = config.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 1.0 or float(value) != floorf(float(value)):
			return false
	for key in ["state_hz", "motion_hz", "fx_per_second", "intents_per_second", "intent_burst", "placement_tolerance_m"]:
		var value: Variant = config.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0.0:
			return false
	var cap: Variant = config.get("max_entities")
	return (cap is int or cap is float) and is_finite(float(cap)) and float(cap) == floorf(float(cap)) and int(cap) >= 0 and int(config.max_spawn_bytes) <= 65536 and int(config.max_batch_bytes) <= 65536 and int(config.max_text_bytes) <= 4096


func _next_request_id() -> int:
	_request_serial += 1
	return _request_serial


func submit_request(text: String, record_unknowns: bool = true, commands_only: bool = false) -> Dictionary:
	if not is_active() or _session.has_authority():
		return _blocked("A sessão ainda não está pronta para pedidos.")
	var request_id: = _next_request_id()
	_request_creation.rpc_id(1, epoch, request_id, text, record_unknowns, commands_only)
	return {"pending": true, "request_id": request_id}


func submit_confirm(dims: Dictionary, at: Vector3 = Vector3.INF, forward: Vector3 = Vector3.ZERO) -> Dictionary:
	if not is_active() or _session.has_authority():
		return _blocked("A sessão ainda não está pronta para confirmar o rascunho.")
	var request_id: = _next_request_id()
	var draft: = Forge.draft_of(_session.local_player_id)
	var placement: = {} if at == Vector3.INF else {"at": at, "forward": forward}
	_confirm_creation.rpc_id(1, epoch, request_id, int(draft.get("draft_id", 0)), dims, placement)
	return {"pending": true, "request_id": request_id}


func submit_cancel() -> void :
	if not is_active() or _session.has_authority():
		return
	var draft: = Forge.draft_of(_session.local_player_id)
	_cancel_creation.rpc_id(1, epoch, _next_request_id(), int(draft.get("draft_id", 0)))


@rpc("any_peer", "call_remote", "reliable", 0)
func _request_creation(packet_epoch: int, request_id: int, text: Variant, record_unknowns: Variant = true, commands_only: Variant = false) -> void :
	var player_id: = _accept_intent(packet_epoch, request_id)
	if player_id == 0:
		return
	if not text is String or not record_unknowns is bool or not commands_only is bool or text.strip_edges().is_empty() or text.to_utf8_buffer().size() > int(_config.max_text_bytes):
		_reject_intent(player_id, request_id, "O pedido está vazio ou excede o tamanho permitido.")
		return
	stats.requests += 1
	_intent_context[player_id] = request_id
	Forge.request(player_id, text, record_unknowns, commands_only)
	_intent_context.erase(player_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _confirm_creation(packet_epoch: int, request_id: int, draft_id: int, dimensions: Dictionary, placement: Dictionary) -> void :
	var player_id: = _accept_intent(packet_epoch, request_id)
	if player_id == 0:
		return
	var draft: = Forge.draft_of(player_id)
	if draft.is_empty() or draft_id <= 0 or draft_id != int(_draft_ids.get(player_id, 0)):
		_reject_intent(player_id, request_id, "Esse rascunho já foi alterado ou cancelado.")
		return
	var clean: = _validate_confirmation(player_id, draft, dimensions, placement)
	if clean.has("error"):
		_reject_intent(player_id, request_id, str(clean.error))
		return
	stats.confirms += 1
	_intent_context[player_id] = request_id
	Forge.confirm_draft(player_id, clean.dims, clean.at, clean.forward)
	_intent_context.erase(player_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func _cancel_creation(packet_epoch: int, request_id: int, draft_id: int) -> void :
	var player_id: = _accept_intent(packet_epoch, request_id)
	if player_id == 0:
		return
	if draft_id <= 0 or draft_id != int(_draft_ids.get(player_id, 0)):
		_reject_intent(player_id, request_id, "Esse rascunho já foi alterado ou cancelado.")
		return
	stats.cancels += 1
	Forge.cancel_draft(player_id)


func _accept_intent(packet_epoch: int, request_id: int) -> int:
	var sender: = multiplayer.get_remote_sender_id()
	var player_id: = _session.player_for_peer(sender)
	if not is_active() or not _session.has_authority() or packet_epoch != epoch or sender <= 1 or player_id <= 1:
		stats.rejected += 1
		return 0
	var now: = Time.get_ticks_msec()
	var stream: Dictionary = _intent_peers.get(sender, {"last": 0, "tokens": float(_config.intent_burst), "at": now})
	stream.tokens = minf(float(_config.intent_burst), float(stream.tokens) + maxf(0.0, float(now - int(stream.at)) / 1000.0) * float(_config.intents_per_second))
	stream.at = now
	_intent_peers[sender] = stream
	if float(stream.tokens) < 1.0 or request_id <= int(stream.last) or request_id > int(stream.last) + int(_config.max_intent_lead):
		stats.rejected += 1
		return 0
	stream.tokens = float(stream.tokens) - 1.0
	stream.last = request_id
	return player_id


func _validate_confirmation(player_id: int, draft: Dictionary, dims: Dictionary, placement: Dictionary) -> Dictionary:
	if dims.size() > 4 or var_to_bytes(dims).size() > 256:
		return {"error": "Medidas inválidas."}
	var clean_dims: = {}
	for key: Variant in dims:
		var value: Variant = dims[key]
		if not key is String or not key in Shape.dim_ids(Lexicon.data) or not (value is int or value is float) or not is_finite(float(value)):
			return {"error": "Medidas inválidas."}
		if float(value) < Lexicon.balf("shaping.min." + key) or float(value) > Lexicon.balf("shaping.max." + key):
			return {"error": "Medidas fora dos limites."}
		clean_dims[key] = Shape.clamp_dim(key, float(value), Lexicon.data)
	var kind: = Lexicon.data.placement_for(str(draft.recipe.get("thing", "")))
	if kind in ["hand", "throwable"]:
		if not placement.is_empty():
			return {"error": "Itens da mão não aceitam uma posição no mundo."}
		return {"dims": clean_dims, "at": Vector3.INF, "forward": Vector3.ZERO}
	if placement.size() != 2 or not placement.get("at") is Vector3 or not placement.get("forward") is Vector3:
		return {"error": "Posição do rascunho inválida."}
	var at: Vector3 = placement.at
	var direction: Vector3 = placement.forward
	if not at.is_finite() or not direction.is_finite() or direction.length_squared() < 0.01 or direction.length_squared() > 4.0:
		return {"error": "Posição do rascunho inválida."}
	var player: = _world.get_player(player_id)

	var up: = player.up()
	var offset: = Gravity.flat(at - player.global_position, up)
	var maximum: = Lexicon.balf("placement.structure_max_range") if kind == "aim_ground" else Lexicon.balf("placement.front_distance")
	var tolerance: = float(_config.placement_tolerance_m)
	var half: = Lexicon.balf("arena.size") * 0.5
	var outside: = ( not Gravity.inside_world(at, 0.0)) if Gravity.active() else (absf(at.x) > half or absf(at.z) > half)
	if offset.length() > maximum + tolerance or outside:
		return {"error": "O rascunho está fora do alcance."}
	var authoritative_ground: = Forge.ground_point(at + up * ((player.global_position - at).dot(up) + tolerance), up)
	if absf((at - authoritative_ground).dot(up)) > tolerance:
		return {"error": "O rascunho precisa estar apoiado no mundo."}
	if offset.length() > maximum:
		var clamped: = player.global_position + offset.normalized() * maximum
		authoritative_ground = Forge.ground_point(clamped + up * tolerance, up)
	direction = Gravity.flat(direction, up)
	if direction.length_squared() < 0.01:
		return {"error": "Direção do rascunho inválida."}
	return {"dims": clean_dims, "at": authoritative_ground, "forward": direction.normalized()}


static func _blocked(message: String) -> Dictionary:
	return {"ok": false, "blocked": true, "warnings": [message]}


func _reject_intent(player_id: int, request_id: int, reason: String) -> void :
	stats.rejected += 1
	var result: = _blocked(reason)
	result["request_id"] = request_id
	_creation_result.rpc_id(_session.peer_for_player(player_id), epoch, player_id, "", result, false)


func _on_request_processed(player_id: int, text: String, result: Dictionary) -> void :
	_publish_result(player_id, text, result, false)


func _on_draft_confirmed(player_id: int, result: Dictionary) -> void :
	_publish_result(player_id, str(result.get("text", "")), result, true)


func _publish_result(player_id: int, text: String, result: Dictionary, confirmed: bool) -> void :
	if not is_active() or not _session.has_authority():
		return
	var packet: = result.duplicate(true)
	packet["request_id"] = int(_intent_context.get(player_id, 0))
	if var_to_bytes(packet).size() <= int(_config.max_spawn_bytes):
		for peer: int in _session.remote_peer_ids():
			_creation_result.rpc_id(peer, epoch, player_id, text, packet, confirmed)


@rpc("authority", "call_remote", "reliable", 0)
func _creation_result(packet_epoch: int, player_id: int, text: String, result: Dictionary, confirmed: bool) -> void :
	if _session.has_authority() or packet_epoch != epoch or not _session.roster.has(player_id) or var_to_bytes(result).size() > int(_config.max_spawn_bytes):
		return
	var request_id: = int(result.get("request_id", 0))
	if request_id > 0:
		if request_id <= int(_last_reply.get(player_id, 0)):
			return
		_last_reply[player_id] = request_id
	Forge.receive_network_result(player_id, text, result, confirmed)


func _on_draft_changed(player_id: int) -> void :
	if not _session.is_online() or not _session.has_authority():
		return
	var draft: = Forge.draft_of(player_id)
	if draft.is_empty():
		_draft_ids.erase(player_id)
	else:
		_draft_serial += 1
		_draft_ids[player_id] = _draft_serial
		draft["draft_id"] = _draft_serial
		draft["novelty_mult"] = float(Forge.novelty_of(player_id, draft.recipe).mult)
	if is_active():
		for peer: int in _session.remote_peer_ids():
			_draft_state.rpc_id(peer, epoch, player_id, draft)


@rpc("authority", "call_remote", "reliable", 0)
func _draft_state(packet_epoch: int, player_id: int, draft: Dictionary) -> void :
	if _session.has_authority() or packet_epoch != epoch or not _session.roster.has(player_id) or var_to_bytes(draft).size() > int(_config.max_spawn_bytes):
		return
	Forge.receive_network_draft(player_id, draft)


func prepare_creation(thing: Thing) -> void :
	if not _session.is_online() or not _session.has_authority() or thing.network_id > 0:
		return
	_entity_serial += 1
	thing.network_id = _entity_serial
	thing.build_seed = int(randi()) + 1




func creation_warning(player_id: int, recipe: Dictionary, cost: float, descendant: bool = false) -> String:
	if not _session.is_online():
		return ""
	if not is_active() or not _session.has_authority():
		return "A sessão ainda não está pronta para pedidos."
	if not recipe.has("thing"):
		return ""
	if var_to_bytes(recipe).size() > 8192:
		return "A receita excede o tamanho permitido para esta sessão."
	var placement: = "world" if descendant else Lexicon.data.placement_for(str(recipe.thing))
	var count: = 1 if descendant or placement in ["hand", "throwable", "attach", "load"] else maxi(1, int((recipe.get("mods", {}) as Dictionary).get("count", 1)))
	var reclaimed: = 0
	var reclaimed_live: = 0
	var player: = _world.get_player(player_id)
	if not descendant and player != null and Forge.transmutes(recipe):
		var held: = player.hands.current_item()
		if held != null and entries.has(held.network_id):
			reclaimed = 1
			for old: Thing in Forge.live_things(player_id):
				if old == held or held.is_ancestor_of(old):
					reclaimed_live += 1
	if int(_config.max_entities) > 0 and entries.size() + count - reclaimed > int(_config.max_entities):
		return "Há criações demais nesta sessão. Recicle uma antes de pedir mais."
	var cache_key: = str(descendant) + JSON.stringify(recipe, "", true)
	if _preflight_cache.has(cache_key):
		return _budget_warning(player_id, count, reclaimed_live, _preflight_cache[cache_key])
	var probe: = Assembler.build(recipe, "head", Lexicon.data)
	var pieces: = probe.model_pieces.size()
	var registered: = _count_thing_nodes(probe)
	var gameplay: = ThingNetworkState.capture(probe)
	if placement in ["hand", "throwable"]:
		registered -= 1
	probe.free()
	var floats: = PackedFloat32Array()
	floats.resize(pieces)
	var vectors: = PackedVector3Array()
	vectors.resize(pieces)
	var indices: = PackedInt32Array()
	indices.resize(pieces)
	var build: = {"clock": 1.0, "flight_clock": 1.0, "launched": pieces, "landed": indices, 
		"progress": 1.0, "paid": 1.0, "waiting_matter": false, "stored": false, "done": true, 
		"cancelled": false, "state": "cancelled", "matter": cost, "launch_times": floats, 
		"flight_durations": floats, "flight_origins": vectors, "flight_controls": vectors, 
		"spins": vectors, "impact_at": 1.0}
	var state: = {"id": 2147483647, "relation": "world", "slot": 2, "parent_id": 2147483647, 
		"transform": Transform3D.IDENTITY, "build": build, "matter": cost, "building": true, 
		"visible": true, "dead": false, "gameplay": gameplay}
	var descriptor: = {"id": 2147483647, "seed": 4294967295, "recipe": recipe, "role": "head", 
		"owner_id": player_id, "team": player_id, "generation": 0, "matter_returns": true, 
		"seconds": 1.0, "cost": cost, "activate_after": true, "state": state}
	var budget: = {"registered": registered, "spawn_bytes": var_to_bytes(descriptor).size() + 16384, 
		"state_bytes": var_to_bytes([state]).size() + 16384}
	if _preflight_cache.size() >= 128:
		_preflight_cache.clear()
	_preflight_cache[cache_key] = budget
	return _budget_warning(player_id, count, reclaimed_live, budget)


func _budget_warning(player_id: int, count: int, reclaimed_live: int, budget: Dictionary) -> String:


	var live_after: = Forge.live_things(player_id).size() + int(budget.registered) * count - reclaimed_live
	var live_cap := int(Lexicon.balf("caps.live_entities_per_player"))
	if live_cap > 0 and live_after > live_cap:
		return "Há criações e anexos demais em uso. Recicle uma criação antes de pedir mais."
	if int(budget.spawn_bytes) > int(_config.max_spawn_bytes) or int(budget.state_bytes) > int(_config.max_batch_bytes):
		return "A criação tem peças demais para esta sessão. Reduza os anexos ou simplifique o pedido."
	return ""


func _count_thing_nodes(thing: Thing) -> int:
	var count: = 1
	for graft: Thing in thing.grafts:
		count += _count_thing_nodes(graft)
	return count


func descendant_allowed(player_id: int, recipe: Dictionary) -> bool:
	return creation_warning(player_id, recipe, 0.0, true).is_empty()


func publish_creation(thing: Thing, seconds: float, activate_after: bool, cost: float) -> void :
	if not is_active() or not _session.has_authority() or not is_instance_valid(thing):
		return
	prepare_creation(thing)
	if entries.has(thing.network_id):
		return
	var descriptor: = {"id": thing.network_id, "seed": thing.build_seed, "recipe": thing.node_data.duplicate(true), 
		"role": thing.role, "owner_id": thing.owner_id, "team": thing.team, "generation": thing.generation, 
		"matter_returns": thing.matter_returns, "seconds": seconds, "cost": cost, "activate_after": activate_after, 
		"state": _capture_state(thing)}
	if not _valid_descriptor(descriptor) or (int(_config.max_entities) > 0 and entries.size() >= int(_config.max_entities)):
		push_error("Creation exceeds the bounded multiplayer spawn envelope.")
		return
	_pending_host[thing.network_id] = thing
	var entry: = _spawner.spawn(descriptor) as NetworkThingEntry
	_pending_host.erase(thing.network_id)
	if entry == null:
		return
	thing.removed.connect(_on_thing_removed)
	stats.spawns += 1


func _spawn_entry(data: Variant) -> Node:
	if not data is Dictionary or not _valid_descriptor(data):
		return null
	var id: = int(data.id)
	if entries.has(id):
		return null
	var entry: = NetworkThingEntry.new()
	entry.name = "Thing_%d" % id
	entry.descriptor = data.duplicate(true)
	entry.replica = not _session.has_authority()
	if entry.replica:
		entry.thing = Assembler.build_replica(data.recipe, str(data.role), Lexicon.data, id, int(data.seed))
		entry.thing.set_owner_info(int(data.owner_id), int(data.team), null, null)
		entry.thing.set_generation(int(data.generation))
		entry.thing.matter_returns = bool(data.matter_returns)
		entry.thing.visible = false
		entry.add_child(entry.thing)
	else:
		entry.thing = _pending_host.get(id) as Thing
		if not is_instance_valid(entry.thing):
			entry.free()
			return null
	entries[id] = entry
	entry.ready.connect(_entry_ready.bind(entry), CONNECT_ONE_SHOT)
	entry.tree_exited.connect(_entry_exited.bind(id, entry))
	return entry


func _valid_descriptor(data: Dictionary) -> bool:
	if data.size() != 12 or var_to_bytes(data).size() > int(_config.max_spawn_bytes):
		return false
	for key in ["id", "seed", "owner_id", "team", "generation"]:
		if not data.get(key) is int:
			return false
	if int(data.id) <= 0 or int(data.seed) <= 0 or int(data.owner_id) < 1 or int(data.owner_id) > NetworkSession.MAX_PLAYERS or int(data.generation) < 0:
		return false
	for key in ["seconds", "cost"]:
		if not (data.get(key) is int or data.get(key) is float) or not is_finite(float(data[key])) or float(data[key]) < 0.0:
			return false
	return data.get("recipe") is Dictionary and data.get("role") is String and data.get("state") is Dictionary\
	and data.get("matter_returns") is bool and data.get("activate_after") is bool and not Lexicon.data.thing_def(str(data.recipe.get("thing", ""))).is_empty()


func _entry_ready(entry: NetworkThingEntry) -> void :
	if entry.replica:
		_attach_replica(entry)
		var state: Dictionary = _pending_states.get(int(entry.descriptor.id), entry.descriptor.state)
		_apply_state(state, true)
	for id: int in _pending_states:
		if int(_pending_states[id].get("parent_id", 0)) == entry.thing.network_id:
			_apply_state(_pending_states[id], true)
	_check_baseline_ready()


func _entry_exited(id: int, entry: NetworkThingEntry) -> void :
	if entries.has(id) and entries[id] != entry:
		return
	if entries.get(id) == entry:
		entries.erase(id)
	_pending_states.erase(id)
	_last_states.erase(id)
	_last_builds.erase(id)
	_motion_seen.erase(id)


func _attach_replica(entry: NetworkThingEntry) -> void :
	if not entry.replica or not is_instance_valid(_world) or not is_instance_valid(entry.thing):
		return
	var thing: = entry.thing
	var player: = _world.get_player(int(entry.descriptor.owner_id))
	thing.set_owner_info(player.player_id, int(entry.descriptor.team), player, null)
	thing.set_generation(int(entry.descriptor.generation))
	_match_mount_exceptions(thing, player)
	if thing.get_parent() == entry:
		entry.remove_child(thing)
		_world.add_thing(thing)
	var state: Dictionary = _pending_states.get(thing.network_id, entry.descriptor.state)
	if thing.get_node_or_null("BuildAnimator") == null and (bool(state.get("building", true)) or thing.model_pieces.any( func(piece: MeshInstance3D): return not piece.visible)):
		var animator: = BuildAnimator.new()
		animator.name = "BuildAnimator"
		animator.visual_only = true
		animator.seed = int(entry.descriptor.seed)
		animator.matter_cost = float(entry.descriptor.cost)
		thing.add_child(animator)
		animator.start(thing, float(entry.descriptor.seconds))
	_apply_state(state, true)


	player.hands.apply_network_state(player.hands.export_network_state())


func _match_mount_exceptions(thing: Thing, player: Player) -> void :
	for graft: Thing in thing.grafts:
		graft.add_collision_exception_with(player)
		var host: = graft.mount_host
		while is_instance_valid(host):
			host.add_collision_exception_with(graft)
			graft.add_collision_exception_with(host)
			host = host.mount_host
		_match_mount_exceptions(graft, player)


func _on_thing_removed(thing: Thing) -> void :
	var entry: = entries.get(thing.network_id) as NetworkThingEntry
	if is_instance_valid(entry):
		entries.erase(thing.network_id)


		if entry.get_parent() == _spawn_root:
			_spawn_root.remove_child(entry)
		entry.queue_free()
	_last_states.erase(thing.network_id)
	_last_builds.erase(thing.network_id)


func _on_build_finished(_player_id: int, thing: Thing) -> void :
	if _session.is_online() and _session.has_authority() and is_instance_valid(thing) and entries.has(thing.network_id):
		_capture_state(thing)


func _capture_state(thing: Thing) -> Dictionary:
	var build: Dictionary = _last_builds.get(thing.network_id, {})
	var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
	if animator != null:
		build = animator.export_network_state()
		_last_builds[thing.network_id] = build
	if not thing.is_building:
		build = {"done": true, "progress": 1.0, "matter": thing.matter}
	var relation: = "world"
	var slot: = -1
	var parent_id: = 0
	if thing.is_held and not thing.is_captured:
		relation = "hand"
		var player: = thing.owner_player as Player
		if player != null:
			for index in player.hands.slot_count():
				if player.hands.item_at(index) == thing:
					slot = index
	if thing.get_parent() is Thing:
		relation = "child"
		parent_id = (thing.get_parent() as Thing).network_id
	return {"id": thing.network_id, "relation": relation, "slot": slot, "parent_id": parent_id, 
		"transform": thing.global_transform if relation == "world" else thing.transform, 
		"build": build, "matter": thing.matter, "building": thing.is_building, 
		"visible": thing.visible, "dead": thing.is_dead, "gameplay": ThingNetworkState.capture(thing)}


func _process(delta: float) -> void :
	if not is_active() or not _session.has_authority():
		return
	_motion_elapsed += delta
	if _motion_elapsed >= 1.0 / float(_config.get("motion_hz", 20.0)):
		_motion_elapsed = 0.0
		_send_motion()
	_elapsed += delta
	if _elapsed < 1.0 / float(_config.state_hz):
		return
	_elapsed = 0.0
	var changed: Array[Dictionary] = []
	for id: int in entries:
		var thing: = replica_for_id(id)
		if thing == null:
			continue
		var state: = _capture_state(thing)
		var previous: Dictionary = _last_states.get(id, {}).duplicate(true)
		if state.relation == "world" and not previous.is_empty():
			previous["transform"] = state.transform
		if state != previous:
			changed.append(state)
			_last_states[id] = state.duplicate(true)
	for peer: int in _session.remote_peer_ids():
		_send_states(changed, peer)


func prepare_epoch(value: int, peer: int) -> void :
	if epoch != value:
		_state_serial = 0
		_intent_peers.clear()
		_intent_context.clear()
		_last_states.clear()
	epoch = value
	_ready_epoch = value
	var ids: = entries.keys()
	ids.sort()
	_sync_begin.rpc_id(peer, epoch, ids)


	for player_id: int in _session.player_ids():
		_draft_state.rpc_id(peer, epoch, player_id, Forge.draft_of(player_id))
	var states: Array[Dictionary] = []
	for id: int in ids:
		var thing: = replica_for_id(id)
		if thing != null:
			states.append(_capture_state(thing))
	_send_states(states, peer)
	_sync_end.rpc_id(peer, epoch)


@rpc("authority", "call_remote", "reliable", 0)
func _sync_begin(value: int, ids: Array) -> void :
	if _session.has_authority() or not _session.is_ready() or value < epoch or value <= 0 or (int(_config.max_entities) > 0 and ids.size() > int(_config.max_entities)):
		return
	var seen: = {}
	for id: Variant in ids:
		if not id is int or id <= 0 or seen.has(id):
			return
		seen[id] = true
	epoch = value
	_ready_epoch = 0
	_request_serial = 0
	_last_reply.clear()
	_last_state_serial = 0
	_motion_seen.clear()
	_expected_ids = ids.duplicate()
	_baseline_ended = false
	_pending_states.clear()
	for player_id: int in _session.player_ids():
		Forge.receive_network_draft(player_id, {})


func _send_states(states: Array[Dictionary], peer: int) -> void :
	var batch: Array[Dictionary] = []
	for state: Dictionary in states:
		var trial: = batch.duplicate()
		trial.append(state)
		if var_to_bytes(trial).size() > int(_config.max_batch_bytes):
			_send_batch(batch, peer)
			batch.clear()
		batch.append(state)
	_send_batch(batch, peer)


func _send_batch(batch: Array[Dictionary], peer: int) -> void :
	if batch.is_empty():
		return
	var payload: = PlayerReplication.encode_packet(batch, int(_config.max_batch_bytes))
	if payload.is_empty():
		push_error("Creation build state exceeds the bounded multiplayer envelope.")
		return
	_state_serial += 1
	_states.rpc_id(peer, epoch, _state_serial, payload)
	stats.states_sent += batch.size()


@rpc("authority", "call_remote", "reliable", 0)
func _states(packet_epoch: int, sequence: int, payload: PackedByteArray) -> void :
	if _session.has_authority() or packet_epoch != epoch or sequence <= _last_state_serial:
		return
	var states: Variant = PlayerReplication.decode_packet(payload, int(_config.max_batch_bytes))
	if not states is Array or (int(_config.max_entities) > 0 and states.size() > int(_config.max_entities)):
		return
	_last_state_serial = sequence
	for state: Variant in states:
		if not state is Dictionary or not _valid_state(state):
			continue
		var id: = int(state.id)
		if int(_config.max_entities) == 0 or _pending_states.size() < int(_config.max_entities) or _pending_states.has(id):
			_pending_states[id] = state
			_apply_state(state, _ready_epoch != epoch)
	_check_baseline_ready()


@rpc("authority", "call_remote", "reliable", 0)
func _sync_end(value: int) -> void :
	if not _session.has_authority() and value == epoch:
		_baseline_ended = true
		_check_baseline_ready()


func _check_baseline_ready() -> void :
	if _session == null or _session.has_authority() or not _baseline_ended or not is_instance_valid(_world) or _ready_epoch == epoch:
		return
	for id: int in _expected_ids:
		var entry: = entries.get(id) as NetworkThingEntry
		if not is_instance_valid(entry) or not entry.is_inside_tree() or not _pending_states.has(id) or not is_instance_valid(entry.thing):
			return
		_apply_state(_pending_states[id], true)
	for id: int in _expected_ids:
		_apply_state(_pending_states[id], true)
	_ready_epoch = epoch
	baseline_ready.emit(epoch)


func _valid_state(state: Dictionary) -> bool:
	if state.size() != 11 or not state.get("id") is int or not state.get("slot") is int or not state.get("parent_id") is int or not state.get("relation") in ["world", "hand", "child"]:
		return false
	if not state.get("transform") is Transform3D or not (state.transform as Transform3D).is_finite() or not state.get("build") is Dictionary:
		return false
	if not (state.get("matter") is int or state.get("matter") is float) or not is_finite(float(state.matter)) or float(state.matter) < 0.0:
		return false
	return state.get("gameplay") is Dictionary and int(state.id) > 0 and state.get("building") is bool and state.get("visible") is bool and state.get("dead") is bool


func _apply_state(state: Dictionary, baseline: bool) -> void :
	if not _valid_state(state) or not is_instance_valid(_world):
		return
	var thing: = replica_for_id(int(state.id))
	if thing == null or not thing.network_replica or not thing.is_inside_tree():
		return
	var entry: = entries.get(int(state.id)) as NetworkThingEntry
	if thing.owner_player == null:
		thing.set_owner_info(int(entry.descriptor.owner_id), int(entry.descriptor.team), _world.get_player(int(entry.descriptor.owner_id)), null)
	thing.matter = float(state.matter)
	thing.set_held(state.relation != "world" or bool(state.gameplay.get("captured", false)))
	thing.set_building(bool(state.building))
	if state.relation == "world":
		if thing.get_parent() is Thing or thing.get_parent() is Hands:
			_world.add_thing(thing)


		if baseline or not thing.network_pose_valid or thing.is_captured != bool(state.gameplay.get("captured", false)):
			thing.receive_network_pose(state.transform, true)
		thing.visible = bool(state.visible)
	elif state.relation == "child":
		var carrier: = replica_for_id(int(state.parent_id))
		if carrier == null:
			return
		if thing.get_parent() != carrier:
			thing.reparent(carrier)
		thing.transform = state.transform
		thing.visible = bool(state.visible)
	var animator: = thing.get_node_or_null("BuildAnimator") as BuildAnimator
	if animator != null:
		animator.apply_network_state(state.build, baseline)
	ThingNetworkState.apply(thing, state.gameplay)
	Forge.track_network_replica(thing, bool(state.building))
	stats.states_applied += 1


func _on_activity_changed() -> void :
	if not _session.has_authority():
		return
	for entry: NetworkThingEntry in entries.values():
		if is_instance_valid(entry.thing):
			_pause_timers(entry.thing, not is_active() or not _world.gameplay_available())


func _pause_timers(node: Node, paused_now: bool) -> void :
	if node is Timer:
		(node as Timer).paused = paused_now
	for child in node.get_children():
		_pause_timers(child, paused_now)



func _send_motion() -> void :
	var batch: Array = []
	for id: int in entries:
		var thing: = replica_for_id(id)
		if thing == null or thing.is_held or thing.is_building:
			continue
		var row: = [id, thing.global_transform, thing.velocity]
		var trial: = batch.duplicate()
		trial.append(row)
		if var_to_bytes(trial).size() > 900:
			_send_motion_batch(batch)
			batch.clear()
		batch.append(row)
	_send_motion_batch(batch)


func _send_motion_batch(batch: Array) -> void :
	if batch.is_empty():
		return
	_motion_sequence += 1
	for peer: int in _session.remote_peer_ids():
		_motion.rpc_id(peer, epoch, _motion_sequence, var_to_bytes(batch))


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func _motion(packet_epoch: int, sequence: int, bytes: PackedByteArray) -> void :
	if _session.has_authority() or not is_active() or packet_epoch != epoch or bytes.size() > 900:
		return
	var rows: Variant = bytes_to_var(bytes)
	if not rows is Array or rows.size() > 16:
		return
	for row: Variant in rows:
		if not row is Array or row.size() != 3 or not row[0] is int or not row[1] is Transform3D or not row[2] is Vector3:
			continue
		var id: int = row[0]
		if sequence <= int(_motion_seen.get(id, 0)) or not (row[1] as Transform3D).is_finite() or not (row[2] as Vector3).is_finite():
			continue
		var thing: = replica_for_id(id)
		if thing == null or thing.is_held:
			continue
		_motion_seen[id] = sequence
		thing.velocity = row[2]
		thing.receive_network_pose(row[1])



func notify_fx(kind: String, args: Array) -> void :
	if not is_active() or not _session.has_authority() or var_to_bytes(args).size() > 2048:
		return
	var tick: = int(Time.get_ticks_msec() / 1000)
	if tick != _fx_budget_tick:
		_fx_budget_tick = tick
		_fx_count = 0
	if _fx_count >= int(_config.get("fx_per_second", 240)):
		return
	_fx_count += 1
	for peer: int in _session.remote_peer_ids():
		_fx.rpc_id(peer, epoch, kind, args)


@rpc("authority", "call_remote", "reliable", 0)
func _fx(packet_epoch: int, kind: String, args: Array) -> void :
	if _session.has_authority() or not is_active() or packet_epoch != epoch or var_to_bytes(args).size() > 2048:
		return
	if not _valid_fx(kind, args):
		stats.rejected += 1
		return
	match kind:
		"coop_state": load("res://scripts/things/coop_encounter.gd").ensure(_world).apply_snapshot(args[0])
		"space_sword": load("res://scripts/fx/space_sword.gd").play(_world, args[0], args[1], args[2], float(args[3]))
		"jujutsu_impact": load("res://scripts/fx/jujutsu_impact.gd").play(_world, args[0], args[1], str(args[2]))
		"pokemon_move": load("res://scripts/fx/pokemon_fx.gd").play(_world, args[0], args[1], str(args[2]), str(args[3]))
		"domain_callout": DomainCallout.announce(_world, args[0], str(args[1]))
		"explosion": Fx.explosion(_world, args[0], float(args[1]), args[2])
		"number": Fx.damage_number(_world, args[0], float(args[1]))
		"muzzle": Fx.muzzle_flash(_world, args[0], args[1], float(args[2]), bool(args[3]))
		"ring": Fx.ring(_world, args[0], float(args[1]), args[2], float(args[3]))
		"slash": Fx.slash(_world, args[0], args[1], float(args[2]), float(args[3]), str(args[4]), args[5], bool(args[6]))
		"blast": Forge.explosion_at.emit(args[0], float(args[1]), float(args[2]))
		"voxel_burst": ExpansionFx.burst(_world, args[0], float(args[1]), args[2], str(args[3]))
		"voxel_rift": ExpansionFx.rift(_world, args[0], args[1], float(args[2]), args[3])
		"fail": FeelSounds.play_at(_world, BuildSounds.fail(), args[0], Lexicon.balf("mechanics.failure_db"))
		"hit": Forge.hit_landed.emit(int(args[0]), null, float(args[1]), bool(args[2]))
		"use":
			var item: = replica_for_id(int(args[1]))
			var player: = _world.get_player(int(args[0]))
			if item != null and player != null:
				player.hands.present_network_use(item, str(args[2]))


static func _valid_fx(kind: String, args: Array) -> bool:
	if kind == "coop_state": return args.size() == 1 and args[0] is Dictionary and String(args[0].get("message", "")).length() <= 300 and args[0].get("members",[]) is Array and args[0].get("members",[]).size() <= 4
	match kind:
		"space_sword":
			return args.size() == 4 and _vec3(args[0]) and _vec3(args[1]) and _vec3(args[2]) and _num(args[3]) and float(args[3]) >= 1.0 and float(args[3]) <= 8.0
		"jujutsu_impact":
			return args.size() == 3 and _vec3(args[0]) and _vec3(args[1]) and args[2] is String and args[2] in ["punch", "black_flash", "cleave", "dismantle", "world_charge", "world_cut", "fuga_charge", "red_burst"]
		"pokemon_move":
			return args.size() == 4 and _vec3(args[0]) and _vec3(args[1]) and args[2] is String and args[2] in ["electric", "quick", "fire", "flame", "water", "bubble", "vine", "leaf", "conductive", "vine_fire"] and args[3] is String and args[3].length() <= 64
		"domain_callout":
			return args.size() == 2 and _vec3(args[0]) and args[1] is String and args[1] in ["void", "shrine"]
		"explosion":
			return args.size() == 3 and _vec3(args[0]) and _num(args[1]) and args[2] is Color
		"number":
			return args.size() == 2 and _vec3(args[0]) and _num(args[1])
		"muzzle":
			return args.size() == 4 and _vec3(args[0]) and _vec3(args[1]) and _num(args[2]) and args[3] is bool
		"ring":
			return args.size() == 4 and _vec3(args[0]) and _num(args[1]) and args[2] is Color and _num(args[3])
		"slash":
			return args.size() == 7 and _vec3(args[0]) and _vec3(args[1]) and _num(args[2]) and _num(args[3])\
			and args[4] is String and args[5] is Color and args[6] is bool
		"blast":
			return args.size() == 3 and _vec3(args[0]) and _num(args[1]) and _num(args[2])
		"voxel_burst":
			return args.size() == 4 and _vec3(args[0]) and _num(args[1]) and args[2] is Color and args[3] is String
		"voxel_rift":
			return args.size() == 4 and _vec3(args[0]) and _vec3(args[1]) and _num(args[2]) and args[3] is Color
		"fail":
			return args.size() == 1 and _vec3(args[0])
		"hit":
			return args.size() == 3 and args[0] is int and _num(args[1]) and args[2] is bool
		"use":
			return args.size() == 3 and args[0] is int and args[1] is int and args[2] is String
	return false


static func _vec3(v: Variant) -> bool:
	return v is Vector3 and (v as Vector3).is_finite()


static func _num(v: Variant) -> bool:
	return (v is int or v is float) and is_finite(float(v))
