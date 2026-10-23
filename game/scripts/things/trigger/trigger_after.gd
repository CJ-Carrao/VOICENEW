class_name TriggerAfter
extends ThingTrigger


var _timer: Timer


func activate() -> void :
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = maxf(param("s", 1.0), TriggerEvery.MIN_INTERVAL)
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	_timer.start()


func _on_timeout() -> void :
	fire(thing.context_here())
