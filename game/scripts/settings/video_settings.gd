class_name VideoSettings
extends RefCounted








const META: = "lavoice_video_original"

const FX_LIGHT: = "lavoice_fx_light"

const DEFAULTS: = {
	"window_mode": "fullscreen", "resolution": "1920x1080", "vsync": true, "max_fps": 0, 
	"render_scale": 1.0, "upscaler": "fsr", "antialias": "fxaa", "shadows": "high", 
	"glow": true, "ssao": false, "effects": "full", "lod": "normal", 
	"fov": 80.0, "brightness": 1.0, "show_fps": false, 
}

const PRESETS: = {
	"low": {"render_scale": 0.7, "upscaler": "fsr", "antialias": "off", "shadows": "off", "glow": false, 
		"ssao": false, "effects": "reduced", "lod": "low"}, 
	"medium": {"render_scale": 0.85, "upscaler": "fsr", "antialias": "fxaa", "shadows": "low", "glow": true, 
		"ssao": false, "effects": "full", "lod": "normal"}, 
	"high": {"render_scale": 1.0, "upscaler": "fsr", "antialias": "fxaa", "shadows": "high", "glow": true, 
		"ssao": false, "effects": "full", "lod": "normal"}, 
	"ultra": {"render_scale": 1.0, "upscaler": "fsr", "antialias": "msaa4", "shadows": "ultra", "glow": true, 
		"ssao": true, "effects": "full", "lod": "high"}, 
}
const PRESET_ORDER: = ["low", "medium", "high", "ultra"]
const PRESET_NAMES: = {"low": "BAIXO", "medium": "MÉDIO", "high": "ALTO", "ultra": "ULTRA"}


const WINDOW_MODES: = [["windowed", "Janela"], ["fullscreen", "Tela cheia (sem bordas)"], ["exclusive", "Tela cheia exclusiva"]]
const RESOLUTIONS: = ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const FPS_LIMITS: = [0, 30, 60, 75, 120, 144, 165, 240]
const UPSCALERS: = [["bilinear", "Bilinear"], ["fsr", "AMD FSR 1.0"], ["fsr2", "AMD FSR 2.2"]]
const ANTIALIAS: = [["off", "Desligada"], ["fxaa", "FXAA"], ["msaa2", "MSAA 2×"], ["msaa4", "MSAA 4×"], ["taa", "TAA"]]
const SHADOWS: = [["off", "Desligadas"], ["low", "Baixas"], ["medium", "Médias"], ["high", "Altas"], ["ultra", "Ultra"]]
const EFFECTS: = [["full", "Completos"], ["reduced", "Reduzidos"]]
const LODS: = [["high", "Alto"], ["normal", "Normal"], ["low", "Baixo"]]

const SHADOW_SPECS: = {
	"off": [1024, 0, RenderingServer.SHADOW_QUALITY_HARD], 
	"low": [1024, 1024, RenderingServer.SHADOW_QUALITY_HARD], 
	"medium": [2048, 2048, RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW], 
	"high": [4096, 4096, RenderingServer.SHADOW_QUALITY_SOFT_LOW], 
	"ultra": [8192, 4096, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM], 
}
const LOD_THRESHOLDS: = {"high": 0.5, "normal": 1.0, "low": 4.0}
const REDUCED_PARTICLES: = 0.4

static var _tree: SceneTree
static var _fps_overlay: CanvasLayer


static func value(key: String) -> Variant:
	var stored: Variant = UserSettings.get_value("video", key, DEFAULTS[key])
	return stored if typeof(stored) == typeof(DEFAULTS[key]) or (stored is int and DEFAULTS[key] is float) else DEFAULTS[key]


static func set_value(key: String, new_value: Variant) -> void :
	UserSettings.set_value("video", key, new_value)
	if key in ["window_mode", "resolution", "vsync"]:
		apply_display()
	else:
		apply_render()



static func apply_preset(id: String) -> void :
	for key: String in PRESETS[id]:
		UserSettings._file().set_value("video", key, PRESETS[id][key])
	UserSettings._file().save(UserSettings.PATH)
	apply_render()



static func current_preset() -> String:
	for id: String in PRESET_ORDER:
		var same: = true
		for key: String in PRESETS[id]:
			var want: Variant = PRESETS[id][key]
			if (want is float and not is_equal_approx(float(value(key)), want)) or ( not want is float and value(key) != want):
				same = false
				break
		if same:
			return id
	return ""


static func fov() -> float:
	return clampf(float(value("fov")), 60.0, 120.0)



static func start(tree: SceneTree) -> void :
	if _tree != tree:
		_tree = tree
		tree.node_added.connect(Callable(VideoSettings, "_on_node_added"))
	apply_render()


static func apply_display() -> void :
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(value("vsync")) else DisplayServer.VSYNC_DISABLED)
	match String(value("window_mode")):
		"windowed":
			if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size: = window_size()
			DisplayServer.window_set_size(size)
			var screen: = DisplayServer.screen_get_usable_rect()
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
		"exclusive":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)



