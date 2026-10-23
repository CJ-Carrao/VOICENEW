class_name NetworkSession
extends Node






signal changed

const DEFAULT_PORT: = 27840
const DEFAULT_BIND: = "127.0.0.1"
const AUTH_TIMEOUT: = 5.0
const CONNECT_TIMEOUT: = 8.0
const MAX_AUTH_BYTES: = 2048
const HOST_PEER_ID: = 1
const MAX_PLAYERS: = 4
const Diagnostics = preload("res://scripts/network/network_diagnostics.gd")

var state: = "offline"
var last_error: = ""
var local_player_id: = 1

var roster: Dictionary = {1: 1, 2: 0}
var roster_revision: = 0
var mode: = "duel"
var endpoint: = ""
var compatibility: Dictionary = {}
var transport: NetworkTransport = NetworkTransport.new()

var generation: int = 0
var replication: PlayerReplication
var creations: ForgeReplication
var world_sync: WorldReplication
var voice_sync: VoiceReplication
var lobby: LobbySession
var diagnostics: Node

var _role: = "offline"
var _api: SceneMultiplayer
var _peer: MultiplayerPeer
var _deadline_ms: = 0
var _authenticating: Dictionary = {}
var _validated: Dictionary = {}
var _reserved_slots: Dictionary = {}
var _peer_generations: Dictionary = {}
var _assigned_player_id: = 2
var _allow_joins: = true
var _closing: = false


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_api()
	creations = ForgeReplication.new()
	creations.name = "ForgeReplication"
	replication = PlayerReplication.new()
	replication.name = "PlayerReplication"
	world_sync = WorldReplication.new()
	world_sync.name = "WorldReplication"
	voice_sync = VoiceReplication.new()
	voice_sync.name = "VoiceReplication"
	lobby = LobbySession.new()
	lobby.name = "LobbySession"
	add_child(world_sync)
	add_child(creations)
	add_child(replication)
	add_child(voice_sync)
	add_child(lobby)
	diagnostics = Diagnostics.new()
	diagnostics.name = "NetworkDiagnostics"
	add_child(diagnostics)


func _process(_delta: float) -> void :
	if is_online() and transport != null:
		transport.poll()
	if _role == "client" and state in ["connecting", "authenticating"] and Time.get_ticks_msec() >= _deadline_ms:
		_fail("Tempo esgotado ao conectar. Confira o endereço, a porta e se o host está aberto.")


func is_online() -> bool:
	return _role != "offline"


func has_authority() -> bool:
	return _role == "offline" or (_role == "host" and state in ["hosting", "ready"])


func is_ready() -> bool:
	return state in ["offline", "ready"]


func peer_for_player(player_id: int) -> int:
	return int(roster.get(player_id, 0))


func player_for_peer(peer_id: int) -> int:
	if peer_id <= 0:
		return 0
	for player_id in roster:
		if int(roster[player_id]) == peer_id:
			return int(player_id)
	return 0


func owns_player(peer_id: int, player_id: int) -> bool:
	return peer_id > 0 and peer_for_player(player_id) == peer_id



func player_ids() -> Array[int]:
	var result: Array[int] = []
	for player_id: int in roster:
		if not is_online() or peer_for_player(player_id) > 0:
			result.append(player_id)
	result.sort()
	return result


func remote_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for player_id: int in player_ids():
		var peer_id: = peer_for_player(player_id)
		if player_id != local_player_id and peer_id > 0 and peer_is_connected(peer_id):
			result.append(peer_id)
	return result


func peer_is_connected(peer_id: int) -> bool:
	if _peer == null or _api == null or not _api.get_peers().has(peer_id): return false
	if _peer is ENetMultiplayerPeer:
		var enet_peer: = (_peer as ENetMultiplayerPeer).get_peer(peer_id)
		return enet_peer != null and enet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED
	return _peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func generation_for_peer(peer_id: int) -> int:
	return generation if peer_id == HOST_PEER_ID and _role == "host" else int(_peer_generations.get(peer_id, 0))


func set_join_allowed(value: bool) -> void :
	_allow_joins = value
	if _role == "host" and not value:
		for peer_id: int in _authenticating.keys():
			_reject_peer(peer_id, "A sala já está escolhendo a arena.")
	_refresh_acceptance()


