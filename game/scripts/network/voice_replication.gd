class_name VoiceReplication
extends Node






signal voice_received(speaker_id: int, samples: PackedFloat32Array)

const CONFIG_PATH: = "res://data/network.json"
const MAX_STORED_SAMPLES: = 160000
const SPURT_TIMEOUT_MS: = 250

class ReceiveStream extends RefCounted:
	var sequence: = 0
	var queue: Array[PackedFloat32Array] = []
	var draining: = false
	var spurt_open: = false
	var last_sample: = 0.0
	var last_packet_ms: = 0
	var tokens: = 0.0
	var budget_ms: = 0
	var drained_frame_id: = -1
	var drained_in_frame: = 0
	var player: AudioStreamPlayer
	var playback: AudioStreamGeneratorPlayback
	var packets: = 0
	var played_samples: = 0
	var peak_rms: = 0.0

var epoch: int = 0
var active_speaker: int = 0
var last_received_rms: float = 0.0
var received_samples: = PackedFloat32Array()
var stats: Dictionary = {
	"sent_packets": 0, 
	"sent_bytes": 0, 
	"received_packets": 0, 
	"received_bytes": 0, 
	"played_samples": 0, 
	"rejected": 0, 
	"stale_packets": 0, 
	"lost_packets": 0, 
	"plc_frames": 0, 
	"dropped_overflow": 0, 
	"underruns": 0, 
	"max_packet_bytes": 0, 
	"relayed_packets": 0, 
}

var _session: NetworkSession
var _world: Match
var _config_valid: = false
var _sample_rate: = 16000
var _frame_samples: = 320
var _max_packet_bytes: = 900
var _packets_per_second: = 60.0
var _packet_burst: = 80.0
var _max_sequence_lead: = 300
var _jitter_buffer_frames: = 3
var _max_buffer_frames: = 25
var _max_plc_frames: = 2

var _generation: = -1
var _send_seq: = 0
var _tx_active: = false
var _tx_buffer: = PackedFloat32Array()
var _streams: Dictionary = {}


func _ready() -> void :
	_session = get_parent() as NetworkSession
	process_mode = Node.PROCESS_MODE_ALWAYS
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	var cfg: Dictionary = parsed.get("voip", {}) if parsed is Dictionary and parsed.get("voip") is Dictionary else {}
	_config_valid = _load_config(cfg)
	_session.changed.connect(_on_session_changed)
	_on_session_changed()


func _load_config(cfg: Dictionary) -> bool:
	for key in ["sample_rate", "frame_samples", "max_packet_bytes", "packets_per_second", 
			"packet_burst", "max_sequence_lead", "jitter_buffer_frames", "max_buffer_frames", "max_plc_frames"]:
		var val: Variant = cfg.get(key)
		if not (val is int or val is float) or not is_finite(float(val)):
			return false
	_sample_rate = int(cfg["sample_rate"])
	_frame_samples = int(cfg["frame_samples"])
	_max_packet_bytes = int(cfg["max_packet_bytes"])
	_packets_per_second = float(cfg["packets_per_second"])
	_packet_burst = float(cfg["packet_burst"])
	_max_sequence_lead = int(cfg["max_sequence_lead"])
	_jitter_buffer_frames = int(cfg["jitter_buffer_frames"])
	_max_buffer_frames = int(cfg["max_buffer_frames"])
	_max_plc_frames = int(cfg["max_plc_frames"])
	if _sample_rate != SpeechEngine.SAMPLE_RATE or _frame_samples < 80 or _frame_samples > 480:
		return false
	if _max_packet_bytes < _frame_samples * 2 or _max_packet_bytes > 1000:
		return false
	if _packets_per_second <= 0.0 or _packet_burst < 1.0 or _max_sequence_lead < 10:
		return false
	if _jitter_buffer_frames < 1 or _max_buffer_frames < _jitter_buffer_frames or _max_plc_frames < 0:
		return false
	return true


