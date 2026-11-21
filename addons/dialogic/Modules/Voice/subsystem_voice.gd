extends DialogicSubsystem
## 管理为文本事件设置语音行的子系统。
##
## 建议使用 [class DialogicVoiceEvent] 为文本事件设置语音行，
## 而不是直接开始播放它们。


## 每当一条新的语音开始播放时发出。
## [param info] 包含以下键和值：
## [br]
## 键       |   值类型      | 值 [br]
## -------- | ------------- | ----- [br]
## `file`   | [type String] | 播放的文件路径。 [br]
signal voiceline_started(info: Dictionary)


## 每当一条语音播放完毕时发出。
## [param info] 包含以下键和值：
## [br]
## 键               |   值类型      | 值 [br]
## ---------------- | ------------- | ----- [br]
## `file`           | [type String] | 播放的文件路径。 [br]
## `remaining_time` | [type float]  | 语音的剩余时间。 [br]
signal voiceline_finished(info: Dictionary)


## 每当一条语音被打断、未能播放完毕时发出。
## [param info] 包含以下键和值：
## [br]
## 键               |   值类型      | 值 [br]
## ---------------- | ------------- | ----- [br]
## `file`           | [type String] | 播放的文件路径。 [br]
## `remaining_time` | [type float]  | 语音的剩余时间。 [br]
signal voiceline_stopped(info: Dictionary)


## 当前正在播放的音频文件。
var current_audio_file: String

## 语音的音频播放器。
var voice_player := AudioStreamPlayer.new()

#region 状态
####################################################################################################

## 停止播放当前语音。
func _pause() -> void:
	voice_player.stream_paused = true


## 恢复已暂停的语音。
func _resume() -> void:
	voice_player.stream_paused = false

#endregion


#region 主要方法
####################################################################################################

func _ready() -> void:
	add_child(voice_player)
	voice_player.finished.connect(_on_voice_finished)


## 当前事件是否为文本事件，并且它前面有一个语音
## 事件。
func is_voiced(index: int) -> bool:
	if index > 0 and dialogic.current_timeline_events[index] is DialogicTextEvent:
		if dialogic.current_timeline_events[index-1] is DialogicVoiceEvent:
			return true

	return false


## 播放语音。此方法由 Dialogic 调用。
## 需要先调用 [method set_file]，否则不会播放任何内容。
func play_voice() -> void:
	voice_player.play()
	voiceline_started.emit({'file': current_audio_file})


## 设置要播放的语音文件 [param path]，然后调用 [method play_voice]。
##
## 该方法不会检查 [param path] 是否为有效文件。
func set_file(path: String) -> void:
	if current_audio_file == path:
		return

	current_audio_file = path
	var audio: AudioStream = load(path)
	voice_player.stream = audio


## 以分贝为单位设置音量 [param value]。
func set_volume(value: float) -> void:
	voice_player.volume_db = value


## 将语音播放器的总线设置为 [param bus_name]。
func set_bus(bus_name: String) -> void:
	voice_player.bus = bus_name


## 停止播放当前语音。
func stop_audio() -> void:
	if voice_player.playing:
		voiceline_stopped.emit({'file':current_audio_file, 'remaining_time':get_remaining_time()})

	voice_player.stop()


## 在语音播放完毕时调用。
## 已连接到 [member voice_player] 上的 [signal finished]
func _on_voice_finished() -> void:
	voiceline_finished.emit({'file':current_audio_file, 'remaining_time':get_remaining_time()})


## 返回当前语音的剩余时间（秒）。
##
## 如果没有语音正在播放，则返回 `0`。
func get_remaining_time() -> float:
	if not voice_player or not voice_player.playing:
		return 0.0

	var stream_length := voice_player.stream.get_length()
	var playback_position := voice_player.get_playback_position()
	var remaining_seconds := stream_length - playback_position

	return remaining_seconds


## 当前语音是否仍有剩余的播放时间。
func is_running() -> bool:
	return get_remaining_time() > 0.0

#endregion
