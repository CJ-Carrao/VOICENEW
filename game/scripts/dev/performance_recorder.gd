class_name PerformanceRecorder
extends Node



var scenario: = "manual"
var duration_s: = 120.0
var warmup_s: = 5.0
var quit_when_done: = false
var automatic: = false
var _driver: Node
var _clock: = 0.0
var _elapsed: = 0.0
var _last_us: = 0
var _sample_start_us: = 0
var _frames: = PackedFloat64Array()
var _all_frames: = PackedFloat64Array()
var _samples: Array[Dictionary] = []
var _started: = false
var _finished: = false
var _ready_scene: Node = null
var _output: = ""
var _compatibility: = {}
var _volume_counts: Dictionary = {}
var _world_cache_stamp: Array[int] = []
var _render_timing_enabled: = false
var _timing_viewport: = RID()
var _render_cpu: = PackedFloat64Array()
var _render_gpu: = PackedFloat64Array()
var _render_setup: = PackedFloat64Array()


static func attach(tree: SceneTree) -> void :
	if not OS.is_debug_build() or tree.root.has_node("PerformanceRecorder"):
		return
	var arguments: = MobileDev.args()
	if not arguments.has("--medir") and not Array(arguments).any( func(a: String) -> bool: return a.begins_with("--medir=")):
		return
	var recorder: = PerformanceRecorder.new()
	recorder.name = "PerformanceRecorder"
	for argument: String in arguments:
		if argument.begins_with("--medir="):
			recorder.scenario = argument.trim_prefix("--medir=").validate_filename().left(80)
		elif argument.begins_with("--medir-segundos="):
			recorder.duration_s = clampf(argument.trim_prefix("--medir-segundos=").to_float(), 1.0, 1800.0)
		elif argument.begins_with("--medir-espera="):
			recorder.warmup_s = clampf(argument.trim_prefix("--medir-espera=").to_float(), 0.0, 300.0)
		elif argument == "--medir-sair":
			recorder.quit_when_done = true
		elif argument == "--medir-auto":
			recorder.automatic = true
	tree.root.add_child(recorder)


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://perf"))
	_output = "user://perf/%s-%s-%d.json" % [scenario, Time.get_datetime_string_from_system().replace(":", "-"), Time.get_ticks_msec()]
	_last_us = Time.get_ticks_usec()
	_compatibility = SessionCompatibility.manifest()
	if DisplayServer.get_name() != "headless":
		_timing_viewport = get_viewport().get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(_timing_viewport, true)
		_render_timing_enabled = true


func _process(_delta: float) -> void :
	if _finished:
		return
	var now: = Time.get_ticks_usec()
	var real_s: = float(now - _last_us) / 1000000.0
	_last_us = now
	if not _started and not _scene_ready():
		_clock = 0.0
		return
	if automatic and _driver == null:
		_driver = (load("res://scripts/dev/performance_scenario.gd") as GDScript).new()
		_driver.configure(scenario, get_tree().current_scene)
		add_child(_driver)
	_clock += real_s
	if _clock < warmup_s:
		return
	if not _started:
		_started = true
		if _driver != null: _driver.begin_measurement()
		_sample_start_us = now
		print("[Perf] iniciando ", scenario, " → ", _output)
		return
	_elapsed += real_s
	_frames.append(real_s * 1000.0)
	_all_frames.append(real_s * 1000.0)
	if _render_timing_enabled:
		_render_cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_timing_viewport))
		var gpu_ms: = RenderingServer.viewport_get_measured_render_time_gpu(_timing_viewport)
		if gpu_ms > 0.0: _render_gpu.append(gpu_ms)
		_render_setup.append(RenderingServer.get_frame_setup_time_cpu())
	if now - _sample_start_us >= 1000000 or _elapsed >= duration_s:
		_sample(now)
	if _elapsed >= duration_s:
		finish()


