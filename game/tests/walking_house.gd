extends SceneTree
var failures := []
var evidence := []
func _initialize():
 call_deferred("run")
func check(ok: bool, message: String):
 if not ok:
  failures.append(message)
  push_error(message)
func run():
 await process_frame
 load("res://scenes/main.gd").next_mode = "practice"
 var game = load("res://scenes/main.tscn").instantiate()
 game.voice_enabled = false
 root.add_child(game)
 current_scene = game
 await create_timer(.5).timeout
 var lex = root.get_node("Lexicon").data
 var parser = load("res://scripts/language/phrase_parser.gd")
 var assembler = load("res://scripts/things/assembler.gd")
 var floor_body = StaticBody3D.new()
 var floor_shape = CollisionShape3D.new()
 var floor_box = BoxShape3D.new()
 floor_box.size = Vector3(40, 1, 40)
 floor_shape.shape = floor_box
 floor_body.add_child(floor_shape)
 game.add_child(floor_body)
 floor_body.global_position = Vector3(0,39.5,0)
 var item
 for phrase in ["quero uma casa ambulante", "quero casa ambulante", "quero uma casa que anda", "quero uma casa ambulante anti bomba de neutrons", "quero uma casa andante", "quero uma casa que caminha", "quero uma casa com pernas"]:
  var result = parser.parse(phrase, lex)
  check(result.get("ok",false) and result.recipe.thing == "walking_house", "Wrong walking model: " + phrase)
  item = assembler.build(result.recipe, "head", lex)
  item.set_owner_info(1,1,game.player,game.player)
  game.add_thing(item)
  item.global_position = Vector3(0,40,0)
  item.activate()
  var start = item.global_position
  for step in 45: await physics_frame
  var horizontal = Vector2(item.global_position.x-start.x,item.global_position.z-start.z).length()
  check(horizontal > 0.4, "House did not stroll: " + phrase)
  check(item.get_node("VoxelCreatureMotion").parts.size() >= 4, "House has no animated legs")
  evidence.append({"phrase":phrase,"horizontal_m":horizontal})
  item.remove()
  await process_frame
 # A full-height wall must make the house turn and continue, not pin it in place.
 var wall = StaticBody3D.new()
 var wall_shape = CollisionShape3D.new()
 var wall_box = BoxShape3D.new()
 wall_box.size = Vector3(12,8,.5)
 wall_shape.shape = wall_box
 wall.add_child(wall_shape)
 game.add_child(wall)
 wall.global_position = Vector3(0,43,-3)
 item = assembler.build(parser.parse("quero uma casa ambulante",lex).recipe,"head",lex)
 item.set_owner_info(1,1,game.player,game.player)
 game.add_thing(item)
 item.global_position=Vector3(0,40,0)
 item.activate()
 var reversed := false
 for step in 180:
  await physics_frame
  if item.move.heading.z > 0.1: reversed = true
 check(reversed and item.global_position.z > -1.0,"House did not turn away from wall")
 item.remove()
 wall.queue_free()
 floor_body.queue_free()
 await process_frame
 # Exercise the real request, assembly completion and activation path too.
 var forge = root.get_node("Forge")
 forge.test_free_matter = true
 forge.test_instant_builds = true
 forge.request(1,"quero uma casa ambulante")
 var deadline := Time.get_ticks_msec() + 5000
 item = null
 while Time.get_ticks_msec() < deadline:
  for built in game.get_node("Things").get_children():
   if built.thing_id == "walking_house" and not built.is_dead: item = built
  if item != null and item.is_active and not item.is_building: break
  await create_timer(.05).timeout
 check(item != null and item.is_active and not item.is_building,"Requested house did not finish/activate")
 if item != null:
  var start = item.global_position
  for step in 75: await physics_frame
  var distance = Vector2(item.global_position.x-start.x,item.global_position.z-start.z).length()
  check(distance > .3,"House built from request stayed still")
  evidence.append({"real_request_distance_m":distance})
 var normal = assembler.build(parser.parse("quero uma casa",lex).recipe,"head",lex)
 check(normal.thing_id == "house" and normal.move.get_script().resource_path.ends_with("move_static.gd"),"Ordinary house changed")
 normal.free()
 var report = {"failures":failures,"evidence":evidence}
 var file=FileAccess.open(ProjectSettings.globalize_path("res://").path_join("../analysis/walking-house.json").simplify_path(),FileAccess.WRITE)
 file.store_string(JSON.stringify(report,"  "))
 print("WALKING_HOUSE ",JSON.stringify(report))
 quit(0 if failures.is_empty() else 1)
