class_name TriggerOnFire
extends ThingTrigger



func activate() -> void :
	thing.fired.connect(fire)
