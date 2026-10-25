class_name Match
extends Node3D




































signal state_changed

const DEV_USE_GAP: = 0.3
const DEV_SCREENSHOT_WAIT: = 0.75
const DEV_RECORD_PHRASES: = 13

const DEV_EXTRACT_S: = 2.5

const DEV_EXTRACT_DISTANCE: = 2.5


@export var mode: String = "duel"

static var next_mode: String = ""
static var return_to_menu: = false

@export var voice_enabled: bool = true

@export var configure_session: bool = true


var state: String = ""
var round_number: int = 0

var score: Dictionary = {}

var countdown_left: float = 0.0

var countdown_total: float = 3.0

var _after_countdown: String = ""
var _map_intro: SpaceIntro = null

var _waiting_world: = false
var _intro_pending: = false
var _intermission_left: = 0.0

var last_winner: Player = null


var _epoch: int = 0
var _players: Dictionary = {}
var _admitted_players: Dictionary = {}
var _console_open: = false
var _options_open: = false
var _paused_by_menu: = false
var _voice_started: = false
var _voice_requests: Dictionary = {}



var player: Player
var opponent: Player

@onready var arena: Arena = $Arena
@onready var bot: BotBrain = $Opponent / BotBrain
@onready var dummy: TargetDummy = $Dummy
@onready var voice: VoiceInput = $Voice
@onready var _things: Node3D = $Things
@onready var _hud: Hud = $HUD


func _enter_tree() -> void :

	var from_lobby: = next_mode == "online" and Session.is_online()
	if from_lobby: Session.lobby.mark_match_entered()
	if not next_mode.is_empty():
		mode = next_mode
		next_mode = ""
	var args: = OS.get_cmdline_user_args()
	for arg in args:
		if arg == "--treino" or arg.begins_with("--gravar-voz") or arg == "--calibrar":
			mode = "practice"
	if configure_session and not from_lobby:
		Session.start_from_args(args)
		if not Session.is_online():
			Session.start_offline(mode)
	_players = {1: get_node("Player"), 2: get_node("Opponent")}
	var admitted: Array[int] = [1, 2]
	if Session.is_online(): admitted = Session.player_ids()


	if Session.is_online() and not Session.lobby.launch_committed and admitted.size() < 2:
		admitted = [1, 2]
	if Session.is_online():
		for id: int in admitted:
			if _players.has(id): continue
			var extra: = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Player
			extra.name = "Player%d" % id
			_configure_fighter(extra, id)
			_players[id] = extra
			add_child(extra)

		for id: int in _players.keys():
			if not admitted.has(id):
				var unused: = _players[id] as Player
				unused.process_mode = Node.PROCESS_MODE_DISABLED
				unused.visible = false
				unused.collision_layer = 0
				_players.erase(id)
	for id: int in _players:
		var fighter: Player = _players[id]
		_configure_fighter(fighter, id)
		if fighter.peer_id > 0: _admitted_players[id] = true
	player = get_player(Session.local_player_id)
	opponent = get_opponent(player.player_id)

	var brain: = get_node("Opponent/BotBrain") as BotBrain
	brain.enabled = not Session.is_online() and mode == "duel"
	brain.process_mode = Node.PROCESS_MODE_DISABLED if Session.is_online() else Node.PROCESS_MODE_INHERIT


func _configure_fighter(fighter: Player, id: int) -> void :
	fighter.player_id = id
	fighter.team = id
	fighter.peer_id = Session.peer_for_player(id)
	fighter.is_local = id == Session.local_player_id
	fighter.display_name = "VOCÊ" if fighter.is_local else ("JOGADOR %d" % id if Session.is_online() else "BOT")
	if Session.is_online():
		var palette: Array = RobotBody.config()["player_colors"]
		var rgb24: = Session.lobby.color_for_player(id)

		fighter.body_color = RobotColor.from_rgb24(rgb24) if rgb24 >= 0 else Color(String(palette[(id - 1) % palette.size()]))
		fighter.configure_network("authority" if Session.has_authority() else ("predicted" if fighter.is_local else "proxy"))

	fighter.paint_bytes = Session.lobby.paint_for_player(id) if Session.is_online() else (PaintSlots.chosen_bytes() if fighter.is_local else PackedByteArray())
	fighter.frozen = Session.is_online()


