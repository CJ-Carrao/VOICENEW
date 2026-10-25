extends RefCounted

static func alive(user: Object) -> bool:
	return is_instance_valid(user) and is_instance_valid(user.thing) and user.thing.is_active and not user.thing.is_dead and not user.thing.is_captured and user.domain_until > user.clock and health(user) > 0.0
static func health(user: Node) -> float:
	var caster = user.domain_caster.get_ref() if user.domain_caster != null else user.thing
	if not is_instance_valid(caster): return 0.0
	return maxf(0.0, float(caster.health if caster is Player else caster.hp))
static func strength(user: Node) -> float:
	var fraction := clampf(health(user) / maxf(user.domain_start_health, 1.0), 0.0, 1.0)
	return clampf(user.thing.power, .5, 2.0) * (.35 + .65 * fraction)
static func update(user: Node) -> void:
	var peer = user.domain_peer.get_ref() if user.domain_peer != null else null
	if not alive(user):
		if user.domain_until > user.clock: user.cancel_domain("lost")
		return
	if peer != null and (not alive(peer) or user.domain_origin.distance_to(peer.domain_origin) >= 18.0):
		user.domain_peer = null
		user.domain_clashing = false
		peer = null
	if peer == null:
		user.domain_clashing = false
		for other in user.get_tree().get_nodes_in_group("jujutsu_users"):
			if other == user or not alive(other) or other.thing.team == user.thing.team or user.domain_origin.distance_to(other.domain_origin) >= 18.0: continue
			if other.domain_peer != null and other.domain_peer.get_ref() != user: continue
			peer = other
			user.domain_peer = weakref(peer)
			peer.domain_peer = weakref(user)
			user.clash_elapsed = 0.0
			peer.clash_elapsed = 0.0
			user.clash_pressure = 0.0
			peer.clash_pressure = 0.0
			user.clash_last_clock = user.clock
			peer.clash_last_clock = peer.clock
			user.clash_point = (user.domain_origin + peer.domain_origin) * .5
			peer.clash_point = user.clash_point
			var axis: Vector3 = peer.center() - user.center()
			if axis.length_squared() < .01: axis = Vector3.RIGHT
			user.clash_axis = axis.normalized()
			peer.clash_axis = -user.clash_axis
			# Ensure one complete, bounded contest even when countered near expiry.
			user.domain_until = maxf(user.domain_until, user.clock + 3.2)
			peer.domain_until = maxf(peer.domain_until, peer.clock + 3.2)
			break
	if peer == null: return
	user.domain_clashing = true
	peer.domain_clashing = true
	if user.get_instance_id() > peer.get_instance_id(): return
	var delta := clampf(user.clock - user.clash_last_clock, 0.0, .3)
	user.clash_last_clock = user.clock
	user.clash_elapsed += delta
	peer.clash_elapsed = user.clash_elapsed
	user.clash_pressure = clampf(user.clash_pressure + (strength(user) - strength(peer)) * delta * .9, -1.0, 1.0)
	peer.clash_pressure = -user.clash_pressure
	if health(user) < user.domain_start_health * .55:
		user.cancel_domain("lost")
		peer.domain_clashing = false
		peer.domain_peer = null
		peer.domain_outcome = "won"
		return
	if health(peer) < peer.domain_start_health * .55:
		peer.cancel_domain("lost")
		user.domain_clashing = false
		user.domain_peer = null
		user.domain_outcome = "won"
		return
	if user.clash_elapsed < 3.0: return
	if absf(user.clash_pressure) < .12:
		user.cancel_domain("tie")
		peer.cancel_domain("tie")
	else:
		var winner: Node = user if user.clash_pressure > 0 else peer
		var loser: Node = peer if winner == user else user
		loser.cancel_domain("lost")
		winner.domain_clashing = false
		winner.domain_peer = null
		winner.domain_outcome = "won"
		winner.domain_until = maxf(winner.domain_until, winner.clock + 1.5)

static func contested(user: Node, at: Vector3) -> bool:
	for peer in user.get_tree().get_nodes_in_group("jujutsu_users"):
		if peer != user and alive(peer) and peer.thing.team != user.thing.team and peer.domain_origin.distance_to(at) < 9.0: return true
	return false
