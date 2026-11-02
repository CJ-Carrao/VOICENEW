extends SceneTree
var failures=[]
var game
var lex
var assembler
var recipes
func _initialize():
 _run.call_deferred()
func check(ok, message):
 if not ok: failures.append(message); push_error(message)
func spawn(id, at, team=2):
 var item=assembler.build(recipes.new_node(id),"head",lex)
 item.set_owner_info(1,team,game.player,null)
 game.add_thing(item)
 item.global_position=at
 item.activate()
 item.set_physics_process(false)
 item.move.set_physics_process(false)
 return item
func _run():
 await process_frame
 load("res://scenes/main.gd").next_mode="practice"
 game=load("res://scenes/main.tscn").instantiate()
 game.voice_enabled=false
 root.add_child(game); current_scene=game
 lex=root.get_node("Lexicon").data
 assembler=load("res://scripts/things/assembler.gd")
 recipes=load("res://scripts/language/recipe.gd")
 await create_timer(.5).timeout
 var model_count=0
 for id in lex.models:
  var data=lex.models[id]
  if not data.has("lab_h4_base") or lex.thing_def(id).get("category", "") != "projectile":continue
  var item=spawn(id,Vector3(100,100,0),1)
  check(item.model_pieces.size()>5,"Refreshed model did not build: "+id)
  check(item.bounds.size.length()>0,"Refreshed model lost collision bounds: "+id)
  item.remove();model_count+=1
 check(model_count==26,"Missing updated bomb/grenade models")
 var reports=[]
 for mode in ["neutron","storm","frost","gravity"]:
  var targets=[]
  for i in 150:
   var cow=spawn("cow",Vector3((i%10)*.03,80,(i/10)*.03))
   cow.hp=50 if mode=="neutron" else 1
   cow.matter=0
   targets.append(weakref(cow))
  var ally=spawn("cow",Vector3(0,80,0),1)
  var outsider=spawn("cow",Vector3(40,80,0))
  var bomb=spawn(mode+"_bomb",Vector3(0,80,0),1)
  await physics_frame
  var found=load("res://scripts/things/combat.gd").in_radius(bomb,bomb.center(),9)
  var counted=0
  for ref in targets:
   if found.has(ref.get_ref()):counted+=1
  check(counted==150,"Crowded field missed targets: "+mode+" "+str(counted))
  bomb.get_node("Do_anomaly").run(bomb.context_here())
  await create_timer(6 if mode=="gravity" else 3).timeout
  var survivors=0
  for ref in targets:
   var cow=ref.get_ref()
   if is_instance_valid(cow) and not cow.is_dead:survivors+=1
  check(survivors==0,"Special bomb skipped crowd: "+mode+" "+str(survivors))
  check(is_instance_valid(ally) and not ally.is_dead,"Special effect damaged ally: "+mode)
  check(is_instance_valid(outsider) and not outsider.is_dead,"Special effect exceeded radius: "+mode)
  if is_instance_valid(ally):ally.remove()
  if is_instance_valid(outsider):outsider.remove()
  reports.append({"mode":mode,"targets":150,"survivors":survivors})
 var ant=spawn("ant",Vector3(0,60,0))
 var motion=ant.creature_animator
 check(motion!=null,"Extra creature animation missing")
 if motion!=null:
  ant.set_captured(true)
  var before=motion.age
  motion._process(.1)
  check(motion.age==before,"Captured extra creature kept animating")
  ant.set_captured(false)
  motion._process(.1)
  check(motion.age>before,"Extra creature did not resume animation")
 print("H4_LAB_REFRESH ",JSON.stringify({"failures":failures,"models":model_count,"crowds":reports}))
 quit(0 if failures.is_empty() else 1)