func _scene_ready() -> bool:
	if scenario.begins_with("menu"):
		var scene: = get_tree().current_scene
		return scene != null and scene.get_script() == load("res://scenes/intro/intro.gd") and float(scene.get("_clock")) >= 29.1
	var scene: = get_tree().current_scene as Match
	if scene == null or scene._waiting_world:
		_ready_scene = null
		return false
	if _ready_scene != scene:
		if not scene.arena.is_world_ready():
			return false
		_ready_scene = scene
	return not Session.is_online() or Session.replication.is_active()


static func frame_stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"frames": 0, "fps_mean": 0.0, "frame_ms_mean": 0.0, "frame_ms_p95": 0.0, "frame_ms_p99": 0.0, "frame_ms_worst": 0.0}
	var sorted: = values.duplicate()
	sorted.sort()
	var total: = 0.0
	for value: float in sorted:
		total += value
	var mean: = total / sorted.size()
	return {"frames": sorted.size(), "fps_mean": 1000.0 / mean if mean > 0.0 else 0.0, 
		"frame_ms_mean": mean, "frame_ms_p95": sorted[ceili(sorted.size() * 0.95) - 1], 
		"frame_ms_p99": sorted[ceili(sorted.size() * 0.99) - 1], "frame_ms_worst": sorted[-1]}


func _sample(now: int) -> void :
	var begin: = Time.get_ticks_usec()
	var sample: = frame_stats(_frames)
	sample["elapsed_s"] = _elapsed
	sample["memory_static_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	sample["video_memory_bytes"] = int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	sample["draw_calls"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	sample["render_objects"] = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	sample["physics_active_objects"] = int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS))
	sample["physics_collision_pairs"] = int(Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS))
	sample["process_ms"] = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	sample["physics_ms"] = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0


	sample["render_cpu_ms"] = _timing_mean(_render_cpu)
	sample["render_gpu_ms"] = _timing_mean(_render_gpu)
	sample["render_setup_cpu_ms"] = _timing_mean(_render_setup)
	sample["render_gpu_frames"] = _render_gpu.size()
	sample["render_cpu_frames"] = _render_cpu.size()
	sample["render_gpu_ms_p95"] = frame_stats(_render_gpu).frame_ms_p95 if not _render_gpu.is_empty() else null
	sample["render_cpu_ms_p95"] = frame_stats(_render_cpu).frame_ms_p95 if not _render_cpu.is_empty() else null
	var cells: = 0
	var meshes: = 0
	var volumes: = 0
	var pending: = 0
	var block_process_ms: = 0.0
	var count_rescans: = 0
	var live_volumes: = {}
	_invalidate_world_cache_if_changed()
	for node: Node in get_tree().get_nodes_in_group(BlockVolume.GROUP):
		var volume: = node as BlockVolume
		if volume == null:
			continue
		volumes += 1
		var id: = volume.get_instance_id()
		live_volumes[id] = true
		if not _volume_counts.has(id):
			_volume_counts[id] = volume.blocks.size() - volume.blocks.count(BlockVolume.AIR)
			count_rescans += 1
		var invalidate: = _invalidate_volume.bind(id)
		if not volume.cells_changed.is_connected(invalidate):
			volume.cells_changed.connect(invalidate)
		cells += int(_volume_counts[id])
		pending += volume._dirty.size() + volume._ready_chunks.size()
		block_process_ms += volume.last_process_ms
		for part: Dictionary in volume._parts.values():
			if is_instance_valid(part.mesh) and (part.mesh as MeshInstance3D).mesh != null:
				meshes += 1
	for id: int in _volume_counts.keys():
		if not live_volumes.has(id):
			_volume_counts.erase(id)
	sample.merge({"world_volumes": volumes, "world_solid_blocks": cells, "world_chunk_meshes": meshes, 
		"world_pending_chunks": pending, "world_process_ms": block_process_ms, "world_count_rescans": count_rescans})
	sample["collector_ms"] = float(Time.get_ticks_usec() - begin) / 1000.0
	_samples.append(sample)
	_frames.clear()
	_render_cpu.clear()
	_render_gpu.clear()
	_render_setup.clear()
	_sample_start_us = now
	if _samples.size() == 1 or _samples.size() % 15 == 0:
		_save(false)


