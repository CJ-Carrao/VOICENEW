extends RefCounted




static func build(bp: Dictionary) -> Array:
	var out: Array = []
	var width: = float(bp["size"][0])
	var depth: = float(bp["size"][1])
	var levels: = int(bp.get("levels", 2))
	var floor_height: = float(bp.get("floor_height", 3.0))
	var style: = String(bp.get("style", "office"))
	var wall: = String(bp.get("wall", "concrete"))
	var glass: = String(bp.get("glass", "glass"))
	var accent: = String(bp.get("accent", "metal" if wall == "concrete" else "concrete"))
	var window_mode: = String(bp.get("window_mode", "standard"))
	var glass_color: = String(bp.get("glass_color", ""))
	var podium_levels: = int(bp.get("podium_levels", 2))
	var setback_m: = float(bp.get("setback_m", 0.0))
	var shaft_x: = - width * 0.5 + 2.5
	var shaft_z: = - depth * 0.5 + 4.0
	var roof_width: = width
	var roof_depth: = depth
	for level in levels:
		var base: = level * floor_height
		var inset: = 0.0
		if String(bp.get("profile", "")) == "setback" and level >= podium_levels:
			inset = setback_m + (0.25 if level >= levels - 2 else 0.0)
		var floor_width: = width - inset * 2.0
		var floor_depth: = depth - inset * 2.0
		roof_width = floor_width
		roof_depth = floor_depth
		if style == "garage":
			_open_facade(out, floor_width, floor_depth, base)
			_garage_detail(out, floor_width, floor_depth, base, floor_height)
		elif style == "construction":
			_columns(out, floor_width, floor_depth, base, floor_height)
			_construction_detail(out, floor_width, floor_depth, base, floor_height)
		else:
			_facades(out, floor_width, floor_depth, base, floor_height, level == 0, wall, glass, 
				accent, window_mode, glass_color)
			_facade_details(out, floor_width, floor_depth, base, floor_height, accent)
			_partition(out, floor_width, floor_depth, base, floor_height, wall, shaft_z)
			if style in ["office", "residential"]:
				_cross_partition(out, floor_width, floor_depth, base, floor_height, wall)
			if style == "retail" and level == 0:
				_piece(out, Vector3(0, base + 2.75, floor_depth * 0.5 + 0.5), Vector3(floor_width * 0.8, 0.25, 1.25), accent)
			if style == "residential" and level > 0:
				_balcony(out, floor_width, floor_depth, base, level)
		_stairs(out, base, floor_height, shaft_x, shaft_z)
		_slab(out, floor_width, floor_depth, base + floor_height, shaft_x, shaft_z)
		if inset > 0.0 and (level == podium_levels or level == levels - 2):
			var previous_inset: = 0.0 if level == podium_levels else setback_m
			_parapet(out, width - previous_inset * 2.0, depth - previous_inset * 2.0, base)
	_parapet(out, roof_width, roof_depth, levels * floor_height)
	if style in ["office", "residential"]:
		_roof_equipment(out, roof_width, roof_depth, levels * floor_height, accent)
	if bool(bp.get("sign", false)):
		_roof_sign(out, roof_depth, levels * floor_height)
	return out


static func build_viaduct(bp: Dictionary) -> Array:
	var out: Array = []
	var length: = float(bp.get("length", 28.0))
	var width: = float(bp.get("width", 4.5))
	var height: = float(bp.get("height", 5.0))
	_piece(out, Vector3(0, height - 0.125, 0), Vector3(length, 0.25, width), "concrete")
	for x in [-10.0, 10.0]:
		for z in [ - width * 0.5 + 0.5, width * 0.5 - 0.5]:
			_piece(out, Vector3(x, height * 0.5 - 0.125, z), Vector3(0.75, height - 0.25, 0.75), "concrete")
	for z in [ - width * 0.5 + 0.125, width * 0.5 - 0.125]:
		_piece(out, Vector3(0, height + 0.375, z), Vector3(length, 0.75, 0.25), "metal")
	return out


static func build_stairs(bp: Dictionary) -> Array:
	var out: Array = []
	var side: = -1.0 if String(bp.get("side", "west")) == "west" else 1.0
	for i in 19:
		var rise: = (i + 1) * 0.25
		var x: = side * (14.0 - (i + 0.5) * 0.5)
		_piece(out, Vector3(x, rise * 0.5, 0), Vector3(0.5, rise, 2.5), "concrete")
	return out