func _refresh_acceptance() -> void :
	if _role == "host" and _api != null and _peer != null:
		_api.refuse_new_connections = not _allow_joins or player_ids().size() + _reserved_slots.size() >= MAX_PLAYERS


func _empty_roster() -> Dictionary:
	return {1: 1, 2: 0, 3: 0, 4: 0}


func status_text() -> String:
	match state:
		"offline": return "Treino local" if mode == "practice" else "Duelo local contra bot"
		"hosting": return "Host aberto em %s · aguardando o segundo jogador" % endpoint
		"connecting": return "Conectando a %s…" % endpoint
		"authenticating": return "Conferindo versão, catálogo e regras…"
		"ready": return "Conexão validada · %d jogadores conectados" % player_ids().size()
		"failed", "disconnected": return last_error
	return state


func start_offline(offline_mode: String = "duel") -> void :
	_ensure_api()
	if diagnostics != null: diagnostics.finish("offline")
	_close_current_peer()
	generation += 1
	_role = "offline"
	if transport != null:
		transport.kind = "enet"
	mode = "practice" if offline_mode in ["practice", "training", "treino"] else "duel"
	state = "offline"
	roster_revision = 0
	local_player_id = 1
	roster = {1: 1} if mode == "practice" else {1: 1, 2: 0}
	last_error = ""
	endpoint = ""
	_api.auth_callback = Callable()
	_api.multiplayer_peer = OfflineMultiplayerPeer.new()
	changed.emit()


func start_from_args(args: PackedStringArray) -> Error:
	var parsed: = parse_args(args)
	if parsed.has("error"):
		_ensure_api()
		if diagnostics != null: diagnostics.finish("replaced")
		_close_current_peer()
		generation += 1
		_role = "client"
		local_player_id = 2
		state = "connecting"
		if diagnostics != null: diagnostics.begin_attempt()
		_fail(str(parsed.error))
		return ERR_INVALID_PARAMETER
	if str(parsed.get("transport", "enet")) == "steam":
		match str(parsed.role):
			"host": return start_steam_host(int(parsed.get("port", 0)), int(parsed.get("app_id", 0)))
			"client": return start_steam_client(str(parsed.get("address", "")), int(parsed.get("port", 0)), int(parsed.get("app_id", 0)))
	match str(parsed.role):
		"host": return start_host(int(parsed.port), str(parsed.bind))
		"client": return start_client(str(parsed.address), int(parsed.port))
	start_offline("practice" if args.has("--treino") else "duel")
	return OK


func start_host(port: int = DEFAULT_PORT, bind_address: String = DEFAULT_BIND) -> Error:
	_prepare_online("host")
	transport.kind = "enet"
	if diagnostics != null: diagnostics.begin_attempt()
	endpoint = "%s:%d" % [bind_address, port]
	if not _valid_port(port) or (bind_address != "*" and not bind_address.is_valid_ip_address()):
		_fail("Porta ou endereço de escuta inválido.")
		return ERR_INVALID_PARAMETER
	return _open_transport(transport.create_host(port, bind_address))


func start_client(address: String, port: int = DEFAULT_PORT) -> Error:
	_prepare_online("client")
	transport.kind = "enet"
	if diagnostics != null: diagnostics.begin_attempt()
	endpoint = "%s:%d" % [address, port]
	if not _valid_port(port) or address.strip_edges().is_empty() or address.length() > 253:
		_fail("Endereço do host ou porta inválidos.")
		return ERR_INVALID_PARAMETER
	return _open_transport(transport.create_client(address, port))


func start_steam_host(virtual_port: int = 0, app_id: int = 0) -> Error:
	_prepare_online("host")
	transport.kind = "steam"
	if diagnostics != null: diagnostics.begin_attempt()
	transport.app_id = app_id
	endpoint = "steam://host:%d" % virtual_port
	if virtual_port < 0 or virtual_port > 65535:
		_fail("A porta virtual Steam deve estar entre 0 e 65535.")
		return ERR_INVALID_PARAMETER
	return _open_transport(transport.create_steam_host(virtual_port, app_id))