func _ready() -> void :
	_waiting_world = Arena.build_async and not Session.is_online()
	if _waiting_world:
		_hold_bodies.call_deferred(true)
	UserSettings.apply_input()
	AudioMix.apply(get_tree())
	VideoSettings.start(get_tree())
	Forge.attach_world(self)
	for id: int in _players:
		get_player(id).place_at(arena.get_spawn(id - 1))
	_place_dummy()
	for fighter: Player in get_players():
		fighter.died.connect(_on_player_died)
	if Session.is_online():
		for candidate: Node in get_tree().get_nodes_in_group(Combat.COMBATANTS_GROUP):
			if candidate is Player and not _players.has((candidate as Player).player_id):
				candidate.remove_from_group(Combat.COMBATANTS_GROUP)

	_hud.bind_player(player)
	_hud.bind_match(self)
	_hud.bind_voice(voice)

	_hud.refresh_controls_help()
	voice.transcribed.connect(_on_voice_transcribed)
	voice.command_transcribed.connect(_on_voice_transcribed.bind(true))

	voice.tapped.connect(_on_voice_tapped)
	_ensure_voice_started()
	_hud.console.submitted.connect(_on_console_submitted)
	_hud.console.opened.connect(_on_console_opened)
	_hud.console.closed.connect(_on_console_closed)
	_hud.options.opened.connect(_on_options_opened)
	_hud.options.closed.connect(_on_options_closed)
	_hud.options.menu_requested.connect(_return_to_menu)
	Forge.request_processed.connect(_hud.show_request)
	Forge.request_processed.connect(_record_network_voice_result)
	Session.changed.connect(_on_session_changed)
	Session.replication.active_changed.connect(_on_replication_changed)
	if Session.is_online():
		_enter_online_lobby()
		Session.world_sync.bind_world(self)
		if Session.has_authority():
			start_match()
		Session.creations.bind_world(self)
		Session.replication.bind_world(self)
		Session.voice_sync.bind_world(self)
	else:
		start_mode(mode)
	_refresh_local_input()
	print("[Match] modo: %s" % mode)
	if local_modes_available():
		_run_dev_args()


func _exit_tree() -> void :
	_epoch += 1
	if _paused_by_menu:
		get_tree().paused = false
	if Session.changed.is_connected(_on_session_changed):
		Session.changed.disconnect(_on_session_changed)
	if Session.replication.active_changed.is_connected(_on_replication_changed):
		Session.replication.active_changed.disconnect(_on_replication_changed)
	Session.voice_sync.unbind_world(self)
	Session.replication.unbind_world(self)
	Session.creations.unbind_world(self)
	Session.world_sync.unbind_world(self)
	Session.stop_online()
	Forge.detach_world(self)


func _return_to_menu() -> void :
	return_to_menu = true
	next_mode = ""
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/intro/intro.tscn")


func get_player(id: int) -> Player:
	return _players.get(id) as Player


func player_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: int in _players: ids.append(id)
	ids.sort()
	return ids


func get_players() -> Array[Player]:
	var fighters: Array[Player] = []
	for id: int in player_ids(): fighters.append(get_player(id))
	return fighters


func get_opponent(player_id: int) -> Player:
	for id: int in _players:
		if id != player_id:
			return get_player(id)
	return null



func gameplay_available() -> bool:
	return (Session.replication.is_active() and state == "online_play") if Session.is_online() else Session.has_authority()


func creations_available() -> bool:
	return (Session.creations.is_active() and gameplay_available()) if Session.is_online() else Session.has_authority()


func local_modes_available() -> bool:
	return not Session.is_online() and Session.has_authority()


func _enter_online_lobby() -> void :
	_epoch += 1
	mode = "online"
	_set_state("session")
	bot.enabled = false
	dummy.set_enabled(false)
	for id: int in _players:
		var fighter: = get_player(id)
		fighter.frozen = true
		fighter.input_enabled = false
		fighter.respawn_on_death = false
	_on_session_changed()


