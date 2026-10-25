class_name JujutsuRules
extends RefCounted

const KEYS := ["adaptation", "infinity", "cleave", "contact_cleave", "world_cut", "fuga", "black_flash", "reverse", "shrine", "void", "simple_domain", "amplification", "blue", "red", "purple", "ryu_beam", "yuta_beam"]

static func powers(node: Dictionary, lex: LexiconData) -> Dictionary:
	var out: Dictionary = lex.thing_def(String(node.get("thing", ""))).get("jujutsu", {}).duplicate()
	for donor in load("res://scripts/things/fusion_rules.gd").donors(node,lex):
		out.merge(lex.thing_def(donor).get("jujutsu",{}))
	for key in KEYS:
		if node.get("mods", {}).get("jj_" + key, false): out[key] = true
	return out

static func of(source: Thing):
	var cursor := source
	var seen := {}
	while is_instance_valid(cursor) and not seen.has(cursor.get_instance_id()):
		seen[cursor.get_instance_id()] = true
		var component = cursor.get_node_or_null("Jujutsu")
		if component != null: return component
		var parent: Variant = cursor.mount_host if is_instance_valid(cursor.mount_host) else cursor.spawner
		cursor = parent as Thing if is_instance_valid(parent) else null
	return null

static func field(target: Object, key: String):
	if not is_instance_valid(target) or not target is Node or not target.is_inside_tree(): return null
	for component in target.get_tree().get_nodes_in_group("jujutsu_users"):
		if component.enabled(key) and component.protects(target): return component
	return null

static func bypasses(source: Thing, kind: String) -> bool:
	if kind in ["world_cut", "domain_slash", "domain_void"]: return true
	var user = of(source)
	return user != null and (user.adapted("infinity") or user.enabled("amplification"))

static func damage(target: Object, amount: float, kind: String, source: Thing) -> float:
	var barrier = field(target, "infinity")
	var attacker = of(source)
	if barrier != null and not bypasses(source, kind):
		if attacker != null: attacker.observe("infinity")
		barrier.feedback("infinity", Color("a3eaff"))
		return 0.0
	if kind in ["domain_slash", "domain_void"]:
		var defense = field(target, "simple_domain")
		if defense != null:
			defense.feedback("simple_domain", Color("f5dda1"))
			return amount * 0.15
	var defender = field(target, "adaptation")
	if defender != null:
		var factor: float = defender.resistance(kind)
		defender.observe(kind)
		return amount * factor
	return amount

static func force(target: Node3D, source: Thing) -> float:
	if field(target, "infinity") != null and not bypasses(source, "gravity"): return 0.0
	var defender = field(target, "adaptation")
	if defender != null:
		var factor: float = defender.resistance("gravity")
		defender.observe("gravity")
		return factor
	return 1.0

static func candidates(tree: SceneTree) -> Array:
	var out := tree.get_nodes_in_group(Combat.COMBATANTS_GROUP)
	if Forge.world != null: out.append_array(Forge.world.get_node("Things").get_children())
	return out
