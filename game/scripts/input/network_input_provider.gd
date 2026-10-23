class_name NetworkInputProvider
extends PlayerInputProvider
















const MAX_MOVEMENT_QUEUE: = 30
const MAX_EVENT_QUEUE: = 64
const STALE_MS: = 500
const MAX_RESERVE: = 3
const MAX_CATCH_UP: = 3
const CALM_TICKS: = 180

var ack_input: int = 0
var ack_event: int = 0

var counters: Dictionary = {}
var _frames: Dictionary = {}
var _events: Dictionary = {}
var _last: PlayerInputFrame = PlayerInputFrame.new()
var _received_ms: int = 0
var _starved_since_ms: int = 0
var _event_wait_since_ms: int = 0
var _reserve: int = 1
var _calm: int = 0


func submit(frame: PlayerInputFrame) -> bool:
	if frame == null or PlayerInputFrame.from_wire(frame.to_wire()) == null or frame.seq <= ack_input or _frames.has(frame.seq):
		return false
	_frames[frame.seq] = frame.movement_only()
	_received_ms = Time.get_ticks_msec()
	if _frames.size() > MAX_MOVEMENT_QUEUE:
		var keys: = _frames.keys()
		keys.sort()
		_frames.erase(keys[0])
		ack_input = maxi(ack_input, int(keys[0]))
		_count("input_dropped_frames")
	return true


func submit_event(event_seq: int, frame: PlayerInputFrame) -> bool:
	if frame == null or PlayerInputFrame.from_wire(frame.to_wire()) == null or not frame.has_events()\
	or event_seq <= ack_event or _events.has(event_seq) or _events.size() >= MAX_EVENT_QUEUE:
		return false
	var event: = frame.copy()
	event.event_seq = event_seq
	_events[event_seq] = event
	return true



func take_steps(player: Player, limit: int = MAX_CATCH_UP) -> Array[PlayerInputFrame]:
	var steps: Array[PlayerInputFrame] = []
	var now: = Time.get_ticks_msec()
	_skip_lost_frames()
	var ready: = _contiguous()
	if ready == 0:
		if _starved_since_ms == 0:
			_starved_since_ms = now
		if _received_ms > 0:
			_count("input_starved_ticks")
			_reserve = mini(_reserve + 1, MAX_RESERVE)
			_calm = 0
		if now - _starved_since_ms > STALE_MS:
			steps.append(_neutral(player))
			_count("input_neutral_steps")
		return steps
	_starved_since_ms = 0
	_calm += 1
	if _calm >= CALM_TICKS:
		_calm = 0
		_reserve = maxi(_reserve - 1, 0)
	var take: = 1
	if ready > _reserve + 1:
		take = mini(ready - _reserve, maxi(limit, 1))
	for i in take:
		var frame: PlayerInputFrame = _frames[ack_input + 1]
		var event: Variant = _event_for(frame, now)
		if event is bool:
			break
		_frames.erase(ack_input + 1)
		ack_input = frame.seq
		frame = frame.copy()
		frame.event_seq = 0
		if event is PlayerInputFrame:
			frame.merge_events(event)
		_last = frame
		steps.append(frame)
		if i > 0:
			_count("input_catch_up_frames")
	return steps




func capture(player: Player) -> PlayerInputFrame:
	var steps: = take_steps(player, 1)
	return steps[0] if not steps.is_empty() else _neutral(player)



func _contiguous() -> int:
	var count: = 0
	while _frames.has(ack_input + 1 + count):
		count += 1
	return count



func _skip_lost_frames() -> void :
	if _frames.is_empty() or _frames.has(ack_input + 1):
		return
	var keys: = _frames.keys()
	keys.sort()
	var lost: = int(keys[0]) - ack_input - 1
	if ack_input > 0 and lost > 0:
		_count("input_lost_frames", lost)
	ack_input = int(keys[0]) - 1




func _event_for(frame: PlayerInputFrame, now: int) -> Variant:
	if not _events.is_empty():
		var keys: = _events.keys()
		keys.sort()
		var event: PlayerInputFrame = _events[keys[0]]
		if event.seq <= frame.seq:
			_events.erase(keys[0])
			ack_event = event.event_seq
			_event_wait_since_ms = 0
			if event.seq < frame.seq:
				_count("input_late_events")
			return event
	if frame.event_seq > ack_event:
		if _event_wait_since_ms == 0:
			_event_wait_since_ms = now
		if now - _event_wait_since_ms <= STALE_MS:
			_count("input_event_waits")
			return true

		ack_event = frame.event_seq
		_event_wait_since_ms = 0
	return null


func _neutral(player: Player) -> PlayerInputFrame:
	var frame: = _last.neutralized()
	frame.seq = ack_input
	if _received_ms == 0:
		frame.yaw = wrapf(player.view_yaw if player.is_free_view() else player.yaw, - PI, PI)
		frame.pitch = player.head.rotation.x if player.head != null else 0.0
	return frame


func _count(key: String, amount: int = 1) -> void :
	counters[key] = int(counters.get(key, 0)) + amount




func clear() -> void :
	pass


func reset() -> void :
	_frames.clear()
	_events.clear()
	_last = PlayerInputFrame.new()
	_received_ms = 0
	_starved_since_ms = 0
	_event_wait_since_ms = 0
	_reserve = 1
	_calm = 0
	ack_input = 0
	ack_event = 0
