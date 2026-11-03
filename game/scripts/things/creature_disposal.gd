extends Node

const GROUP := "creature_disposal_jobs"
var owner_id := 0
var world_ref: WeakRef
var rows: Array = []
var cursor := 0
var explosive := false
var holders: Dictionary = {}
var done := 0
static var totals := {"killed":0,"exploded":0}
static var frame := -1
static var processed := 0

static func blast_size(body: Thing) -> Dictionary:
 var size := body.bounds.size * body.global_basis.get_scale().abs()
 var radius := clampf(size.length() * .9, .75, 8.0)
 return {"radius":radius,"damage":clampf(12.0 * pow(radius,1.15),8.0,130.0)}

static func request(player: Player, settings: Dictionary) -> Dictionary:
 if not Forge.has_gameplay_authority() or not player.can_act(): return {"blocked":true,"warnings":["Você não pode dar ordens agora."]}
 for job in player.get_tree().get_nodes_in_group(GROUP):
  if job.owner_id == player.player_id: return {"blocked":true,"warnings":["Aguarde o comando anterior terminar."]}
 var species := String(settings.get("actor",""))
 var selected: Dictionary = {}
 var places: Dictionary = {}
 var candidates: Array = Forge.live_things(player.player_id).duplicate()
 candidates.append_array(Forge.world.get_node("Things").get_children())
 for candidate in candidates:
  if not candidate is Thing: continue
  var ball = candidate.get_node_or_null("CaptureBall")
  if ball != null and ball.occupant() != null: places[ball.occupant()] = candidate.center()
  for body in CreatureLimit.family(candidate):
   if body.owner_id != player.player_id or body.category != "creature" or body.is_dead or body._def.get("coop_boss",false): continue
   if not species.is_empty() and body.thing_id != species: continue
   selected[body] = true
 if selected.is_empty(): return {"blocked":true,"warnings":["Você não tem animais vivos desse tipo."]}
 var job = load("res://scripts/things/creature_disposal.gd").new()
 job.owner_id = player.player_id
 job.world_ref = weakref(Forge.world)
 job.explosive = settings.action == "detonate"
 # Snapshot and retain every source before a parent death or blast can remove another.
 for body: Thing in selected:
  var size := blast_size(body)
  body.hold_effect_job()
  body.set_meta("disposal_pending",true)
  var parent = body.get_parent()
  while parent is Thing:
   if not job.holders.has(parent):parent.hold_effect_job();job.holders[parent]=true
   parent=parent.get_parent()
  job.rows.append({"body":body,"at":places.get(body,body.center()),"radius":size.radius,"damage":size.damage,"killed":false})
 player.get_tree().root.add_child(job)
 job.add_to_group(GROUP)
 return {"animal_order":settings.action,"animal_count":selected.size(),"warnings":["%d animais seus vão %s." % [selected.size(),"explodir" if job.explosive else "ser eliminados"]]}

func _process(_delta: float) -> void:
 if not is_instance_valid(world_ref.get_ref()) or Forge.world != world_ref.get_ref() or not Forge.has_effect_authority():
  queue_free(); return
 if frame != Engine.get_process_frames():frame = Engine.get_process_frames();processed = 0
 var until := Time.get_ticks_usec()+2000
 while cursor < rows.size() and processed < 2:
  var row: Dictionary = rows[cursor]
  var body = row.body
  if not is_instance_valid(body) or body.owner_id != owner_id:
   _release(row);cursor+=1;continue
  # Deaths and terrain scans are bounded; native H-4 limits pace the detonations.
  if not row.killed:
   row.killed = true
   if explosive:body.explosion_spent = true
   body.die()
   totals.killed += 1
   processed += 1
   if Time.get_ticks_usec() >= until: return
  if explosive:
   if not Forge.explosion_ready(owner_id): return
   Combat.explode(body,row.at,row.radius,row.damage)
   totals.exploded += 1
   processed += 1
  _release(row)
  done += 1
  cursor += 1
  if Time.get_ticks_usec() >= until:break
 if cursor >= rows.size():queue_free()

func _release(row: Dictionary) -> void:
 var body = row.get("body")
 if is_instance_valid(body):
  body.remove_meta("disposal_pending")
  body.release_effect_job()
 row.body = null

func _exit_tree() -> void:
 for row in rows:_release(row)
 for holder in holders:
  if is_instance_valid(holder):holder.release_effect_job()
