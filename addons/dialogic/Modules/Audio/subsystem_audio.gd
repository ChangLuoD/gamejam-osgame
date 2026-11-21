extends DialogicSubsystem
## 用于管理背景音频与单次音效的子系统。
##
## 该子系统提供了许多用于管理音频的辅助方法，
## 可在你的时间线中使用。
## 例如，你可以通过 [signal audio_started] 监听音频变化。


## 每当开始一个新的音频事件时，会发出该信号，
## 其中包含一个字典，键如下：[br]
## [br]
## 键          |   值类型      | 说明 [br]
## ----------- | ------------- | ----- [br]
## `path`      | [type String] | 音频资源文件的路径。[br]
## `channel`   | [type String] | 播放音频所用的通道名称。[br]
## `volume`    | [type float]  | 将设置到 [AudioStreamPlayer] 的音频资源音量，单位为 `db`。[br]
## `audio_bus` | [type String] | [AudioStreamPlayer] 将使用的音频总线名称。[br]
## `loop`      | [type bool]   | 音频资源播放结束后是否循环。[br]
signal audio_started(info: Dictionary)


@export_group("State")
@export var info := {}


## 用于容纳音频播放器的音频节点
var audio_node := Node.new()
## 用于容纳音效播放器的音效节点
var one_shot_audio_node := Node.new()
## 包含当前所有音频通道信息的字典
var current_audio_channels: Dictionary = {}

#region 状态
####################################################################################################

## 清除该子系统的状态并停止所有音频。
func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	stop_all_channels()
	stop_all_one_shot_sounds()


## 从当前状态信息中加载该子系统的状态。
func _load_state(load_flag:=LoadFlags.FULL_LOAD) -> void:
	if load_flag == LoadFlags.ONLY_DNODES:
		return

	for channel_name in info.keys():
		if info[channel_name].path.is_empty():
			update_audio(channel_name)
		else:
			update_audio(channel_name, info[channel_name].path, info[channel_name].settings_overrides)


## 暂停播放音频。
func _pause() -> void:
	for child in audio_node.get_children():
		child.stream_paused = true
	for child in one_shot_audio_node.get_children():
		child.stream_paused = true


## 恢复播放音频。
func _resume() -> void:
	for child in audio_node.get_children():
		child.stream_paused = false
	for child in one_shot_audio_node.get_children():
		child.stream_paused = false


func _on_dialogic_timeline_ended() -> void:
	if not dialogic.Styles.get_layout_node():
		_clear_state()

#endregion


#region 主要方法
####################################################################################################

func _ready() -> void:
	dialogic.timeline_ended.connect(_on_dialogic_timeline_ended)

	audio_node.name = "Audio"
	add_child(audio_node)
	one_shot_audio_node.name = "OneShotAudios"
	add_child(one_shot_audio_node)


