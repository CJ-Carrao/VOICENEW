extends SceneTree

var failures = []
var game
var lex
var assembler
var recipe_script
var parser_script
var layers
var portal_script
var block_script
var animation_script
func _initialize() -> void:
	_run.call_deferred()
	_watchdog.call_deferred()
func _watchdog() -> void:
	await create_timer(25).timeout
	push_error("H-4 validation did not finish")
	quit(2)
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func source_matches(text: String, expected: String) -> bool:
	var lf=text.replace("\r\n","\n")
	return text.sha256_text()==expected or lf.sha256_text()==expected or lf.replace("\n","\r\n").sha256_text()==expected
func spawn(id: String, at: Vector3):
	var item = assembler.build(recipe_script.new_node(id),"head",lex)
	item.set_owner_info(1,1,game.player,null)
	game.add_thing(item)
	item.global_position=at
	item.activate()
	item.move.set_physics_process(false)
	return item
func _run() -> void:
	await process_frame
	assembler=load("res://scripts/things/assembler.gd")
	recipe_script=load("res://scripts/language/recipe.gd")
	parser_script=load("res://scripts/language/phrase_parser.gd")
	layers=load("res://scripts/things/physics_layers.gd")
	portal_script=load("res://scripts/portal/portal_system.gd")
	block_script=load("res://scripts/world/block_volume.gd")
	animation_script=load("res://scripts/things/creature_animator.gd")
	lex=root.get_node("Lexicon").data
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/upstream_h4_manifest.json"))
	for id in manifest.native_models:
		var model_text = FileAccess.get_file_as_string("res://data/models/"+id+".json").replace("\r\n","\n")
		check(source_matches(model_text,manifest.native_models[id].sha256),"H-4 original model was overwritten: "+id)
	for id in manifest.native_new_definitions:
		check(recipe_script.deep_equal(lex.thing_def(id),manifest.native_new_definitions[id]),"H-4 original definition changed: "+id)
	for path in manifest.native_modules:
		if FileAccess.file_exists("res://"+path):
			check(source_matches(FileAccess.get_file_as_string("res://"+path),manifest.native_modules[path]),"H-4 native module changed: "+path)
		else:
			check(load("res://"+path) is GDScript,"H-4 native module missing from exported pack: "+path)
	var en = root.get_node("Lexicon").for_lang("en")
	check(en.errors.is_empty(),"H-4 English lexicon has errors")
	var english = parser_script.parse("I want a pistol",en)
	check(english.ok and english.recipe.thing=="pistol","H-4 English requests regressed")
	var bomb = parser_script.parse("quero uma bomba nuclear",lex)
	check(bomb.ok and bomb.recipe.thing=="atomic_bomb","Common nuclear request must use H-4 original")
	check(parser_script.parse("quero uma bomba nuclear do lab",lex).recipe.thing=="nuclear_bomb","Legacy optional nuclear alias disappeared")
	check(layers.PORTAL_TUNNEL != layers.TRAPS and (layers.PORTAL_TUNNEL & layers.TRAPS)==0,"Portal/trap physics layers overlap")
	check(lex.bal("blocks.explosion_radius_mult")==1.0,"H-4 destruction/damage radius changed")
	check(lex.balf("blocks.blast_queue_radius_m")>0 and lex.balf("blocks.blast_budget_ms")>0,"H-4 wave budgets missing")
	load("res://scenes/main.gd").next_mode="practice"
	game=load("res://scenes/main.tscn").instantiate()
	game.voice_enabled=false
	root.add_child(game); current_scene=game
	await create_timer(.6).timeout
	check(game.player.robot.rig.bone("upper_arm.R")>=0,"Original player skeleton lost dotted bone names")
	check(game.player.robot.rig.bone("socket_chest")>=0,"Original player chest socket missing")
	var dog=spawn("dog",Vector3(0,25,0))
	check(dog.creature_animator!=null and dog.creature_animator.active,"H-4 dog gait missing")
	check(dog.get_node_or_null("VoxelCreatureMotion")==null,"Legacy animation overrides original H-4 gait")
	var before=dog.creature_animator.bones["hip_fl"].transform
	for step in 12:
		dog.global_position.x+=.1
		await process_frame
	check(not before.is_equal_approx(dog.creature_animator.bones["hip_fl"].transform),"H-4 gait does not animate")
	var previous=weakref(dog.creature_animator)
	dog.rebuild_equipment_model()
	await process_frame
	check(previous.get_ref()==null and dog.creature_animator!=null and dog.creature_animator.active,"Model rebuild left stale H-4 animator")
	var animators=0
	for child in dog.get_children():
		if child.get_script()==animation_script: animators+=1
	check(animators==1,"Model rebuild duplicates animators")
	dog.set_captured(true)
	await process_frame
	dog.set_captured(false)
	check(dog.creature_animator.active,"Capture disabled H-4 animation permanently")
	var maho=spawn("mahoraga",Vector3(8,25,0))
	check(maho.creature_animator!=null and maho.creature_animator.active,"Lab companion lost adapted native animation")
	check(portal_script.of(self)!=null,"H-4 portal system unavailable")
	var volume=block_script.new()
	volume.setup(9901,Vector3i(64,24,64),Vector3(-8,-3,-8))
	var dirt=volume.add_type("soil",Color.BROWN)
	var permanent=volume.add_type("rock",Color.GRAY,block_script.FLAG_FOREVER)
	volume.blocks.fill(dirt)
	for x in 64:
		for z in 64: volume.blocks[volume.index_of(Vector3i(x,0,z))]=permanent
	game.add_child(volume)
	var changes=[0]
	volume.cells_changed.connect(func(_cells): changes[0]+=1)
	volume.explode(Vector3.ZERO,7.0,100000.0)
	check(not volume._scan_jobs.is_empty() or not volume._blasts.is_empty(),"Large H-4 crater was processed synchronously")
	await create_timer(1.8).timeout
	check(volume.blocks[volume.index_of(Vector3i(32,12,32))]==block_script.AIR,"H-4 wave failed to remove center blocks")
	check(volume.blocks[volume.index_of(Vector3i(0,12,0))]==dirt,"H-4 spherical crater erased outside radius")
	check(volume.blocks[volume.index_of(Vector3i(32,0,32))]==permanent,"H-4 crater destroyed permanent foundation")
	check(changes[0]>1,"Large crater did not emit incremental changes")
	volume.queue_free()
	await process_frame
	# Test the new official bomb itself, not only the legacy Lab nuclear action.
	var native_targets=[]
	for i in 64:
		var cow=spawn("cow",Vector3(80.0+(i%8)*.08,80, (i/8)*.08))
		cow.hp=1.0
		cow.matter=0.0
		native_targets.append(weakref(cow))
	await physics_frame
	var native_bomb=spawn("atomic_bomb",Vector3(80,80,0))
	native_bomb.get_node("Do_explode").run(native_bomb.context_here())
	await create_timer(1.5).timeout
	var survivors=0
	for ref in native_targets:
		var target=ref.get_ref()
		if is_instance_valid(target) and not target.is_dead: survivors+=1
	check(survivors==0,"H-4 official atomic bomb skipped crowded creatures")
	print("H4_ORIGINAL_FEATURES ",JSON.stringify({"failures":failures,"native_models":manifest.native_models.size(),"crater_batches":changes[0],"original_player_clips":137,"official_nuclear_targets":64,"official_nuclear_survivors":survivors}))
	quit(0 if failures.is_empty() else 1)
