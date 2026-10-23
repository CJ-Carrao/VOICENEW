class_name NetworkThingEntry
extends Node



var descriptor: Dictionary = {}
var thing: Thing
var replica: bool = false


func _exit_tree() -> void :

	if replica and is_instance_valid(thing):
		if not thing.is_dead:
			thing.is_dead = true
			thing.removed.emit(thing)
		thing.queue_free()
