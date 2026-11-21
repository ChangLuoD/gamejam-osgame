@tool
class_name DialogicHistoryEvent
extends DialogicEvent

## 用于清空、暂停和恢复历史记录功能的事件。

enum Actions {CLEAR, PAUSE, RESUME}

### 设置

## 动作类型：清空、暂停或恢复
@export var action := Actions.PAUSE


#region 执行
################################################################################

func _execute() -> void:
	match action:
		Actions.CLEAR:
			dialogic.History.simple_history_content = []
		Actions.PAUSE:
			dialogic.History.simple_history_enabled = false
		Actions.RESUME:
			dialogic.History.simple_history_enabled = true

	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "History"
	event_description = "对简单历史记录执行一个动作。"
	set_default_color('Color9')
	event_category = "Other"
	event_sorting_index = 20

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "history"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 		: property_info
		"action" 			: {"property": "action", "default": Actions.PAUSE,
								"suggestions": func(): return {"清空":{'value':0, 'text_alt':['clear']}, "暂停":{'value':1, 'text_alt':['pause']}, "恢复":{'value':2, 'text_alt':['resume', 'start']}}},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('action', ValueType.FIXED_OPTIONS, {
		'options': [
			{
				'label': '暂停历史记录',
				'value': Actions.PAUSE,
			},
			{
				'label': '恢复历史记录',
				'value': Actions.RESUME,
			},
			{
				'label': '清空历史记录',
				'value': Actions.CLEAR,
			},
		]
		})

#endregion
