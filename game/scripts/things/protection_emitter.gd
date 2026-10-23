extends Node

var profile_id := "blast"
var radius := 3.5
var last_feedback_ms := -1000


func _ready() -> void:
	add_to_group("protective_fields")


func feedback() -> void:
	if Time.get_ticks_msec() - last_feedback_ms < 200:
		return
	last_feedback_ms = Time.get_ticks_msec()
	var shield := get_parent() as Thing
	if shield != null and shield.is_inside_tree():
		ExpansionFx.burst(Forge.fx_root(shield), shield.center(), 1.2, Color("8cc8cf"), "shield")
