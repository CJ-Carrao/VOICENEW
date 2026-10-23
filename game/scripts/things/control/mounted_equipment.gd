extends Node


var item: Thing
var _cooldown: float = 0.0
var _warm: float = 0.0
var _burst: int = 0
var _weapon: bool = false
var _automatic: bool = false
var _range: float = 18.0
var _slot: int = 0
var _slots: int = 1
var _spacing: float = 1.1


func setup(thing: Thing, lex: LexiconData, slot: int = 0, slots: int = 1) -> void :
	item = thing
	_slot = slot
	_slots = slots
	_spacing = float(lex.bal("grafts.spacing_mult", 1.1))
	_weapon = lex.is_weapon(item.thing_id)
	_automatic = item.mount_host.category in ["creature", "vehicle", "structure"]
	_range = float(lex.bal("control.auto.fire_range", 18.0))
	item.auto_aim = _automatic
	item.mount_host.fired.connect(_on_host_fire)
	_place()


func _place() -> void :
	var host: = item.mount_host
	var socket: Vector3 = host.mounts.get(item.mount_socket, Vector3.ZERO)
	var at: = host.model.transform * socket
	var b: = item.bounds
	at.x += (_slot - (_slots - 1) * 0.5) * b.size.x * _spacing
	var plug: = b.get_center()
	match item.mount_socket:
		"mount_front": plug.z = b.end.z
		"mount_back": plug.z = b.position.z
		"mount_top": plug.y = b.position.y
		"mount_bottom": plug.y = b.end.y
		"mount_left": plug.x = b.end.x
		"mount_right": plug.x = b.position.x
		"mount_hand": plug = item.grip_local("main")
	item.position = at - item.basis * plug


func _physics_process(delta: float) -> void :
	if not item.has_simulation_authority():
		return
	_place()
	var usable: = item.can_act() and item.is_visible_in_tree()
	item.collision_layer = PhysicsLayers.THINGS if usable else 0
	item.collision_mask = 0
	item.set_collision_disabled( not usable, true)
	_cooldown = maxf(0.0, _cooldown - delta)
	if not usable:
		_warm = 0.0
		_burst = 0
		return
	if not _weapon or not _automatic:
		return
	var target: = Combat.nearest_enemy(item.center(), item.team, get_tree())
	if target == null or item.center().distance_to(Combat.center_of(target)) > _range:
		_warm = 0.0
		return
	_warm += delta
	if _warm < item.spin_up:
		return
	_fire(ActionContext.make(item.center(), (Combat.center_of(target) - item.center()).normalized(), target))


func _on_host_fire(ctx: ActionContext) -> void :
	if not _automatic and _weapon:
		_fire(ActionContext.make(item.center(), ctx.direction, ctx.target))


func _fire(ctx: ActionContext) -> void :
	if _cooldown > 0.0 or not item.fire(ctx):
		return
	if _burst <= 0:
		_burst = item.burst
	_burst -= 1
	_cooldown = item.burst_interval if _burst > 0 else item.fire_cooldown
