extends Node

## AudioManager.gd
## Autoload managing background music and sound effects across scenes,
## including victory fanfares and defeat sound effects on level ends.

var music_player: AudioStreamPlayer
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var tracks: Dictionary = {
	"menu": "res://graphic/bgmusic1.mp3",
	"battle": "res://graphic/bgmusic2.mp3",
	"ambient": "res://graphic/bgmusic3.mp3"
}

var master_volume: float = 0.8
var visibility_cb: JavaScriptObject

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	music_player = AudioStreamPlayer.new()
	bgm_player = music_player
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	music_player.bus = "Master"
	music_player.volume_db = 0.0
	music_player.finished.connect(_on_music_finished)
	add_child(music_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_player.bus = "Master"
	sfx_player.volume_db = 0.0
	add_child(sfx_player)

	set_master_volume(master_volume)

	if OS.has_feature("web"):
		visibility_cb = JavaScriptBridge.create_callback(_on_visibility_change)
		var doc = JavaScriptBridge.get_interface("document")
		if doc:
			doc.addEventListener("visibilitychange", visibility_cb)

func _on_visibility_change(args) -> void:
	var is_hidden = JavaScriptBridge.eval("document.hidden")
	var master_idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(master_idx, is_hidden == true)

func _on_music_finished() -> void:
	if is_music_enabled and not current_track_name.is_empty():
		music_player.play()

func set_master_volume(val: float) -> void:
	master_volume = clampf(val, 0.0, 1.0)
	var bus_idx := AudioServer.get_bus_index("Master")
	if bus_idx != -1:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(bus_idx, true)
		else:
			AudioServer.set_bus_mute(bus_idx, false)
			AudioServer.set_bus_volume_db(bus_idx, linear_to_db(master_volume))

func get_master_volume() -> float:
	return master_volume

var is_music_enabled: bool = true
var current_track_name: String = ""

func play_music(track_name: String) -> void:
	if not is_inside_tree():
		return
	if not tracks.has(track_name):
		return
	if not music_player or not is_instance_valid(music_player):
		return
	if current_track_name == track_name and music_player.playing:
		return
	
	current_track_name = track_name
	var path: String = tracks[track_name]
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if stream:
		if stream is AudioStreamMP3:
			stream.loop = true
		elif stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if music_player.playing:
			music_player.stop()
		music_player.stream = stream
		if is_music_enabled:
			music_player.play()

func toggle_music() -> bool:
	set_music_enabled(not is_music_enabled)
	return is_music_enabled

func set_music_enabled(enabled: bool) -> void:
	is_music_enabled = enabled
	if not is_music_enabled:
		stop_music()
	else:
		if music_player and not music_player.playing and music_player.stream != null:
			music_player.play()
		elif not current_track_name.is_empty():
			play_music(current_track_name)

func pause_music() -> void:
	if music_player and is_instance_valid(music_player) and music_player.playing:
		music_player.stream_paused = true

func resume_music() -> void:
	if music_player and is_instance_valid(music_player):
		music_player.stream_paused = false

func stop_music() -> void:
	if music_player and is_instance_valid(music_player) and music_player.playing:
		music_player.stop()

func stop_sfx() -> void:
	if sfx_player and is_instance_valid(sfx_player) and sfx_player.playing:
		sfx_player.stop()

func stop_all() -> void:
	stop_music()
	stop_sfx()

var is_sfx_enabled: bool = true

func toggle_sfx() -> bool:
	set_sfx_enabled(not is_sfx_enabled)
	return is_sfx_enabled

func set_sfx_enabled(enabled: bool) -> void:
	is_sfx_enabled = enabled
	if not is_sfx_enabled and sfx_player:
		stop_sfx()

func play_sfx_path(path: String) -> void:
	if not is_inside_tree() or not is_sfx_enabled:
		return
	if not sfx_player or not is_instance_valid(sfx_player):
		return
	if ResourceLoader.exists(path):
		var stream = load(path)
		if stream:
			if sfx_player.playing:
				sfx_player.stop()
			sfx_player.stream = stream
			sfx_player.play()

func play_victory_jingle() -> void:
	if not is_inside_tree():
		return
	stop_music()
	if not is_sfx_enabled:
		return
	if not sfx_player or not is_instance_valid(sfx_player):
		return
	if sfx_player.playing:
		sfx_player.stop()
	# Procedural bright ascending triad victory jingle (C5 -> E5 -> G5 -> C6)
	var stream := _generate_jingle([523.25, 659.25, 783.99, 1046.5], 0.14)
	sfx_player.stream = stream
	sfx_player.play()

func play_defeat_jingle() -> void:
	if not is_inside_tree():
		return
	stop_music()
	if not is_sfx_enabled:
		return
	if not sfx_player or not is_instance_valid(sfx_player):
		return
	if sfx_player.playing:
		sfx_player.stop()
	# Procedural descending somber defeat tone (F4 -> Eb4 -> Db4 -> C4)
	var stream := _generate_jingle([349.23, 311.13, 277.18, 220.0], 0.22)
	sfx_player.stream = stream
	sfx_player.play()

func _generate_jingle(notes: Array, note_duration: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var total_samples := int(sample_rate * note_duration * notes.size())
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2) # 16-bit mono
	
	var sample_idx := 0
	for note_freq in notes:
		var note_samples := int(sample_rate * note_duration)
		for i in range(note_samples):
			var t := float(i) / float(sample_rate)
			var env := 1.0 - (float(i) / float(note_samples)) # Linear decay
			var val := sin(t * note_freq * TAU) * env * 0.4
			var sample_16 := int(clampf(val, -1.0, 1.0) * 32767.0)
			bytes.encode_s16(sample_idx * 2, sample_16)
			sample_idx += 1
			
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream
