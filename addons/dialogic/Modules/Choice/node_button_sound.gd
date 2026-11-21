class_name DialogicNode_ButtonSound
extends AudioStreamPlayer

## 用于在相邻 DialogicNode_ChoiceButton 悬停/聚焦/按下时播放音效的节点。

## 当相邻的某个 ChoiceButton 被按下时播放的音效。
## 若相邻 ChoiceButton 设置了 sound_pressed，则优先使用该音效。
@export var sound_pressed: AudioStream
## 悬停时播放的音效。更多说明见 [sound_pressed]。
@export var sound_hover: AudioStream
## 聚焦时播放的音效。更多说明见 [sound_pressed]。
@export var sound_focus: AudioStream

func _ready() -> void:
	add_to_group('dialogic_button_sound')
	_connect_all_buttons()
	if bus == "Master":
		bus = ProjectSettings.get_setting("dialogic/audio/type_sound_bus", "Master")


# 基础播放音效
func play_sound(sound) -> void:
	if sound != null:
		stream = sound
		play()

func _connect_all_buttons() -> void:
	for child in get_parent().get_children():
		if child is DialogicNode_ChoiceButton:
			child.button_up.connect(_on_pressed.bind(child.sound_pressed))
			child.mouse_entered.connect(_on_hover.bind(child.sound_hover))
			child.focus_entered.connect(_on_focus.bind(child.sound_focus))


# custom_sound 参数来自对应的按钮，并会被使用
# 如果没有找到，则使用上面那些音效

func _on_pressed(custom_sound) -> void:
	if custom_sound != null:
		play_sound(custom_sound)
	else:
		play_sound(sound_pressed)

func _on_hover(custom_sound) -> void:
	if custom_sound != null:
		play_sound(custom_sound)
	else:
		play_sound(sound_hover)

func _on_focus(custom_sound) -> void:
	if custom_sound != null:
		play_sound(custom_sound)
	else:
		play_sound(sound_focus)

