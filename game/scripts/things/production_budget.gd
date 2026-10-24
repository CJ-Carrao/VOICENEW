class_name ProductionBudget
extends RefCounted

# Bound new work, never the number of animals already alive.
const PER_SECOND := 12.0
const BURST := 3.0
const PER_FRAME := 2
const FRAME_US := 2500

var _owners := {}
var _frame := -1
var _created := 0
var _work_us := 0

static func complex(node: Dictionary, lex: LexiconData) -> bool:
	var id := String(node.get("thing", ""))
	if lex.category_of(id) != "projectile": return true
	return not node.get("behaviors", []).is_empty() or not node.get("mods", {}).get("grafts", []).is_empty() or lex.models.get(id, {}).get("pieces", []).size() > 8

func reset() -> void:
	_owners.clear()
	_frame = -1
	_created = 0
	_work_us = 0

func available(owner_id: int, population: int = 0) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _frame:
		_frame = frame
		_created = 0
		_work_us = 0
	var now := Time.get_ticks_msec()
	var state: Dictionary = _owners.get(owner_id, {"tokens": BURST, "at": now})
	var rate := PER_SECOND / (1.0 + maxf(float(population - 80), 0.0) / 80.0)
	state.tokens = minf(BURST, float(state.tokens) + maxf(float(now - int(state.at)), 0.0) * rate / 1000.0)
	state.at = now
	_owners[owner_id] = state
	return float(state.tokens) >= 1.0 and _created < PER_FRAME and _work_us < FRAME_US

func reserve(owner_id: int, population: int = 0) -> bool:
	if not available(owner_id, population): return false
	_owners[owner_id].tokens -= 1.0
	_created += 1
	return true

func record_work(usec: int) -> void:
	_work_us += maxi(usec, 0)
