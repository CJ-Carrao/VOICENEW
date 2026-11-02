extends SceneTree
var failures=[]
var game
var lex
var assembler
var recipe
func _initialize():_run.call_deferred()
func check(ok,message):
 if not ok:failures.append(message);push_error(message)
func spawn(tree,at):
 var body=assembler.build(tree,"head",lex)
 body.set_owner_info(1,1,game.player,null)
 game.add_thing(body);body.global_position=at;body.activate()
 body.set_physics_process(false);body.move.set_physics_process(false)
 return body
func _run():
 await process_frame
 load("res://scenes/main.gd").next_mode="practice"
 game=load("res://scenes/main.tscn").instantiate();game.voice_enabled=false
 root.add_child(game);current_scene=game
 lex=root.get_node("Lexicon").data
 assembler=load("res://scripts/things/assembler.gd");recipe=load("res://scripts/language/recipe.gd")
 var rules=load("res://scripts/things/innovation_rules.gd")
 await create_timer(.3).timeout
 var count=0
 var adapted=0
 for id in lex.defs.things:
  if lex.thing_def(id).get("category","")!="creature":continue
  var item=spawn(recipe.new_node(id),Vector3(0,80,0))
  check(item.creature_animator!=null,"Missing native animation: "+id)
  var anim=item.creature_animator
  if anim!=null:
   count+=1
   if anim.rig.get("lab_adapted",false):adapted+=1
   check(anim.active,"Inactive creature rig: "+id)
   var before={}
   for key in anim.bones:before[key]=anim.bones[key].transform
   for step in 12:
    item.global_position.x+=.06
    anim._process(.04)
   var changed=false
   for key in anim.bones:
    check(anim.bones[key].transform.is_finite(),"Invalid joint: "+id+"/"+key)
    if not anim.bones[key].transform.is_equal_approx(before[key]):changed=true
   check(changed,"Creature does not animate: "+id)
   item.set_captured(true)
   var age=anim.age;anim._process(.1)
   check(anim.age==age,"Captured creature kept animating: "+id)
   item.set_captured(false);anim._process(.1)
   check(anim.age>age,"Released creature lost animation: "+id)
  item.remove()
 var weapons=0
 for id in lex.models:
  var model=lex.models[id]
  if not model.has("lab_h4_base") or lex.thing_def(id).get("category","")!="weapon":continue
  var item=spawn(recipe.new_node(id),Vector3(0,80,0))
  check(item.unsupported.is_empty() and not item.muzzle_points().is_empty(),"Refreshed weapon lost muzzle/grip: "+id)
  weapons+=1;item.remove()
 check(weapons==11,"Missing refreshed weapons")
 for id in ["atomic_bomb","little_boy","fat_man","tsar_bomba"]:
  var bomb=spawn(recipe.new_node(id),Vector3(0,80,0))
  check(rules.threat(bomb,"explosive")=="nuclear","Native bomb bypassed nuclear threat classification: "+id)
  check(rules.multiplier("nuclear","nuclear")<rules.multiplier("blast","nuclear"),"Nuclear defense lost specialization")
  bomb.remove()
 # Geometry from a donor must use destination joints and stay attached, including eyes/feet.
 for tree in [{"thing":"elephant","mods":{"anatomy":{"head":"dog"}}},{"thing":"dog","mods":{"anatomy":{"head":"trex"}}},{"thing":"pikachu","mods":{"anatomy":{"legs":"elephant","wings":"charizard"}}}]:
  var item=spawn(tree,Vector3(0,80,0))
  check(item.creature_animator!=null,"Hybrid lost animation")
  for piece in item.model_pieces:
   check(piece.get_parent()!=item.model,"Hybrid piece detached from rig")
  item.remove()
 # Real protection must recognize native nuclear damage without editing native definitions.
 var defender=spawn(recipe.new_node("cow"),Vector3(40,80,0))
 defender.hp=1000
 var shield=spawn(recipe.new_node("nuclear_shield"),Vector3(40,80,0))
 var nuclear=spawn(recipe.new_node("atomic_bomb"),Vector3(40,80,0))
 nuclear.set_owner_info(2,2,null,null)
 var before_hp=defender.hp
 load("res://scripts/things/combat.gd").apply_damage(defender,100,"explosive",nuclear)
 check(is_equal_approx(before_hp-defender.hp,100*rules.multiplier("nuclear","nuclear")),"Native nuclear blast ignored the matching shield")
 defender.remove();shield.remove();nuclear.remove()
 # Red is a one-shot blast: all targets need damage, not a rotating sixteen-target field.
 var red_targets=[]
 for n in 32:
  var target=spawn(recipe.new_node("cow"),Vector3(80+(n%8)*.03,80,(n/8)*.03))
  target.set_owner_info(2,2,null,null);target.hp=5;target.matter=0
  red_targets.append(weakref(target))
 var red=spawn(recipe.new_node("reversal_red"),Vector3(80,80,0))
 red.get_node("SpatialOrb").elapsed=2
 red.get_node("SpatialOrb")._red(Vector3(80,80,0))
 await create_timer(1.5).timeout
 var red_alive=0
 for ref in red_targets:
  var target=ref.get_ref()
  if is_instance_valid(target) and not target.is_dead:red_alive+=1
 check(red_alive==0,"Red skipped crowded targets: "+str(red_alive))
 # Cuts must intersect rotated structures using world-space bounds.
 var block=load("res://scripts/world/block_volume.gd")
 var volume=block.new()
 volume.setup(9982,Vector3i(4,4,20),Vector3.ZERO)
 var dirt=volume.add_type("soil",Color.BROWN);volume.blocks.fill(dirt)
 game.add_child(volume);volume.position=Vector3(120,80,0);volume.rotation.y=PI/2
 var cell=Vector3i(2,2,16)
 var point=volume.to_global((Vector3(cell)+Vector3.ONE*.5)*volume.size_m)
 var source=spawn(recipe.new_node("rift_knife"),Vector3(120,80,0))
 var cut=load("res://scripts/things/spatial_cut_work.gd").new();cut.setup(source);root.add_child(cut)
 cut.add_segment(point,point,.3)
 await create_timer(.4).timeout
 check(volume.blocks[volume.index_of(cell)]==block.AIR,"Space cut missed rotated structure")
 source.remove();volume.queue_free()
 print("H4_REST_UPGRADE ",JSON.stringify({"failures":failures,"animated_creatures":count,"adapted_rigs":adapted,"weapons":weapons,"nuclear_variants":4,"red_targets":32,"red_survivors":red_alive,"rotated_cut":true}))
 quit(0 if failures.is_empty() else 1)
