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



static func apply(target: Object, kind: String, source: Thing, duration_mult: float = 1.0) -> void :
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
	_update_shell(kind)


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



func _update_shell(kind: String) -> void :
	var element: = String(Lexicon.bal("status.%s.element" % kind, ""))
	var tint: = Color.from_string(String((Lexicon.data.elements.get(element, {}) as Dictionary).get("tint", "#ffffff")), Color.WHITE)
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
	status._update_shell(str(values.keys()[0]))