func _on_session_changed() -> void :
	if not Session.is_ready():
		_voice_requests.clear()
	for id: int in _players:
		var fighter: = get_player(id)
		fighter.peer_id = Session.peer_for_player(id)
		if Session.is_online() and fighter.peer_id > 0:
			if not _admitted_players.has(id) or not fighter.visible:
				fighter.visible = true
				fighter.collision_layer = PhysicsLayers.PLAYERS
				fighter.add_to_group(Combat.COMBATANTS_GROUP)


				if Session.has_authority() and ( not _admitted_players.has(id) or not _round_in_progress()):
					fighter.reset_for_round()
			_admitted_players[id] = true
		elif Session.is_online() and _admitted_players.has(id):


			if Session.has_authority() and fighter.is_alive():
				if _round_in_progress():


					fighter.eliminate.call_deferred()
				else:
					fighter.health = 0.0
			fighter.release_input()
			fighter.frozen = true
			fighter.visible = false
			fighter.collision_layer = 0
			fighter.remove_from_group(Combat.COMBATANTS_GROUP)
	if Session.is_online():
		print("[Session] %s · jogador local %d · peer %d" % [Session.status_text(), player.player_id, player.peer_id])
		_on_replication_changed()
		if Session.has_authority() and state in ["fight", "online_play"]:
			_resolve_elimination.call_deferred(_epoch)


func _on_replication_changed() -> void :
	if not Session.is_online():
		return
	var active: = gameplay_available()
	for id: int in _players:
		get_player(id).frozen = not active or not get_player(id).is_alive() or Session.peer_for_player(id) <= 0

		if not get_player(id).is_local:
			get_player(id).input_enabled = active and get_player(id).is_alive() and Session.peer_for_player(id) > 0
	state_changed.emit()
	_refresh_local_input()
	_ensure_voice_started()


func add_thing(thing: Thing) -> void :
	if thing.get_parent() == null:
		_things.add_child(thing)
	elif thing.get_parent() != _things:
		thing.reparent(_things)



func start_mode(new_mode: String) -> void :
	if not local_modes_available():
		return
	mode = new_mode
	Session.start_offline(mode)
	var duel: = mode == "duel"
	_set_opponent_enabled(duel)
	dummy.set_enabled( not duel)
	player.respawn_on_death = not duel
	opponent.respawn_on_death = false
	if duel:
		start_match()
	else:
		_epoch += 1
		_clear_everything()
		player.reset_for_round()
		player.frozen = false
		_set_state("practice")
		if arena.space != null and Arena.take_intro():
			if arena.is_world_ready():
				_play_map_intro()
			else:
				_intro_pending = true



func _play_map_intro() -> void :
	if is_instance_valid(_map_intro):
		_map_intro.queue_free()
	_map_intro = SpaceIntro.new()
	add_child(_map_intro)
	_map_intro.setup(arena.space, player)
	player.frozen = true
	_set_state("map_intro")
	_hud.set_cinematic(true)
	_refresh_local_input()
	_map_intro.countdown_started.connect( func(seconds: float) -> void :
		_hud.set_cinematic(false)
		_begin_countdown(seconds, "practice"))


func _begin_countdown(seconds: float, after: String) -> void :
	countdown_left = seconds
	countdown_total = seconds
	_after_countdown = after
	_set_state("countdown")
	_refresh_local_input()



func start_match() -> void :
	if not Session.has_authority():
		return
	score.clear()
	for id: int in _players: score[id] = 0
	last_winner = null
	Forge.reset_novelty()
	_start_round(1)


func _start_round(number: int) -> void :
	_epoch += 1
	round_number = number
	_clear_everything()
	for fighter: Player in get_players():
		fighter.reset_for_round()
		fighter.frozen = true
		if Session.is_online() and _admitted_players.has(fighter.player_id) and Session.peer_for_player(fighter.player_id) <= 0:
			fighter.health = 0.0
	bot.reset()
	countdown_left = Lexicon.balf("match.countdown_s")
	countdown_total = countdown_left
	_after_countdown = ""
	_set_state("countdown")
	if Session.is_online():
		Session.replication.restart_round_baseline()


func _on_player_died(dead: Player) -> void :
	var encounter := get_node_or_null("CoopEncounter")
	if encounter != null and encounter.phase == "battle":
		dead.frozen = true
		return
	if not Session.has_authority() or state not in ["fight", "online_play"]:
		return
	dead.frozen = true


	if _players.size() > 2:
		_resolve_elimination.call_deferred(_epoch)
	else:
		_resolve_elimination(_epoch)



func _round_in_progress() -> bool:
	return state in ["countdown", "fight", "online_play"]