static func build_station(_bp: Dictionary) -> Array:
	var out: Array = []

	for side: float in [-1.0, 1.0]:
		_piece(out, Vector3(0, 4.875, side * 3.375), Vector3(18.0, 0.25, 2.25), "concrete")
		_piece(out, Vector3(0, 5.375, side * 4.375), Vector3(18.0, 0.75, 0.25), "metal")
		for x in [-6.0, 6.0]:
			_piece(out, Vector3(x, 2.375, side * 3.5), Vector3(0.75, 4.75, 0.75), "concrete")
	return out


static func build_car(bp: Dictionary) -> Array:
	var out: Array = []
	var paint: = String(bp.get("paint", "#637c90"))
	_piece(out, Vector3(0, 0.65, 0), Vector3(1.9, 0.75, 4.25), "metal", paint)
	_piece(out, Vector3(0, 1.25, -0.15), Vector3(1.7, 0.7, 2.15), "glass")
	for x in [-0.8, 0.8]:
		for z in [-1.4, 1.4]:
			_piece(out, Vector3(x, 0.25, z), Vector3(0.35, 0.5, 0.65), "scrap", "#252d35")
	for x in [-0.55, 0.55]:
		_piece(out, Vector3(x, 0.7, -2.15), Vector3(0.35, 0.25, 0.05), "glass", "#f1dbb1")
		_piece(out, Vector3(x, 0.7, 2.15), Vector3(0.35, 0.25, 0.05), "glass", "#b9423d")
	return out


static func _facades(out: Array, width: float, depth: float, base: float, height: float, 
		ground: bool, wall: String, glass: String, accent: String, window_mode: String, glass_color: String) -> void :
	var t: = 0.25
	for side in 4:
		var length: = width if side < 2 else depth
		var along: = Vector3.RIGHT if side < 2 else Vector3.BACK
		var origin: = Vector3(0.0, 0.0, (depth * 0.5 - t * 0.5) * (1.0 if side == 0 else -1.0)) if side < 2\
		else Vector3((width * 0.5 - t * 0.5) * (1.0 if side == 2 else -1.0), 0.0, 0.0)
		var bays: = maxi(2, roundi(length / 3.0))
		var bay: = length / bays
		for i in bays:
			var center: = origin + along * ( - length * 0.5 + (i + 0.5) * bay)
			var door: = ground and side == 0 and i == bays / 2
			var ribbon: = window_mode == "ribbon" and not door
			var opening_width: = 1.75 if door else minf(2.75 if ribbon else 1.5, bay - 0.5)
			var bottom: = 0.0 if door else 0.45 if ribbon else 0.95
			var opening_height: = 2.5 if door else height - 0.7 if ribbon else 1.3
			var jamb: = (bay - opening_width) * 0.5
			_piece(out, center - along * (bay * 0.5 - jamb * 0.5) + Vector3.UP * (base + height * 0.5), 
				_side_size(along, jamb, height, t), wall)
			_piece(out, center + along * (bay * 0.5 - jamb * 0.5) + Vector3.UP * (base + height * 0.5), 
				_side_size(along, jamb, height, t), wall)
			if bottom > 0.0:
				_piece(out, center + Vector3.UP * (base + bottom * 0.5), 
					_side_size(along, opening_width, bottom, t), wall)
			var header: = height - bottom - opening_height
			if header > 0.0:
				_piece(out, center + Vector3.UP * (base + bottom + opening_height + header * 0.5), 
					_side_size(along, opening_width, header, t), wall)
			if not door:
				_piece(out, center + Vector3.UP * (base + bottom + opening_height * 0.5), 
					_side_size(along, opening_width, opening_height, 0.05), glass, glass_color)
				if window_mode == "paired":
					_piece(out, center + Vector3.UP * (base + bottom + opening_height * 0.5), 
						_side_size(along, 0.25, opening_height, 0.25), accent)


static func _side_size(along: Vector3, length: float, height: float, thick: float) -> Vector3:
	return Vector3(length, height, thick) if along == Vector3.RIGHT else Vector3(thick, height, length)



