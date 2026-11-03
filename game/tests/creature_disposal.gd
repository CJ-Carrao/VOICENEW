extends SceneTree
var failures=[]
var game
var forge
var lex
var parser
var assembler
var recipe
func _initialize():_run.call_deferred()
func check(ok,message):
 if not ok:failures.append(message);push_error(message)
func spawn(id,owner,at,mods={}):
 var tree=recipe.new_node(id);tree.mods.merge(mods,true)
 var body=assembler.build(tree,"head",lex);body.set_owner_info(owner,owner,game.get_player(owner),null)
 game.add_thing(body);body.global_position=at;forge._register(body);body.activate()
 body.set_physics_process(false);body.move.set_physics_process(false)
 return body
func settled():
 var until=Time.get_ticks_msec()+10000
 while not get_nodes_in_group("creature_disposal_jobs").is_empty() and Time.get_ticks_msec()<until:await create_timer(.04).timeout
 check(get_nodes_in_group("creature_disposal_jobs").is_empty(),"Disposal job did not finish")
func _run():
 await process_frame
 load("res://scenes/main.gd").next_mode="practice"
 game=load("res://scenes/main.tscn").instantiate();game.voice_enabled=false;root.add_child(game);current_scene=game
 forge=root.get_node("Forge");lex=root.get_node("Lexicon").data
 parser=load("res://scripts/language/phrase_parser.gd");assembler=load("res://scripts/things/assembler.gd");recipe=load("res://scripts/language/recipe.gd")
 var disposal=load("res://scripts/things/creature_disposal.gd")
 await create_timer(.4).timeout
 game.player.frozen=false;game.player.set_physics_process(false);game.player.global_position=Vector3(0,80,30)
 game.opponent.set_physics_process(false);game.opponent.global_position=Vector3(100,80,30)
 var phrases=0
 for id in lex.defs.things:
  if lex.thing_def(id).get("category","")!="creature" or lex.thing_def(id).get("coop_boss",false):continue
  for phrase in ["mate todos os "+lex.thing_name(id),"quero que todos os "+lex.thing_name(id)+" se explodam"]:
   var result=parser.parse(phrase,lex)
   check(result.ok and result.recipe.get("command","")=="creature_tactics" and result.recipe.tactics.actor==id and result.unknown_words.is_empty(),"Disposal phrase failed: "+phrase)
   phrases+=1
 for phrase in ["mate todos os animais","mate todos meus bichos","quero que todos os meus animais se explodam","quero que todos os elefantes se esplodao"]:
  var result=parser.parse(phrase,lex);check(result.ok and result.recipe.has("command"),"Natural disposal wording failed: "+phrase)
 check(parser.parse("quero uma bomba que mate todos os elefantes",lex).recipe.thing=="species_bomb","Disposal swallowed species bomb creation")
 var a=spawn("elephant",1,Vector3(0,80,0))
 var b=spawn("elephant",1,Vector3(4,80,0))
 var other=spawn("dog",1,Vector3(8,80,0))
 var enemy=spawn("elephant",2,Vector3(100,80,0))
 var result=forge.request(1,"mate todos os elefantes",false,true)
 check(result.get("animal_count",0)==2,"Species kill did not select two owned elephants")
 await settled()
 check((not is_instance_valid(a) or a.is_dead) and (not is_instance_valid(b) or b.is_dead),"Own elephants survived kill")
 check(not other.is_dead and not enemy.is_dead,"Species kill affected wrong owner/species")
 var captured=spawn("cat",1,Vector3(0,80,0));captured.set_captured(true)
 result=forge.request(1,"mate todos os animais",false,true)
 check(result.get("animal_count",0)==2,"All animals omitted captured animal")
 await settled()
 check((not is_instance_valid(other) or other.is_dead) and (not is_instance_valid(captured) or captured.is_dead) and not enemy.is_dead,"All animals crossed ownership")
 var small=spawn("elephant",1,Vector3(0,80,0),{"scale":.5})
 var big=spawn("elephant",1,Vector3(10,80,0),{"scale":2.0})
 var sm=disposal.blast_size(small);var lg=disposal.blast_size(big)
 check(lg.radius>sm.radius and lg.damage>sm.damage and lg.radius<=8,"Explosion does not scale with physical size")
 small.remove();big.remove()
 # Even when the first blast kills the others, every queued source must detonate.
 var targets=[]
 for n in 30:
  var animal=spawn("ant",1,Vector3((n%6)*.03,80,(n/6)*.03))
  animal.hp=1;animal.matter=0;targets.append(weakref(animal))
 var before=disposal.totals.exploded
 result=forge.request(1,"quero que todos os animais se explodam",false,true)
 check(result.get("animal_count",0)==30,"Mass detonation missed animals")
 var repeated=forge.request(1,"mate todos os animais",false,true)
 check(repeated.get("blocked",false),"Concurrent cleanup jobs accepted")
 await settled()
 check(disposal.totals.exploded-before==30,"Native rate limit or early death skipped queued detonations")
 for ref in targets:
  var animal=ref.get_ref()
  check(not is_instance_valid(animal) or animal.is_dead,"Selected animal survived detonation")
 check(not enemy.is_dead,"Detonation command directly killed distant enemy")
 # A retained graft must still explode after its parent was removed by a prior blast.
 var tree=recipe.new_node("dog");tree.mods.grafts=[{"socket":"mount_top","node":recipe.new_node("ant")}]
 var carrier=assembler.build(tree,"head",lex);carrier.set_owner_info(1,1,game.player,null);game.add_thing(carrier);carrier.global_position=Vector3(0,80,0);forge._register(carrier);carrier.activate();carrier.set_physics_process(false);carrier.move.set_physics_process(false)
 before=disposal.totals.exploded
 result=forge.request(1,"quero que todos os animais se explodam",false,true)
 await settled()
 check(result.get("animal_count",0)==2 and disposal.totals.exploded-before==2,"Mounted animal was lost before detonation")
 print("CREATURE_DISPOSAL ",JSON.stringify({"failures":failures,"species_phrases":phrases,"mass_detonations":30,"small_radius":sm.radius,"big_radius":lg.radius,"ownership_preserved":true}))
 quit(0 if failures.is_empty() else 1)
