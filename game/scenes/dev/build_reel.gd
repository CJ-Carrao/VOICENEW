extends Node3D







const PHRASES: = [
	"quero uma pistola", 
	"quero um fuzil de 50 bocas", 
	"quero uma escopeta de tres bocas", 
	"quero uma bazuca gigante", 
	"quero uma minigun", 
	"quero uma ak com cano de escopeta", 
	"quero uma pistola com corpo de bazuca e 6 canos", 
	"quero uma katana", 
	"quero uma sniper com luneta", 
	"quero uma escopeta de 8 bocas", 
]
const YELLOW: = Color("#ffc928")

const FIT_LENGTH: = 2.9
const FIT_HEIGHT: = 1.35

const SWING_CENTER_DEG: = -58.0
const SWING_DEG: = 22.0
const SWING_PERIOD_S: = 3.2
const BREAK_S: = 0.32

var _build_s: = 1.0
var _hold_s: = 0.45
var _pivot: Node3D
var _clock: = 0.0


func _ready() -> void :
	var phrases: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frase="):
			phrases.append(arg.trim_prefix("--frase="))
		elif arg.begins_with("--montagem="):
			_build_s = arg.trim_prefix("--montagem=").to_float()
		elif arg.begins_with("--parada="):
			_hold_s = arg.trim_prefix("--parada=").to_float()
	if phrases.is_empty():
		phrases.assign(PHRASES)
	_studio()
	_run.call_deferred(phrases)


func _process(delta: float) -> void :
	if _pivot != null:
		_clock += delta
		_swing(_clock)


func _swing(t: float) -> void :
	_pivot.rotation_degrees = Vector3(12.0, SWING_CENTER_DEG + SWING_DEG * sin(TAU * t / SWING_PERIOD_S - PI * 0.5), 0.0)


func _run(phrases: Array[String]) -> void :
	await get_tree().create_timer(0.2).timeout
	for phrase in phrases:
		var result: = PhraseParser.parse(phrase, Lexicon.data)
		if not result["ok"] or (result["recipe"] as Dictionary).has("ability"):
			push_warning("[Rolo] não montou: " + phrase)
			continue
		var thing: = await _build(result["recipe"])
		await get_tree().create_timer(_hold_s).timeout
		await _break(thing)
	get_tree().quit()



func _build(recipe: Dictionary) -> Thing:
	var thing: = Assembler.build(recipe, "head", Lexicon.data)
	thing.set_physics_process(false)
	_pivot = Node3D.new()
	_clock = 0.0
	add_child(_pivot)
	_pivot.add_child(thing)

	var box: = AABB()
	var first: = true
	for piece: MeshInstance3D in thing.model_pieces:
		var local: = _pivot.global_transform.affine_inverse() * piece.global_transform * piece.get_aabb()
		box = local if first else box.merge(local)
		first = false
	thing.position = - box.get_center()

	var length: = maxf(box.size.x, box.size.z)
	_pivot.scale = Vector3.ONE * minf(FIT_LENGTH / maxf(length, 0.001), FIT_HEIGHT / maxf(box.size.y, 0.001))
	_swing(0.0)
	var animator: = BuildAnimator.new()
	thing.add_child(animator)
	animator.start(thing, _build_s)
	await animator.finished
	return thing



func _break(thing: Thing) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = hash(thing.thing_id)
	var center: = thing.bounds.get_center()
	var pieces: Array = thing.model_pieces
	for i in pieces.size():
		var piece: = pieces[i] as MeshInstance3D
		var away: = piece.position - center
		away = (away.normalized() if away.length() > 0.001 else Vector3.UP) + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.2, 0.8), rng.randf_range(-0.4, 0.4))
		var tween: = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var delay: = float(i) / maxf(pieces.size(), 1.0) * BREAK_S * 0.5
		tween.tween_property(piece, "position", piece.position + away * thing.bounds.size.length() * 0.6, BREAK_S).set_delay(delay)
		tween.tween_property(piece, "scale", Vector3.ZERO, BREAK_S).set_delay(delay)
		tween.tween_property(piece, "rotation", piece.rotation + Vector3(rng.randf_range(-3, 3), rng.randf_range(-3, 3), 0), BREAK_S).set_delay(delay)
	await get_tree().create_timer(BREAK_S * 1.5).timeout
	_pivot.queue_free()
	_pivot = null


func _studio() -> void :
	var environment: = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = YELLOW
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 0.92, 0.75)
	environment.ambient_light_energy = 0.7

	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world: = WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var key: = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 30.0, 0.0)
	key.light_energy = 1.25
	key.shadow_enabled = true
	add_child(key)
	var fill: = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, -140.0, 0.0)
	fill.light_energy = 0.5
	add_child(fill)
	var camera: = Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0.0, 0.0, 4.6)
	add_child(camera)
	camera.make_current()