static func _facade_details(out: Array, width: float, depth: float, base: float, height: float, accent: String) -> void :
	for z in [ - depth * 0.5, depth * 0.5]:
		_piece(out, Vector3(0, base + height - 0.125, z), Vector3(width, 0.25, 0.5), accent)
	for x in [ - width * 0.5, width * 0.5]:
		_piece(out, Vector3(x, base + height - 0.125, 0), Vector3(0.5, 0.25, depth), accent)
		for z in [ - depth * 0.5, depth * 0.5]:
			_piece(out, Vector3(x, base + height * 0.5, z), Vector3(0.5, height, 0.5), accent)



static func _cross_partition(out: Array, width: float, depth: float, base: float, height: float, wall: String) -> void :
	var x: = width * 0.18
	var passage: = 2.5
	var room_depth: = (depth - passage) * 0.5 - 0.5
	for side in [-1.0, 1.0]:
		_piece(out, Vector3(x, base + height * 0.5, side * (passage * 0.5 + room_depth * 0.5)), 
			Vector3(0.25, height - 0.25, room_depth), wall)


static func _balcony(out: Array, width: float, depth: float, base: float, level: int) -> void :
	var x: = width * (0.22 if level % 2 == 0 else -0.22)
	var balcony_width: = width * 0.4
	var front: = depth * 0.5 + 1.0
	_piece(out, Vector3(x, base + 0.125, depth * 0.5 + 0.5), Vector3(balcony_width, 0.25, 1.25), "concrete")
	_piece(out, Vector3(x, base + 0.75, front), Vector3(balcony_width, 0.75, 0.25), "metal")
	for side in [-1.0, 1.0]:
		_piece(out, Vector3(x + side * balcony_width * 0.5, base + 0.75, depth * 0.5 + 0.5), 
			Vector3(0.25, 0.75, 1.0), "metal")


static func _roof_equipment(out: Array, width: float, depth: float, roof: float, accent: String) -> void :
	_piece(out, Vector3(width * 0.25, roof + 0.75, - depth * 0.2), Vector3(2.5, 1.5, 2.5), accent)
	_piece(out, Vector3(width * 0.25, roof + 1.625, - depth * 0.2), Vector3(2.0, 0.25, 2.0), "metal")
	_piece(out, Vector3( - width * 0.05, roof + 0.5, depth * 0.25), Vector3(1.5, 1.0, 1.5), "metal")
	_piece(out, Vector3( - width * 0.05, roof + 1.125, depth * 0.25), Vector3(1.0, 0.25, 1.0), "glass")
	_piece(out, Vector3(width * 0.25, roof + 3.0, - depth * 0.2), Vector3(0.25, 3.0, 0.25), "metal")


static func _garage_detail(out: Array, width: float, depth: float, base: float, height: float) -> void :
	for z in [ - depth * 0.5, depth * 0.5]:
		_piece(out, Vector3(0, base + height - 0.25, z), Vector3(width, 0.5, 0.5), "metal")
		_piece(out, Vector3(0, base + 1.375, z), Vector3(width, 0.75, 0.25), "concrete")
	for x in [ - width * 0.5, width * 0.5]:
		_piece(out, Vector3(x, base + height - 0.25, 0), Vector3(0.5, 0.5, depth), "metal")


static func _construction_detail(out: Array, width: float, depth: float, base: float, height: float) -> void :
	for z in [ - depth * 0.5, depth * 0.5]:
		_piece(out, Vector3(0, base + height - 0.25, z), Vector3(width, 0.5, 0.5), "metal")
	for x in [ - width * 0.5, width * 0.5]:
		_piece(out, Vector3(x, base + height - 0.25, 0), Vector3(0.5, 0.5, depth), "metal")
		for z in [ - depth * 0.5, depth * 0.5]:
			_piece(out, Vector3(x, base + 1.0, z), Vector3(0.25, 2.0, 0.25), "metal")


static func _partition(out: Array, width: float, depth: float, base: float, height: float, 
		wall: String, shaft_z: float) -> void :
	var z: = minf(depth * 0.25, shaft_z + 4.0)
	var passage: = 2.5
	var side: = (width - passage) * 0.5
	for sign in [-1.0, 1.0]:
		_piece(out, Vector3(sign * (passage * 0.5 + side * 0.5), base + height * 0.5, z), 
			Vector3(side, height - 0.25, 0.25), wall)


