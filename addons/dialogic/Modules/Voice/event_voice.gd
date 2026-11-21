@tool
class_name DialogicVoiceEvent
extends DialogicEvent

## 用于设置下一个文本事件要播放的语音文件的事件。


### Settings

## 语音文件的路径。
@export_file var file_path := "":
	set(value):
		if file_path != value:
			file_path = value
			ui_update_needed.emit()
## 语音播放时的音量。
@export var volume: float = 0
## 播放语音所用的音频总线。
@export var audio_bus := "Master"


#region 执行
################################################################################

func _execute() -> void:
	# 如果启用了自动跳过，我们可能不想播放语音。
	# 立即自动跳过会总是跳过语音。
	if (dialogic.Inputs.auto_skip.enabled
	and dialogic.Inputs.auto_skip.skip_voice):
		finish()
		return

	dialogic.Voice.set_file(file_path)
	dialogic.Voice.set_volume(volume)
	dialogic.Voice.set_bus(audio_bus)
	finish()
	# 其余部分由文本事件执行

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Voice"
	event_description = "设置一个音频文件，它将在下一个文本事件中一同播放。"
	set_default_color('Color7')
	event_category = "Audio"
	event_sorting_index = 5

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "voice"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 : 属性信息
		"path"		: {"property": "file_path", "default": ""},
		"volume"	: {"property": "volume", 	"default": 0},
		"bus"		: {"property": "audio_bus", "default": "Master"}
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('file_path', ValueType.FILE, {
			'left_text'		: '设为',
			'right_text'	: '作为下一个语音音频',
			'file_filter'	: "*.mp3, *.ogg, *.wav",
			'placeholder' 	: "选择文件",
			'editor_icon' 	: ["AudioStreamPlayer", "EditorIcons"],
			"type":["VoiceAudio", "Audio", "Asset"]})
	add_header_edit('file_path', ValueType.AUDIO_PREVIEW)
	add_body_edit('volume', ValueType.NUMBER, {'left_text':'音量：', 'mode':2}, '!file_path.is_empty()')
	add_body_edit('audio_bus', ValueType.SINGLELINE_TEXT, {'left_text':'音频总线：'}, '!file_path.is_empty()')

#endregion
