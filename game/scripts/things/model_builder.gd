class_name ModelBuilder
extends RefCounted















const FALLBACK_PIECE: = {"shape": "box", "size": [0.5, 0.5, 0.5], "pos": [0, 0.25, 0], "color": "#c040c0", "tag": "body"}

const DEFAULT_AXES: = {"width": "x", "height": "y", "length": "z"}

const BARREL_SPACING: = 1.3


const BARREL_BEND: = 1.0

const BARREL_LINK_SEGMENTS: = 4
const ROUND_SEGMENTS: = 16

const FINISHES: = {
	"metal": {"roughness": 0.38, "metallic": 0.65}, 
	"wood": {"roughness": 0.82, "metallic": 0.0}, 
	"plastic": {"roughness": 0.6, "metallic": 0.0}, 
	"rubber": {"roughness": 0.95, "metallic": 0.0}, 
	"glass": {"roughness": 0.08, "metallic": 0.3}, 
}

static var _mesh_cache: Dictionary = {}
static var _material_cache: Dictionary = {}






static func build(thing_id: String, mods: Dictionary, lex: LexiconData) -> Dictionary:
	var weapon: = lex.is_weapon(thing_id)
	var rear_id: = lex.part_source(thing_id, mods, "rear") if weapon else thing_id
	var data: Dictionary = lex.models.get(rear_id if not weapon or lex.uses_weapon_section(rear_id, mods, "rear") else thing_id, {})
	var pieces: Array = _weapon_pieces(thing_id, mods, lex) if weapon else data.get("pieces", [])
	if pieces.is_empty():
		pieces = [FALLBACK_PIECE]
	var stretch: = axis_stretch(thing_id, mods, lex)
	var length: = float(mods.get("length", 1.0))
	if weapon and _length_axis(thing_id, lex) == "z" and not is_equal_approx(length, 1.0):
		var sections: Array = ["front", "muzzle"] if lex.thing_def(lex.behavior_source({"thing": thing_id, "mods": mods})).get("melee", false) else ["muzzle"]
		pieces = _stretch_muzzle(pieces, length, lex, sections)
		stretch.z /= length
	var mounts: = mount_points(pieces, weapon, lex)
	pieces = _with_attachments(pieces, mounts, mods, lex)
	var barrels: = lex.barrels_of(thing_id, mods)
	var spacing: = 0.0
	for piece: Dictionary in pieces:
		if _replicates(piece, weapon, lex):
			spacing = maxf(spacing, _piece_width(piece))
	spacing *= BARREL_SPACING

	var muzzle_model: Dictionary = lex.models.get(lex.part_source(thing_id, mods, "muzzle") if weapon else thing_id, {})
	var ring: = String(muzzle_model.get("muzzle_layout", "row")) == "ring" and barrels > 1
	var ring_radius: = maxf(spacing * barrels / TAU, spacing * 0.6)
	var spinner: Node3D = null
	var voxel: = voxel_size(pieces)
	if barrels > 1 and not ring:
		pieces = pieces + _barrel_links(pieces, barrels, spacing, voxel, weapon, lex)
	var element: Dictionary = (lex.elements.get(String(mods.get("element", "")), {}) as Dictionary).duplicate()
	element.merge(lex.material_pack({"mods": mods})["visual"], true)
	var paint: Dictionary = lex.colors.get(String(mods.get("color", "")), {})

	var anchor: = _vec(data.get("anchor", [0, 0, 0]))
	var root: = Node3D.new()
	root.name = "Model"
	var bounds: = AABB()
	var has_bounds: = false
	var muzzles: Array[Vector3] = []
	var built: Array[MeshInstance3D] = []
	var solids: Array[AABB] = []
	var enclosure: = bool(lex.thing_def(thing_id).get("hollow", false)) or bool(lex.thing_def(thing_id).get("enclosure", false))

	var tag_boxes: = {}
	for piece: Dictionary in pieces:
		var is_barrel: = String(piece.get("tag", "")) == "barrel"
		var copies: = barrels if _replicates(piece, weapon, lex) else 1
		for i in copies:
			var mesh_instance: = MeshInstance3D.new()
			mesh_instance.mesh = piece_mesh(piece, voxel)
			mesh_instance.material_override = piece_material(piece, element, paint)
			var at: = _vec(piece.get("pos", [0, 0, 0]))
			var parent: Node3D = root
			if copies > 1 and ring:

				var angle: = TAU * float(i) / float(copies)
				var around: = Vector3(cos(angle), sin(angle), 0.0) * ring_radius
				if bool(muzzle_model.get("spins", false)):
					if spinner == null:
						spinner = Node3D.new()
						spinner.name = "Spinner"
						spinner.position = Vector3(at.x, at.y, 0.0)
						root.add_child(spinner)
					parent = spinner
					at = Vector3(0.0, 0.0, at.z) + around
				else:
					at += around
			elif copies > 1:
				var side: = (i - (copies - 1) * 0.5) * spacing
				at += Vector3(side, 0.0, - absf(side) * BARREL_BEND)
			mesh_instance.position = at
			mesh_instance.rotation_degrees = _vec(piece.get("rot", [0, 0, 0]))
			if piece.has("_stretch"):
				mesh_instance.basis = Basis.from_scale(_vec(piece["_stretch"])) * mesh_instance.basis
			mesh_instance.set_meta("tag", piece.get("tag", ""))
			mesh_instance.set_meta("section", lex.section_of(piece))
			mesh_instance.set_meta("source", piece.get("source", thing_id))
			parent.add_child(mesh_instance)
			built.append(mesh_instance)
			var box: AABB = parent.transform * mesh_instance.transform * mesh_instance.mesh.get_aabb() if parent != root\
			else mesh_instance.transform * mesh_instance.mesh.get_aabb()
			bounds = bounds.merge(box) if has_bounds else box
			has_bounds = true
			if enclosure and bool(piece.get("collision", true)):
				solids.append(box)
			var piece_tag: = String(piece.get("tag", ""))
			tag_boxes[piece_tag] = (tag_boxes[piece_tag] as AABB).merge(box) if tag_boxes.has(piece_tag) else box
			if is_barrel:
				var center: = box.get_center()
				muzzles.append(Vector3(center.x, center.y, box.position.z))

	var scale: = Vector3.ONE * float(mods.get("scale", 1.0)) * stretch
	root.scale = scale
	for i in solids.size():
		solids[i] = AABB(solids[i].position * scale, solids[i].size * scale)
	mounts.merge(universal_mounts(bounds, tag_boxes, data), true)
	return {"root": root, "bounds": AABB(bounds.position * scale, bounds.size * scale), "muzzles": muzzles, 
		"anchor": anchor, "pieces": build_order(built, anchor), "mounts": mounts, "solids": solids, 
		"sight_y": _sight_height(pieces, mounts, mods, weapon, lex, thing_id), "grips": _grips(tag_boxes, anchor, lex)}



