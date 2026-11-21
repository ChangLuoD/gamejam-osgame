@tool
class_name DialogicWaitEvent
extends DialogicEvent

## 在继续之前等待一段时间的事件。


### Settings

## 事件在继续之前会停留的时间（秒）。
@export var time: float = 1.0
## 若为 true，等待期间会隐藏文本框。
@export var hide_text := true
## 若为 true，可以用用户输入跳过等待
@export var skippable := false


#region 执行
################################################################################

func _execute() -> void:
	await dialogic.Wait.update_wait(time, hide_text, skippable)

	if dialogic.Animations.is_animating():
		dialogic.Animations.stop_animation()
	dialogic.current_state = dialogic.States.IDLE

	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Wait"
	event_description = "等待一段指定的时间。可以隐藏文本框，并允许跳过。"
	set_default_color('Color5')
	event_category = "Flow"
	event_sorting_index = 11

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "wait"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 : 属性信息
		"time" 		:  {"property": "time", 		"default": 1},
		"hide_text" :  {"property": "hide_text", 	"default": true},
		"skippable" :  {"property": "skippable", 	"default": false},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('time', ValueType.NUMBER, {'left_text':'等待', 'autofocus':true, 'min':0.1})
	add_header_label('秒', 'time != 1')
	add_header_label('秒', 'time == 1')
	add_body_edit('hide_text', ValueType.BOOL, {'left_text':'隐藏文本框：'})
	add_body_edit('skippable', ValueType.BOOL, {'left_text':'可跳过：'})

#endregion
