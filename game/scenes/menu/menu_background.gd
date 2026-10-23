class_name MenuBackground
extends Control



var player: VideoStreamPlayer
var _start_s: float
var _duration_s: float
var _video_size: Vector2
var _volume_db: float
var _started: = false


func setup(config: Dictionary, start_s: float) -> void :
	name = "MenuBackground"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false
	_start_s = start_s
	_duration_s = float(config.get("duration_s", 80.0))
	_video_size = Vector2(float(config.get("width", 1920)), float(config.get("height", 1080)))
	_volume_db = float(config.get("volume_db", -6.0))
	var path: = String(config.get("stream", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Menu background unavailable: " + path)
		return
	var stream: = load(path) as VideoStream
	if stream == null:
		push_warning("Invalid menu video: " + path)
		return
	player = VideoStreamPlayer.new()
	player.name = "CityFilm"
	player.stream = stream
	player.expand = true
	player.loop = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.volume_db = _volume_db

	player.bus = AudioMix.bus(AudioMix.MUSIC)
	add_child(player)
	resized.connect(_fit_video)
	_fit_video()


func update_clock(time_s: float) -> void :
	if _started or player == null or time_s < _start_s:
		return
	_started = true
	visible = true
	player.play()


	var offset: = fposmod(time_s - _start_s, _duration_s)
	if offset > 0.1:
		player.stream_position = offset


func fade_audio(amount: float) -> void :
	if player != null:
		player.volume_db = lerpf(_volume_db, -60.0, clampf(amount, 0.0, 1.0))


func _fit_video() -> void :
	if player == null or _video_size.x <= 0.0 or _video_size.y <= 0.0:
		return

	var factor: = maxf(size.x / _video_size.x, size.y / _video_size.y)
	player.size = _video_size * factor
	player.position = (size - player.size) * 0.5
