class_name GameAudioManager
extends Node

enum RevealSound {
	STANDARD,
	MONSTER_ROAR,
	MERCHANT_BELL,
	EXPLOSION,
	PAPER_PLANE,
	MINE_CART,
	WIND,
	SILENT
}

## Lightweight fallback audio. Assign authored streams in the Inspector when
## the project has final music and sound assets; generated audio remains usable
## when those fields are empty.
@export var music_stream: AudioStream
@export var tile_reveal_stream: AudioStream
@export var monster_roar_stream: AudioStream
@export var merchant_bell_stream: AudioStream
@export var explosion_stream: AudioStream
@export var paper_plane_stream: AudioStream
@export var mine_cart_stream: AudioStream
@export var wind_stream: AudioStream
@export_range(-30.0, 0.0, 0.5) var music_volume_db := -15.0
@export_range(-30.0, 0.0, 0.5) var sound_volume_db := -8.0
@export var music_enabled := true
@export var sounds_enabled := true

const SAMPLE_RATE := 44100.0
const MUSIC_BEAT_SECONDS := 0.42
const MUSIC_NOTES := [261.63, 329.63, 392.0, 523.25, 392.0, 329.63, 293.66, 392.0]

var music_player: AudioStreamPlayer
var sound_player: AudioStreamPlayer
var music_playback: AudioStreamGeneratorPlayback
var sound_playback: AudioStreamGeneratorPlayback
var music_phase := 0.0
var music_note_index := 0
var music_elapsed := 0.0
var reveal_samples := PackedFloat32Array()
var standard_reveal_samples := PackedFloat32Array()
var monster_roar_samples := PackedFloat32Array()
var event_samples: Dictionary = {}
var reveal_sample_index := 0

func _ready() -> void:
	_build_players()
	_build_fallback_reveal_sound()
	_build_fallback_monster_roar()
	_build_fallback_event_sounds()
	if music_enabled:
		_start_music()

func _process(delta: float) -> void:
	if music_enabled and music_playback != null:
		_fill_music_buffer(delta)
	if sounds_enabled and sound_playback != null and not reveal_samples.is_empty():
		_fill_sound_buffer()

func _build_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.volume_db = music_volume_db
	add_child(music_player)
	sound_player = AudioStreamPlayer.new()
	sound_player.name = "SoundPlayer"
	sound_player.volume_db = sound_volume_db
	add_child(sound_player)

func _start_music() -> void:
	if music_stream != null:
		var mp3 := music_stream as AudioStreamMP3
		if mp3 != null:
			mp3.loop = true
		music_player.stream = music_stream
		music_player.play()
		return
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = int(SAMPLE_RATE)
	stream.buffer_length = 0.35
	music_player.stream = stream
	music_player.play()
	music_playback = music_player.get_stream_playback() as AudioStreamGeneratorPlayback

func _fill_music_buffer(_delta: float) -> void:
	if music_playback == null:
		return
	var available := music_playback.get_frames_available()
	for _frame in range(available):
		var note_time := music_elapsed
		var note := float(MUSIC_NOTES[music_note_index])
		var envelope := 0.12 + 0.08 * sin(note_time * PI / MUSIC_BEAT_SECONDS)
		var sample := sin(music_phase) * envelope
		# A quiet fifth gives the generated loop a less synthetic, empty sound.
		sample += sin(music_phase * 1.5) * envelope * 0.18
		music_playback.push_frame(Vector2(sample, sample))
		music_phase += TAU * note / SAMPLE_RATE
		music_elapsed += 1.0 / SAMPLE_RATE
		if music_elapsed >= MUSIC_BEAT_SECONDS:
			music_elapsed -= MUSIC_BEAT_SECONDS
			music_note_index = (music_note_index + 1) % MUSIC_NOTES.size()

func _build_fallback_reveal_sound() -> void:
	if tile_reveal_stream != null:
		return
	var duration := 0.24
	standard_reveal_samples.resize(int(SAMPLE_RATE * duration))
	for index in range(standard_reveal_samples.size()):
		var progress := float(index) / float(standard_reveal_samples.size())
		var frequency := lerpf(220.0, 660.0, progress)
		var envelope := (1.0 - progress) * (1.0 - progress)
		standard_reveal_samples[index] = (sin(TAU * frequency * float(index) / SAMPLE_RATE) * 0.42 + sin(TAU * frequency * 2.0 * float(index) / SAMPLE_RATE) * 0.10) * envelope

func _build_fallback_monster_roar() -> void:
	if monster_roar_stream != null:
		return
	var duration := 0.82
	monster_roar_samples.resize(int(SAMPLE_RATE * duration))
	for index in range(monster_roar_samples.size()):
		var progress := float(index) / float(monster_roar_samples.size())
		var frequency := lerpf(175.0, 68.0, progress) + sin(progress * TAU * 2.0) * 12.0
		var phase := TAU * frequency * float(index) / SAMPLE_RATE
		var attack := clampf(progress / 0.045, 0.0, 1.0)
		var release := 1.0 - clampf((progress - 0.54) / 0.46, 0.0, 1.0)
		var envelope := attack * release
		var growl := sin(phase) * 0.48 + sin(phase * 1.97) * 0.22 + sin(phase * 3.01) * 0.10
		var rasp := sin(phase * 7.0 + sin(progress * 30.0) * 1.8) * 0.07
		monster_roar_samples[index] = (growl + rasp) * envelope