func _resolve_elimination(round_epoch: int) -> void :
	if round_epoch != _epoch or not Session.has_authority() or state not in ["fight", "online_play"]:
		return
	var survivors: Array[Player] = []
	for fighter: Player in get_players():
		if fighter.is_alive() and ( not Session.is_online() or Session.peer_for_player(fighter.player_id) > 0):
			survivors.append(fighter)
	if survivors.size() > 1: return
	_epoch += 1
	last_winner = survivors[0] if survivors.size() == 1 else null
	if last_winner != null:
		score[last_winner.player_id] = int(score.get(last_winner.player_id, 0)) + 1
	for fighter: Player in get_players():
		fighter.frozen = true
	var match_over: = last_winner != null and int(score[last_winner.player_id]) >= int(Lexicon.balf("match.rounds_to_win"))
	_set_state("match_over" if match_over else "round_over")
	if match_over:
		return
	_intermission_left = Lexicon.balf("match.intermission_s")



func _clear_everything() -> void :
	for fighter: Player in get_players():
		Forge.clear_player(fighter.player_id)
		fighter.hands.clear()
		fighter.stop_piloting()
	arena.reset_world()


func _set_opponent_enabled(enabled: bool) -> void :
	opponent.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	opponent.visible = enabled
	opponent.collision_layer = PhysicsLayers.PLAYERS if enabled else 0
	bot.enabled = enabled
	if enabled:
		opponent.add_to_group(Combat.COMBATANTS_GROUP)
	else:
		opponent.remove_from_group(Combat.COMBATANTS_GROUP)


func _set_state(new_state: String) -> void :
	state = new_state
	state_changed.emit()




func _wait_for_world() -> void :
	if not _waiting_world:
		return
	var screen: = LoadingScreen.current
	if screen != null:
		screen.set_progress(0.35 + 0.65 * arena.world_progress())
	var painted: = player.robot == null or player.robot.paint_ready()
	if not arena.is_world_ready() or not painted:
		_hold_bodies(true)
		return
	_waiting_world = false
	_hold_bodies(false)
	Arena.build_async = false
	BlockVolume.loading = false
	if state == "practice" and not _intro_pending:
		player.frozen = false
	if screen != null:
		screen.close()
	if _intro_pending:
		_intro_pending = false
		_play_map_intro()





func _hold_bodies(hold: bool) -> void :
	for fighter: Player in get_players():
		fighter.frozen = hold or fighter.frozen
		fighter.set_physics_process( not hold)
		fighter.velocity = Vector3.ZERO
		if not hold:
			fighter.place_at(arena.get_spawn(fighter.player_id - 1))
	dummy.set_physics_process( not hold)
	if not hold:
		_place_dummy(true)




func _place_dummy(grounded: bool = false) -> void :
	var spawn: = arena.get_spawn(0)
	var spot: = spawn.origin - spawn.basis.z * Lexicon.balf("dummy.distance_from_spawn")
	if arena.space != null:
		var up: = Gravity.up_at(spot, spawn.basis.y)
		var at: = Forge.ground_point(spot + up * 2.0, up) if grounded else spot
		var frame: = Gravity.frame_for(up)

		var side: = Gravity.flat(spawn.basis.x, up).normalized()
		dummy.place_at(Transform3D(Basis(side, up, side.cross(up)) if side.length_squared() > 0.5 else frame, at))
		return
	var ground: = 0.0
	if grounded and arena.terrain != null:
		ground = arena.terrain.height_at(spot.x, spot.z)
	dummy.place_at(Transform3D(Basis.IDENTITY, Vector3(spot.x, ground, spot.z)))


