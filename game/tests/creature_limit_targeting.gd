extends SceneTree
var failures=[]
var game
var forge
var lex
var recipes
var assembler
var parser
func _initialize():_run.call_deferred()
func check(ok,message):
 if not ok:failures.append(message);push_error(message)
func spawn(id,owner=1,mods={}):
 var tree=recipes.new_node(id);tree.mods.merge(mods,true)
 var body=assembler.build(tree,"head",lex)
 body.set_owner_info(owner,owner,game.get_player(owner),null)
 game.add_thing(body);body.global_position=Vector3(0,80,0)
 forge._register(body);body.activate();body.set_physics_process(false);body.move.set_physics_process(false)
 return body
func _run():
 await process_frame
 load("res://scenes/main.gd").next_mode="practice"
 game=load("res://scenes/main.tscn").instantiate();game.voice_enabled=false
 root.add_child(game);current_scene=game
 forge=root.get_node("Forge");lex=root.get_node("Lexicon").data
 recipes=load("res://scripts/language/recipe.gd");assembler=load("res://scripts/things/assembler.gd");parser=load("res://scripts/language/phrase_parser.gd")
 var limit=load("res://scripts/things/creature_limit.gd")
 var rules=load("res://scripts/things/innovation_rules.gd")
 await create_timer(.4).timeout
 game.player.frozen=false;game.player.set_physics_process(false);game.player.global_position=Vector3(0,80,8)
 game.opponent.set_physics_process(false);game.opponent.global_position=Vector3(0,80,-8)
 var animals=[]
 for n in 30:animals.append(spawn("ant"))
 check(limit.count(1)==30,"Population did not reach 30")
 var before=game.player.matter_spendable()
 var denied=forge.request(1,"quero uma formiga",false)
 check(denied.get("blocked",false) and denied.warnings[0].contains("30"),"31st direct creation was not rejected")
 check(game.player.matter_spendable()==before,"Rejected creation charged matter")
 var source=spawn("pistol")
 check(forge.spawn_child(recipes.new_node("cat"),"projectile",Vector3(0,80,0),Vector3.FORWARD,source)==null,"Animal gun exceeded limit")
 check(forge.summon_child(recipes.new_node("ant"),Vector3(0,80,0),Vector3.FORWARD,source)==null,"Nest/summon exceeded limit")
 var stranger=spawn("cat",2)
 check(limit.count(2)==1,"Second owner lost independent population")
 check(not forge.transfer_owner(stranger,game.player),"Ownership transfer exceeded limit")
 var ball=spawn("capture_ball")
 check(not ball.get_node("CaptureBall")._attempt(weakref(stranger),0.0),"Capture exceeded limit")
 check(not stranger.is_dead and not stranger.is_captured and stranger.owner_id==2,"Blocked capture harmed animal")
 animals[0].remove()
 check(limit.count(1)==29,"Death/removal did not free a slot")
 check(not limit.allows(1,{"thing":"ant","mods":{"count":2}},true),"Batch crossed cap")
 check(forge.transfer_owner(stranger,game.player),"Freed slot could not accept transfer")
 check(limit.count(1)==30,"Transferred creature was not counted")
 stranger.set_captured(true)
 check(limit.count(1)==30,"Capture hid a live creature from population")
 stranger.set_captured(false)
 # A projectile without animal payload remains usable at the cap.
 forge.production.reset()
 var bullet=forge.spawn_child(recipes.new_node("grenade"),"projectile",Vector3(0,80,0),Vector3.FORWARD,source)
 check(bullet!=null,"Non-animal weapon blocked by animal limit")
 for item in animals:
  if is_instance_valid(item) and not item.is_dead:item.remove()
 stranger.remove();source.remove();ball.remove()
 if bullet!=null:bullet.remove()
 var parsed_count=0
 for id in lex.defs.things:
  if lex.thing_def(id).get("category","")!="creature" or lex.thing_def(id).get("coop_boss",false):continue
  var name=lex.thing_name(id)
  for number in ["1","dois","3","quatro"]:
   var result=parser.parse("quero um "+name+" que so ataque o jogador "+number,lex)
   check(result.ok and result.recipe.mods.get("target_player",0)=={"1":1,"dois":2,"3":3,"quatro":4}[number] and result.unknown_words.is_empty(),"Player target phrase failed: "+id+" "+number)
   parsed_count+=1
 check(not parser.parse("quero um pombo que so ataque o jogador 5",lex).ok,"Invalid player slot accepted")
 var bird=spawn("pigeon",1,{"target_player":2})
 var combat=load("res://scripts/things/combat.gd")
 check(combat.nearest_target(bird,bird.center(),self)==game.opponent,"Creature did not select player 2")
 check(bird.get_node("AnimalOrders").mode=="attack","Player-specific creature did not enter pursuit mode")
 var walking=spawn("dog",1,{"target_player":2})
 walking.get_node("AnimalOrders")._physics_process(1.0)
 check(walking.get_node("AnimalOrders").goal.distance_to(game.opponent.center())<.01,"Creature did not walk toward chosen player")
 walking.remove()
 check(rules.allows_target(bird,game.opponent) and not rules.allows_target(bird,game.player),"Selected player filter ignored")
 var bystander=spawn("cat",2)
 check(not rules.allows_target(bird,bystander),"Selective creature attacked another animal")
 var hp=bystander.hp
 combat.apply_damage(bystander,10,"bite",bird)
 check(bystander.hp==hp,"Selective attack damaged another creature")
 for number in [1,2,3,4]:
  var cmd=parser.parse("pombos ataquem so o jogador "+str(number),lex)
  check(cmd.ok and cmd.recipe.tactics.target_player==number,"Numbered voice order failed")
 game.player.look_at_point(bird.center())
 await physics_frame
 var command=forge.request(1,"pombos ataquem so o jogador 4",false,true)
 check(not command.get("blocked",false) and command.get("animal_count",0)==1,"Group numbered command did not execute")
 check(bird.node_data.mods.target_player==4 and bird.get_node("AnimalOrders").snapshot().target_player==4,"Target order did not persist/replicate")
 check(combat.nearest_target(bird,bird.center(),self)==null,"Absent player caused fallback attack")
 bird.node_data.mods.target_player=2;bird.target_filter="player:2"
 forge.production.reset()
 var child=forge.spawn_child(recipes.new_node("cat"),"projectile",Vector3(0,80,0),Vector3.FORWARD,bird)
 check(child!=null and rules.target_diet(child)=="player:2","Spawned animal lost selected player")
 bird.remove()
 check(child!=null and rules.target_diet(child)=="player:2","Target filter depended on living parent")
 print("CREATURE_LIMIT_TARGETING ",JSON.stringify({"failures":failures,"cap":30,"owners_independent":true,"target_phrases":parsed_count,"players":4}))
 quit(0 if failures.is_empty() else 1)
