class_name PlayerInputFrame
extends RefCounted



var tick: int = 0
var seq: int = 0
var event_seq: int = 0
var wish: Vector2 = Vector2.ZERO
var sprint: bool = false
var jump_pressed: bool = false
var jump_held: bool = false
var crouch_pressed: bool = false
var climb: float = 0.0

var yaw: float = 0.0
var pitch: float = 0.0
var free_view: bool = false


var face_aim: bool = false
var aiming: bool = false
var use_held: bool = false
var use_pressed: bool = false
var use_released: bool = false
var reload: bool = false
var slot: int = -1
var exit_pilot: bool = false
var toggle_extract: bool = false
var pickup: bool = false
var drop_item: bool = false

const FLAGS: = ["sprint", "jump_pressed", "jump_held", "crouch_pressed", "free_view", "face_aim", "aiming", "use_held", 
	"use_pressed", "use_released", "reload", "exit_pilot", "toggle_extract", "pickup", "drop_item"]

const VALUES: = 8
const EVENTS: = ["jump_pressed", "crouch_pressed", "use_pressed", "use_released", "reload", "exit_pilot", "toggle_extract", "pickup", "drop_item"]


func has_events() -> bool:
	return jump_pressed or crouch_pressed or use_pressed or use_released or reload or slot >= 0 or exit_pilot or toggle_extract or pickup or drop_item


func copy() -> PlayerInputFrame:
	return from_wire(to_wire())


func without_events() -> PlayerInputFrame:
	var frame: = copy()
	for key: String in EVENTS:
		frame.set(key, false)
	frame.slot = -1
	frame.event_seq = 0
	return frame




func movement_only() -> PlayerInputFrame:
	var frame: = without_events()
	frame.event_seq = event_seq
	return frame



func neutralized() -> PlayerInputFrame:
	var frame: = PlayerInputFrame.new()
	frame.tick = tick
	frame.seq = seq
	frame.yaw = yaw
	frame.pitch = pitch
	frame.free_view = free_view
	return frame


func merge_events(frame: PlayerInputFrame) -> void :
	for key: String in EVENTS:
		set(key, frame.get(key))
	slot = frame.slot
	event_seq = frame.event_seq


func to_wire() -> Dictionary:
	var data: = {"seq": seq, "tick": tick, "event_seq": event_seq, "wish": wish, "climb": climb, 
		"yaw": yaw, "pitch": pitch, "slot": slot}
	for key: String in FLAGS:
		data[key] = get(key)
	return data



static func from_wire(data: Variant) -> PlayerInputFrame:
	if not data is Dictionary or data.size() != VALUES + FLAGS.size():
		return null
	for key in ["seq", "tick", "event_seq", "slot"]:
		if not data.get(key) is int:
			return null
	for key in ["seq", "tick", "event_seq"]:
		if int(data[key]) < 0 or int(data[key]) > 2147483647:
			return null
	if int(data.slot) < -1 or int(data.slot) > 2:
		return null
	if not data.get("wish") is Vector2 or not (data.wish as Vector2).is_finite() or (data.wish as Vector2).length() > 1.001:
		return null
	for key in ["climb", "yaw", "pitch"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
			return null
	if absf(float(data.climb)) > 1.0 or absf(float(data.yaw)) > TAU or absf(float(data.pitch)) > PI * 0.5:
		return null
	for key: String in FLAGS:
		if not data.get(key) is bool:
			return null
	var frame: = PlayerInputFrame.new()
	for key: String in data:
		frame.set(key, data[key])
	return frame



func movement() -> Dictionary:
	return {
		"wish": wish.limit_length(1.0), 
		"sprint": sprint, 
		"jump_pressed": jump_pressed, 
		"jump_held": jump_held, 
		"crouch_pressed": crouch_pressed, 
		"climb": climb, 
	}
