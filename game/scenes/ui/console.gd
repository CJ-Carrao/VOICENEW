class_name TextConsole
extends PanelContainer



signal submitted(text: String)
signal opened
signal closed

var is_open: bool = false
var _history: PackedStringArray = []
var _history_index: int = 0

@onready var _line: LineEdit = %Line


func _ready() -> void :
	hide()
	_line.text_submitted.connect(_on_text_submitted)


func _input(event: InputEvent) -> void :
	if not is_open:
		if event.is_action_pressed("console"):
			get_viewport().set_input_as_handled()
			open()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_browse_history(-1)
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_browse_history(1)


func open() -> void :
	is_open = true
	_history_index = _history.size()
	_line.clear()
	show()
	_line.grab_focus.call_deferred()
	opened.emit()


func close() -> void :
	is_open = false
	_line.release_focus()
	hide()
	closed.emit()


func _on_text_submitted(text: String) -> void :
	var phrase: = text.strip_edges()
	close()
	if phrase.is_empty():
		return
	if _history.is_empty() or _history[_history.size() - 1] != phrase:
		_history.append(phrase)
	submitted.emit(phrase)


func _browse_history(step: int) -> void :
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + step, 0, _history.size())
	_line.text = _history[_history_index] if _history_index < _history.size() else ""
	_line.caret_column = _line.text.length()
