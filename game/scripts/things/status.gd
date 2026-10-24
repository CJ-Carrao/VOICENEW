class_name Status
extends Node3D





const NODE_NAME: = "Status"
const SHELL_ALPHA: = 0.3

const BURN_DAMAGE: = "burn"


var remaining: Dictionary = {}
var _target: Node3D

var _sources: Dictionary = {}
var _tick: float = 0.0
var _shell: MeshInstance3D
var _material: StandardMaterial3D
var _void_sources: Dictionary = {}
var _void_check_left := 0.0
var _combo_marks: Node3D
var _combo_signature := ""

static func paralyzed(target: Node) -> bool:
	if not is_instance_valid(target): return false
	var status := of(target)
	return status != null and float(status.remaining.get("void_overload", 0.0)) > 0.0

static func movement_locked(target: Node) -> bool:
	var status := of(target)
	return status != null and (float(status.remaining.get("void_overload", 0.0)) > 0.0 or float(status.remaining.get("entangled", 0.0)) > 0.0)

static func remove_effect(target: Node, kind: String) -> void:
	var status := of(target)
	if status == null: return
	status.remaining.erase(kind)
	status._sources.erase(kind)
	status._refresh_presentation()

static func apply_void(target: Node3D, source: Thing) -> void:
	apply(target, "void_overload", source)
	var status := of(target)
	if status == null: return
	status._void_sources[source.get_instance_id()] = weakref(source)
	if target.has_method("release_input"): target.release_input()
	if target is CharacterBody3D: target.velocity = Vector3.ZERO

func _refresh_void() -> void:
	if not remaining.has("void_overload"): return
	for id in _void_sources.keys():
		var source = _void_sources[id].get_ref()
		var user = source.get_node_or_null("Jujutsu") if is_instance_valid(source) else null
		if user == null or not user.void_affects(_target): _void_sources.erase(id)
	if _void_sources.is_empty():
		remaining.erase("void_overload")
		_sources.erase("void_overload")
	else: remaining["void_overload"] = .6



static func apply(target: Object, kind: String, source: Thing, duration_mult: float = 1.0) -> void :
	if not is_instance_valid(target): return
	if not Forge.has_effect_authority() or (Session.is_online() and not (target is Thing or target is Player)):
		return
	var config: Variant = Lexicon.bal("status." + kind)
	if not (config is Dictionary) or not (target is Node3D) or not is_instance_valid(target)\
	or not target.has_method("take_damage") or not (target as Node3D).is_inside_tree():
		return
	if target.has_method("is_alive") and not target.call("is_alive"):
		return
	var status: = of(target as Node)
	if status == null:
		status = Status.new()
		status.name = NODE_NAME
		status._target = target as Node3D
		(target as Node).add_child(status)
	status._add(kind, float((config as Dictionary).get("duration_s", 0.0)) * duration_mult, source)


static func of(target: Node) -> Status:
	return target.get_node_or_null(NODE_NAME) as Status if target != null else null



static func speed_mult(target: Node) -> float:
	var status: = of(target)
	return status._speed_mult() if status != null else 1.0



static func clear(target: Node) -> void :
	var status: = of(target)
	if status != null:
		status.remaining.clear()
		status.queue_free()


func _add(kind: String, duration: float, source: Thing) -> void :
	remaining[kind] = maxf(float(remaining.get(kind, 0.0)), duration)
	_sources[kind] = source
	_refresh_presentation()


func _speed_mult() -> float:
	var mult: = 1.0
	for kind: String in remaining:
		mult *= float(Lexicon.bal("status.%s.speed_mult" % kind, 1.0))
	return mult


func _physics_process(delta: float) -> void :
	if not Forge.has_effect_authority():
		return
	if not is_instance_valid(_target) or (_target.has_method("is_alive") and not _target.call("is_alive")):
		queue_free()
		return
	_void_check_left -= delta
	if _void_check_left <= 0.0:
		_void_check_left = .1
		_refresh_void()
	if remaining.has("burning"):
		_tick += delta
		var tick: = Lexicon.balf("status.burning.tick_s")
		while _tick >= tick:
			_tick -= tick
			var source: Thing = _sources.get("burning") if is_instance_valid(_sources.get("burning")) else null
			Combat.apply_damage(_target, Lexicon.balf("status.burning.damage_per_s") * tick, BURN_DAMAGE, source)
			if not is_instance_valid(_target):
				return

	if not _target is Player:
		_count_down(delta)
	if remaining.is_empty():
		queue_free()
	elif _shell != null:
		_material.albedo_color.a = SHELL_ALPHA * (0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012))




