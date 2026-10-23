class_name TargetDummy
extends CharacterBody3D




signal health_changed(current: float, maximum: float)

const FLASH_TIME: = 0.12

@export var team: int = 2

@export var moving: bool = true

var max_hp: float = 0.0
var hp: float = 0.0
var _home: Transform3D = Transform3D.IDENTITY
var _gravity: float = 0.0
var _friction: float = 0.0
var _respawn_s: float = 0.0
var _move_speed: float = 0.0
var _move_range: float = 0.0
var _move_dir: float = 1.0
var _base_color: Color

@onready var _label: Label3D = $Label
@onready var _body: MeshInstance3D = $Body
@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _material: StandardMaterial3D = _body.get_active_material(0)


func _ready() -> void :
	add_to_group(Combat.COMBATANTS_GROUP)
	max_hp = Lexicon.balf("dummy.max_health")
	_respawn_s = Lexicon.balf("dummy.respawn_s")
	_friction = Lexicon.balf("dummy.friction")
	_move_speed = Lexicon.balf("dummy.move_speed")
	_move_range = Lexicon.balf("dummy.move_range")
	_gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
	_base_color = _material.albedo_color
	reset()


func place_at(home: Transform3D) -> void :
	_home = home
	reset()



func reset() -> void :
	Status.clear(self)
	hp = max_hp
	velocity = Vector3.ZERO
	global_transform = _home
	up_direction = _home.basis.y
	visible = true
	_shape.set_deferred("disabled", false)
	_update_label()



func set_enabled(enabled: bool) -> void :
	process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if enabled:
		add_to_group(Combat.COMBATANTS_GROUP)
		reset()
	else:
		remove_from_group(Combat.COMBATANTS_GROUP)
		visible = false
		_shape.set_deferred("disabled", true)


func center() -> Vector3:
	return global_position + global_basis.y * 1.0


func is_alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, _type: String, _source: Node) -> void :
	if hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	_update_label()
	_flash()
	if hp <= 0.0:
		_die()


func apply_knockback(impulse: Vector3) -> void :
	if is_alive():
		velocity += impulse


func _physics_process(delta: float) -> void :
	if not is_alive():
		return

	var up: = Gravity.up_at(global_position + up_direction, up_direction)
	if Gravity.active():
		up_direction = up
		global_basis = Gravity.frame_for(up)
	var side: = Gravity.flat(_home.basis.x, up).normalized()
	var walk: = Vector3.ZERO
	if moving:
		var offset: = (global_position - _home.origin).dot(side)
		if absf(offset) >= _move_range:
			_move_dir = - signf(offset)
		walk = side * _move_dir * _move_speed * Status.speed_mult(self)
	if not is_on_floor():
		velocity += Gravity.direction_at(global_position + up_direction) * _gravity * delta
	else:
		var vertical: = velocity.dot(up)
		velocity = Gravity.flat(velocity, up).move_toward(walk, _friction * delta) + up * vertical
	move_and_slide()


func _die() -> void :
	visible = false
	_shape.set_deferred("disabled", true)
	get_tree().create_timer(_respawn_s, false).timeout.connect(reset)


func _update_label() -> void :
	_label.text = "ALVO  %d" % ceili(hp)
	health_changed.emit(hp, max_hp)


func _flash() -> void :
	var tween: = create_tween()
	tween.tween_property(_material, "albedo_color", Color.WHITE, FLASH_TIME * 0.3)
	tween.tween_property(_material, "albedo_color", _base_color, FLASH_TIME)