func bind_world(world: Match) -> void :
	if _world == world:
		return
	unbind_world()
	if not _config_valid:
		_session.stop_online("Configuração de voz em rede indisponível.")
		return
	_world = world
	_world.arena.world_reset.connect(_on_world_reset)
	_world.state_changed.connect(_on_world_state_changed)
	if _world.voice != null:
		_world.voice.voip_started.connect(_on_voip_started)
		_world.voice.voip_frames.connect(_on_voip_frames)
		_world.voice.voip_ended.connect(_on_voip_ended)
	_reset_stream_state()


func unbind_world(world: Match = null) -> void :
	if world != null and world != _world:
		return
	if is_instance_valid(_world):
		if _world.arena != null and _world.arena.world_reset.is_connected(_on_world_reset):
			_world.arena.world_reset.disconnect(_on_world_reset)
		if _world.state_changed.is_connected(_on_world_state_changed):
			_world.state_changed.disconnect(_on_world_state_changed)
		if _world.voice != null:
			if _world.voice.voip_started.is_connected(_on_voip_started):
				_world.voice.voip_started.disconnect(_on_voip_started)
			if _world.voice.voip_frames.is_connected(_on_voip_frames):
				_world.voice.voip_frames.disconnect(_on_voip_frames)
			if _world.voice.voip_ended.is_connected(_on_voip_ended):
				_world.voice.voip_ended.disconnect(_on_voip_ended)
	_world = null
	_reset_stream_state()


func speaker_stats(speaker_id: int) -> Dictionary:
	var stream: ReceiveStream = _streams.get(speaker_id)
	if stream == null:
		return {}
	return {"packets": stream.packets, "played_samples": stream.played_samples, 
		"peak_rms": stream.peak_rms, "sequence": stream.sequence, "queued_frames": stream.queue.size()}


func _process(_delta: float) -> void :
	if not is_instance_valid(_world) or not _session.is_online():
		return
	var current_ep: = _current_epoch()
	if current_ep != epoch:
		epoch = current_ep
		_reset_stream_state()
		return
	active_speaker = 0
	for speaker_id: int in _streams:
		var stream: ReceiveStream = _streams[speaker_id]
		if stream.spurt_open and Time.get_ticks_msec() - stream.last_packet_ms > SPURT_TIMEOUT_MS:
			stream.spurt_open = false
			stream.draining = not stream.queue.is_empty()
			stats.underruns += 1
		if stream.draining:
			_drain_jitter_queue(speaker_id, stream)
			if stream.queue.is_empty() and not stream.spurt_open:
				stream.draining = false
			else:
				active_speaker = speaker_id


func _stream_for(speaker_id: int) -> ReceiveStream:
	if _streams.has(speaker_id):
		return _streams[speaker_id]
	var stream: = ReceiveStream.new()
	stream.tokens = _packet_burst
	stream.budget_ms = Time.get_ticks_msec()
	var generator: = AudioStreamGenerator.new()
	generator.mix_rate = float(_sample_rate)
	generator.buffer_length = 2.0
	stream.player = AudioStreamPlayer.new()
	stream.player.name = "RemoteVoiceOutput%d" % speaker_id
	stream.player.bus = AudioMix.bus(VoiceInput.PLAYBACK_BUS)
	stream.player.stream = generator
	add_child(stream.player)
	stream.player.play()
	stream.playback = stream.player.get_stream_playback() as AudioStreamGeneratorPlayback
	_streams[speaker_id] = stream
	return stream


func _remove_stream(speaker_id: int) -> void :
	var stream: ReceiveStream = _streams.get(speaker_id)
	if stream != null and is_instance_valid(stream.player):
		stream.player.stop()
		stream.player.queue_free()
	_streams.erase(speaker_id)


func _on_session_changed() -> void :
	if _session.generation != _generation or not _session.is_ready() or not _session.is_online():
		_generation = _session.generation
		epoch = 0
		_reset_stream_state()
	else:
		for speaker_id: int in _streams.keys():
			if not _session.player_ids().has(speaker_id):
				_remove_stream(speaker_id)


func _on_world_reset() -> void :
	_reset_stream_state()


