class_name StickerCatalog
extends RefCounted






static var folder: = "user://stickers"
const STICKER_PX: = 256

const MAX_BYTES: = 20000

const MAX_LIBRARY: = 40

const MAX_SOURCE_BYTES: = 20 * 1024 * 1024
const MAX_SOURCE_PX: = 8192


static var _bytes: Dictionary = {}
static var _textures: Dictionary = {}
static var _images: Dictionary = {}

static var _local: Dictionary = {}
static var _scanned: = false

static var last_error: = ""


static func ids() -> PackedStringArray:
	_scan()
	var list: = PackedStringArray(_local.keys())
	list.sort()
	return list


static func has(id: String) -> bool:
	_scan()
	return _bytes.has(id)


static func is_local(id: String) -> bool:
	_scan()
	return _local.has(id)


static func bytes(id: String) -> PackedByteArray:
	_scan()
	return _bytes.get(id, PackedByteArray())


static func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var img: = image(id)
	if img == null:
		return null
	_textures[id] = ImageTexture.create_from_image(img)
	return _textures[id]



static func image(id: String) -> Image:
	if _images.has(id):
		return _images[id]
	_scan()
	if not _bytes.has(id):
		return null
	var img: = Image.new()
	if img.load_webp_from_buffer(_bytes[id]) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	_images[id] = img
	return img




static func import_file(path: String) -> String:
	last_error = ""
	var file: = FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "não deu pra abrir o arquivo"
		return ""
	if file.get_length() > MAX_SOURCE_BYTES:
		last_error = "imagem grande demais (máx. 20 MB)"
		return ""
	var data: = file.get_buffer(file.get_length())
	file.close()
	var img: = Image.new()
	var error: = ERR_FILE_UNRECOGNIZED
	if data.size() > 8 and data.slice(0, 8) == PackedByteArray([137, 80, 78, 71, 13, 10, 26, 10]):
		error = img.load_png_from_buffer(data)
	elif data.size() > 3 and data[0] == 255 and data[1] == 216 and data[2] == 255:
		error = img.load_jpg_from_buffer(data)
	elif data.size() > 12 and data.slice(0, 4).get_string_from_ascii() == "RIFF" and data.slice(8, 12).get_string_from_ascii() == "WEBP":
		error = img.load_webp_from_buffer(data)
	if error != OK or img.is_empty():
		last_error = "formato não suportado (use PNG, JPG ou WebP)"
		return ""
	return import_image(img)



static func import_image(source: Image) -> String:
	last_error = ""
	_scan()
	if _local.size() >= MAX_LIBRARY:
		last_error = "gaveta cheia (%d figurinhas): apague alguma" % MAX_LIBRARY
		return ""
	if source.get_width() > MAX_SOURCE_PX or source.get_height() > MAX_SOURCE_PX:
		last_error = "imagem grande demais"
		return ""
	var img: = source.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var longest: = maxi(img.get_width(), img.get_height())
	if longest > STICKER_PX:
		img.resize(maxi(1, roundi(img.get_width() * float(STICKER_PX) / longest)), 
			maxi(1, roundi(img.get_height() * float(STICKER_PX) / longest)), Image.INTERPOLATE_LANCZOS)
	var encoded: = PackedByteArray()
	for quality: float in [0.85, 0.75, 0.6, 0.45, 0.3]:
		encoded = img.save_webp_to_buffer(true, quality)
		if encoded.size() <= MAX_BYTES:
			break
	if encoded.is_empty() or encoded.size() > MAX_BYTES:
		last_error = "não deu pra reduzir a imagem"
		return ""
	var id: = id_of(encoded)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file: = FileAccess.open(folder.path_join(id + ".webp"), FileAccess.WRITE)
	if file == null:
		last_error = "não deu pra salvar"
		return ""
	file.store_buffer(encoded)
	file.close()
	_bytes[id] = encoded
	_local[id] = true
	return id



static func remove(id: String) -> void :
	_scan()
	if not _local.has(id):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder.path_join(id + ".webp")))
	_local.erase(id)
	_bytes.erase(id)
	_images.erase(id)
	_textures.erase(id)




static func accept_remote(id: String, data: Variant) -> bool:
	if not data is PackedByteArray:
		return false
	var encoded: = data as PackedByteArray
	if encoded.is_empty() or encoded.size() > MAX_BYTES or id != id_of(encoded):
		return false
	_scan()
	if _bytes.has(id):
		return true
	var img: = Image.new()
	if img.load_webp_from_buffer(encoded) != OK or img.get_width() > STICKER_PX or img.get_height() > STICKER_PX:
		return false
	_bytes[id] = encoded
	return true


static func id_of(encoded: PackedByteArray) -> String:
	var hashing: = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(encoded)
	return "u" + hashing.finish().hex_encode().left(16)


static func _scan() -> void :
	if _scanned:
		return
	_scanned = true
	var dir: = DirAccess.open(folder)
	if dir == null:
		return
	for file: String in dir.get_files():
		if file.get_extension().to_lower() != "webp":
			continue
		var encoded: = FileAccess.get_file_as_bytes(folder.path_join(file))
		var id: = file.get_basename()

		if encoded.size() <= MAX_BYTES and id == id_of(encoded):
			_bytes[id] = encoded
			_local[id] = true



static func reset_for_test() -> void :
	_bytes.clear()
	_textures.clear()
	_images.clear()
	_local.clear()
	_scanned = false
