class_name TriggerOnCommand
extends ThingTrigger




func activate() -> void :
	thing.commanded.connect(fire)