func _on_world_state_changed() -> void :
	if not is_instance_valid(_world) or not _world.gameplay_available():
		_tx_active = false
		_tx_buffer.clear()


func _reset_stream_state() -> void :
	_send_seq = 0
	_tx_active = false
	_tx_buffer.clear()
	for speaker_id: int in _streams.keys():
		_remove_stream(speaker_id)
	active_speaker = 0


func _current_epoch() -> int:
	return _session.replication.epoch if _session != null and _session.replication != null else 0



func can_transmit() -> bool:
	return _can_transmit()


func _can_transmit() -> bool:
	if not _config_valid or not is_instance_valid(_world) or _session == null:
		return false
	if not _session.is_online() or not _session.is_ready() or _session.replication == null or not _session.replication.is_active():
		return false
	var current_ep: = _current_epoch()
	if current_ep != epoch:
		epoch = current_ep
		_reset_stream_state()
	if not _world.gameplay_available() or _session.remote_peer_ids().is_empty() or current_ep <= 0:
		return false
	if _world.voice != null and _world.voice.is_private_talk():
		return false
	return true


func _can_receive(packet_epoch: int) -> bool:
	if not _config_valid or not is_instance_valid(_world) or _session == null:
		return false
	if not _session.is_online() or not _session.is_ready() or _session.replication == null or not _session.replication.is_active():
		return false
	var current_ep: = _current_epoch()
	if current_ep != epoch:
		epoch = current_ep
		_reset_stream_state()
	if packet_epoch <= 0 or packet_epoch != current_ep:
		stats.stale_packets += 1
		stats.rejected += 1
		return false
	return true


func _on_voip_started() -> void :
	_tx_buffer.clear()
	_tx_active = _can_transmit()


func _on_voip_frames(samples: PackedFloat32Array) -> void :
	if samples.is_empty():
		return
	if not _tx_active:
		if not _can_transmit():
			return
		_tx_active = true
	if not _can_transmit():
		_tx_active = false
		_tx_buffer.clear()
		return
	_tx_buffer.append_array(samples)
	while _tx_buffer.size() >= _frame_samples:
		var chunk: = _tx_buffer.slice(0, _frame_samples)
		_tx_buffer = _tx_buffer.slice(_frame_samples)
		_send_frame(chunk, false)


func _on_voip_ended() -> void :
	if not _tx_active:
		_tx_buffer.clear()
		return
	_tx_active = false
	if not _can_transmit():
		_tx_buffer.clear()
		return
	while _tx_buffer.size() > _frame_samples:
		var chunk: = _tx_buffer.slice(0, _frame_samples)
		_tx_buffer = _tx_buffer.slice(_frame_samples)
		_send_frame(chunk, false)
	if not _tx_buffer.is_empty():
		var tail: = _tx_buffer
		_tx_buffer = PackedFloat32Array()
		_send_frame(tail, true)
	elif _send_seq > 0:
		if _session.has_authority():
			_relay_end(_session.local_player_id, _current_epoch(), _send_seq)
		elif _session.peer_is_connected(1):
			_voice_end.rpc_id(1, _current_epoch(), _send_seq)


func _send_frame(samples: PackedFloat32Array, is_final: bool) -> void :
	var current_ep: = _current_epoch()
	if not _can_transmit() or current_ep <= 0 or samples.is_empty():
		return
	var pcm_bytes: = encode_pcm16(samples)
	if pcm_bytes.is_empty() or pcm_bytes.size() > _max_packet_bytes:
		return
	_send_seq += 1
	stats.sent_packets += 1
	stats.sent_bytes += pcm_bytes.size()
	stats.max_packet_bytes = maxi(int(stats.max_packet_bytes), pcm_bytes.size())
	if _session.has_authority():
		_relay_packet(_session.local_player_id, current_ep, _send_seq, pcm_bytes, is_final)
	elif _session.peer_is_connected(1):
		_voice_packet.rpc_id(1, current_ep, _send_seq, pcm_bytes, is_final)