static func tick_for(target: Node, delta: float) -> void :
	var status: = of(target)
	if status == null or status.remaining.is_empty():
		return
	status._count_down(delta)
	if status.remaining.is_empty():
		status.visible = false


func _count_down(delta: float) -> void :
	for kind: String in remaining.keys():
		remaining[kind] = float(remaining[kind]) - delta
		if float(remaining[kind]) <= 0.0:
			remaining.erase(kind)
	_refresh_presentation()

func _refresh_presentation() -> void:
	var visible_kind := ""
	for kind in ["void_overload", "entangled", "webbed", "frozen", "burning", "wet"]:
		if float(remaining.get(kind, 0.0)) > 0.0:
			visible_kind = kind
			break
	if not visible_kind.is_empty(): _update_shell(visible_kind)
	if _shell != null: _shell.visible = not visible_kind.is_empty()
	var signature := ("wet" if float(remaining.get("wet", 0.0)) > 0.0 else "") + ("vines" if float(remaining.get("entangled", 0.0)) > 0.0 else "")
	if signature == _combo_signature: return
	_combo_signature = signature
	if is_instance_valid(_combo_marks):
		_combo_marks.hide()
		_combo_marks.queue_free()
	if signature.is_empty(): return
	_combo_marks = Node3D.new()
	_combo_marks.name = "CreatureComboMarks"
	add_child(_combo_marks)
	var size: Vector3 = _target.bounds.size if _target is Thing else Vector3.ONE
	var cube := BoxMesh.new()
	for effect in ["wet", "entangled"]:
		if float(remaining.get(effect, 0.0)) <= 0.0: continue
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("79c7dd") if effect == "wet" else Color("74965b")
		for i in 8:
			var piece := MeshInstance3D.new()
			piece.mesh = cube
			piece.material_override = material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_combo_marks.add_child(piece)
			var angle := TAU * (i % 4) / 4.0
			piece.position = Vector3(cos(angle) * (size.x * .5 + .06), size.y * (-.20 if i < 4 else .20), sin(angle) * (size.z * .5 + .06))
			piece.rotation.y = -angle
			piece.scale = Vector3(.07, .16, .07) if effect == "wet" else Vector3(.07, .08, (size.z if i % 2 == 0 else size.x) + .18)



func _update_shell(kind: String) -> void :
	var element: = String(Lexicon.bal("status.%s.element" % kind, ""))
	var tint: = Color.from_string(String((Lexicon.data.elements.get(element, {}) as Dictionary).get("tint", "#ffffff")), Color.WHITE)
	if kind == "void_overload": tint = Color("aebce4")
	if kind == "wet": tint = Color("79c7dd")
	if kind == "entangled": tint = Color("74965b")
	if kind == "webbed": tint = Color("d1d5c3")
	if _shell == null:
		_shell = MeshInstance3D.new()
		var sphere: = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		_shell.mesh = sphere
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shell.material_override = _material
		_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_shell)

		var body: Variant = _target.get("body")
		if body is VisualInstance3D:
			_shell.layers = (body as VisualInstance3D).layers
		var size: = Vector3.ONE * 1.8
		if _target is Thing:
			size = (_target as Thing).bounds.size
		var diameter: = maxf(size.x, maxf(size.y, size.z)) + 0.3
		_shell.scale = Vector3.ONE * diameter
		position = _target.to_local(Combat.center_of(_target))
	_material.albedo_color = Color(tint, SHELL_ALPHA)


static func snapshot(target: Node) -> Dictionary:
	var status: = of(target)
	return status.remaining.duplicate() if status != null else {}


static func apply_snapshot(target: Node3D, values: Dictionary) -> void :
	if Session.has_authority():
		return
	var status: = of(target)
	if values.is_empty():
		if status != null:
			status.remaining.clear()
			status.visible = false
		return
	if status == null:
		status = Status.new()
		status.name = NODE_NAME
		status._target = target
		target.add_child(status)
	status.remaining = values.duplicate()
	status.visible = true
	status._refresh_presentation()