func start_steam_client(steam_id_text: String, virtual_port: int = 0, app_id: int = 0) -> Error:
	_prepare_online("client")
	transport.kind = "steam"
	if diagnostics != null: diagnostics.begin_attempt()
	transport.app_id = app_id
	endpoint = "steam://%s:%d" % [steam_id_text.strip_edges(), virtual_port]
	var host_steam_id: = NetworkTransport.parse_steam_id(steam_id_text)
	if host_steam_id <= 0 or virtual_port < 0 or virtual_port > 65535:
		_fail("SteamID64 do host ou porta virtual inválidos.")
		return ERR_INVALID_PARAMETER
	return _open_transport(transport.create_steam_client(host_steam_id, virtual_port, app_id))


func stop_online(reason: String = "Sessão encerrada.") -> void :
	if not is_online():
		return
	if diagnostics != null: diagnostics.finish("closed")
	_close_current_peer()
	roster = _empty_roster() if _role == "host" else {}
	state = "disconnected"
	last_error = reason
	changed.emit()


func reject_peer(remote_peer: int, reason: String) -> void :
	if _role != "host":
		return
	if remote_peer <= 1 or player_for_peer(remote_peer) <= 1:
		return
	if diagnostics != null: diagnostics.note_event("auth_rejected", diagnostics.reason_code(reason), player_for_peer(remote_peer))
	_api.disconnect_peer(remote_peer)
	_on_peer_disconnected(remote_peer)
	last_error = reason
	changed.emit()


func _prepare_online(role: String) -> void :
	_ensure_api()
	if diagnostics != null: diagnostics.finish("replaced")
	_close_current_peer()
	generation += 1
	_role = role
	mode = "online"
	state = "hosting" if role == "host" else "connecting"
	local_player_id = 1 if role == "host" else 2
	_assigned_player_id = local_player_id
	roster = _empty_roster()
	roster_revision = 0
	_allow_joins = true
	last_error = ""
	compatibility = SessionCompatibility.manifest()
	_api.allow_object_decoding = false
	_api.auth_timeout = AUTH_TIMEOUT
	_api.auth_callback = _on_auth_data
	_deadline_ms = Time.get_ticks_msec() + int(CONNECT_TIMEOUT * 1000.0)


func _open_transport(result: Dictionary) -> Error:
	var error: Error = int(result.get("error", ERR_CANT_CREATE)) as Error
	var candidate: = result.get("peer") as MultiplayerPeer
	if error != OK or candidate == null or compatibility.has("error"):
		if candidate != null:
			candidate.close()
		var reason: = str(result.get("reason", ""))
		if reason.is_empty():
			reason = str(compatibility.get("error", "Não foi possível abrir a conexão (%s)." % error_string(error)))
		_fail(reason)
		return error if error != OK else ERR_CANT_CREATE
	_peer = candidate
	_api.multiplayer_peer = candidate
	_api.refuse_new_connections = false
	changed.emit()
	return OK


func _ensure_api() -> void :
	if _api != null:
		return
	_api = multiplayer as SceneMultiplayer

	_api.server_relay = false
	_api.peer_authenticating.connect(_on_peer_authenticating)
	_api.peer_authentication_failed.connect(_on_auth_failed)
	_api.peer_connected.connect(_on_peer_connected)
	_api.peer_disconnected.connect(_on_peer_disconnected)
	_api.connection_failed.connect(_on_connection_failed)
	_api.server_disconnected.connect(_on_server_disconnected)


func _configure_enet_peer(peer_id: int) -> void :
	if _peer is ENetMultiplayerPeer:
		var enet_peer: = (_peer as ENetMultiplayerPeer).get_peer(peer_id)
		if enet_peer != null:
			enet_peer.throttle_configure(5000, 2, 0)