## 在给定通道上播放给定文件（或不播放任何内容）。
## 未指定通道时默认为「单次音效」通道，
##   该通道不保存音频，但可以同时播放多个音频。
func update_audio(channel_name:= "", path := "", settings_overrides := {}) -> void:
	#volume := 0.0, audio_bus := "", fade_time := 0.0, loop := true, sync_channel := "") -> void:
	if not is_channel_playing(channel_name) and path.is_empty():
		return

	## 确定音频设置
	var audio_settings: Dictionary = DialogicUtil.get_audio_channel_defaults().get(channel_name, {}).merged(
		{"volume":0, "audio_bus":"", "fade_length":0.0, "loop":true, "sync_channel":""}
		).merged(settings_overrides, true)

	## 处理通道上先前的音频
	if is_channel_playing(channel_name):
		var prev_audio_node: AudioStreamPlayer = current_audio_channels[channel_name]
		prev_audio_node.name += "_Prev"
		if audio_settings.fade_length > 0.0:
			var fade_out_tween: Tween = create_tween()
			fade_out_tween.tween_method(
				interpolate_volume_linearly.bind(prev_audio_node),
				db_to_linear(prev_audio_node.volume_db),
				0.0,
				audio_settings.fade_length)
			fade_out_tween.tween_callback(prev_audio_node.queue_free)

		else:
			prev_audio_node.queue_free()

	## 设置状态
	if not path:
		info.erase(channel_name)
		return

	info[channel_name] = {'path':path, 'settings_overrides':settings_overrides}
	audio_started.emit(info[channel_name])

	var new_player := AudioStreamPlayer.new()
	if channel_name:
		new_player.name = channel_name.validate_node_name()
		audio_node.add_child(new_player)
	else:
		new_player.name = "OneShotSFX"
		one_shot_audio_node.add_child(new_player)

	var file := load(path)
	if file == null:
		printerr("[Dialogic] 音频文件 \"%s\" 加载失败。" % path)
		return

	new_player.stream = load(path)

	## 应用音频设置

	## 音量与淡入淡出
	if audio_settings.fade_length > 0.0:
		new_player.volume_db = linear_to_db(0.0)
		var fade_in_tween := create_tween()
		fade_in_tween.tween_method(
			interpolate_volume_linearly.bind(new_player),
			0.0,
			db_to_linear(audio_settings.volume),
			audio_settings.fade_length)

	else:
		new_player.volume_db = audio_settings.volume

	## 音频总线
	new_player.bus = audio_settings.audio_bus

	## 循环
	if "loop" in new_player.stream:
		new_player.stream.loop = audio_settings.loop
	elif "loop_mode" in new_player.stream:
		if audio_settings.loop:
			new_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			new_player.stream.loop_begin = 0
			new_player.stream.loop_end = new_player.stream.mix_rate * new_player.stream.get_length()
		else:
			new_player.stream.loop_mode = AudioStreamWAV.LOOP_DISABLED

	## 同步并开始播放
	if audio_settings.sync_channel and is_channel_playing(audio_settings.sync_channel):
		var play_position: float = current_audio_channels[audio_settings.sync_channel].get_playback_position()
		new_player.play(play_position)

		# TODO 在 https://github.com/godotengine/godot/issues/18878 修复后移除这段代码
		if new_player.stream is AudioStreamWAV and new_player.stream.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			printerr("[Dialogic] 使用 Ima-ADPCM 压缩的 WAV 文件无法同步。请使用其他压缩模式重新导入该文件。")
			dialogic.print_debug_moment()
	else:
		new_player.play()

	new_player.finished.connect(_on_audio_finished.bind(new_player, channel_name, path))

	if channel_name:
		current_audio_channels[channel_name] = new_player


## 如果给定 [param channel_name] 上有音频正在播放，则返回 `true`。
func is_channel_playing(channel_name: String) -> bool:
	return (current_audio_channels.has(channel_name)
		and is_instance_valid(current_audio_channels[channel_name])
		and current_audio_channels[channel_name].is_playing())


## 停止所有通道上的音频。
func stop_all_channels(fade := 0.0) -> void:
	for channel_name in current_audio_channels.keys():
		update_audio(channel_name, '', {"fade_length":fade})


### 停止所有单次音效。
func stop_all_one_shot_sounds() -> void:
	for i in one_shot_audio_node.get_children():
		i.queue_free()


## 将线性响度值转换为分贝，并把该音量设置到
## 给定的 [param node]。
func interpolate_volume_linearly(value: float, node: AudioStreamPlayer) -> void:
	node.volume_db = linear_to_db(value)


## 返回当前正在播放的音频资源是否与该事件的 [param resource_path] 相同，
## 针对 [param channel_name]。
func is_channel_playing_file(file_path: String, channel_name: String) -> bool:
	return (is_channel_playing(channel_name)
		and current_audio_channels[channel_name].stream.resource_path == file_path)


## 如果有任何通道正在播放，则返回 `true`。
func is_any_channel_playing() -> bool:
	for channel in current_audio_channels:
		if is_channel_playing(channel):
			return true
	return false


func _on_audio_finished(player: AudioStreamPlayer, channel_name: String, path: String) -> void:
	if current_audio_channels.has(channel_name) and current_audio_channels[channel_name] == player:
		current_audio_channels.erase(channel_name)
	player.queue_free()
	if info.get(channel_name, {}).get('path', '') == path:
		info.erase(channel_name)

#endregion