static func encode_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes: = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var s: = samples[i]
		var clean: = 0.0 if not is_finite(s) else clampf(s, -1.0, 1.0)
		bytes.encode_s16(i * 2, clampi(roundi(clean * 32767.0), -32768, 32767))
	return bytes


static func decode_pcm16(bytes: PackedByteArray) -> PackedFloat32Array:
	var count: = bytes.size() >> 1
	var samples: = PackedFloat32Array()
	samples.resize(count)
	for i in count:
		samples[i] = clampf(float(bytes.decode_s16(i * 2)) / 32767.0, -1.0, 1.0)
	return samples


func _consume_token(stream: ReceiveStream) -> bool:
	var now: = Time.get_ticks_msec()
	var elapsed: = maxf(0.0, float(now - stream.budget_ms) / 1000.0)
	stream.budget_ms = now
	stream.tokens = minf(_packet_burst, stream.tokens + elapsed * _packets_per_second)
	if stream.tokens < 1.0:
		return false
	stream.tokens -= 1.0
	return true


func _enqueue_jitter_frame(stream: ReceiveStream, frame: PackedFloat32Array) -> void :
	if frame.is_empty():
		return
	stream.queue.append(frame)
	while stream.queue.size() > _max_buffer_frames:
		stream.queue.pop_front()
		stats.dropped_overflow += 1


func _conceal_loss(stream: ReceiveStream, gap: int) -> void :
	var count: = mini(gap, _max_plc_frames)
	for g in count:
		var plc: = PackedFloat32Array()
		plc.resize(_frame_samples)
		var base: = stream.last_sample * pow(0.5, float(g + 1))
		for i in _frame_samples:
			var decay: = 1.0 - float(i) / float(_frame_samples)
			plc[i] = base * decay
		_enqueue_jitter_frame(stream, plc)
		stats.plc_frames += 1
	stream.last_sample = 0.0


func _drain_jitter_queue(speaker_id: int, stream: ReceiveStream) -> void :
	var frame_id: = Engine.get_process_frames()
	if frame_id != stream.drained_frame_id:
		stream.drained_frame_id = frame_id
		stream.drained_in_frame = 0
	while not stream.queue.is_empty() and ( not stream.spurt_open or stream.drained_in_frame < _jitter_buffer_frames * 2):
		var frame: PackedFloat32Array = stream.queue[0]

		if stream.playback != null and not stream.playback.can_push_buffer(frame.size()):
			break
		stream.drained_in_frame += 1
		if stream.playback != null:
			var stereo: = PackedVector2Array()
			stereo.resize(frame.size())
			for i in frame.size():
				stereo[i] = Vector2(frame[i], frame[i])
			stream.playback.push_buffer(stereo)
		stream.queue.pop_front()
		stats.played_samples += frame.size()
		stream.played_samples += frame.size()
		var sum: = 0.0
		for sample in frame:
			sum += sample * sample
		if not frame.is_empty():
			var rms: = sqrt(sum / float(frame.size()))
			stream.peak_rms = maxf(stream.peak_rms, rms)
			last_received_rms = maxf(last_received_rms, rms)
		received_samples.append_array(frame)
		if received_samples.size() > MAX_STORED_SAMPLES:
			received_samples = received_samples.slice(received_samples.size() - MAX_STORED_SAMPLES)
		voice_received.emit(speaker_id, frame)