static func universal_mounts(box: AABB, tags: Dictionary, data: Dictionary) -> Dictionary:
	var c: = box.get_center()
	var result: = {"mount_front": Vector3(c.x, c.y, box.position.z), 
		"mount_back": Vector3(c.x, c.y, box.end.z), "mount_top": Vector3(c.x, box.end.y, c.z), 
		"mount_bottom": Vector3(c.x, box.position.y, c.z), "mount_left": Vector3(box.position.x, c.y, c.z), 
		"mount_right": Vector3(box.end.x, c.y, c.z), "mount_hand": Vector3(box.end.x, c.y, box.position.z)}
	for key: String in result:
		if tags.has(key):
			result[key] = (tags[key] as AABB).get_center()
		if (data.get("sockets", {}) as Dictionary).has(key):
			result[key] = _vec(data["sockets"][key])
	return result




static func _grips(tag_boxes: Dictionary, anchor: Vector3, lex: LexiconData) -> Dictionary:
	var rules: = lex.grip_rules
	var main: = anchor
	var handle: = AABB()
	var has_handle: = false
	for tag: String in rules.get("main", []):
		if tag_boxes.has(tag):
			handle = tag_boxes[tag]
			main = handle.get_center()
			has_handle = true
			break
	var support: Variant = null
	var hold: = AABB()
	var has_hold: = false
	for tag: String in rules.get("support", []):
		if tag_boxes.has(tag):
			hold = (hold.merge(tag_boxes[tag]) if has_hold else tag_boxes[tag]) as AABB
			has_hold = true
	if has_hold:
		support = hold.get_center()
	elif has_handle and handle.size.z >= float(rules.get("two_hand_handle_m", 0.2)):
		support = main + Vector3(0.0, 0.0, handle.size.z * float(rules.get("two_hand_handle_frac", 0.35)))
	return {"main": main, "support": support}





