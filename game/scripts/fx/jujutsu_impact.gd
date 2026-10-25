extends RefCounted

const STYLES := ["punch", "black_flash", "cleave", "dismantle", "world_charge", "world_cut", "fuga_charge", "red_burst"]
static var last_style := ""
static var active := 0
static func released() -> void: active = maxi(0, active - 1)
static func play(parent: Node, at: Vector3, direction: Vector3, style: String) -> void:
	if not is_instance_valid(parent) or style not in STYLES or active >= 32: return
	active += 1
	if Session.is_online() and Session.has_authority(): Session.creations.notify_fx("jujutsu_impact", [at, direction, style])
	last_style = style
	var effect := Node3D.new()
	effect.tree_exited.connect(released)
	effect.name = "JujutsuImpact_" + style
	parent.add_child(effect)
	effect.global_position = at
	var dir := direction.normalized() if direction.length_squared() > .001 else Vector3.FORWARD
	var up := Vector3.RIGHT if absf(dir.dot(Vector3.UP)) > .95 else Vector3.UP
	effect.global_basis = Basis.looking_at(dir, up)
	var colors := [Color("100c14"), Color("f42243")] if style == "black_flash" else [Color("fff1d6"), Color("f28b37")] if style == "fuga_charge" else [Color("e9eff5"), Color("8d9cba")]
	if style == "red_burst": colors = [Color("ff344d"), Color("ffc4b5")]
	var mesh := BoxMesh.new()
	var materials := []
	for color in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		if style == "black_flash" and color == colors[1]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .55
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = .1 if style == "black_flash" and color == colors[0] else 2.0
		materials.append(mat)
	var count := 24 if style == "black_flash" else 16 if style == "red_burst" else 8
	for i in count:
		var angle := (i / 4) * TAU / 6.0
		var segment := i % 4
		var a := Vector3(cos(angle), sin(angle), 0) * (.10 + segment * .27)
		var b := Vector3(cos(angle + (.22 if i % 2 == 0 else -.22)), sin(angle + (.22 if i % 2 == 0 else -.22)), .03) * (.37 + segment * .27)
		if style in ["cleave", "dismantle", "world_cut", "world_charge"]:
			a = Vector3(-.75, (i % 4 - 1.5) * .3, .04 * i)
			b = Vector3(.75, a.y + (.7 if i % 2 == 0 else -.7), a.z)
		elif style in ["punch", "fuga_charge"]:
			a *= .35
			b *= .5
		elif style == "red_burst":
			a = Vector3.ZERO
			b = Vector3(cos(i * TAU / count), sin(i * TAU / count), sin(i * 2.1) * .2) * 3.0
		for layer in (2 if style == "black_flash" else 1):
			var bit := MeshInstance3D.new()
			bit.mesh = mesh
			bit.material_override = materials[1 - layer if style == "black_flash" else i % 2]
			bit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			effect.add_child(bit)
			bit.position = (a + b) * .5
			var delta := b - a
			bit.basis = Basis.looking_at(delta.normalized(), Vector3.UP if absf(delta.normalized().y) < .95 else Vector3.RIGHT)
			var width := .075 if layer == 0 else .04
			bit.scale = Vector3(width, width, delta.length())
	var tween := effect.create_tween()
	tween.tween_property(effect, "scale", Vector3.ONE * 1.25, .10)
	tween.tween_interval(.40 if style in ["world_charge", "fuga_charge"] else .06)
	tween.tween_property(effect, "scale", Vector3.ONE * .001, .18)
	tween.tween_callback(effect.queue_free)
