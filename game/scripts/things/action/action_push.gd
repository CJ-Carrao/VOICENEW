class_name ActionPush
extends ThingAction



const KEY: = "push"

const DIRECTION: = 1.0


func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	var profile: Dictionary = Lexicon.bal("actions.impulse_profiles." + String(spec.get("profile", "")), {})
	if bool(spec.get("contact", false)) and not profile.is_empty():
		var target: = ctx.target
		if not is_instance_valid(target):
			return
		if not bool(profile.get("affects_own_team", false)) and not Combat.affects(thing, target):
			return
		if bool(profile.get("above_only", false)) and Combat.center_of(target).y <= thing.center().y:
			return
		var values: Array = profile.get("direction", [0, 1, 0])
		var impulse: = Vector3(float(values[0]), float(values[1]), float(values[2])).normalized() * float(profile.get("strength", 0.0))
		if target.has_method("apply_knockback"):
			target.call("apply_knockback", impulse)
		elif target is Thing:
			(target as Thing).nudge(impulse)
		return
	var cfg: = "actions.%s." % _key()
	Combat.impulse(thing, ctx.point, Lexicon.balf(cfg + "radius") * thing.scale_factor, 
		Lexicon.balf(cfg + "strength") * _direction(), Lexicon.balf(cfg + "lift"))


func _key() -> String:
	return KEY


func _direction() -> float:
	return DIRECTION