static func _sight_height(pieces: Array, mounts: Dictionary, mods: Dictionary, weapon: bool, lex: LexiconData, 
		thing_id: String) -> float:
	for id: Variant in mods.get("attachments", []):
		if lex.attachment_slot(String(id)) == "optic":
			return (mounts["optic"] as Vector3).y + float((lex.models.get(String(id), {}) as Dictionary).get("sight_height", 0.02))
	var front: Dictionary = lex.models.get(lex.part_source(thing_id, mods, "front") if weapon else thing_id, {})
	if front.has("sight_height"):
		return float(front["sight_height"])
	var top: = - INF
	for piece: Dictionary in pieces:
		if String(piece.get("tag", "")) == "sight":
			top = maxf(top, _piece_box(piece).end.y)
	return top if top > - INF else (mounts["optic"] as Vector3).y





static func mount_points(pieces: Array, weapon: bool, lex: LexiconData) -> Dictionary:
	var body: = AABB()
	var everything: = AABB()
	var tip: = AABB()
	var seen: = [false, false, false]
	for piece: Dictionary in pieces:
		var box: = _piece_box(piece)
		everything = everything.merge(box) if seen[0] else box
		seen[0] = true
		var section: = lex.section_of(piece) if weapon else "front"
		if section == "front":
			body = body.merge(box) if seen[1] else box
			seen[1] = true
		if String(piece.get("tag", "")) == "barrel":
			tip = tip.merge(box) if seen[2] else box
			seen[2] = true
	if not seen[1]:
		body = everything
	var c: = body.get_center()
	var muzzle: = Vector3(c.x, c.y, everything.position.z)
	if seen[2]:
		muzzle = Vector3(tip.get_center().x, tip.get_center().y, tip.position.z)
	return {
		"optic": Vector3(c.x, body.end.y, c.z), 
		"under": Vector3(c.x, body.position.y, c.z - body.size.z * 0.15), 
		"side": Vector3(body.end.x, c.y, c.z - body.size.z * 0.2), 
		"side_left": Vector3(body.position.x, c.y, c.z - body.size.z * 0.2), 
		"muzzle": muzzle, 
	}



static func _with_attachments(pieces: Array, mounts: Dictionary, mods: Dictionary, lex: LexiconData) -> Array:
	var gear: Array = mods.get("attachments", [])
	if gear.is_empty():
		return pieces
	var out: = pieces.duplicate()
	for id: Variant in gear:
		var slot: = lex.attachment_slot(String(id))
		if not mounts.has(slot):
			continue
		var at: Vector3 = mounts[slot]
		for piece: Dictionary in (lex.models.get(String(id), {}) as Dictionary).get("pieces", []):
			var moved: = piece.duplicate()
			var spot: Vector3 = _vec(piece.get("pos", [0, 0, 0])) + at
			moved["pos"] = [spot.x, spot.y, spot.z]
			moved["section"] = "muzzle" if slot == "muzzle" else "front"
			moved["replicate"] = slot == "muzzle"
			moved["tag"] = "attachment"
			out.append(moved)
	return out



static func _piece_box(piece: Dictionary) -> AABB:
	var rot: = _vec(piece.get("rot", [0, 0, 0])) * (PI / 180.0)
	var basis: = Basis.from_euler(rot)
	if piece.has("_stretch"):
		basis = Basis.from_scale(_vec(piece["_stretch"])) * basis
	return Transform3D(basis, _vec(piece.get("pos", [0, 0, 0]))) * piece_mesh(piece).get_aabb()




