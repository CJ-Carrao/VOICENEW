class_name MenuAssembly
extends Control


const STATE: = &"menu_assembly_state"
const MOTION: = &"menu_assembly_tween"
var _age: = 0.0
var _points: = PackedVector2Array()
var _out: = false


static func cancel(piece: Control) -> void :
	if not is_instance_valid(piece): return
	if piece.has_meta(MOTION):
		var motion: Tween = piece.get_meta(MOTION)
		if motion != null and motion.is_valid(): motion.kill()
		piece.remove_meta(MOTION)
	if piece.has_meta(STATE):
		var state: Dictionary = piece.get_meta(STATE)
		piece.position = state.position
		piece.scale = state.scale
		piece.modulate = state.modulate
		piece.pivot_offset = state.pivot
		piece.remove_meta(STATE)


static func piece(control: Control, index: = 0, leaving: = false) -> void :
	cancel(control)
	var rest: = {"position": control.position, "scale": control.scale, 
		"modulate": control.modulate, "pivot": control.pivot_offset}
	control.set_meta(STATE, rest)
	control.pivot_offset = control.size * 0.5
	var shift: = Vector2(-52.0 - float(index % 3) * 9.0, float(index % 3 - 1) * 12.0)
	var small: Vector2 = rest.scale * Vector2(0.94, 0.86)
	var transparent: Color = rest.modulate
	transparent.a = 0.0
	var delay: = minf(index * (0.012 if leaving else 0.023), 0.14)
	var motion: = control.create_tween().set_parallel(true)
	control.set_meta(MOTION, motion)
	if leaving:
		motion.tween_property(control, "position", rest.position + shift * 1.25, 0.19).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		motion.tween_property(control, "scale", small, 0.19).set_delay(delay)
		motion.tween_property(control, "modulate", transparent, 0.16).set_delay(delay)
	else:
		control.position = rest.position + shift
		control.scale = small
		control.modulate = transparent
		motion.tween_property(control, "position", rest.position, 0.32).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		motion.tween_property(control, "scale", rest.scale, 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		motion.tween_property(control, "modulate", rest.modulate, 0.14).set_delay(delay)
		motion.chain().tween_callback( func():
			control.pivot_offset = rest.pivot
			control.remove_meta(STATE)
			control.remove_meta(MOTION))


static func retire(root: Control) -> void :

	for child in root.find_children("*", "Control", true, false):
		var control: = child as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.release_focus()
		control.focus_mode = Control.FOCUS_NONE
		if control is BaseButton: (control as BaseButton).disabled = true
		if control is LineEdit: (control as LineEdit).editable = false
		if control is OptionButton: (control as OptionButton).get_popup().hide()
	var index: = 0
	for child in root.get_children():
		if child is Control and not child is MenuAssembly:
			piece(child, index, true)
			index += 1


func setup(points: PackedVector2Array, leaving: = false) -> void :
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_points = points
	_out = leaving
	_age = 0.0


func _process(delta: float) -> void :
	_age += delta
	queue_redraw()
	if _age >= 0.6: queue_free()


func _draw() -> void :
	for i in _points.size():
		var u: = clampf((_age - i * 0.025) / 0.38, 0.0, 1.0)
		if u <= 0.0 or u >= 1.0: continue
		var travel: = u if _out else 1.0 - u
		for j in 3:
			var direction: = Vector2(-1.0, (float(j) - 1.0) * 0.75)
			var at: = _points[i] + direction * (16.0 + j * 8.0) * travel
			var edge: = 3.0 + (1.0 - travel) * 2.0
			var color: = Color("#f2601a")
			color.a = sin(PI * u) * 0.42
			draw_set_transform(at, travel * (j - 1) * 0.25)
			draw_rect(Rect2( - Vector2.ONE * edge * 0.5, Vector2.ONE * edge), color)
	draw_set_transform(Vector2.ZERO)