static func _slab(out: Array, width: float, depth: float, top: float, sx: float, sz: float) -> void :
	var x0: = sx - 1.0
	var x1: = sx + 1.0
	var z0: = sz - 3.0
	var z1: = sz + 3.0
	var y: = top - 0.125
	_piece(out, Vector3(( - width * 0.5 + x0) * 0.5, y, 0), Vector3(x0 + width * 0.5, 0.25, depth), "concrete")
	_piece(out, Vector3((width * 0.5 + x1) * 0.5, y, 0), Vector3(width * 0.5 - x1, 0.25, depth), "concrete")
	_piece(out, Vector3(sx, y, ( - depth * 0.5 + z0) * 0.5), Vector3(2.0, 0.25, z0 + depth * 0.5), "concrete")
	_piece(out, Vector3(sx, y, (depth * 0.5 + z1) * 0.5), Vector3(2.0, 0.25, depth * 0.5 - z1), "concrete")


static func _stairs(out: Array, base: float, height: float, sx: float, sz: float) -> void :
	var steps: = roundi(height / 0.25)
	var run: = 6.0 / steps
	for i in steps:
		var rise: = (i + 1) * height / steps
		_piece(out, Vector3(sx, base + rise * 0.5, sz - 3.0 + (i + 0.5) * run), 
			Vector3(2.0, rise, run), "concrete")


static func _open_facade(out: Array, width: float, depth: float, base: float) -> void :
	for x in [ - width * 0.5 + 0.25, width * 0.5 - 0.25]:
		for z in [ - depth * 0.5 + 0.25, depth * 0.5 - 0.25]:
			_piece(out, Vector3(x, base + 1.5, z), Vector3(0.5, 3.0, 0.5), "concrete")
	for z in [ - depth * 0.5 + 0.125, depth * 0.5 - 0.125]:
		_piece(out, Vector3(0, base + 0.5, z), Vector3(width, 1.0, 0.25), "concrete")


static func _columns(out: Array, width: float, depth: float, base: float, height: float) -> void :
	for x in [ - width * 0.5 + 0.25, 0.0, width * 0.5 - 0.25]:
		for z in [ - depth * 0.5 + 0.25, 0.0, depth * 0.5 - 0.25]:
			_piece(out, Vector3(x, base + height * 0.5, z), Vector3(0.5, height, 0.5), "concrete")


static func _parapet(out: Array, width: float, depth: float, roof: float) -> void :
	for z in [ - depth * 0.5 + 0.125, depth * 0.5 - 0.125]:
		_piece(out, Vector3(0, roof + 0.375, z), Vector3(width, 0.75, 0.25), "concrete")
	for x in [ - width * 0.5 + 0.125, width * 0.5 - 0.125]:
		_piece(out, Vector3(x, roof + 0.375, 0), Vector3(0.25, 0.75, depth), "concrete")


static func _roof_sign(out: Array, depth: float, roof: float) -> void :
	var glyphs: = {
		"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"], 
		"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], 
		"K": ["10001", "10010", "10100", "11000", "10100", "10010", "10001"], 
		"Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], 
		"3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"], 
	}
	var label: = "TOKYO 3"
	var left: = - label.length() * 0.75
	for character in label.length():
		var letter: = label[character]
		if not glyphs.has(letter):
			continue
		var rows: Array = glyphs[letter]
		for row in 7:
			for col in 5:
				if rows[row][col] == "1":
					_piece(out, Vector3(left + character * 1.5 + col * 0.25, roof + 0.875 + (6 - row) * 0.25, 
						depth * 0.5 - 0.125), Vector3.ONE * 0.25, "glass", "#ffc078", 1.5)


static func _piece(out: Array, at: Vector3, size: Vector3, material: String, color: String = "", glow: float = 0.0) -> void :
	if size.x < 0.01 or size.y < 0.01 or size.z < 0.01:
		return
	var entry: = {"pos": at, "size": size, "material": material}
	if not color.is_empty():
		entry["color"] = color
	if glow > 0.0:
		entry["glow"] = glow
	out.append(entry)