static func axis_stretch(thing_id: String, mods: Dictionary, lex: LexiconData) -> Vector3:
	var axes: Dictionary = lex.thing_def(thing_id).get("shape_axes", {})
	var out: = Vector3.ONE
	for dim: String in DEFAULT_AXES:
		var value: = float(mods.get(dim, 1.0))
		match String(axes.get(dim, DEFAULT_AXES[dim])):
			"x":
				out.x *= value
			"y":
				out.y *= value
			_:
				out.z *= value
	return out


static func _length_axis(thing_id: String, lex: LexiconData) -> String:
	return String((lex.thing_def(thing_id).get("shape_axes", {}) as Dictionary).get("length", "z"))





static func _stretch_muzzle(pieces: Array, length: float, lex: LexiconData, sections: Array = ["muzzle"]) -> Array:
	var back: = - INF
	for piece: Dictionary in pieces:
		if lex.section_of(piece) in sections:
			var box: = _piece_box(piece)
			back = maxf(back, box.position.z + box.size.z)
	if back == - INF:
		return pieces
	var out: Array = []
	for piece: Dictionary in pieces:
		if not lex.section_of(piece) in sections:
			out.append(piece)
			continue
		var moved: = piece.duplicate()
		var at: = _vec(piece.get("pos", [0, 0, 0]))
		at.z = back + (at.z - back) * length
		moved["pos"] = [at.x, at.y, at.z]
		var previous: = _vec(piece.get("_stretch", [1, 1, 1]))
		moved["_stretch"] = [previous.x, previous.y, previous.z * length]
		out.append(moved)
	return out





static func _weapon_pieces(thing_id: String, mods: Dictionary, lex: LexiconData) -> Array:
	var rear: = _section_model(thing_id, mods, "rear", lex)
	var front: = _section_model(thing_id, mods, "front", lex)
	var muzzle: = _section_model(thing_id, mods, "muzzle", lex)
	if rear == front and front == muzzle:
		return rear.get("pieces", [])
	var front_offset: = _joint(rear, "trigger") - _joint(front, "front_plug", "trigger")
	var muzzle_offset: = _joint(front, "muzzle") + front_offset - _joint(muzzle, "muzzle_plug", "muzzle")
	var out: Array = []
	for part: Array in [[rear, "rear", Vector3.ZERO], [front, "front", front_offset], [muzzle, "muzzle", muzzle_offset]]:
		for piece: Dictionary in (part[0] as Dictionary).get("pieces", []):
			if lex.section_of(piece) == String(part[1]):
				var moved: = piece.duplicate()
				var at: Vector3 = _vec(piece.get("pos", [0, 0, 0])) + part[2]
				moved["pos"] = [at.x, at.y, at.z]
				out.append(moved)
	return out




static func _section_model(thing_id: String, mods: Dictionary, section: String, lex: LexiconData) -> Dictionary:
	var source: = lex.part_source(thing_id, mods, section)
	var model: Dictionary = lex.models.get(source, {})
	if lex.uses_weapon_section(source, mods, section):
		return model
	var base: Dictionary = lex.models.get(thing_id, {})
	var target: = AABB()
	var box: = AABB()
	var core: = AABB()
	var entrance: = AABB()
	var seen: = false
	for piece: Dictionary in base.get("pieces", []):
		if lex.section_of(piece) == section:
			target = target.merge(_piece_box(piece)) if seen else _piece_box(piece)
			seen = true
	seen = false
	for piece: Dictionary in model.get("pieces", []):
		var piece_box: = _piece_box(piece)
		box = box.merge(piece_box) if seen else piece_box
		if piece_box.get_volume() > core.get_volume():
			core = piece_box
		if not seen or piece_box.end.z > entrance.end.z:
			entrance = piece_box
		seen = true
	var size: = maxf(target.size[target.size.max_axis_index()], float(lex.bal("mechanics.min_section_m", 0.1)))
	var fit: = size / maxf(box.size[box.size.max_axis_index()], 0.001)
	var offset: = target.get_center() - box.get_center() * fit


	var fitted: = AABB(core.position * fit + offset, core.size * fit)
	var out: Array = []
	for piece: Dictionary in model.get("pieces", []):
		var moved: = piece.duplicate(true)
		var at: = _vec(piece.get("pos", [0, 0, 0])) * fit + offset
		var stretch: = _vec(piece.get("_stretch", [1, 1, 1])) * fit
		moved["pos"] = [at.x, at.y, at.z]
		moved["_stretch"] = [stretch.x, stretch.y, stretch.z]
		moved["section"] = section
		moved["source"] = source

		if moved.get("tag") == "barrel":
			moved["tag"] = "body"
		out.append(moved)
	var c: = fitted.get_center()
	var back: = [c.x, c.y, c.z + fitted.size.z * 0.4]
	var front: = [c.x, c.y, c.z - fitted.size.z * 0.4]
	if section == "muzzle":


		var entry: = AABB(entrance.position * fit + offset, entrance.size * fit)
		back = [entry.get_center().x, entry.get_center().y, entry.get_center().z + entry.size.z * 0.4]
	return {"pieces": out, "joints": {"trigger": front if section == "rear" else back, 
		"front_plug": back, "muzzle": front, "muzzle_plug": back}}