func _invalidate_volume(_changes: Dictionary, id: int) -> void :
	_volume_counts.erase(id)


func _invalidate_world_cache_if_changed() -> void :



	var sync: = Session.world_sync
	var stamp: Array[int] = [Session.generation, sync.epoch, sync.revision, sync._received]
	if stamp != _world_cache_stamp:
		_world_cache_stamp = stamp
		_volume_counts.clear()


static func _timing_mean(values: PackedFloat64Array) -> Variant:
	if values.is_empty(): return null
	var total: = 0.0
	for value: float in values: total += value
	return total / values.size()


func _save(complete: bool) -> void :
	var summary: = frame_stats(_all_frames)
	var video: = {}
	for key: String in VideoSettings.DEFAULTS:
		video[key] = VideoSettings.value(key)
	var report: = {"schema": 1, "scenario": scenario, "complete": complete, "elapsed_s": _elapsed, 
		"requested_duration_s": duration_s, "warmup_s": warmup_s, "summary": summary, "samples": _samples, 
		"platform": OS.get_name(), "engine": Engine.get_version_info().string, 
		"renderer": RenderingServer.get_current_rendering_method(), "video_preset": VideoSettings.current_preset(), 
		"video": video, "compatibility": _compatibility, 
		"memory_note": "memory_static_bytes = alocador Godot; PSS e térmica são coletados separadamente pelo adb", 
		"activity_verified": false}
	var viewport: = get_viewport()
	var size: = viewport.get_visible_rect().size
	report["video_effective"] = {"viewport_size_px": [size.x, size.y], "aspect_ratio": size.x / maxf(size.y, 1.0), 
		"render_scale": viewport.scaling_3d_scale, "scaling_3d_mode": viewport.scaling_3d_mode, 
		"upscaler": {0: "bilinear", 1: "fsr1", 2: "fsr2"}.get(viewport.scaling_3d_mode, "other"), 
		"upscaler_supported_by_renderer": viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR or RenderingServer.get_current_rendering_method() == "forward_plus", 
		"upscaler_note": "Propriedade lida do Viewport; se unsupported, não comprova execução do upscaler. Android seleciona bilinear explicitamente.", 
		"msaa_3d": viewport.msaa_3d, "screen_space_aa": viewport.screen_space_aa, "taa": viewport.use_taa}
	report["render_timing_note"] = "RenderingServer: média/p95 dos timestamps por intervalo; setup CPU separado; GPU indisponível e headless são null. Tempos podem se sobrepor e não devem ser somados."
	if _driver != null:
		report["activity"] = _driver.snapshot()
		report["activity_verified"] = complete and bool(report.activity.activity_verified)
	var payload: = JSON.stringify(report, "\t")
	var tmp_path: = _output + ".tmp"
	var file: = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file != null:
		file.store_string(payload)
		file.close()
		var abs_tmp: = ProjectSettings.globalize_path(tmp_path)
		var abs_out: = ProjectSettings.globalize_path(_output)
		if DirAccess.rename_absolute(abs_tmp, abs_out) != OK:
			DirAccess.remove_absolute(abs_out)
			if DirAccess.rename_absolute(abs_tmp, abs_out) != OK:
				DirAccess.remove_absolute(abs_tmp)
				var direct: = FileAccess.open(_output, FileAccess.WRITE)
				if direct != null:
					direct.store_string(payload)
	else:
		var direct: = FileAccess.open(_output, FileAccess.WRITE)
		if direct != null:
			direct.store_string(payload)


func finish() -> void :
	if _finished:
		return
	_finished = true
	if _driver != null: _driver.stop()
	_stop_render_timing()
	_save(true)
	print("[Perf] concluído ", _output, ": ", JSON.stringify(frame_stats(_all_frames)))
	if quit_when_done:
		get_tree().quit()


func _stop_render_timing() -> void :
	if _render_timing_enabled:
		RenderingServer.viewport_set_measure_render_time(_timing_viewport, false)
		_render_timing_enabled = false


func _exit_tree() -> void :
	if _started and not _finished:
		_save(false)
	_stop_render_timing()
