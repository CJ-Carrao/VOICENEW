class_name DomainCallout
extends RefCounted

static var count := 0
static var last_mode := ""
static var last_text := ""

static func announce(parent: Node, at: Vector3, mode: String) -> void:
	if not is_instance_valid(parent) or not parent.is_inside_tree() or mode not in ["void", "shrine"]: return
	count += 1
	last_mode = mode
	last_text = "Expansão de domínio! " + ("Vazio Infinito!" if mode == "void" else "Santuário Malevolente!")
	if Session.is_online() and Session.has_authority(): Session.creations.notify_fx("domain_callout", [at, mode])
	var stream = load("res://assets/audio/domains/" + mode + ".wav") as AudioStream
	var duration := clampf(stream.get_length() / .90 + .3, 3.7, 8.0) if stream != null else 3.7
	FeelSounds.play_at(parent, stream, at, 1.0, .90)
	var words := Label3D.new()
	words.name = "DomainWords"
	words.text = last_text
	words.font_size = 40
	words.pixel_size = .007
	words.outline_size = 8
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	words.no_depth_test = false
	parent.add_child(words)
	words.global_position = at + Gravity.up_at(at, Vector3.UP) * 2.2
	var life := parent.create_tween()
	life.tween_interval(duration)
	life.tween_callback(words.queue_free)
	# Also show the line to nearby players whose own third-person head is off-screen.
	var viewer: Node3D = Forge.world.get_player(Session.local_player_id) if Forge.world != null else null
	if viewer == null or viewer.global_position.distance_to(at) > 45.0: return
	var layer := CanvasLayer.new()
	layer.name = "DomainSubtitle"
	layer.layer = 8
	parent.add_child(layer)
	var label := Label.new()
	label.text = last_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -450
	label.offset_right = 450
	label.offset_top = 110 if mode == "void" else 158
	label.offset_bottom = label.offset_top + 45
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(label)
	var caption_life := layer.create_tween()
	caption_life.tween_interval(duration)
	caption_life.tween_callback(layer.queue_free)
