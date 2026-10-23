class_name TriggerNearEnemy
extends ThingTrigger



var _cooldown: float = 0.0
var _cooldown_time: float = 0.0
var _active: bool = false


func activate() -> void :
	_cooldown_time = Lexicon.balf("triggers.near_enemy_cooldown_s")
	_active = true


func _physics_process(delta: float) -> void :
	if not thing.has_simulation_authority():
		return
	if not _active or thing.is_held or thing.is_dead:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var from: = thing.center()
	var enemy: = Combat.nearest_enemy(from, thing.team, get_tree())
	if enemy != null and Combat.center_of(enemy).distance_to(from) <= param("r", 3.0):
		_cooldown = _cooldown_time
		fire(ActionContext.make(from, Combat.center_of(enemy) - from, enemy))
