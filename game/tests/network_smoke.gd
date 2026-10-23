extends SceneTree

var session
var role := "client"
var port := 29841
var deadline := 0
var finished := false
var selected := false
var readied := false
var voted := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-role="):
			role = argument.trim_prefix("--test-role=")
	session = root.get_node("Session")
	session.lobby.match_requested.connect(_success)
	var error: int = session.start_host(port, "127.0.0.1") if role == "host" else session.start_client("127.0.0.1", port)
	if error != OK:
		_finish(false, "Cannot open transport: " + error_string(error) + "; " + session.last_error)
		return
	deadline = Time.get_ticks_msec() + 25000
	while not finished:
		await create_timer(0.1).timeout
		if finished:
			break
		if Time.get_ticks_msec() > deadline:
			_finish(false, "Timed out; state=%s phase=%s error=%s" % [session.state, session.lobby.phase, session.last_error])
			return
		if session.state != "ready" or session.player_ids().size() != 2 or not session.lobby.synchronized:
			continue
		var lobby = session.lobby
		if not selected:
			var body_script = load("res://scenes/player/robot/robot_body.gd")
			var color_script = load("res://scenes/player/robot/robot_color.gd")
			var palette: Array = body_script.config()["player_colors"]
			selected = lobby.set_local_color(color_script.to_rgb24(Color(String(palette[0 if role == "host" else 1]))))
		elif not readied and lobby.color_for_player(session.local_player_id) >= 0:
			lobby.set_local_ready(true)
			readied = true
		elif lobby.phase == "arena" and not lobby.transition_locked and not voted:
			lobby.set_local_map(0)
			lobby.set_local_vote(true)
			voted = true


func _success() -> void:
	if finished:
		return
	finished = true
	var match_script = load("res://scenes/main.gd")
	match_script.next_mode = "online"
	var game = load("res://scenes/main.tscn").instantiate()
	game.voice_enabled = false
	game.configure_session = false
	root.add_child(game)
	current_scene = game
	var replication_deadline := Time.get_ticks_msec() + 20000
	while not session.replication.is_active() or not session.creations.is_active():
		await create_timer(0.1).timeout
		if Time.get_ticks_msec() > replication_deadline:
			_finish(false, "Match replication did not become active: " + session.last_error)
			return
	await create_timer(4.0).timeout
	var stats: Dictionary = session.replication.stats
	var snapshot_count: int = stats.snapshots_sent if role == "host" else stats.snapshots_received
	_finish(snapshot_count > 0, "ENet lobby and online match replication completed; snapshots=%d" % snapshot_count)


func _finish(ok: bool, message: String) -> void:
	finished = true
	var report := {"ok": ok, "role": role, "message": message, "player_id": session.local_player_id, "roster": session.roster, "phase": session.lobby.phase, "map": session.lobby.chosen_map_id(), "replication": session.replication.stats}
	var file := FileAccess.open("res://../analysis/network-" + role + ".json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "  "))
	print("NETWORK_SMOKE ", JSON.stringify(report))
	quit(0 if ok else 1)
