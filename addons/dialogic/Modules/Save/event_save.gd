@tool
class_name DialogicSaveEvent
extends DialogicEvent

## 允许保存到指定存档位的事件。


### 设置

## 要保存到的存档位名称。详见保存子系统。
## 若留空，事件会尝试保存到最新的存档位，否则使用默认存档位。
@export var slot_name := ""


#region 执行
################################################################################

func _execute() -> void:
	if slot_name.is_empty():
		if dialogic.Save.get_latest_slot():
			dialogic.Save.save(dialogic.Save.get_latest_slot())
		else:
			dialogic.Save.save()
	else:
		dialogic.Save.save(slot_name)
	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Save"
	event_description = "使用 Dialogic 内置的保存 API 将进度保存到某个存档位。"
	set_default_color('Color6')
	event_category = "Other"
	event_sorting_index = 0


func _get_icon() -> Resource:
	return load(self.get_script().get_path().get_base_dir().path_join('icon.svg'))

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "save"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 : 属性信息
		"slot"		: {"property": "slot_name", "default": "Default"},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('slot_name', ValueType.SINGLELINE_TEXT, {'left_text':'保存到存档位'})

#endregion
