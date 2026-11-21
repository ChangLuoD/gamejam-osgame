@tool
class_name DialogicNode_TypeSounds
extends AudioStreamPlayer

## 允许在文本字符逐个显示时播放音效的节点。
## 应是 DialogicNode_DialogText 节点的子节点！

## 如果你想更改不同节点的音效，这项设置会很有用
@export var enabled := true
enum Modes {INTERRUPT, OVERLAP, AWAIT}
## 若为 true，会中断当前音效以播放新的音效
@export var mode := Modes.INTERRUPT
## 音效数组。每次会随机挑选一个。
@export var sounds: Array[AudioStream] = []
## 作为最后一个音效播放的声音。
@export var end_sound:AudioStream
## 决定每两次音效之间隔多少个字符。默认为 1，即每个字符都播放。
@export var play_every_character  := 1
## 允许在 (pitch - pitch_variance) 到 (pitch + pitch_variance) 之间随机改变音高
@export_range(0, 3, 0.01) var pitch_variance := 0.0
## 允许在 (volume - volume_variance) 到 (volume + volume_variance) 之间随机改变音量
@export_range(0, 10, 0.01) var volume_variance := 0.0
## 不会增加 'characters_since_last_sound' 变量的字符，适用于空格或句号
@export var ignore_characters: String = ' .,'

var characters_since_last_sound: int = 0
var base_pitch: float = pitch_scale
var base_volume: float = volume_db
var RNG := RandomNumberGenerator.new()

var current_overwrite_data := {}

func _ready() -> void:
	# 加入必要的分组
	add_to_group('dialogic_type_sounds')

	if not Engine.is_editor_hint() and get_parent() is DialogicNode_DialogText:
		if bus == "Master":
			bus = ProjectSettings.get_setting("dialogic/audio/type_sound_bus", "Master")

		get_parent().started_revealing_text.connect(_on_started_revealing_text)
		get_parent().continued_revealing_text.connect(_on_continued_revealing_text)
		get_parent().finished_revealing_text.connect(_on_finished_revealing_text)


func _on_started_revealing_text() -> void:
	if !enabled or (get_parent() is DialogicNode_DialogText and !get_parent().enabled):
		return
	characters_since_last_sound = current_overwrite_data.get('skip_characters', play_every_character-1)+1


func _on_continued_revealing_text(new_character:String) -> void:
	if !enabled or (get_parent() is DialogicNode_DialogText and !get_parent().enabled):
		return

	# 如果启用了自动跳过，就不播放打字音效。
	if !Engine.is_editor_hint() and DialogicUtil.autoload().Inputs.auto_skip.enabled:
		return

	# 如果有语音轨道正在播放，就不播放
	if !Engine.is_editor_hint() and get_parent() is DialogicNode_DialogText:
		if DialogicUtil.autoload().has_subsystem("Voice") and DialogicUtil.autoload().Voice.is_running():
			return

	# 如果正在播放音效且无法中断
	if playing and current_overwrite_data.get('mode', mode) == Modes.AWAIT:
		return

	# 如果没有提供任何音效
	if current_overwrite_data.get('sounds', sounds).size() == 0:
		return

	# 如果这个新字符不允许触发
	if new_character in ignore_characters:
		return

	characters_since_last_sound += 1
	if characters_since_last_sound < current_overwrite_data.get('skip_characters', play_every_character-1)+1:
		return

	characters_since_last_sound = 0

	var audio_player: AudioStreamPlayer = self
	if current_overwrite_data.get('mode', mode) == Modes.OVERLAP:
		audio_player = AudioStreamPlayer.new()
		audio_player.bus = bus
		add_child(audio_player)
	elif current_overwrite_data.get('mode', mode) == Modes.INTERRUPT:
		stop()

	# 随机选择音效
	audio_player.stream = current_overwrite_data.get('sounds', sounds)[RNG.randi_range(0, current_overwrite_data.get('sounds', sounds).size() - 1)]

	# 随机选择音高和音量
	audio_player.pitch_scale = max(0.0001, current_overwrite_data.get('pitch_base', base_pitch) + current_overwrite_data.get('pitch_variance', pitch_variance) * RNG.randf_range(-1.0, 1.0))
	audio_player.volume_db = current_overwrite_data.get('volume_base', base_volume) + current_overwrite_data.get('volume_variance',volume_variance) * RNG.randf_range(-1.0, 1.0)

	# 播放音效
	audio_player.play(0)

	if current_overwrite_data.get('mode', mode) == Modes.OVERLAP:
		audio_player.finished.connect(audio_player.queue_free)


func _on_finished_revealing_text() -> void:
	# 如果启用了自动跳过，就不播放打字音效。
	if !Engine.is_editor_hint() and DialogicUtil.autoload().Inputs.auto_skip.enabled:
		return

	if end_sound != null:
		stream = end_sound
		play()


func load_overwrite(dictionary:Dictionary) -> void:
	current_overwrite_data = dictionary
	if dictionary.has('sound_path'):
		current_overwrite_data['sounds'] = DialogicNode_TypeSounds.load_sounds_from_path(dictionary.sound_path)


static func load_sounds_from_path(path:String) -> Array[AudioStream]:
	if path.get_extension().to_lower() in ['mp3', 'wav', 'ogg'] and load(path) is AudioStream:
		return [load(path)]
	var _sounds: Array[AudioStream] = []
	for file in DialogicUtil.listdir(path, true, false, true, true):
		if !file.ends_with('.import'):
			continue
		if file.trim_suffix('.import').get_extension().to_lower() in ['mp3', 'wav', 'ogg'] and ResourceLoader.load(file.trim_suffix('.import')) is AudioStream:
			_sounds.append(ResourceLoader.load(file.trim_suffix('.import')))
	return _sounds


############# 用户界面 ###################################################

func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is DialogicNode_DialogText:
		return ["此节点应是 DialogText 节点的子节点！"]
	return []