func _process(delta: float) -> void :
	_wait_for_world()

	if _waiting_world:
		return
	if Session.is_online() and ( not Session.has_authority() or not Session.replication.is_active()):
		return
	if state == "countdown":
		countdown_left = maxf(0.0, countdown_left - delta)
		if countdown_left <= 0.0:
			var after: = _after_countdown
			_after_countdown = ""
			_set_state(after if not after.is_empty() else ("online_play" if Session.is_online() else "fight"))
			for fighter: Player in get_players():
				fighter.frozen = not fighter.is_alive() or (Session.is_online() and Session.peer_for_player(fighter.player_id) <= 0)
			if Session.is_online():
				_on_replication_changed()

				_resolve_elimination.call_deferred(_epoch)
	elif state == "round_over":
		_intermission_left = maxf(0.0, _intermission_left - delta)
		if _intermission_left <= 0.0:
			_start_round(round_number + 1)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("debug"):
		_hud.toggle_debug()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo()\
	and (event as InputEventKey).physical_keycode == KEY_F4:

		start_mode("practice" if mode == "duel" else "duel")
	elif state == "match_over" and event.is_action_pressed("jump"):
		if Session.is_online(): Session.world_sync.request_rematch()
		else: start_match()
	elif event.is_action_pressed("ui_cancel"):
		_hud.options.open()
		get_viewport().set_input_as_handled()
	elif gameplay_available() and event is InputEventMouseButton and event.is_pressed() and not _hud.console.is_open\
	and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:

		_set_mouse_captured(true)
		get_viewport().set_input_as_handled()


func _on_console_submitted(text: String) -> void :
	if not creations_available():
		return
	Forge.request(player.player_id, text)



func _on_voice_transcribed(text: String, seconds: float, commands_only: bool = false) -> void :
	if not creations_available() or not player.can_act():
		return
	var matter_before: = player.matter_spendable()
	var result: = Forge.request(player.player_id, text, VoiceFeedback.enabled(), commands_only)
	if result.get("pending", false):
		_voice_requests[int(result["request_id"])] = {"seconds": seconds, "quality": voice.engine_id(), "matter": matter_before}
	else:
		VoiceFeedback.record(text, result, seconds, voice.engine_id(), matter_before)


func _ensure_voice_started() -> void :
	if not _voice_started and creations_available() and voice_enabled and not OS.get_cmdline_user_args().has("--sem-voz"):
		_voice_started = true
		voice.setup(player, Lexicon.data)


func _record_network_voice_result(player_id: int, text: String, result: Dictionary) -> void :
	if player_id != player.player_id or not _voice_requests.has(int(result.get("request_id", -1))):
		return
	var request_id: = int(result["request_id"])
	var pending: Dictionary = _voice_requests[request_id]
	_voice_requests.erase(request_id)
	VoiceFeedback.record(text, result, float(pending.seconds), str(pending.quality), float(pending.matter))


func _on_console_opened() -> void :
	_console_open = true
	player.release_input()
	_refresh_local_input()


func _on_console_closed() -> void :
	_console_open = false
	_refresh_local_input()



func _on_options_opened() -> void :
	_options_open = true
	player.release_input()
	_paused_by_menu = not Session.is_online()
	if _paused_by_menu:
		get_tree().paused = true
	_refresh_local_input()


func _on_options_closed() -> void :
	_options_open = false
	if _paused_by_menu:
		get_tree().paused = false
	_paused_by_menu = false
	player.release_input()
	_refresh_local_input()


func _on_voice_tapped() -> void :
	if gameplay_available() and player.can_act():
		if Session.is_online() and player.input_provider is LocalPlayerInput:
			(player.input_provider as LocalPlayerInput).queue_action("toggle_extract")
		else:
			player.set_extracting( not player.extracting)


func _refresh_local_input() -> void :
	var enabled: = gameplay_available() and not _console_open and not _options_open and state != "map_intro"
	player.input_enabled = enabled

	_set_mouse_captured(enabled or (state == "map_intro" and not _options_open))


