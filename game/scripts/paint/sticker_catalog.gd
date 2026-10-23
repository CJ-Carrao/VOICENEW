class_name StickerCatalog
extends RefCounted



const FOLDER: = "res://assets/stickers"
const EXTENSIONS: = ["png", "webp", "jpg", "jpeg", "svg"]

static var _paths: Dictionary = {}
static var _images: Dictionary = {}


static func ids() -> PackedStringArray:
	_scan()
	var list: = PackedStringArray(_paths.keys())
	list.sort()
	return list


static func has(id: String) -> bool:
	_scan()
	return _paths.has(id)


static func texture(id: String) -> Texture2D:
	_scan()
	return load(_paths[id]) as Texture2D if _paths.has(id) else null



static func image(id: String) -> Image:
	if _images.has(id):
		return _images[id]
	var source: = texture(id)
	if source == null:
		return null
	var img: = source.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var limit: = int(RobotPaint.config().get("sticker_px", 256))
	var longest: = maxi(img.get_width(), img.get_height())
	if longest > limit:
		img.resize(maxi(1, roundi(img.get_width() * float(limit) / longest)), maxi(1, roundi(img.get_height() * float(limit) / longest)), Image.INTERPOLATE_BILINEAR)
	_images[id] = img
	return img


static func _scan() -> void :
	if not _paths.is_empty():
		return
	for file: String in ResourceLoader.list_directory(FOLDER):
		if EXTENSIONS.has(file.get_extension().to_lower()):
			_paths[file.get_basename()] = FOLDER.path_join(file)
