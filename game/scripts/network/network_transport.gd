class_name NetworkTransport
extends RefCounted





const CHANNEL_COUNT: = 5
const MAX_PLAYERS: = 4
const CONFIG_PATH: = "res://data/network.json"
const MIN_STEAM_ID64: = 76561197960265728
const MAX_VIRTUAL_PORT: = 65535

var kind: String = "enet"
var app_id: int = 0
var runtime_override: Dictionary = {}
var _manual_callbacks: = false


func _init(transport_kind: String = "enet", configured_app_id: int = 0) -> void :
	kind = transport_kind.to_lower()
	app_id = configured_app_id


func create_host(port: int, bind_address: String = "127.0.0.1") -> Dictionary:
	if kind == "steam":
		return create_steam_host(port, app_id)
	var peer: = ENetMultiplayerPeer.new()
	peer.set_bind_ip(bind_address)
	var error: = peer.create_server(port, MAX_PLAYERS - 1, CHANNEL_COUNT)
	return {"error": error, "peer": peer, "transport": "enet"}


func create_client(address: String, port: int = 0) -> Dictionary:
	if kind == "steam":
		var host_steam_id: = parse_steam_id(address)
		if host_steam_id <= 0:
			return {
				"error": ERR_INVALID_PARAMETER, 
				"peer": null, 
				"transport": "steam", 
				"reason": "SteamID64 do host inválido. Use o ID de 64 bits da conta Steam do host.", 
			}
		return create_steam_client(host_steam_id, port, app_id)
	var peer: = ENetMultiplayerPeer.new()
	var error: = peer.create_client(address, port, CHANNEL_COUNT)
	return {"error": error, "peer": peer, "transport": "enet"}


func create_steam_host(virtual_port: int = 0, configured_app_id: int = 0) -> Dictionary:
	if not _valid_virtual_port(virtual_port):
		return {
			"error": ERR_INVALID_PARAMETER, 
			"peer": null, 
			"transport": "steam", 
			"reason": "A porta virtual Steam deve estar entre 0 e 65535.", 
		}
	var status: = steam_status(configured_app_id if configured_app_id > 0 else app_id, runtime_override)
	if not bool(status.get("available", false)):
		return {
			"error": ERR_UNAVAILABLE, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": str(status.get("reason", "Transporte Steam indisponível.")), 
		}
	_manual_callbacks = bool(status.get("manual_callbacks", false))
	var peer: = _instantiate_steam_peer()
	if peer == null:
		return {
			"error": ERR_UNAVAILABLE, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": "Não foi possível instanciar SteamMultiplayerPeer.", 
		}
	var error: = _invoke_steam_host(peer, virtual_port)
	if error != OK:
		peer.close()
		return {
			"error": error, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": "Falha ao abrir host Steam na porta virtual %d (%s)." % [virtual_port, error_string(error)], 
		}
	return {"error": OK, "peer": peer, "transport": "steam", "status": status}


func create_steam_client(host_steam_id: int, virtual_port: int = 0, configured_app_id: int = 0) -> Dictionary:
	if host_steam_id < MIN_STEAM_ID64:
		return {
			"error": ERR_INVALID_PARAMETER, 
			"peer": null, 
			"transport": "steam", 
			"reason": "SteamID64 do host inválido. Use o ID de 64 bits da conta Steam do host.", 
		}
	if not _valid_virtual_port(virtual_port):
		return {
			"error": ERR_INVALID_PARAMETER, 
			"peer": null, 
			"transport": "steam", 
			"reason": "A porta virtual Steam deve estar entre 0 e 65535.", 
		}
	var status: = steam_status(configured_app_id if configured_app_id > 0 else app_id, runtime_override)
	if not bool(status.get("available", false)):
		return {
			"error": ERR_UNAVAILABLE, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": str(status.get("reason", "Transporte Steam indisponível.")), 
		}
	_manual_callbacks = bool(status.get("manual_callbacks", false))
	var peer: = _instantiate_steam_peer()
	if peer == null:
		return {
			"error": ERR_UNAVAILABLE, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": "Não foi possível instanciar SteamMultiplayerPeer.", 
		}
	var error: = _invoke_steam_client(peer, host_steam_id, virtual_port)
	if error != OK:
		peer.close()
		return {
			"error": error, 
			"peer": null, 
			"transport": "steam", 
			"status": status, 
			"reason": "Falha ao conectar ao host Steam %d na porta virtual %d (%s)." % [host_steam_id, virtual_port, error_string(error)], 
		}
	return {"error": OK, "peer": peer, "transport": "steam", "status": status}