func _on_peer_authenticating(peer_id: int) -> void :
	if _closing or not is_online():
		return
	if (_role == "host" and not _allow_joins) or (_role == "client" and peer_id != HOST_PEER_ID):
		_api.disconnect_peer(peer_id)
		return
	if _role == "host":
		var available: = 0
		for player_id in range(2, MAX_PLAYERS + 1):
			if peer_for_player(player_id) == 0 and not _reserved_slots.values().has(player_id):
				available = player_id
				break
		if available == 0:
			_api.disconnect_peer(peer_id)
			return
		_reserved_slots[peer_id] = available
	_configure_enet_peer(peer_id)
	_authenticating[peer_id] = true
	if diagnostics != null: diagnostics.note_event("auth_started", "none", int(_reserved_slots.get(peer_id, 1 if _role == "client" else 0)))
	if _role == "client":
		state = "authenticating"
	var payload: = compatibility.duplicate()
	payload["role"] = _role
	payload["generation"] = generation
	if _role == "host":
		payload["assigned_player_id"] = int(_reserved_slots[peer_id])
		if diagnostics != null: payload["diagnostic_session"] = diagnostics.session_id
	var error: = _api.send_auth(peer_id, JSON.stringify(payload).to_utf8_buffer())
	if error != OK:
		_reject_peer(peer_id, "Falha ao enviar a verificação de versão.")
	_refresh_acceptance()
	changed.emit()


func _on_auth_data(peer_id: int, bytes: PackedByteArray) -> void :
	if _closing or not _authenticating.has(peer_id) or _validated.has(peer_id):
		return
	if bytes.is_empty() or bytes.size() > MAX_AUTH_BYTES:
		_reject_peer(peer_id, "Pacote de verificação inválido.")
		return
	var payload: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not payload is Dictionary:
		_reject_peer(peer_id, "Pacote de verificação inválido.")
		return
	var expected_role: = "client" if _role == "host" else "host"
	var reason: = SessionCompatibility.mismatch(compatibility, payload)
	if str(payload.get("role", "")) != expected_role:
		reason = "Identidade de sessão inválida."
	var remote_generation: Variant = payload.get("generation")
	if not (remote_generation is int or remote_generation is float) or not is_finite(float(remote_generation))\
	or float(remote_generation) != floorf(float(remote_generation)) or int(remote_generation) < 1 or int(remote_generation) > 2147483647:
		reason = "Geração de conexão inválida."
	if _role == "client":
		var assigned: Variant = payload.get("assigned_player_id")
		if not (assigned is int or assigned is float) or not is_finite(float(assigned))\
		or float(assigned) != floorf(float(assigned)) or int(assigned) < 2 or int(assigned) > MAX_PLAYERS:
			reason = "Lugar de jogador inválido."
		else:
			_assigned_player_id = int(assigned)
	if not reason.is_empty():
		_reject_peer(peer_id, reason)
		return


	if _role == "client" and diagnostics != null:
		diagnostics.adopt_session_id(payload.get("diagnostic_session"))
	_peer_generations[peer_id] = int(remote_generation)
	_validated[peer_id] = true
	if _api.complete_auth(peer_id) != OK:
		_reject_peer(peer_id, "Não foi possível concluir a verificação de versão.")


func _reject_peer(peer_id: int, reason: String) -> void :
	if diagnostics != null: diagnostics.note_event("auth_rejected", diagnostics.reason_code(reason), int(_reserved_slots.get(peer_id, 0)))
	last_error = reason
	_api.disconnect_peer(peer_id)
	_authenticating.erase(peer_id)
	_validated.erase(peer_id)
	_reserved_slots.erase(peer_id)
	_peer_generations.erase(peer_id)
	if _role == "client":
		_fail(reason)
	else:
		_refresh_acceptance()
		changed.emit()


func _on_peer_connected(peer_id: int) -> void :
	if _closing or not _validated.has(peer_id):
		return
	_configure_enet_peer(peer_id)
	_authenticating.erase(peer_id)
	last_error = ""
	if _role == "host":
		var player_id: = int(_reserved_slots.get(peer_id, 0))
		_reserved_slots.erase(peer_id)
		if not _allow_joins or player_id < 2 or peer_for_player(player_id) != 0:
			_api.disconnect_peer(peer_id)
			_validated.erase(peer_id)
			_peer_generations.erase(peer_id)
			_refresh_acceptance()
			return
		roster[player_id] = peer_id
		if diagnostics != null: diagnostics.note_event("peer_joined", "none", player_id)
		state = "ready"
		roster_revision += 1
		_refresh_acceptance()
		_publish_roster()
		changed.emit()
	else:

		state = "authenticating"
		local_player_id = _assigned_player_id
		if diagnostics != null: diagnostics.note_event("peer_joined", "none", HOST_PEER_ID)
		changed.emit()


func _publish_roster() -> void :
	if _role != "host": return
	for peer_id: int in remote_peer_ids():
		_roster_state.rpc_id(peer_id, generation_for_peer(peer_id), roster_revision, roster)


@rpc("authority", "call_remote", "reliable", 0)
func _roster_state(client_generation: int, revision: int, snapshot: Dictionary) -> void :
	if _role != "client" or multiplayer.get_remote_sender_id() != HOST_PEER_ID or not _validated.has(HOST_PEER_ID)\
	or client_generation != generation or revision <= roster_revision or revision > 2147483647\
	or state not in ["authenticating", "ready"] or snapshot.size() != MAX_PLAYERS:
		return
	var seen: = {}
	for player_id in range(1, MAX_PLAYERS + 1):
		var peer_id: Variant = snapshot.get(player_id)
		if not peer_id is int or int(peer_id) < 0 or (int(peer_id) > 0 and seen.has(peer_id)):
			return
		if int(peer_id) > 0: seen[peer_id] = true
	if snapshot[1] != HOST_PEER_ID or snapshot.get(_assigned_player_id) != _api.get_unique_id():
		return
	roster = snapshot.duplicate()
	roster_revision = revision
	local_player_id = _assigned_player_id
	state = "ready"
	last_error = ""
	changed.emit()


func _on_auth_failed(peer_id: int) -> void :
	if _closing:
		return


	if diagnostics != null: diagnostics.note_event("auth_failed", "other", int(_reserved_slots.get(peer_id, 0)))
	_authenticating.erase(peer_id)
	_validated.erase(peer_id)
	_reserved_slots.erase(peer_id)
	_peer_generations.erase(peer_id)
	if _role == "client" and state not in ["failed", "disconnected"]:
		_fail(last_error if not last_error.is_empty() else "Verificação recusada ou tempo esgotado. Confira se ambos usam a mesma versão.")
	elif _role == "host":
		_refresh_acceptance()
		changed.emit()


func _on_peer_disconnected(peer_id: int) -> void :
	if _closing:
		return
	_authenticating.erase(peer_id)
	_validated.erase(peer_id)
	_reserved_slots.erase(peer_id)
	_peer_generations.erase(peer_id)
	var player_id: = player_for_peer(peer_id)
	if diagnostics != null: diagnostics.note_event("peer_left", "closed", player_id)
	if _role == "host" and player_id > 1:
		roster[player_id] = 0
		state = "ready" if player_ids().size() > 1 else "hosting"
		last_error = "O jogador %d desconectou." % player_id
		roster_revision += 1
		_refresh_acceptance()
		_publish_roster()
		changed.emit()
	elif _role == "client" and peer_id == HOST_PEER_ID:
		_on_server_disconnected()


func _on_connection_failed() -> void :
	if not _closing and _role == "client" and state not in ["failed", "disconnected"]:
		_fail("Não foi possível conectar ao host. Confira o endereço e a porta.")


func _on_server_disconnected() -> void :
	if not _closing and _role == "client" and state not in ["failed", "disconnected"]:
		_fail("A conexão com o host foi encerrada.", "disconnected")


func _fail(reason: String, failed_state: String = "failed") -> void :
	if diagnostics != null: diagnostics.note_event("failure", diagnostics.reason_code(reason))
	state = failed_state
	last_error = reason
	roster = {}
	_authenticating.clear()
	_validated.clear()
	_reserved_slots.clear()
	_peer_generations.clear()


	if _peer != null:
		_close_retired_peer.call_deferred(_peer)
		_peer = null
	changed.emit()


func _close_retired_peer(peer: MultiplayerPeer) -> void :


	if _api.multiplayer_peer == peer:
		_api.multiplayer_peer = null
	peer.close()


func _close_current_peer() -> void :
	_closing = true
	if _peer != null:
		if _api.multiplayer_peer == _peer:
			_api.multiplayer_peer = null
		_peer.close()
		_peer = null
	_authenticating.clear()
	_validated.clear()
	_reserved_slots.clear()
	_peer_generations.clear()
	_closing = false