func _accept_packet(speaker_id: int, sequence: int, pcm_bytes: PackedByteArray, is_final: bool) -> bool:
	if pcm_bytes.size() < 2 or pcm_bytes.size() > _max_packet_bytes or (pcm_bytes.size() % 2) != 0 or pcm_bytes.size() > _frame_samples * 2:
		stats.rejected += 1
		return false
	var stream: = _stream_for(speaker_id)
	if sequence <= stream.sequence or sequence - stream.sequence > _max_sequence_lead:
		stats.rejected += 1
		return false
	if not _consume_token(stream):
		stats.rejected += 1
		return false
	if stream.sequence > 0 and stream.spurt_open:
		var gap: = sequence - stream.sequence - 1
		if gap > 0:
			stats.lost_packets += gap
			_conceal_loss(stream, gap)
	stream.sequence = sequence
	stream.spurt_open = not is_final
	active_speaker = speaker_id
	stream.last_packet_ms = Time.get_ticks_msec()
	var decoded: = decode_pcm16(pcm_bytes)
	stream.last_sample = decoded[decoded.size() - 1]
	_enqueue_jitter_frame(stream, decoded)
	stream.packets += 1
	stats.received_packets += 1
	stats.received_bytes += pcm_bytes.size()
	stats.max_packet_bytes = maxi(int(stats.max_packet_bytes), pcm_bytes.size())
	if is_final or stream.queue.size() >= _jitter_buffer_frames:
		stream.draining = true
		_drain_jitter_queue(speaker_id, stream)
	return true


func _accept_end(speaker_id: int, sequence: int) -> bool:
	var stream: ReceiveStream = _streams.get(speaker_id)
	if stream == null or sequence < stream.sequence or sequence - stream.sequence > _max_sequence_lead or not _consume_token(stream):
		stats.rejected += 1
		return false
	stream.sequence = maxi(stream.sequence, sequence)
	stream.spurt_open = false
	stream.draining = true
	_drain_jitter_queue(speaker_id, stream)
	if stream.queue.is_empty():
		stream.draining = false
	return true


func _relay_packet(speaker_id: int, packet_epoch: int, sequence: int, pcm_bytes: PackedByteArray, is_final: bool) -> void :
	for peer_id: int in _session.remote_peer_ids():
		if _session.player_for_peer(peer_id) != speaker_id:
			_voice_relay.rpc_id(peer_id, packet_epoch, speaker_id, sequence, pcm_bytes, is_final)
			stats.relayed_packets += 1


func _relay_end(speaker_id: int, packet_epoch: int, sequence: int) -> void :
	for peer_id: int in _session.remote_peer_ids():
		if _session.player_for_peer(peer_id) != speaker_id:
			_voice_relay_end.rpc_id(peer_id, packet_epoch, speaker_id, sequence)



@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice_packet(packet_epoch: int, sequence: int, pcm_bytes: PackedByteArray, is_final: bool) -> void :
	if not _session.has_authority():
		stats.rejected += 1
		return
	if not _can_receive(packet_epoch):
		return
	var speaker_id: = _session.player_for_peer(multiplayer.get_remote_sender_id())
	if speaker_id <= 1:
		stats.rejected += 1
		return
	if _accept_packet(speaker_id, sequence, pcm_bytes, is_final):
		_relay_packet(speaker_id, packet_epoch, sequence, pcm_bytes, is_final)


@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice_end(packet_epoch: int, sequence: int) -> void :
	if not _session.has_authority():
		stats.rejected += 1
		return
	if not _can_receive(packet_epoch):
		return
	var speaker_id: = _session.player_for_peer(multiplayer.get_remote_sender_id())
	if speaker_id <= 1:
		stats.rejected += 1
		return
	if _accept_end(speaker_id, sequence):
		_relay_end(speaker_id, packet_epoch, sequence)



@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice_relay(packet_epoch: int, speaker_id: int, sequence: int, pcm_bytes: PackedByteArray, is_final: bool) -> void :
	if _session.has_authority() or multiplayer.get_remote_sender_id() != 1 or speaker_id == _session.local_player_id or not _session.player_ids().has(speaker_id):
		stats.rejected += 1
		return
	if _can_receive(packet_epoch):
		_accept_packet(speaker_id, sequence, pcm_bytes, is_final)


@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func _voice_relay_end(packet_epoch: int, speaker_id: int, sequence: int) -> void :
	if _session.has_authority() or multiplayer.get_remote_sender_id() != 1 or speaker_id == _session.local_player_id or not _session.player_ids().has(speaker_id):
		stats.rejected += 1
		return
	if _can_receive(packet_epoch):
		_accept_end(speaker_id, sequence)
