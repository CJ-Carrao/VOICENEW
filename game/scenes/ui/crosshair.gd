extends Control





@export var color: Color = Color(1, 1, 1, 0.92)
@export var outline: Color = Color(0, 0, 0, 0.55)
@export var arm: float = 7.0
@export var gap: float = 4.0
@export var thickness: float = 2.0

var player: Player
var _cfg: Dictionary
var _spread: float = 0.0
var _bloom: float = 0.0
var _show: float = 1.0
var _hit_t: float = 1.0
var _hit_kill: bool = false


func bind(owner_player: Player) -> void :
	player = owner_player
	_cfg = Lexicon.bal("feel.crosshair", {})
	player.hands.used.connect( func(_item: Thing, kind: String) -> void :
		if kind == "fire":
			_bloom = minf(_bloom + float(_cfg.get("fire_px", 6.0)), float(_cfg.get("max_px", 26.0))))



func hit(killed: bool) -> void :
	_hit_t = 0.0
	_hit_kill = killed


func _process(delta: float) -> void :
	if player == null:
		return
	var speed: = player.planar_velocity().length()
	var want: = speed * float(_cfg.get("move_px_per_ms", 1.2)) + (float(_cfg.get("air_px", 8.0)) if not player.is_on_floor() else 0.0)
	_spread = RobotSpring.damp(_spread, want, float(_cfg.get("halflife_s", 0.08)), delta)
	_bloom = RobotSpring.damp(_bloom, 0.0, float(_cfg.get("bloom_halflife_s", 0.12)), delta)
	var hidden: = player.move.sprinting or (player.aiming and player.hands.current_item() != null)
	_show = RobotSpring.damp(_show, 0.0 if hidden else 1.0, 0.04, delta)
	_hit_t += delta
	queue_redraw()


func _draw() -> void :
	var center: = size * 0.5
	var open: = gap + _spread + _bloom
	var lines: = Color(color, color.a * _show)
	var shade: = Color(outline, outline.a * _show)
	for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var from: = center + dir * open
		var to: = center + dir * (open + arm)
		draw_line(from, to, shade, thickness + 2.0)
		draw_line(from, to, lines, thickness)
	draw_circle(center, 1.5, color)
	var show_s: = float(_cfg.get("hit_s", 0.16)) * (1.6 if _hit_kill else 1.0)
	if _hit_t < show_s:
		var k: = 1.0 - _hit_t / show_s
		var mark: = Color(1.0, 0.25, 0.2, k) if _hit_kill else Color(1, 1, 1, k)
		var inner: = float(_cfg.get("hit_inner_px", 6.0)) * (1.3 if _hit_kill else 1.0)
		var outer: = inner + float(_cfg.get("hit_len_px", 7.0)) * (1.5 if _hit_kill else 1.0)
		for dir: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var d: = dir.normalized()
			draw_line(center + d * inner, center + d * outer, Color(0, 0, 0, 0.5 * k), thickness + 2.0)
			draw_line(center + d * inner, center + d * outer, mark, thickness + (1.0 if _hit_kill else 0.0))
