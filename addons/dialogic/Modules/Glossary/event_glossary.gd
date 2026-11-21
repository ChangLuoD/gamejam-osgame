@tool
class_name DialogicGlossaryEvent
extends DialogicEvent

## 目前不做任何事的事件。



#region 执行
################################################################################

func _execute() -> void:
	pass

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Glossary"
	set_default_color('Color6')
	event_category = "Other"
	event_sorting_index = 0

#endregion


#region 保存/加载
################################################################################
func get_shortcode() -> String:
	return "glossary"

func get_shortcode_parameters() -> Dictionary:
	return {
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	pass

#endregion
