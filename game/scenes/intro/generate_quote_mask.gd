extends SceneTree


func _initialize() -> void :
	call_deferred("generate")

func generate() -> void :
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/intro.json"))
	var q: Dictionary = cfg["quote"]
	var source: Dictionary = cfg["cinematic"]["quote_matter"]
	var density: = int(source["mask_scale"])
	var padding: = int(source["mask_padding_px"]) * density
	var font: = FontVariation.new()
	font.base_font = load(String(cfg["font"]))
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): int(q["weight"])}
	var font_size: = int(q["size"]) * density
	var text: = String(q["lines"][int(q["accent_line"])])
	var extent: = Vector2(ceilf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x), ceilf(font.get_height(font_size)))
	var viewport: = SubViewport.new()
	viewport.size = Vector2i(extent) + Vector2i.ONE * padding * 2
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	var label: = Label.new()
	label.text = text
	label.position = Vector2.ONE * padding
	var style: = LabelSettings.new()
	style.font = font
	style.font_size = font_size
	style.font_color = Color.WHITE
	label.label_settings = style
	viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	var picture: = viewport.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://assets/intro/fx")
	var result: = picture.save_png(String(source["mask"]))
	print("QUOTE_MASK ", result, " ", picture.get_size())
	viewport.queue_free()
	await process_frame
	quit(int(result))
