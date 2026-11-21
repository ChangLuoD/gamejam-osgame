@tool
extends DialogicVisualEditorField

## 用于颜色值的事件块字段。

#region 主要方法
################################################################################

func _ready() -> void:
	self.color_changed.connect(_on_value_changed)


func _load_display_info(info:Dictionary) -> void:
	self.edit_alpha = info.get("edit_alpha", true)


func _set_value(value:Variant) -> void:
	if value is Color:
		self.color = Color(value)

#endregion


#region 信号方法
################################################################################

func _on_value_changed(value: Color) -> void:
	value_changed.emit(property_name, value)

#endregion
