# core/music_manager.gd
# Autoloaded as MusicManager
# Persistent audio player — survives scene changes.
# Drop audio files in res://assets/audio/ and call the play functions.
extends Node

const MENU_MUSIC_PATH : String = "res://assets/audio/menu_theme.ogg"

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Master"
	add_child(_player)


func play_menu_music() -> void:
	if _player.playing:
		return
	var stream := _try_load(MENU_MUSIC_PATH)
	if stream == null:
		return
	_player.stream = stream
	_player.play()


func stop() -> void:
	_player.stop()


func is_playing() -> bool:
	return _player.playing


# Returns the loaded stream or null if the file doesn't exist yet.
func _try_load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
