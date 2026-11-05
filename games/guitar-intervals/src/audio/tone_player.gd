extends Node
## Offline, equal-tempered plucked reference tones. A chord is one PCM stream,
## so all voices start at the same sample. No samples, plugins or network needed.

signal playback_started(midi_notes: Array[int])
signal playback_ended

const SAMPLE_RATE: int = 44100
const DURATION: float = 1.6
const PEAK: float = 0.72
const CACHE_LIMIT: int = 48
const HARMONICS: Array[float] = [1.0, 0.28, 0.12, 0.05]

var player: AudioStreamPlayer
var volume_percent: float = 70.0
var muted: bool = false
var current_notes: Array[int] = []
var _tones: Dictionary = {}
var _streams: Dictionary = {}


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "ReferenceTones"
	add_child(player)
	_apply_volume()
	player.finished.connect(_on_finished)


static func frequency(midi_note: int) -> float:
	return 440.0 * pow(2.0, (midi_note - 69) / 12.0)


func _tone(midi_note: int) -> PackedFloat32Array:
	if _tones.has(midi_note):
		return _tones[midi_note]
	var samples := PackedFloat32Array()
	samples.resize(roundi(SAMPLE_RATE * DURATION))
	var hz: float = frequency(midi_note)
	var total_weight: float = 0.0
	for harmonic_index in range(HARMONICS.size()):
		if hz * (harmonic_index + 1) < SAMPLE_RATE * 0.45:
			total_weight += HARMONICS[harmonic_index]
	for index in range(samples.size()):
		var time: float = index / float(SAMPLE_RATE)
		var envelope: float = minf(time / 0.006, 1.0) * exp(-2.1 * time) * clampf((DURATION - time) / 0.08, 0.0, 1.0)
		var sample: float = 0.0
		for harmonic_index in range(HARMONICS.size()):
			var harmonic: int = harmonic_index + 1
			if hz * harmonic < SAMPLE_RATE * 0.45:
				sample += HARMONICS[harmonic_index] * sin(TAU * hz * harmonic * time)
		samples[index] = PEAK * envelope * sample / total_weight
	if _tones.size() >= CACHE_LIMIT:
		_tones.erase(_tones.keys()[0])
	_tones[midi_note] = samples
	return samples


func stream_for(midi_notes: Array[int]) -> AudioStreamWAV:
	if midi_notes.is_empty() or midi_notes.size() > 3:
		return null
	for note in midi_notes:
		if note < 0 or note > 127:
			return null
	var sorted_notes: Array[int] = midi_notes.duplicate()
	sorted_notes.sort()
	var key: String = str(sorted_notes)
	if _streams.has(key):
		return _streams[key]
	var voices: Array[PackedFloat32Array] = []
	for note in sorted_notes:
		voices.append(_tone(note))
	var frame_count: int = voices[0].size()
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	for index in range(frame_count):
		var sample: float = 0.0
		for voice in voices:
			sample += voice[index]
		# Normalize by voice count so even unisons and rapid retries cannot clip.
		data.encode_s16(index * 2, roundi(clampf(sample / voices.size(), -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if _streams.size() >= CACHE_LIMIT:
		_streams.erase(_streams.keys()[0])
	_streams[key] = stream
	return stream


func play_notes(midi_notes: Array[int]) -> bool:
	if muted or volume_percent <= 0.0:
		return false
	var stream: AudioStreamWAV = stream_for(midi_notes)
	if stream == null:
		return false
	# Replace the previous sound rather than accumulating voices across clicks.
	player.stop()
	player.stream = stream
	current_notes.assign(midi_notes)
	player.play()
	playback_started.emit(current_notes.duplicate())
	return true


func set_volume(value: float) -> void:
	volume_percent = clampf(value, 0.0, 100.0)
	_apply_volume()
	if volume_percent == 0.0:
		stop()


func set_muted(value: bool) -> void:
	muted = value
	_apply_volume()
	if muted:
		stop()


func _apply_volume() -> void:
	if is_instance_valid(player):
		player.volume_linear = 0.0 if muted else volume_percent / 100.0 * 0.5


func stop() -> void:
	if is_instance_valid(player):
		player.stop()
	_on_finished()


func _on_finished() -> void:
	current_notes.clear()
	playback_ended.emit()
