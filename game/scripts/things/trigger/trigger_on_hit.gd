class_name TriggerOnHit
extends ThingTrigger



func activate() -> void :
	thing.hit.connect(fire)
