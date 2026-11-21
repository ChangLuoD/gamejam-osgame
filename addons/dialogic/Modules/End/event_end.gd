@tool
class_name DialogicEndTimelineEvent
extends DialogicEvent

## 结束时间线的事件（即使后面还有事件）。


#region 执行
################################################################################

func _execute() -> void:
	dialogic.end_timeline()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "End"
	event_description = "提前结束时间线。时间线末尾不强制要求此事件。"
	set_default_color('Color4')
	event_category = "Flow"
	event_sorting_index = 10

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "end_timeline"

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_label('结束时间线')

#endregion