static func window_size() -> Vector2i:
	var parts: = String(value("resolution")).split("x")
	var size: = Vector2i(1920, 1080)
	if parts.size() == 2:
		size = Vector2i(maxi(640, parts[0].to_int()), maxi(360, parts[1].to_int()))
	if DisplayServer.get_name() != "headless":
		var screen: = DisplayServer.screen_get_usable_rect().size
		size = Vector2i(mini(size.x, screen.x), mini(size.y, screen.y))
	return size



static func resolutions() -> PackedStringArray:
	var out: = PackedStringArray()
	var screen: = Vector2i(100000, 100000) if DisplayServer.get_name() == "headless" else DisplayServer.screen_get_size()
	for entry: String in RESOLUTIONS:
		var parts: = entry.split("x")
		if parts[0].to_int() <= screen.x and parts[1].to_int() <= screen.y:
			out.append(entry)
	if out.is_empty():
		out.append(RESOLUTIONS[0])
	return out


static func apply_render() -> void :
	Engine.max_fps = int(value("max_fps"))
	var shadow: Array = SHADOW_SPECS.get(String(value("shadows")), SHADOW_SPECS.high)
	RenderingServer.directional_shadow_atlas_set_size(int(shadow[0]), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow[2])
	RenderingServer.positional_soft_shadow_filter_set_quality(shadow[2])
	if _tree == null:
		return
	_apply_viewport(_tree.root, true)
	for node: Node in _tree.root.find_children("*", "", true, false):
		_touch(node)
	_update_fps_overlay()


static func _on_node_added(node: Node) -> void :

	_touch(node)
	if node is WorldEnvironment or node is Light3D:

		Callable(VideoSettings, "_touch_id").call_deferred(node.get_instance_id())


static func _touch_id(id: int) -> void :
	var node: = instance_from_id(id) as Node
	if node != null:
		_touch(node)


static func _touch(node: Node) -> void :
	if not is_instance_valid(node):
		return
	if node is SubViewport:
		_apply_viewport(node as Viewport, false)
	elif node is WorldEnvironment:
		_apply_environment((node as WorldEnvironment).environment)
	elif node is Light3D:
		_apply_light(node as Light3D)
	elif node is CPUParticles3D or node is GPUParticles3D:
		_apply_particles(node)


static func _apply_viewport(viewport: Viewport, root: bool) -> void :
	var aa: = String(value("antialias"))
	viewport.msaa_3d = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X}.get(aa, Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if aa == "fxaa" else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = aa == "taa"
	viewport.mesh_lod_threshold = float(LOD_THRESHOLDS.get(String(value("lod")), 1.0))
	viewport.positional_shadow_atlas_size = int((SHADOW_SPECS.get(String(value("shadows")), SHADOW_SPECS.high) as Array)[1])
	if not root:
		return

	var scale: = clampf(float(value("render_scale")), 0.5, 1.0)
	viewport.scaling_3d_scale = scale
	match String(value("upscaler")):
		"fsr2":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		"fsr":
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		_:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


static func _apply_environment(env: Environment) -> void :
	if env == null:
		return
	var original: Dictionary = _original(env, {"glow": env.glow_enabled, "ssao": env.ssao_enabled, "exposure": env.tonemap_exposure})
	env.glow_enabled = bool(original.glow) and bool(value("glow"))
	env.ssao_enabled = bool(original.ssao) or bool(value("ssao"))
	env.tonemap_exposure = float(original.exposure) * clampf(float(value("brightness")), 0.5, 1.5)


static func _apply_light(light: Light3D) -> void :
	var original: Dictionary = _original(light, {"shadow": light.shadow_enabled, "visible": light.visible})
	light.shadow_enabled = bool(original.shadow) and String(value("shadows")) != "off"
	if light.has_meta(FX_LIGHT):
		light.visible = bool(original.visible) and String(value("effects")) != "reduced"


static func _apply_particles(node: Node) -> void :
	var original: Dictionary = _original(node, {"amount": int(node.get("amount"))})
	var amount: = int(original.amount)
	if String(value("effects")) == "reduced":
		amount = maxi(1, roundi(amount * REDUCED_PARTICLES))
	if int(node.get("amount")) != amount:
		node.set("amount", amount)


static func _original(object: Object, current: Dictionary) -> Dictionary:
	if not object.has_meta(META):
		object.set_meta(META, current)
	return object.get_meta(META)


static func _update_fps_overlay() -> void :
	var show: = bool(value("show_fps"))
	if show and not is_instance_valid(_fps_overlay) and _tree != null:
		_fps_overlay = FpsOverlay.new()
		_tree.root.add_child.call_deferred(_fps_overlay)
	elif not show and is_instance_valid(_fps_overlay):
		_fps_overlay.queue_free()
		_fps_overlay = null
