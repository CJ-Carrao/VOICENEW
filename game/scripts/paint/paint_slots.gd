class_name PaintSlots
extends RefCounted



const PATH: = "user://pinturas.json"
const VERSION: = 1

var names: Array[String] = []
var paints: Array[RobotPaint] = []
var selected: = 0
var path: = PATH


static func count() -> int:
	return int(RobotPaint.config().get("slots", 5))


static func default_name(index: int) -> String:
	return "PINTURA %d" % (index + 1)


static func load_from(file_path: String = PATH) -> PaintSlots:
	var slots: = PaintSlots.new()
	slots.path = file_path
	for i in count():
		slots.names.append(default_name(i))
		slots.paints.append(RobotPaint.new())
	if not FileAccess.file_exists(file_path):
		return slots
	var json: = JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		return slots
	var data: Variant = json.data
	if not data is Dictionary or int(data.get("version", 0)) != VERSION or not data.get("slots") is Array:
		return slots
	var list: Array = data["slots"]
	for i in mini(list.size(), count()):
		if not list[i] is Dictionary:
			continue
		slots.names[i] = clean_name(list[i].get("name", ""), i)
		slots.paints[i] = RobotPaint.from_data(list[i].get("strokes", []), list[i].get("stickers", []))
	slots.selected = clampi(int(data.get("selected", 0)) if data.get("selected") is float else 0, 0, count() - 1)
	return slots



static func chosen_bytes() -> PackedByteArray:
	var index: = int(UserSettings.get_value("paint", "lobby_slot", -1))
	if index < 0 or index >= count():
		return PackedByteArray()
	var paint: = load_from().paints[index]
	return PackedByteArray() if paint.is_empty() else paint.encode()


static func clean_name(value: Variant, index: int) -> String:
	var text: = String(value).strip_edges().to_upper() if value is String else ""
	text = text.substr(0, int(RobotPaint.config().get("slot_name_max", 18)))
	return text if not text.is_empty() else default_name(index)


func save() -> bool:
	var list: Array = []
	for i in count():
		list.append({"name": names[i], "strokes": paints[i].to_data(), "stickers": paints[i].stickers_data()})
	var file: = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": VERSION, "selected": selected, "slots": list}))
	file.close()
	return true
