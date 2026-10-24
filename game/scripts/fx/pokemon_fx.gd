extends RefCounted

static var count := 0
static var last_style := ""
static var combo_count := 0
static var last_combo := ""
const STYLES := ["electric", "quick", "fire", "flame", "water", "bubble", "vine", "leaf", "conductive", "vine_fire"]

static func play(parent: Node, origin: Vector3, target: Vector3, style: String, title: String) -> void:
	if not is_instance_valid(parent) or style not in STYLES: return
	if Session.is_online() and Session.has_authority(): Session.creations.notify_fx("pokemon_move", [origin, target, style, title])
	count += 1
	last_style = style
	if style in ["conductive", "vine_fire"]:
		combo_count += 1
		last_combo = style
	var colors := {"electric": "f5df6c", "quick": "e7e6d5", "fire": "e7a051", "flame": "e27941", "water": "7abed2", "bubble": "9cd3dd", "vine": "769f67", "leaf": "9eb96a", "conductive": "f6e28b", "vine_fire": "ee9c53"}
	var effect := Node3D.new()
	effect.name = "PokemonMove_" + style
	parent.add_child(effect)
	effect.global_position = origin
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(colors[style])
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.8
	var cube := BoxMesh.new()
	var offset := target - origin
	var up := Gravity.up_at(origin, Vector3.UP)
	var side := offset.normalized().cross(up).normalized()
	var pieces := 24 if style in ["vine", "electric", "flame"] else 16
	for i in pieces:
		var t := float(i + 1) / pieces
		var bit := MeshInstance3D.new()
		bit.mesh = cube
		bit.material_override = material
		bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.add_child(bit)
		var bend := side * sin(t * 27.0) * .22 if style == "electric" else side * sin(t * 15.0) * .15
		if style == "vine": bend = side * sin(t * PI * 2.0) * .40 + up * sin(t * PI) * .35
		var destination := offset * t + bend
		if style in ["conductive", "vine_fire"]:
			var frame := Gravity.frame_for(up)
			destination = frame * Vector3(cos(t * TAU) * (.8 + .12 * (i % 3)), sin(t * 23.0) * .5, sin(t * TAU) * (.8 + .12 * (i % 3)))
		var size := .10 if style == "electric" else .13 if style == "vine" else .20
		bit.scale = Vector3(size, size, size)
		if style in ["conductive", "vine_fire"]:
			bit.position = destination * .6
			bit.rotation = Vector3(t * 9.0, t * 12.0, .4)
			bit.scale = Vector3(.08, .08, .38) if style == "conductive" else Vector3(.12, .30, .12)
			var reaction := bit.create_tween()
			reaction.tween_property(bit, "position", destination, .28)
		elif style in ["electric", "vine", "water", "flame", "quick"]:
			bit.position = destination
			if offset.length_squared() > .001: bit.look_at(origin + destination + offset.normalized(), up)
			bit.scale.z = maxf(size, offset.length() / pieces * 1.25)
		else:
			bit.position = offset * maxf(0.0, t - .45)
			var flight := bit.create_tween()
			flight.tween_property(bit, "position", destination, .22 + t * .16)
		if style == "leaf":
			bit.scale = Vector3(.27, .045, .13)
			bit.rotation = Vector3(.3, t * 18.0, .4)
		if style == "bubble": bit.scale = Vector3.ONE * (.12 + float(i % 3) * .07)
	var caption := Label3D.new()
	caption.text = title
	caption.font_size = 28
	caption.pixel_size = .006
	caption.outline_size = 6
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	effect.add_child(caption)
	caption.position = up * 1.1
	var life := effect.create_tween()
	life.tween_interval(.45)
	life.tween_property(effect, "scale", Vector3.ONE * .001, .25)
	life.tween_callback(effect.queue_free)
