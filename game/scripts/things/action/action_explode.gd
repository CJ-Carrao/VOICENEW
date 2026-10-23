class_name ActionExplode
extends ThingAction



func run(ctx: ActionContext) -> void :
	if not thing.has_simulation_authority():
		return
	if thing.is_held and thing.melee and not thing.is_dead:
		Combat.explode(thing, ctx.point, thing.explosion_radius * float(Lexicon.bal("material_effects.melee_explosion_radius_mult", 0.6)), thing.explosion_damage)
		return
	if thing.explosion_spent:
		return
	thing.explosion_spent = true
	Combat.explode(thing, thing.center(), thing.explosion_radius, thing.explosion_damage)
	thing.die()