func poll() -> void :
	if kind != "steam" or not _manual_callbacks:
		return
	var steam_obj: Object = runtime_override.get("steam_singleton") if runtime_override.has("steam_singleton") else (Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null)
	if steam_obj != null and steam_obj.has_method("run_callbacks"):
		steam_obj.call("run_callbacks")


static func parse_steam_id(text: String) -> int:
	var cleaned: = text.strip_edges()
	if cleaned.begins_with("steam:"):
		cleaned = cleaned.trim_prefix("steam:").strip_edges()
	if cleaned.is_empty() or not cleaned.is_valid_int():
		return 0
	var value: = cleaned.to_int()
	return value if value >= MIN_STEAM_ID64 else 0


static func resolve_app_id(explicit_app_id: int = 0) -> int:
	if explicit_app_id > 0:
		return explicit_app_id
	for env_key in ["SteamAppId", "STEAM_APP_ID"]:
		var env_val: = OS.get_environment(env_key).strip_edges()
		if env_val.is_valid_int() and env_val.to_int() > 0:
			return env_val.to_int()
	for candidate in ["res://steam_appid.txt", OS.get_executable_path().get_base_dir().path_join("steam_appid.txt")]:
		if FileAccess.file_exists(candidate):
			var text: = FileAccess.get_file_as_string(candidate).strip_edges()
			if text.is_valid_int() and text.to_int() > 0:
				return text.to_int()
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary and parsed.get("steam") is Dictionary:
			var steam_cfg: Dictionary = parsed["steam"]
			var cfg_id: Variant = steam_cfg.get("app_id", 0)
			if (cfg_id is int or cfg_id is float) and int(cfg_id) > 0:
				return int(cfg_id)
	return 0


static func steam_status(explicit_app_id: int = 0, override: Dictionary = {}) -> Dictionary:
	var has_singleton: = bool(override.get("has_steam_singleton", Engine.has_singleton("Steam")))
	var has_peer_class: = bool(override.get("has_steam_peer_class", ClassDB.class_exists("SteamMultiplayerPeer") and ClassDB.can_instantiate("SteamMultiplayerPeer")))
	var resolved_app_id: = int(override.get("app_id", resolve_app_id(explicit_app_id)))
	var missing: Array[String] = []
	if not has_singleton:
		missing.append("singleton Steam (GDExtension/módulo GodotSteam)")
	if not has_peer_class:
		missing.append("classe SteamMultiplayerPeer (GDExtension/módulo GodotSteam)")
	if resolved_app_id <= 0:
		missing.append("App ID da Steam (defina STEAM_APP_ID, steam_appid.txt ou steam.app_id em data/network.json)")
	if not missing.is_empty():
		return {
			"available": false, 
			"has_steam_singleton": has_singleton, 
			"has_steam_peer_class": has_peer_class, 
			"app_id": resolved_app_id, 
			"missing": missing, 
			"reason": "Transporte Steam indisponível: falta %s." % ", ".join(missing), 
		}
	var steam_obj: Object = override.get("steam_singleton") if override.has("steam_singleton") else Engine.get_singleton("Steam")
	var init_info: = _ensure_steam_initialized(steam_obj, resolved_app_id)
	if not bool(init_info.get("ok", false)):
		missing.append(str(init_info.get("missing", "cliente Steam aberto e autenticado")))
		return {
			"available": false, 
			"has_steam_singleton": has_singleton, 
			"has_steam_peer_class": has_peer_class, 
			"app_id": resolved_app_id, 
			"missing": missing, 
			"reason": str(init_info.get("reason", "Transporte Steam indisponível: cliente Steam fechado ou não autenticado.")), 
		}
	return {
		"available": true, 
		"has_steam_singleton": true, 
		"has_steam_peer_class": true, 
		"app_id": resolved_app_id, 
		"steam_id": int(init_info.get("steam_id", 0)), 
		"manual_callbacks": bool(init_info.get("manual_callbacks", false)), 
		"missing": missing, 
		"reason": "", 
	}


