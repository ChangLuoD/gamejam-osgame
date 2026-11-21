extends Node
class_name MusicPlayer

## 调试打印
@export var debug_print: bool = false
## 音乐渐变时长
@export var fade_time: float = 1.0

static var node: MusicPlayer

## 音乐播放器数量
var music_player_count: int = 2
## 当前音乐播放器索引
var current_player_index: int = 0
## 音乐播放器列表
var music_players: Array[AudioStreamPlayer] = []
## 渐变tween
var fade_in_tween: Tween
var fade_out_tween: Tween

var current_music: AudioStream	## 当前播放音乐

func _ready() -> void:
	_init_music_player()

## 播放背景音乐
func play_music(_audio: AudioStream, is_replay: bool = false) -> void:
	var current_player: AudioStreamPlayer = music_players[current_player_index]
	if current_music == _audio and not is_replay:
		return

	var empty_player_index: int = 0 if current_player_index == 1 else 1
	var empty_player: AudioStreamPlayer = music_players[empty_player_index]

	await _stop_and_fade_out(current_player)
	empty_player.stream = _audio
	current_player_index = empty_player_index
	current_music = _audio
	if debug_print:
		print("音乐播放: [%s]" % empty_player.stream.resource_path)
	
	_play_and_fade_in(empty_player)

## 清空音乐播放器
func clear_music() -> void:
	for player in music_players:
		player.stream = null
		player.stop()
	current_music = null

## 初始化音乐播放器
func _init_music_player() -> void:
	for i in music_player_count:
		var new_music_player: AudioStreamPlayer = AudioStreamPlayer.new()
		new_music_player.name = "MusicPlayer[%s]" % str(i)
		new_music_player.bus = AudioServer.get_bus_name(1)
		new_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(new_music_player)
		music_players.append(new_music_player)

## 背景音乐渐出
func _stop_and_fade_out(_audio_player: AudioStreamPlayer) -> void:
	if not _audio_player.playing:
		return
	fade_out_tween = create_tween()
	fade_out_tween.tween_property(_audio_player, "volume_db", -40, fade_time)
	await  fade_out_tween.finished
	_audio_player.stop()
	_audio_player.stream = null

## 背景音乐渐入
func _play_and_fade_in(_audio_player: AudioStreamPlayer) -> void:
	if fade_in_tween:
		fade_in_tween.kill()
	if fade_out_tween:
		fade_out_tween.kill()
	_audio_player.volume_db = -40  # 初始静音
	_audio_player.play()
	fade_in_tween = create_tween()
	fade_in_tween.tween_property(_audio_player, "volume_db", 0, fade_time)

func _enter_tree() -> void:
	node = self
func _exit_tree() -> void:
	node = null
