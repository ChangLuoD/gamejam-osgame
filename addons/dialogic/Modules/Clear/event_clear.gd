@tool
class_name DialogicClearEvent
extends DialogicEvent

## 清除音频与视觉（不清除变量）的事件。
## 适合用来确保场景为全新的内容做好准备。

@export var time := 1.0
@export var step_by_step := true

@export var clear_textbox := true
@export var clear_portraits := true
@export var clear_style := true
@export var clear_music := true
@export var clear_portrait_positions := true
@export var clear_background := true

## 为 true 时，如果该事件是时间线的最后一个事件，Dialogic 不会真正切换样式，
## 因为这种情况非常常见，而且会让资源开销变得不必要。
var auto_avoid_style_change := true

#region 执行
################################################################################

func _execute() -> void:
	var final_time := time

	if dialogic.Inputs.auto_skip.enabled:
		var time_per_event: float = dialogic.Inputs.auto_skip.time_per_event
		final_time = min(time, time_per_event)

	if clear_textbox and dialogic.has_subsystem("Text") and dialogic.Text.is_textbox_visible():
		dialogic.Text.update_dialog_text("", true)
		if step_by_step:
			await dialogic.Text.hide_textbox(final_time == 0)
		else:
			dialogic.Text.hide_textbox(final_time == 0)
		dialogic.current_state = dialogic.States.IDLE

	if clear_portraits and dialogic.has_subsystem("Portraits") and len(dialogic.Portraits.get_joined_characters()) != 0:
		if final_time == 0:
			dialogic.Portraits.leave_all_characters("Instant", final_time, step_by_step)
		else:
			dialogic.Portraits.leave_all_characters("", final_time, step_by_step)
		if step_by_step: await dialogic.get_tree().create_timer(final_time).timeout

	if clear_background and dialogic.has_subsystem('Backgrounds') and dialogic.Backgrounds.has_background():
		dialogic.Backgrounds.update_background("", "", final_time)
		if step_by_step: await dialogic.get_tree().create_timer(final_time).timeout

	if clear_music and dialogic.has_subsystem("Audio"):
		dialogic.Audio.stop_all_one_shot_sounds()
		if dialogic.Audio.is_any_channel_playing():
			dialogic.Audio.stop_all_channels(final_time)
			if step_by_step: await dialogic.get_tree().create_timer(final_time).timeout

	if clear_style and dialogic.has_subsystem("Styles"):
		if auto_avoid_style_change and Dialogic.current_event_idx == Dialogic.current_timeline_events.size()-1:
			pass
		else:
			dialogic.Styles.change_style()

	#if clear_portrait_positions and dialogic.has_subsystem("Portraits"):
		#dialogic.PortraitContainers.reset_all_containers()

	if not step_by_step:
		await dialogic.get_tree().create_timer(final_time).timeout

	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Clear"
	event_description = "清除当前状态，例如文本、背景、立绘、样式或音频。"
	set_default_color("Color9")
	event_category = "Other"
	event_sorting_index = 2

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "clear"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 : 属性信息
		"time"		: {"property": "time",	 			"default": ""},
		"step"		: {"property": "step_by_step", 		"default": true},
		"text"		: {"property": "clear_textbox",		"default": true},
		"portraits"	: {"property": "clear_portraits", 	"default": true},
		"music"		: {"property": "clear_music", 		"default": true},
		"background": {"property": "clear_background", 	"default": true},
		"positions"	: {"property": "clear_portrait_positions", 	"default": true},
		"style"		: {"property": "clear_style", 		"default": true},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_label('清空')

	add_body_edit('time', ValueType.NUMBER, {'left_text':'时间：'})

	add_body_edit('step_by_step', ValueType.BOOL, {'left_text':'逐步：'}, 'time > 0')
	add_body_line_break()

	add_body_edit('clear_textbox', ValueType.BOOL_BUTTON, {'left_text':'清空：', 'icon':load("res://addons/dialogic/Modules/Clear/clear_textbox.svg"), 'tooltip':'清空文本框'})
	add_body_edit('clear_portraits', ValueType.BOOL_BUTTON, {'icon':load("res://addons/dialogic/Modules/Clear/clear_characters.svg"), 'tooltip':'清空立绘'})
	add_body_edit('clear_background', ValueType.BOOL_BUTTON, {'icon':load("res://addons/dialogic/Modules/Clear/clear_background.svg"), 'tooltip':'清空背景'})
	add_body_edit('clear_music', ValueType.BOOL_BUTTON, {'icon':load("res://addons/dialogic/Modules/Clear/clear_music.svg"), 'tooltip':'清空音频'})
	add_body_edit('clear_style', ValueType.BOOL_BUTTON, {'icon':load("res://addons/dialogic/Modules/Clear/clear_style.svg"), 'tooltip':'清空样式'})
	add_body_edit('clear_portrait_positions', ValueType.BOOL_BUTTON, {'icon':load("res://addons/dialogic/Modules/Clear/clear_positions.svg"), 'tooltip':'清空立绘位置'})

#endregion
