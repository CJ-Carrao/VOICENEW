class_name IntroCinematicFX
extends Node2D



var cfg: Dictionary = {}
var clock_s: float = 0.0
var bursts: Array[Dictionary] = []
var _halo: GradientTexture2D


func setup(config: Dictionary) -> void :
	cfg = config
	var ramp: = Gradient.new()
	ramp.set_color(0, Color.WHITE)
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.18, Color(1, 1, 1, 0.38))
	ramp.add_point(0.5, Color(1, 1, 1, 0.06))
	_halo = GradientTexture2D.new()
	_halo.gradient = ramp
	_halo.width = 128
	_halo.height = 128
	_halo.fill = GradientTexture2D.FILL_RADIAL
	_halo.fill_from = Vector2(0.5, 0.5)
	_halo.fill_to = Vector2(1, 0.5)
	var blend: = CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend


func burst(at: Vector2, color: Color, amount: int, strength: float, event_s: float, light: bool = false) -> void :
	var rng: = RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"]) + roundi(event_s * 1000.0) + amount
	var velocities: = PackedVector2Array()
	var widths: = PackedFloat32Array()
	velocities.resize(amount)
	widths.resize(amount)
	for i in amount:
		var angle: = rng.randf_range( - PI, PI)
		var speed: = rng.randf_range(float(cfg["speed_min"]), float(cfg["speed_max"])) * (0.6 + strength)
		velocities[i] = Vector2(cos(angle), sin(angle)) * speed
		widths[i] = rng.randf_range(float(cfg["width_min"]), float(cfg["width_max"]))
	bursts.append({"at": at, "color": color, "t": event_s, "v": velocities, "w": widths, "strength": strength, "light": light})


	var life: = float(cfg["life_s"])
	bursts = bursts.filter( func(entry: Dictionary) -> bool: return float(entry["t"]) + life > clock_s)


func update(t: float) -> void :
	clock_s = t
	queue_redraw()


func _draw() -> void :
	if cfg.is_empty():
		return
	var life: = float(cfg["life_s"])
	for entry: Dictionary in bursts:
		var age: = clock_s - float(entry["t"])
		if age < 0.0 or age >= life:
			continue
		var origin: Vector2 = entry["at"]
		var color: Color = entry["color"]
		var strength: = float(entry["strength"])
		if bool(entry["light"]):
			var light_age: = age / float(cfg["light_s"])
			var power: = exp( - light_age * light_age) * strength
			var radius: = float(cfg["light_radius"]) * (0.45 + strength) * (1.0 + age)
			draw_texture_rect(_halo, Rect2(origin - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(color, power * float(cfg["light_alpha"])))
			var streak: = Vector2(float(cfg["streak_width"]) * (0.5 + strength), float(cfg["streak_height"]))
			draw_texture_rect(_halo, Rect2(origin - streak * 0.5, streak), false, Color(color.lerp(Color.WHITE, 0.5), power * float(cfg["streak_alpha"])))
		var velocities: PackedVector2Array = entry["v"]
		var widths: PackedFloat32Array = entry["w"]
		var alpha: = pow(1.0 - age / life, 2.0)
		for i in velocities.size():
			var velocity: = velocities[i]
			var point: = origin + velocity * age + Vector2(0.0, float(cfg["gravity"]) * age * age * 0.5)
			var width: = widths[i] * (1.0 - age / life * 0.6)
			var trail: = velocity * minf(age, float(cfg["trail_s"])) * pow(1.0 - age / life, 2.0)
			if trail.length_squared() > width * width:
				draw_line(point - trail, point, Color(color, alpha * 0.22), maxf(width * 0.5, 1.0), true)
			draw_rect(Rect2(point - Vector2.ONE * width * 0.5, Vector2.ONE * width), Color(color, alpha))
