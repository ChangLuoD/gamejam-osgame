@tool
class_name DialogicWaitInputEvent
extends DialogicEvent

## 等待输入后再继续的事件。

@export var hide_textbox := true


#region 执行
################################################################################

func _execute() -> void:
	if hide_textbox:
		dialogic.Text.hide_textbox()
	dialogic.current_state = DialogicGameHandler.States.IDLE
	dialogic.Inputs.auto_skip.enabled = false
	await dialogic.Inputs.dialogic_action
	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Wait for Input"
	event_description = "等待直到下一次推进输入动作。"
	set_default_color('Color5')
	event_category = "Flow"
	event_sorting_index = 12
	collapse_on_create = true

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "wait_input"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name : property_info
		"hide_text" :  {"property": "hide_textbox", 	"default": true},
	}


func build_event_editor() -> void:
	add_header_label('等待输入')
	add_body_edit('hide_textbox', ValueType.BOOL, {'left_text':'隐藏文本框：'})

#endregion