static func _joint(model: Dictionary, name: String, fallback: String = "") -> Vector3:
	var joints: Dictionary = model.get("joints", {})
	return _vec(joints.get(name, joints.get(fallback, [0, 0, 0])))






static func _barrel_links(pieces: Array, barrels: int, spacing: float, voxel: float, weapon: bool, 
		lex: LexiconData) -> Array:
	var group: = AABB()
	var seen: = false


	var main: Dictionary = {}
	var main_volume: = -1.0
	var main_is_barrel: = false
	for piece: Dictionary in pieces:
		if not _replicates(piece, weapon, lex):
			continue
		var box: = _piece_box(piece)
		group = group.merge(box) if seen else box
		seen = true
		var is_barrel: = String(piece.get("tag", "")) == "barrel"
		var volume: = box.get_volume()
		if (is_barrel and not main_is_barrel) or (is_barrel == main_is_barrel and volume > main_volume):
			main = piece
			main_volume = volume
			main_is_barrel = is_barrel
	if not seen:
		return []
	var main_box: = _piece_box(main)
	var thick: = clampf(minf(main_box.size.x, main_box.size.y) * 0.85, voxel, maxf(spacing * 0.7, voxel))
	var color: = String(main.get("color", "#2a2d32"))
	var joint: = Vector3(group.get_center().x, group.get_center().y, group.end.z)
	var links: Array = []
	for i in barrels:
		var side: = (i - (barrels - 1) * 0.5) * spacing
		if absf(side) < 0.0001:
			continue
		var target: = joint + Vector3(side, 0.0, - absf(side) * BARREL_BEND)
		var reach: = absf(target.z - joint.z)
		var c1: = joint + Vector3(0.0, 0.0, - reach * 0.5)
		var c2: = target + Vector3(0.0, 0.0, reach * 0.5)
		var previous: = joint
		for k in range(1, BARREL_LINK_SEGMENTS + 1):
			var t: = float(k) / float(BARREL_LINK_SEGMENTS)
			var point: = joint.bezier_interpolate(c1, c2, target, t)
			var along: = point - previous
			if along.length() > 0.0001:
				var euler: = Basis.looking_at(along.normalized(), Vector3.UP).get_euler() * (180.0 / PI)
				links.append({"shape": "box", "size": [thick, thick, along.length() + thick], 
					"pos": [(previous.x + point.x) * 0.5, (previous.y + point.y) * 0.5, (previous.z + point.z) * 0.5], 
					"rot": [euler.x, euler.y, euler.z], "color": color, "finish": "metal", "tag": "barrel_link", 
					"section": "muzzle", "replicate": false})
			previous = point
	return links



static func _replicates(piece: Dictionary, weapon: bool, lex: LexiconData) -> bool:
	if not bool(piece.get("replicate", true)):
		return false
	return lex.section_of(piece) == "muzzle" if weapon else String(piece.get("tag", "")) == "barrel"





