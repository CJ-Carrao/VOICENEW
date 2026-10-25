extends Node

var phase = "idle"
var accepted: Array[int] = []
var members: Array[int] = []
var boss_ref: WeakRef
var elapsed = 0.0
var cooldown = 0.0
var network_tick = 0.0
var message = ""
var paid = false
var caption: Label

static func of(world: Node) -> Node:
	return world.get_node_or_null("CoopEncounter") if is_instance_valid(world) else null
static func ensure(world: Node) -> Node:
	var found = of(world)
	if found != null: return found
	var encounter = load("res://scripts/things/coop_encounter.gd").new()
	encounter.name = "CoopEncounter"
	world.add_child(encounter)
	return encounter
static func allied(a: int, b: int) -> bool:
	var encounter = of(Forge.world)
	return encounter != null and encounter.phase == "battle" and encounter.members.has(a) and encounter.members.has(b)
static func request(player: Player, action: String) -> Dictionary:
	var encounter = ensure(Forge.world)
	if action == "status": return {"warnings":[encounter.message if not encounter.message.is_empty() else "Diga desafio cooperativo para convidar. Cada jogador deve aceitar desafio. Custo total: 300 de matéria do iniciador."]}
	if action == "cancel":
		if encounter.phase == "waiting" and encounter.accepted.has(player.player_id): encounter.finish("cancelled","Convite cancelado.")
		return {"warnings":[encounter.message]}
	if encounter.phase == "battle" or encounter.cooldown > 0: return {"blocked":true,"warnings":["Desafio em andamento ou recarregando por %.0f s." % encounter.cooldown]}
	if action == "invite":
		if encounter.phase != "waiting":
			encounter.accepted.clear()
			encounter.phase = "waiting"
			encounter.elapsed = 0.0
			encounter.message = "Desafio: T-Rex alado adaptativo. Cada jogador diga aceitar desafio; o iniciador paga 300 de matéria."
			encounter.accepted.append(player.player_id)
	elif encounter.phase == "waiting" and not encounter.accepted.has(player.player_id): encounter.accepted.append(player.player_id)
	if encounter.phase != "waiting": return {"blocked":true,"warnings":["Primeiro diga desafio cooperativo."]}
	var players = encounter.connected_players()
	var ready = not players.is_empty()
	for fighter in players:
		if not encounter.accepted.has(fighter.player_id) or not fighter.is_alive(): ready = false
	if ready:
		var reply: Dictionary = encounter.begin(players)
		if reply.get("blocked",false): return reply
	return {"warnings":[encounter.message]}
func connected_players() -> Array:
	var players = []
	for player in get_parent().get_players():
		if Session.is_online():
			if Session.peer_for_player(player.player_id) <= 0: continue
		elif player != get_parent().player: continue
		players.append(player)
	return players
func begin(players: Array) -> Dictionary:
	var initiator = get_parent().get_player(accepted[0])
	if not is_instance_valid(initiator) or initiator.matter_spendable() < 300.0: return {"blocked":true,"warnings":["O iniciador precisa de 300 de matéria para o chefe."]}
	var forge = get_node("/root/Forge")
	var source = initiator.hands.current_item()
	var temporary = false
	if source == null:
		source = Assembler.build(Recipe.new_node("pistol"),"head",Lexicon.data)
		get_parent().add_thing(source)
		source.set_owner_info(initiator.player_id,initiator.team,initiator,null)
		temporary = true
	var ray: Dictionary = initiator.look_ray()
	var at: Vector3 = forge.ground_point(initiator.global_position+Gravity.flat(ray.direction,initiator.up_direction).normalized()*12.0)
	var boss = forge.spawn_child(Recipe.new_node("coop_chimera"),"spawned",at+Vector3.UP*2.0,Vector3.FORWARD,source,0.0)
	if temporary: source.remove()
	if boss == null: return {"blocked":true,"warnings":["Aguarde espaço para invocar o chefe."]}
	if not initiator.try_spend(300.0): boss.remove(); return {"blocked":true,"warnings":["Matéria insuficiente."]}
	members.clear()
	for player in players: members.append(player.player_id)
	forge.transfer_neutral(boss,99)
	boss.matter = 0.0
	boss.matter_returns = false
	boss.max_hp = 600.0+350.0*(players.size()-1)
	boss.hp = boss.max_hp
	boss.get_node("CoopBoss").damage_scale = 1.0+.15*(players.size()-1)
	boss_ref = weakref(boss)
	phase = "battle"
	paid = false
	elapsed = 0.0
	message = "COOP · derrotem a Quimera Adaptativa · aliados protegidos · 180 s"
	return {"coop_started":true}
func finish(result: String, text: String) -> void:
	if phase == "battle" and result == "victory" and not paid:
		paid = true
		for id in members:
			var player = get_parent().get_player(id)
			if is_instance_valid(player): player.store_or_spill(120.0)
	phase = result
	message = text
	cooldown = 60.0 if result != "cancelled" else 0.0
	var boss = boss_ref.get_ref() if boss_ref != null else null
	if is_instance_valid(boss) and not boss.is_dead: boss.remove()
	boss_ref = null
	if Session.is_online() and get_parent().has_method("_resolve_elimination"): get_parent().call_deferred("_resolve_elimination",get_parent().get("_epoch"))
	send_state()
func _physics_process(delta: float) -> void:
	if not Session.has_authority(): return
	cooldown = maxf(0.0,cooldown-delta)
	elapsed += delta
	if phase == "waiting" and elapsed > 30.0: finish("cancelled","O convite expirou.")
	if phase == "battle":
		var players = connected_players()
		var connected = []
		var alive = 0
		for player in players:
			connected.append(player.player_id)
			if members.has(player.player_id) and player.is_alive(): alive += 1
		for id in members:
			if not connected.has(id): finish("cancelled","Desafio cancelado: jogador desconectado."); return
		var boss = boss_ref.get_ref() if boss_ref != null else null
		if alive == 0: finish("defeat","Derrota · ninguém sobreviveu ao chefe.")
		elif not is_instance_valid(boss) or boss.is_dead: finish("victory","Vitória cooperativa · +120 de matéria por jogador!")
		elif elapsed >= 180.0: finish("defeat","Tempo esgotado no desafio.")
	network_tick -= delta
	if network_tick <= 0.0: network_tick = .5; send_state()
func snapshot() -> Dictionary: return {"phase":phase,"members":members,"message":message,"cooldown":cooldown}
func apply_snapshot(data: Dictionary) -> void:
	phase = String(data.get("phase","idle"))
	members.assign(data.get("members",[]))
	message = String(data.get("message",""))
	cooldown = float(data.get("cooldown",0.0))
func send_state() -> void:
	if Session.is_online() and Session.has_authority(): Session.creations.notify_fx("coop_state",[snapshot()])
func _process(_delta: float) -> void:
	if caption == null:
		var canvas = CanvasLayer.new()
		add_child(canvas)
		caption = Label.new()
		caption.position = Vector2(20,105)
		caption.add_theme_color_override("font_color",Color("eed3ab"))
		canvas.add_child(caption)
	caption.text = message
	caption.visible = phase in ["waiting","battle"] or cooldown > 50.0
