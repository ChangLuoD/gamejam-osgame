@tool
extends DialogicVisualEditorField

## 单行文本的事件块字段。


var placeholder := "":
	set(value):
		placeholder = value
		self.placeholder_text = placeholder


#region 主要方法
################################################################################

func _ready() -> void:
	self.text_changed.connect(_on_text_changed)


func _load_display_info(info:Dictionary) -> void:
	self.placeholder = info.get('placeholder', '')


func _set_value(value:Variant) -> void:
	self.text = str(value)


func _autofocus() -> void:
	grab_focus()

#endregion


#region 信号方法
################################################################################

func _on_text_changed(value := "") -> void:
	value_changed.emit(property_name, self.text)

#endregion
