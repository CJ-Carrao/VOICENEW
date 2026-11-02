class_name DevProbe
extends Node





const HITCH_MS: = 80.0

static var enabled: = false
static var _mutex: = Mutex.new()
static var _frame: Dictionary = {}
static var _window: Dictionary = {}

var _last_us: = 0
var _window_us: = 0


static func attach(tree: SceneTree) -> void :
	if not OS.is_debug_build() or tree.root.has_node("DevProbe") or not MobileDev.args().has("--sonda"):
		return
	enabled = true
	var probe: = DevProbe.new()
	probe.name = "DevProbe"
	tree.root.add_child.call_deferred(probe)
	for edge: Array in [["DevProbeFirst", -100000, true], ["DevProbeLast", 100000, false]]:
		var mark: = _Edge.new()
		mark.name = edge[0]
		mark.first = edge[2]
		mark.process_priority = edge[1]
		mark.process_physics_priority = edge[1]
		tree.root.add_child.call_deferred(mark)


static func now() -> int:
	return Time.get_ticks_usec() if enabled else 0


static func done(label: String, started: int) -> void :
	if not enabled or started == 0:
		return
	_add(label, Time.get_ticks_usec() - started)


static func _add(label: String, us: int) -> void :
	_mutex.lock()
	_frame[label] = int(_frame.get(label, 0)) + us
	var entry: Array = _window.get(label, [0, 0, 0])
	entry[0] += us
	entry[1] += 1
	entry[2] = maxi(entry[2], us)
	_window[label] = entry
	_mutex.unlock()



class _Edge extends Node:
	static var _proc_us: = 0
	static var _phys_us: = 0
	var first: = false

	func _ready() -> void :
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void :
		if first:
			_proc_us = Time.get_ticks_usec()
		elif _proc_us > 0:
			DevProbe._add("SCRIPTS_process", Time.get_ticks_usec() - _proc_us)

	func _physics_process(_delta: float) -> void :
		if first:
			_phys_us = Time.get_ticks_usec()
		elif _phys_us > 0:
			DevProbe._add("SCRIPTS_physics", Time.get_ticks_usec() - _phys_us)
			DevProbe._add("passos_fisica", 0)


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000
	_last_us = Time.get_ticks_usec()
	_window_us = _last_us
	print("[sonda] ligada")
	for arg in MobileDev.args():
		if String(arg).begins_with("--sonda-segundos="):
			var seconds: = String(arg).trim_prefix("--sonda-segundos=").to_float()
			get_tree().create_timer(seconds, true, false, true).timeout.connect( func() -> void :
				print("[sonda] fim depois de %.0f s" % seconds)
				get_tree().quit())


func _process(_delta: float) -> void :
	var now_us: = Time.get_ticks_usec()
	var frame_ms: = (now_us - _last_us) / 1000.0
	_last_us = now_us
	_mutex.lock()
	var frame: = _frame
	_frame = {}
	_mutex.unlock()
	if frame_ms > HITCH_MS:
		print("[sonda] TRAVOU %.0f ms: %s" % [frame_ms, _top(frame)])
	if now_us - _window_us >= 2000000:
		_mutex.lock()
		var window: = _window
		_window = {}
		_mutex.unlock()
		var parts: Array[String] = []
		var labels: = window.keys()
		labels.sort_custom( func(a: String, b: String) -> bool: return window[a][0] > window[b][0])
		for label: String in labels:
			var entry: Array = window[label]
			parts.append("%s %.0fms/%dx max %.0f" % [label, entry[0] / 1000.0, entry[1], entry[2] / 1000.0])
		if not parts.is_empty():
			print("[sonda] 2s: ", ", ".join(parts))
		_window_us = now_us


func _top(frame: Dictionary) -> String:
	var labels: = frame.keys()
	labels.sort_custom( func(a: String, b: String) -> bool: return frame[a] > frame[b])
	var parts: Array[String] = []
	for label: String in labels.slice(0, 8):
		parts.append("%s %.0f" % [label, frame[label] / 1000.0])
	return ", ".join(parts)