func _build_fallback_event_sounds() -> void:
	event_samples[RevealSound.MERCHANT_BELL] = _make_event_samples(RevealSound.MERCHANT_BELL, 0.62)
	event_samples[RevealSound.EXPLOSION] = _make_event_samples(RevealSound.EXPLOSION, 0.58)
	event_samples[RevealSound.PAPER_PLANE] = _make_event_samples(RevealSound.PAPER_PLANE, 0.70)
	event_samples[RevealSound.MINE_CART] = _make_event_samples(RevealSound.MINE_CART, 0.78)
	event_samples[RevealSound.WIND] = _make_event_samples(RevealSound.WIND, 0.74)

func _make_event_samples(sound_type: int, duration: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(SAMPLE_RATE * duration))
	for index in range(samples.size()):
		var progress := float(index) / float(samples.size())
		var time := float(index) / SAMPLE_RATE
		var sample := 0.0
		match sound_type:
			RevealSound.MERCHANT_BELL:
				var strike := exp(-progress * 9.0)
				sample = (sin(TAU * 880.0 * time) * 0.42 + sin(TAU * 1320.0 * time) * 0.22) * strike
				sample += sin(TAU * 660.0 * maxf(0.0, time - 0.18)) * 0.30 * exp(-maxf(0.0, progress - 0.18) * 12.0)
			RevealSound.EXPLOSION:
				var boom := sin(TAU * lerpf(92.0, 42.0, progress) * time) * exp(-progress * 5.5)
				var crackle := sin(TAU * 1733.0 * time + sin(time * 91.0) * 2.0) * exp(-progress * 15.0)
				sample = boom * 0.72 + crackle * 0.24
			RevealSound.PAPER_PLANE:
				var envelope := sin(PI * progress) * 0.75
				var whoosh := sin(TAU * lerpf(260.0, 980.0, progress) * time) * 0.42
				sample = (whoosh + sin(TAU * 1260.0 * time) * 0.10) * envelope
			RevealSound.MINE_CART:
				var rumble := sin(TAU * 72.0 * time) * 0.42 + sin(TAU * 118.0 * time) * 0.20
				var rail_clack := sin(TAU * 410.0 * time) * (0.12 + 0.10 * sin(TAU * 7.0 * progress))
				sample = (rumble + rail_clack) * (1.0 - progress * 0.72)
			RevealSound.WIND:
				var gust := sin(TAU * lerpf(180.0, 420.0, progress) * time + sin(progress * 24.0) * 1.5)
				var whistle := sin(TAU * 820.0 * time) * 0.16
				sample = (gust * 0.34 + whistle) * sin(PI * progress)
		samples[index] = sample
	return samples

func _get_authored_stream(sound_type: int) -> AudioStream:
	match sound_type:
		RevealSound.MONSTER_ROAR:
			return monster_roar_stream
		RevealSound.MERCHANT_BELL:
			return merchant_bell_stream
		RevealSound.EXPLOSION:
			return explosion_stream
		RevealSound.PAPER_PLANE:
			return paper_plane_stream
		RevealSound.MINE_CART:
			return mine_cart_stream
		RevealSound.WIND:
			return wind_stream
		_:
			return tile_reveal_stream

func _get_fallback_samples(sound_type: int) -> PackedFloat32Array:
	match sound_type:
		RevealSound.MONSTER_ROAR:
			return monster_roar_samples
		RevealSound.STANDARD:
			return standard_reveal_samples
		_:
			return event_samples.get(sound_type, standard_reveal_samples)

func play_tile_reveal(sound_type: int = RevealSound.STANDARD) -> void:
	if not sounds_enabled or sound_type == RevealSound.SILENT:
		return
	var authored_stream := _get_authored_stream(sound_type)
	if authored_stream != null:
		var player := AudioStreamPlayer.new()
		player.stream = authored_stream
		player.volume_db = sound_volume_db
		add_child(player)
		player.finished.connect(player.queue_free)
		player.play()
		return
	if sound_playback == null:
		var stream := AudioStreamGenerator.new()
		stream.mix_rate = int(SAMPLE_RATE)
		stream.buffer_length = 0.35
		sound_player.stream = stream
		sound_player.play()
		sound_playback = sound_player.get_stream_playback() as AudioStreamGeneratorPlayback
	reveal_samples = _get_fallback_samples(sound_type)
	reveal_sample_index = 0

func stop_all() -> void:
	if music_player != null:
		music_player.stop()
	if sound_player != null:
		sound_player.stop()

func _fill_sound_buffer() -> void:
	if sound_playback == null:
		return
	var available := sound_playback.get_frames_available()
	for _frame in range(available):
		if reveal_sample_index >= reveal_samples.size():
			sound_playback.push_frame(Vector2.ZERO)
			continue
		var sample := reveal_samples[reveal_sample_index]
		sound_playback.push_frame(Vector2(sample, sample))
		reveal_sample_index += 1