static func _ensure_steam_initialized(steam_obj: Object, resolved_app_id: int) -> Dictionary:
	if steam_obj == null:
		return {"ok": false, "missing": "singleton Steam", "reason": "Singleton Steam indisponível no runtime."}
	var running: = bool(steam_obj.call("isSteamRunning")) if steam_obj.has_method("isSteamRunning") else false
	var logged_on: = bool(steam_obj.call("loggedOn")) if steam_obj.has_method("loggedOn") else false
	var manual_callbacks: = false
	if not running or not logged_on:
		if steam_obj.has_method("steamInitEx"):
			var init_res: Variant = steam_obj.call("steamInitEx", resolved_app_id, true)
			if init_res is Dictionary and int(init_res.get("status", 1)) != 0:
				var verbal: = str(init_res.get("verbal", "falha em steamInitEx"))
				return {
					"ok": false, 
					"missing": "cliente Steam inicializado", 
					"reason": "Não foi possível inicializar a Steam (App ID %d): %s." % [resolved_app_id, verbal], 
				}
		elif steam_obj.has_method("steamInit"):
			var ok: = bool(steam_obj.call("steamInit", false))
			manual_callbacks = true
			if not ok:
				return {
					"ok": false, 
					"missing": "cliente Steam inicializado", 
					"reason": "Não foi possível inicializar a Steam (App ID %d). Confira se o cliente Steam está aberto." % resolved_app_id, 
				}
		running = bool(steam_obj.call("isSteamRunning")) if steam_obj.has_method("isSteamRunning") else true
		logged_on = bool(steam_obj.call("loggedOn")) if steam_obj.has_method("loggedOn") else true
	if not running or not logged_on:
		return {
			"ok": false, 
			"missing": "cliente Steam aberto e autenticado", 
			"reason": "O cliente Steam precisa estar aberto e conectado a uma conta para usar o transporte Steam.", 
		}
	if steam_obj.has_method("initRelayNetworkAccess"):
		steam_obj.call("initRelayNetworkAccess")
	var local_steam_id: = int(steam_obj.call("getSteamID")) if steam_obj.has_method("getSteamID") else 0
	return {"ok": true, "steam_id": local_steam_id, "manual_callbacks": manual_callbacks}


func _instantiate_steam_peer() -> MultiplayerPeer:
	if runtime_override.has("peer_factory") and runtime_override["peer_factory"] is Callable:
		return (runtime_override["peer_factory"] as Callable).call() as MultiplayerPeer
	if ClassDB.class_exists("SteamMultiplayerPeer") and ClassDB.can_instantiate("SteamMultiplayerPeer"):
		return ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	return null


static func _invoke_steam_host(peer: MultiplayerPeer, virtual_port: int) -> Error:
	for method in ["create_host", "create_with_socket"]:
		if peer.has_method(method):
			var argc: = _method_arg_count(peer, method)
			var res: Variant = peer.call(method, virtual_port) if argc <= 1 else peer.call(method, virtual_port, [])
			return int(res) as Error if (res is int or res is float) else ERR_CANT_CREATE
	return ERR_METHOD_NOT_FOUND


static func _invoke_steam_client(peer: MultiplayerPeer, host_steam_id: int, virtual_port: int) -> Error:
	for method in ["create_client", "connect_to_socket"]:
		if peer.has_method(method):
			var argc: = _method_arg_count(peer, method)
			var res: Variant = peer.call(method, host_steam_id, virtual_port) if argc <= 2 else peer.call(method, host_steam_id, virtual_port, [])
			return int(res) as Error if (res is int or res is float) else ERR_CANT_CREATE
	return ERR_METHOD_NOT_FOUND


static func _method_arg_count(obj: Object, method_name: String) -> int:
	for entry: Dictionary in obj.get_method_list():
		if str(entry.get("name", "")) == method_name:
			var args: Array = entry.get("args", [])
			var defaults: Array = entry.get("default_args", [])
			return maxi(0, args.size() - defaults.size())
	return 1


static func _valid_virtual_port(virtual_port: int) -> bool:
	return virtual_port >= 0 and virtual_port <= MAX_VIRTUAL_PORT