static func build_order(pieces: Array[MeshInstance3D], anchor: Vector3) -> Array[MeshInstance3D]:
	var keyed: Array = []
	for i in pieces.size():
		keyed.append([pieces[i].position.distance_to(anchor), i, pieces[i]])
	keyed.sort_custom( func(a: Array, b: Array) -> bool:
		return a[0] < b[0] - 0.0001 or (absf(a[0] - b[0]) <= 0.0001 and a[1] < b[1]))
	var ordered: Array[MeshInstance3D] = []
	for entry: Array in keyed:
		ordered.append(entry[2])
	return ordered





static func voxel_size(pieces: Array) -> float:
	var first: = true
	var box: = AABB()
	for piece: Dictionary in pieces:
		var piece_box: = _piece_box(piece)
		box = piece_box if first else box.merge(piece_box)
		first = false
	var extent: = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var cfg: Dictionary = Lexicon.bal("blocks", {})
	return clampf(extent / maxf(float(cfg.get("creation_grain", 18.0)), 1.0), float(cfg.get("creation_min_m", 0.004)), 
		float(cfg.get("creation_max_m", 0.25)))




static func piece_mesh(piece: Dictionary, voxel: float = 0.0) -> Mesh:
	if voxel > 0.0:
		var key: = "voxel|%s|%s|%s|%s|%s|%s|%s|%s" % [piece.get("shape", "box"), str(piece.get("size", [])), 
			piece.get("radius", ""), piece.get("height", ""), piece.get("top_radius", ""), piece.get("inner_radius", ""), 
			piece.get("point", ""), snappedf(voxel, 0.0001)]
		if _mesh_cache.has(key):
			return _mesh_cache[key]
		var blocky: = _voxel_mesh(piece, voxel)
		if blocky != null:
			_mesh_cache[key] = blocky
			return blocky
	var shape: = String(piece.get("shape", "box"))
	var radius: = float(piece.get("radius", 0.1))
	var height: = float(piece.get("height", 0.2))
	var top: = float(piece.get("top_radius", radius))
	var inner: = float(piece.get("inner_radius", radius * 0.7))
	var key: = "%s|%s|%s|%s|%s|%s|%s" % [shape, str(piece.get("size", [])), radius, height, top, inner, piece.get("point", 0.5)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var mesh: Mesh
	match shape:
		"cylinder", "cone":
			var cylinder: = CylinderMesh.new()
			cylinder.bottom_radius = radius
			cylinder.top_radius = 0.0 if shape == "cone" else top
			cylinder.height = height
			cylinder.radial_segments = clampi(int(piece.get("radial_segments", ROUND_SEGMENTS)), 3, 64)
			cylinder.rings = 1
			mesh = cylinder
		"sphere":
			var sphere: = SphereMesh.new()
			sphere.radius = radius
			sphere.height = radius * 2.0
			sphere.radial_segments = ROUND_SEGMENTS
			sphere.rings = ROUND_SEGMENTS >> 1
			mesh = sphere
		"torus":
			var torus: = TorusMesh.new()
			torus.inner_radius = inner
			torus.outer_radius = radius
			torus.rings = ROUND_SEGMENTS
			torus.ring_segments = 8
			mesh = torus
		"capsule":
			var capsule: = CapsuleMesh.new()
			capsule.radius = radius
			capsule.height = maxf(height, radius * 2.0)
			capsule.radial_segments = ROUND_SEGMENTS
			capsule.rings = 4
			mesh = capsule
		"wedge":
			mesh = _wedge_mesh(_vec(piece.get("size", [0.02, 0.05, 0.1])), float(piece.get("point", 0.5)))
		_:
			var box: = BoxMesh.new()
			box.size = _vec(piece.get("size", [0.5, 0.5, 0.5]))
			mesh = box
	_mesh_cache[key] = mesh
	return mesh




static func _voxel_mesh(piece: Dictionary, voxel: float) -> Mesh:
	var extent: = _shape_extent(piece)
	var n: = Vector3i(maxi(roundi(extent.x / voxel), 1), maxi(roundi(extent.y / voxel), 1), maxi(roundi(extent.z / voxel), 1))
	if n.x * n.y * n.z > 40000:
		return null
	var cell: = Vector3(extent.x / n.x, extent.y / n.y, extent.z / n.z)
	var start: = - extent * 0.5
	var solid: = PackedByteArray()
	solid.resize(n.x * n.y * n.z)
	var count: = 0
	for x in n.x:
		for y in n.y:
			for z in n.z:
				var center: = start + Vector3(x + 0.5, y + 0.5, z + 0.5) * cell
				if _inside_shape(piece, center):
					solid[(x * n.y + y) * n.z + z] = 1
					count += 1
	if count == 0:
		return null
	var verts: = PackedVector3Array()
	var normals: = PackedVector3Array()
	var colors: = PackedColorArray()
	var indices: = PackedInt32Array()
	var variation: = 0.07
	for x in n.x:
		for y in n.y:
			for z in n.z:
				if solid[(x * n.y + y) * n.z + z] == 0:
					continue

				var wobble: = (fposmod(sin(Vector3(x, y, z).dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453, 1.0) - 0.5) * 2.0
				var shade: = Color(1.0 + wobble * variation, 1.0 + wobble * variation, 1.0 + wobble * variation)
				var lo: = start + Vector3(x, y, z) * cell
				for d in 6:
					var axis: = d >> 1
					var sgn: = 1 if (d & 1) == 1 else -1
					var nb: = Vector3i(x, y, z)
					nb[axis] += sgn
					if nb.x >= 0 and nb.y >= 0 and nb.z >= 0 and nb.x < n.x and nb.y < n.y and nb.z < n.z and solid[(nb.x * n.y + nb.y) * n.z + nb.z] == 1:
						continue
					_voxel_face(verts, normals, colors, indices, lo, cell, axis, sgn, shade)
	var arrays: = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _voxel_face(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, 
		indices: PackedInt32Array, lo: Vector3, cell: Vector3, axis: int, sgn: int, shade: Color) -> void :
	var u: = (axis + 1) % 3
	var v: = (axis + 2) % 3
	var base: = lo
	if sgn > 0:
		base[axis] += cell[axis]
	var du: = Vector3.ZERO
	du[u] = cell[u]
	var dv: = Vector3.ZERO
	dv[v] = cell[v]
	var normal: = Vector3.ZERO
	normal[axis] = float(sgn)
	var first: = verts.size()
	for corner: Vector3 in [base, base + du, base + du + dv, base + dv]:
		verts.append(corner)
		normals.append(normal)
		colors.append(shade)

	if du.cross(dv).dot(normal) < 0.0:
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	else:
		indices.append_array([first, first + 2, first + 1, first, first + 3, first + 2])



static func _shape_extent(piece: Dictionary) -> Vector3:
	var radius: = float(piece.get("radius", 0.1))
	var height: = float(piece.get("height", 0.2))
	match String(piece.get("shape", "box")):
		"cylinder", "cone":
			var r: = maxf(radius, float(piece.get("top_radius", radius)))
			return Vector3(r * 2.0, height, r * 2.0)
		"sphere":
			return Vector3.ONE * radius * 2.0
		"torus":
			var tube: = (radius - float(piece.get("inner_radius", radius * 0.7))) * 0.5
			return Vector3(radius * 2.0, tube * 2.0, radius * 2.0)
		"capsule":
			return Vector3(radius * 2.0, maxf(height, radius * 2.0), radius * 2.0)
		"wedge":
			return _vec(piece.get("size", [0.02, 0.05, 0.1]))
		_:
			return _vec(piece.get("size", [0.5, 0.5, 0.5]))



static func _inside_shape(piece: Dictionary, p: Vector3) -> bool:
	var radius: = float(piece.get("radius", 0.1))
	var height: = float(piece.get("height", 0.2))
	match String(piece.get("shape", "box")):
		"cylinder", "cone":
			if absf(p.y) > height * 0.5:
				return false
			var top: = 0.0 if String(piece.get("shape")) == "cone" else float(piece.get("top_radius", radius))
			var r: = lerpf(radius, top, (p.y + height * 0.5) / maxf(height, 0.0001))
			return Vector2(p.x, p.z).length() <= r
		"sphere":
			return p.length() <= radius
		"torus":
			var inner: = float(piece.get("inner_radius", radius * 0.7))
			var ring: = (radius + inner) * 0.5
			var tube: = (radius - inner) * 0.5
			return pow(Vector2(p.x, p.z).length() - ring, 2.0) + p.y * p.y <= tube * tube
		"capsule":
			var reach: = maxf(maxf(height, radius * 2.0) * 0.5 - radius, 0.0)
			return Vector3(p.x, p.y - clampf(p.y, - reach, reach), p.z).length() <= radius
		"wedge":
			var size: = _vec(piece.get("size", [0.02, 0.05, 0.1]))
			var hy: = size.y * 0.5
			var hz: = size.z * 0.5
			if absf(p.x) > size.x * 0.5 or absf(p.z) > hz:
				return false

			var t: = (hz - p.z) / maxf(size.z, 0.0001)
			var tip_y: = lerpf( - hy, hy, clampf(float(piece.get("point", 0.5)), 0.0, 1.0))
			return p.y >= lerpf( - hy, tip_y, t) and p.y <= lerpf(hy, tip_y, t)
		_:
			return true




static func _wedge_mesh(size: Vector3, point: float) -> Mesh:
	var hx: = size.x * 0.5
	var hy: = size.y * 0.5
	var hz: = size.z * 0.5
	var tip_y: = lerpf( - hy, hy, clampf(point, 0.0, 1.0))
	var corners: = [Vector3(0, - hy, hz), Vector3(0, hy, hz), Vector3(0, tip_y, - hz)]
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for c: Vector3 in corners:
		left.append(c + Vector3( - hx, 0, 0))
		right.append(c + Vector3(hx, 0, 0))
	var triangles: Array = [[left[0], left[2], left[1]], [right[0], right[1], right[2]]]
	for quad in [[0, 1], [1, 2], [2, 0]]:
		var a: int = quad[0]
		var b: int = quad[1]
		triangles.append([left[a], right[a], right[b]])
		triangles.append([left[a], right[b], left[b]])
	var tool: = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	tool.set_smooth_group(-1)
	for tri: Array in triangles:
		for order in [[0, 1, 2], [0, 2, 1]]:
			for i: int in order:
				tool.add_vertex(tri[i])
	tool.generate_normals()
	return tool.commit()



static func piece_material(piece: Dictionary, element: Dictionary, paint: Dictionary = {}) -> StandardMaterial3D:
	var color: = Color.from_string(String(piece.get("color", "#c040c0")), Color.MAGENTA)
	var glow: = float(piece.get("glow", 0.0))
	if not paint.is_empty():
		color = color.lerp(Color.from_string(String(paint.get("tint", "#ffffff")), Color.WHITE), float(paint.get("mix", 0.8)))
		glow += float(paint.get("glow", 0.0))
	if not element.is_empty():
		color = color.lerp(Color.from_string(String(element.get("tint", "#ffffff")), Color.WHITE), float(element.get("mix", 0.5)))
		glow += float(element.get("glow", 0.0))
	var finish: Dictionary = FINISHES.get(String(piece.get("finish", "")), {})
	var key: = "%s|%s|%s|%s|%s" % [color.to_html(), glow, piece.get("finish", ""), 
		element.get("roughness", ""), element.get("metallic", "")]
	if _material_cache.has(key):
		return _material_cache[key]
	var material: = StandardMaterial3D.new()
	material.albedo_color = color

	material.vertex_color_use_as_albedo = true
	material.roughness = float(element.get("roughness", finish.get("roughness", 0.75)))
	material.metallic = float(element.get("metallic", finish.get("metallic", 0.0)))
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_material_cache[key] = material
	return material


static func _piece_width(piece: Dictionary) -> float:
	if piece.has("size"):
		return float((piece["size"] as Array)[0])
	return float(piece.get("radius", 0.1)) * 2.0


static func _vec(values: Variant) -> Vector3:
	var list: Array = values
	return Vector3(float(list[0]), float(list[1]), float(list[2]))