func _set_mouse_captured(captured: bool) -> void :
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _run_dev_args() -> void :
	var screenshot_path: = ""
	var uses: = 0
	var aim_down: = false
	var open_options: = false
	var calibrate: = false
	var extract: = false
	var die: = false
	var extract_from: = ""
	var wait: = DEV_SCREENSHOT_WAIT
	var frames: = 1
	var frame_gap: = 0.1
	var phrases: Array[String] = []
	var voice_files: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--say="):
			phrases.append(arg.trim_prefix("--say="))
		elif arg.begins_with("--voz="):
			voice_files.append(arg.trim_prefix("--voz="))
		elif arg.begins_with("--use="):
			uses = arg.trim_prefix("--use=").to_int()
		elif arg == "--debug":
			_hud.toggle_debug()
		elif arg == "--mirar":
			aim_down = true
		elif arg == "--opcoes":
			open_options = true
		elif arg == "--calibrar":
			calibrate = true
		elif arg.begins_with("--ver-robo"):
			_dev_robot_camera(arg.trim_prefix("--ver-robo").trim_prefix("="))
		elif arg.begins_with("--camera="):
			player.view.zoom(arg.trim_prefix("--camera=").to_int())
		elif arg == "--morrer":
			die = true
		elif arg.begins_with("--andar="):
			_dev_walk(arg.trim_prefix("--andar="))
		elif arg.begins_with("--materia="):
			player.add_matter(arg.trim_prefix("--materia=").to_float())
		elif arg.begins_with("--extrair"):
			extract = true
			extract_from = arg.trim_prefix("--extrair").trim_prefix("=")
		elif arg.begins_with("--gravar-voz"):
			_start_recording(arg.trim_prefix("--gravar-voz").trim_prefix("=").to_int())
		elif arg.begins_with("--screenshot="):
			screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--wait="):
			wait = arg.trim_prefix("--wait=").to_float()
		elif arg.begins_with("--quadros="):
			var spec: = arg.trim_prefix("--quadros=").split("x")
			frames = maxi(1, spec[0].to_int())
			if spec.size() > 1:
				frame_gap = spec[1].to_float()
		elif arg.begins_with("--ir="):
			var at: = arg.trim_prefix("--ir=").split(",")
			var x: = at[0].to_float()
			var z: = at[1].to_float() if at.size() > 1 else 0.0
			player.global_position = Vector3(x, (arena.terrain.height_at(x, z) if arena.terrain != null else 0.0) + 0.05, z)
		elif arg == "--pular":
			get_tree().physics_frame.connect( func() -> void :
				if player.is_on_floor() and not Input.is_action_pressed("jump"):
					Input.action_press("jump")
				else:
					Input.action_release("jump"))
		elif arg == "--agachar":
			_dev_tap("crouch")
		elif arg.begins_with("--escorregar"):
			var after: = arg.trim_prefix("--escorregar").trim_prefix("=").to_float()
			Input.action_press("move_forward")
			Input.action_press("sprint")
			get_tree().create_timer(after if after > 0.0 else 0.7).timeout.connect( func() -> void : _dev_tap("crouch"))
		elif arg.begins_with("--girar="):
			var rate: = deg_to_rad(arg.trim_prefix("--girar=").to_float())
			get_tree().process_frame.connect( func() -> void : player.yaw = wrapf(player.yaw + rate * get_process_delta_time(), - PI, PI))
	if ( not phrases.is_empty() or not voice_files.is_empty()) and state == "countdown":

		await state_changed
	if extract:
		await _dev_extract(extract_from)
	for phrase in phrases:
		_on_console_submitted(phrase)
	for file in voice_files:
		await voice.inject(WavReader.read_16k_mono(file))
		while voice.state == "thinking":
			await voice.state_changed
	if aim_down:
		while Forge.is_building(player.player_id):
			await get_tree().process_frame
		player.aiming = true
	for i in uses:
		await get_tree().create_timer(DEV_USE_GAP).timeout
		if player.shaper.active:

			player.shaper.confirm()
			continue
		player.hands.use_pressed()
		player.hands.use_released()
	if die:
		player.take_damage(100000.0, "kinetic", null)
	if open_options:
		_hud.options.open()
	if calibrate:
		_start_calibration()
	if not screenshot_path.is_empty():
		await get_tree().create_timer(wait).timeout
		if frames > 1:
			await _take_contact_sheet(screenshot_path, frames, frame_gap)
		else:
			_take_screenshot(screenshot_path)




func _dev_robot_camera(view: String) -> void :
	var target: Player = opponent if view == "bot" else player
	_hud.visible = false
	var cam: = Camera3D.new()
	cam.name = "DevRobotCamera"
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	var offset: = Vector3(3.2, 1.2, 0.4) if view == "lado" else Vector3(1.4, 1.5, -3.0)

	var fixed_yaw: = target.global_rotation.y
	get_tree().process_frame.connect( func() -> void :
		if not is_instance_valid(cam) or not is_instance_valid(target):
			return
		var flat: = Basis(Vector3.UP, fixed_yaw if view == "fixo" else target.global_rotation.y)
		cam.global_position = target.global_position + flat * offset
		cam.look_at(target.global_position + Vector3.UP * 1.0))