static func _valid_port(port: int) -> bool:
	return port >= 1 and port <= 65535


static func parse_args(args: PackedStringArray) -> Dictionary:
	var options: Dictionary = {}
	var index: = 0
	var known: = ["--host", "--join", "--port", "--bind", "--transport", "--steam-host", "--steam-join", "--steam-app-id"]
	while index < args.size():
		var argument: = args[index]
		var key: = argument.get_slice("=", 0)
		if key not in known:
			index += 1
			continue
		if options.has(key):
			return {"error": "Argumento repetido: " + key}
		var value: = ""
		var optional_val: = key in ["--host", "--steam-host"]
		if argument.contains("="):
			value = argument.substr(key.length() + 1)
		elif index + 1 < args.size() and not args[index + 1].begins_with("--"):
			index += 1
			value = args[index]
		elif not optional_val:
			return {"error": "Falta o valor de " + key}
		if value.is_empty() and ( not optional_val or argument.contains("=")):
			return {"error": "Valor vazio em " + key}
		options[key] = value
		index += 1
	var transport_kind: = str(options.get("--transport", "")).to_lower()
	if not transport_kind.is_empty() and transport_kind not in ["enet", "steam"]:
		return {"error": "Transporte inválido: use --transport=enet ou --transport=steam."}
	if (options.has("--steam-host") or options.has("--steam-join") or options.has("--steam-app-id")) and transport_kind == "enet":
		return {"error": "Argumentos --steam-* não podem ser combinados com --transport=enet."}
	if options.has("--steam-host") or options.has("--steam-join"):
		transport_kind = "steam"
	if transport_kind.is_empty():
		transport_kind = "enet"
	var host_count: = int(options.has("--host")) + int(options.has("--steam-host"))
	var join_count: = int(options.has("--join")) + int(options.has("--steam-join"))
	if host_count + join_count > 1:
		return {"error": "Use apenas um modo de conexão (--host, --join, --steam-host ou --steam-join)."}
	var is_host: = host_count == 1
	var is_join: = join_count == 1
	if not is_host and not is_join:
		return {"error": "--port, --bind e --transport exigem --host ou --join."} if not options.is_empty() else {"role": "offline"}
	if options.has("--bind") and ( not is_host or transport_kind == "steam"):
		return {"error": "--bind só se aplica ao host ENet."}
	var app_id: = 0
	if options.has("--steam-app-id"):
		if transport_kind != "steam":
			return {"error": "--steam-app-id exige o transporte Steam."}
		var app_text: = str(options.get("--steam-app-id", ""))
		if not app_text.is_valid_int() or app_text.to_int() <= 0:
			return {"error": "O App ID da Steam deve ser um inteiro positivo."}
		app_id = app_text.to_int()
	var host_port_inline: = str(options.get("--steam-host", options.get("--host", "")))
	if options.has("--port") and not host_port_inline.is_empty():
		return {"error": "Informe a porta apenas uma vez (--host=porta ou --port=porta)."}
	var port_text: = str(options.get("--port", host_port_inline))
	if transport_kind == "steam":
		var vport: = 0
		if not port_text.is_empty():
			if not port_text.is_valid_int() or port_text.to_int() < 0 or port_text.to_int() > 65535:
				return {"error": "A porta virtual Steam deve estar entre 0 e 65535."}
			vport = port_text.to_int()
		var target: = str(options.get("--steam-join", options.get("--join", "")))
		if is_join and NetworkTransport.parse_steam_id(target) <= 0:
			return {"error": "SteamID64 do host inválido."}
		return {
			"role": "host" if is_host else "client", 
			"transport": "steam", 
			"port": vport, 
			"address": target, 
			"app_id": app_id, 
		}
	var port: = DEFAULT_PORT
	if not port_text.is_empty():
		if not port_text.is_valid_int() or not _valid_port(port_text.to_int()):
			return {"error": "A porta deve ser um número entre 1 e 65535."}
		port = port_text.to_int()
	return {
		"role": "host" if is_host else "client", 
		"transport": "enet", 
		"port": port, 
		"address": str(options.get("--join", "")), 
		"bind": str(options.get("--bind", DEFAULT_BIND)), 
	}
