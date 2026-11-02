extends SceneTree

func _initialize() -> void:
	var native = load("res://assets/characters/lavoice/LAVOICE_base.native.scn") as PackedScene
	if native == null:
		quit(1)
		return
	var model = native.instantiate()
	var skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var animator = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var names = []
	for bone in skeleton.get_bone_count(): names.append(skeleton.get_bone_name(bone))
	var good = skeleton.find_bone("upper_arm.R") >= 0 and skeleton.find_bone("socket_chest") >= 0 and animator.get_animation_list().size() >= 137
	print("H4_NATIVE_RIG ", JSON.stringify({"bones": names, "clips": animator.get_animation_list().size(), "ok":good}))
	model.free()
	quit(0 if good else 1)
