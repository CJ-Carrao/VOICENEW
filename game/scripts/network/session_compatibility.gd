class_name SessionCompatibility
extends RefCounted




const PROTOCOL_VERSION: = 20

const GAMEPLAY_VERSION: = "block-steps-20"


static func manifest(data_root: String = "res://data", character_root: String = "") -> Dictionary:
	var paths: Array[String] = []
	_collect_json(data_root, "", paths)
	paths.sort()
	if paths.is_empty():
		return {"error": "O catálogo de dados está vazio ou indisponível."}
	var hash: = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for relative_path in paths:
		var path: = data_root.path_join(relative_path)
		var file: = FileAccess.open(path, FileAccess.READ)
		if file == null:
			return {"error": "Não foi possível ler os dados de compatibilidade: " + relative_path}
		var bytes: = file.get_buffer(file.get_length())
		_hash_file(hash, relative_path, bytes)
	var files: = paths.size()


	if character_root.is_empty() and data_root == "res://data":
		character_root = "res://assets/characters/lavoice"
	if not character_root.is_empty():
		var character: = _hash_character_assets(hash, character_root)
		if character.has("error"):
			return character
		files += int(character.files)
	var settings: Dictionary = {}
	for property in ProjectSettings.get_property_list():
		var setting_name: = str(property.name)
		if setting_name.begins_with("physics/") or setting_name.begins_with("layer_names/3d_physics/"):
			settings[setting_name] = ProjectSettings.get_setting(setting_name)
	hash.update(JSON.stringify(settings, "", true).to_utf8_buffer())
	var engine: = Engine.get_version_info()
	return {
		"protocol": PROTOCOL_VERSION, 
		"gameplay": GAMEPLAY_VERSION, 
		"engine": "%s.%s.%s" % [engine.major, engine.minor, engine.patch], 
		"content": hash.finish().hex_encode(), 
		"files": files, 
	}


static func _hash_file(hash: HashingContext, relative_path: String, bytes: PackedByteArray) -> void :

	hash.update((relative_path + "\n" + str(bytes.size()) + "\n").to_utf8_buffer())
	hash.update(bytes)


static func _hash_character_assets(hash: HashingContext, root: String) -> Dictionary:
	for name in ["clips.json", "rosto.json"]:
		var file: = FileAccess.open(root.path_join(name), FileAccess.READ)
		if file == null:
			return {"error": "Metadados do robô indisponíveis: " + name}
		_hash_file(hash, "character/" + name, file.get_buffer(file.get_length()))
	var report_path: = root.path_join("validacao.json")
	if not FileAccess.file_exists(report_path):
		return {"error": "Checksum publicado do modelo do robô indisponível."}
	var report: Variant = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not report is Dictionary or not report.get("glb_sha256") is String:
		return {"error": "Checksum publicado do modelo do robô inválido."}
	var checksum: String = report.glb_sha256
	if checksum.length() != 64 or not checksum.is_valid_hex_number(false):
		return {"error": "Checksum publicado do modelo do robô inválido."}
	checksum = checksum.to_lower()
	var model_path: = root.path_join("LAVOICE_base.glb")



	if FileAccess.file_exists(model_path) and FileAccess.get_sha256(model_path) != checksum:
		return {"error": "O modelo do robô mudou sem atualizar seu checksum em validacao.json."}
	_hash_file(hash, "character/LAVOICE_base.glb.sha256", checksum.to_utf8_buffer())
	return {"files": 4}


static func mismatch(local_manifest: Dictionary, remote_manifest: Dictionary) -> String:
	for key in ["protocol", "gameplay", "engine", "content", "files"]:
		var remote_value: Variant = remote_manifest.get(key)
		var local_value: Variant = local_manifest.get(key)
		var same_type: = typeof(remote_value) == typeof(local_value)

		if key in ["protocol", "files"]:
			same_type = typeof(remote_value) in [TYPE_INT, TYPE_FLOAT]
		if not same_type or remote_value != local_value:
			return "Versões incompatíveis (%s). Host e cliente precisam da mesma versão do jogo e dos dados." % key
	return ""


static func _collect_json(root: String, relative: String, result: Array[String]) -> void :
	var directory: = DirAccess.open(root.path_join(relative))
	if directory == null:
		return
	for child in directory.get_directories():
		_collect_json(root, relative.path_join(child), result)
	for child in directory.get_files():
		if child.ends_with(".json"):
			result.append(relative.path_join(child))