func _dev_tap(action: String) -> void :
	await get_tree().physics_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)



func _dev_walk(spec: String) -> void :
	var actions: = {"frente": "move_forward", "tras": "move_back", "esquerda": "move_left", "direita": "move_right"}
	for part in spec.split(","):
		if actions.has(part):
			Input.action_press(String(actions[part]))
		elif part == "correr":
			Input.action_press("sprint")




func _dev_extract(blueprint: String) -> void :
	var best: = Vector3.INF
	for structure: Structure in arena.structures():
		if not blueprint.is_empty() and structure.blueprint_id != blueprint:
			continue
		var point: = structure.facing_chunk_point(player.global_position)
		if point.distance_squared_to(player.global_position) < best.distance_squared_to(player.global_position):
			best = point
	if best == Vector3.INF:
		push_warning("--extrair: nenhuma construção %s" % blueprint)
		return
	var away: = player.global_position - best
	away.y = 0.0
	var spot: = best + away.normalized() * DEV_EXTRACT_DISTANCE
	player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	player.look_at_point(best)
	player.set_extracting(true)
	player.hands.use_pressed()
	await get_tree().create_timer(DEV_EXTRACT_S, false).timeout


func _start_recording(count: int) -> void :
	if not voice.is_on():
		_hud.show_voice_prompt("Sem voz, sem gravação: %s" % voice.off_reason)
		return
	var recorder: = VoiceRecorder.new()
	recorder.name = "VoiceRecorder"
	add_child(recorder)
	recorder.prompt_changed.connect(_hud.show_voice_prompt)
	recorder.start(voice, count if count > 0 else DEV_RECORD_PHRASES)



func _start_calibration() -> void :
	if not voice.is_on():
		_hud.show_voice_prompt("Sem voz, sem calibração: %s" % voice.off_reason)
		return
	var calibration: = VoiceCalibration.new()
	calibration.name = "VoiceCalibration"
	_hud.get_node("Root").add_child(calibration)
	get_tree().paused = true
	_set_mouse_captured(false)
	while voice.state == "warming":
		await voice.state_changed
	calibration.finished.connect( func() -> void :
		calibration.queue_free()
		get_tree().paused = false
		_set_mouse_captured(true))
	calibration.start(voice)



func _take_contact_sheet(path: String, count: int, gap: float) -> void :
	var shots: Array[Image] = []
	for i in count:
		if i > 0:
			await get_tree().create_timer(gap).timeout
		await RenderingServer.frame_post_draw
		var image: = get_viewport().get_texture().get_image()
		if image == null:
			push_error("[Match] sem imagem pra salvar (rodando headless?)")
			get_tree().quit()
			return
		@warning_ignore("integer_division")
		image.resize(image.get_width() / 2, image.get_height() / 2)
		shots.append(image)
	var columns: = mini(count, 4)
	var w: = shots[0].get_width()
	var h: = shots[0].get_height()
	var sheet: = Image.create(w * columns, h * ceili(float(count) / columns), false, shots[0].get_format())
	for i in shots.size():
		@warning_ignore("integer_division")
		sheet.blit_rect(shots[i], Rect2i(0, 0, w, h), Vector2i((i % columns) * w, (i / columns) * h))
	sheet.save_png(path)
	print("[Match] folha de %d quadros salva em %s" % [count, path])
	get_tree().quit()


func _take_screenshot(path: String) -> void :
	var image: = get_viewport().get_texture().get_image()
	if image == null:
		push_error("[Match] sem imagem pra salvar (rodando headless?)")
	else:
		image.save_png(path)
		print("[Match] print salvo em ", path)
	get_tree().quit()


func export_round_state() -> Dictionary:
	return {"state": state, "number": round_number, "score": score.duplicate(), "countdown": countdown_left, 
		"intermission": _intermission_left, "winner": last_winner.player_id if is_instance_valid(last_winner) else 0}


func apply_round_state(data: Dictionary) -> void :
	if Session.has_authority():
		return
	round_number = int(data.get("number", 0))
	score = data.get("score", {}).duplicate()
	countdown_left = float(data.get("countdown", 0.0))
	_intermission_left = float(data.get("intermission", 0.0))
	last_winner = get_player(int(data.get("winner", 0)))
	_set_state(str(data.get("state", "session")))
	_on_replication_changed()
