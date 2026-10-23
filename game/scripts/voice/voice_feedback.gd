class_name VoiceFeedback
extends RefCounted



const DIRECTORY: = "user://voice_logs"
const MAX_FILE_BYTES: = 2 * 1024 * 1024
static var _session: String = ""
static var _part: int = 1


static func enabled() -> bool:
	return bool(UserSettings.get_value("voice", "save_text_log", true))


static func folder_path() -> String:
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	return ProjectSettings.globalize_path(DIRECTORY)


static func record(text: String, result: Dictionary, seconds: float, quality: String, matter_before: float) -> void :
	if not enabled() or text.strip_edges().is_empty():
		return
	if DirAccess.make_dir_recursive_absolute(DIRECTORY) != OK:
		push_warning("[Voz] Não foi possível criar a pasta dos registros de texto.")
		return
	if _session.is_empty():
		_session = "falas-%s-%d" % [Time.get_datetime_string_from_system().replace(":", "-"), OS.get_process_id()]
	var path: = _path()
	var file: FileAccess
	if FileAccess.file_exists(path):
		file = FileAccess.open(path, FileAccess.READ_WRITE)
		if file != null and file.get_length() >= MAX_FILE_BYTES:
			file.close()
			_part += 1
			path = _path()
			file = FileAccess.open(path, FileAccess.WRITE)
	else:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[Voz] Não foi possível salvar o registro de texto.")
		return
	file.seek_end()
	if file.get_length() == 0:
		file.store_string("LAVOICE — REGISTRO DE FALAS RECONHECIDAS\nSó texto dos pedidos falados na partida. Não contém áudio.\nEnvio manual: revise o conteúdo antes de compartilhar.\nHorários locais; fuso: %s.\nO texto reconhecido pode ser diferente do que a pessoa realmente falou.\n\n" % str(Time.get_time_zone_from_system()))
	file.store_string(format_entry(text, result, seconds, quality, matter_before))
	file.close()


static func format_entry(text: String, result: Dictionary, seconds: float, quality: String, matter_before: float) -> String:
	var lines: = PackedStringArray([
		"[%s]" % Time.get_datetime_string_from_system(), 
		"Fala reconhecida: " + JSON.stringify(text), 
		"Resultado: " + ("ENTENDIDO" if result.get("ok", false) else "NÃO ENTENDIDO"), 
		"Interpretação: " + String(result.get("pretty", "")), 
		"Motor de voz: %s | reconhecimento: %.2f s | léxico: %s" % [quality, seconds, result.get("lexicon_version", "")], 
	])
	for key in ["unknown_words", "corrections", "ignored_words", "notes", "warnings", "unsupported"]:
		var values: Array = result.get(key, [])
		if not values.is_empty():
			var labels: = {"unknown_words": "Palavras desconhecidas", "corrections": "Correções do ouvido", 
				"ignored_words": "Palavras ignoradas", "notes": "Atalhos", "warnings": "Avisos", "unsupported": "Comportamentos não implementados"}
			lines.append("%s: %s" % [labels[key], JSON.stringify(values)])
	if result.get("ok", false):
		lines.append("Matéria antes do pedido: %.1f | custo estimado: %.1f | matéria recuperada da mão: %.1f" % [
			matter_before, float(result.get("cost", 0.0)), float(result.get("transmuted_matter", 0.0))])
		if result.get("draft", false):
			lines.append("Situação: rascunho aguardando forma e confirmação do jogador.")
		elif float(result.get("cost", 0.0)) > matter_before + float(result.get("transmuted_matter", 0.0)) + 0.01:
			lines.append("Matéria inicial insuficiente para o custo total; isso não significa que o pedido não existe no jogo.")
		lines.append("Entendido indica a interpretação inicial, não a conclusão da montagem.")
	return "\n".join(lines) + "\n\n"


static func _path() -> String:
	return DIRECTORY.path_join("%s-parte%d.txt" % [_session, _part])
