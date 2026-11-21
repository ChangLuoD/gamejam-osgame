@tool
class_name DialogicVisualEditorField
extends Control

@warning_ignore("unused_signal")
signal value_changed(property_name:String, value:Variant)
var property_name := ""

var event_resource: DialogicEvent = null

#region 覆写方法
################################################################################

## 供子类重写
func _load_display_info(_info:Dictionary) -> void:
	pass


## 供子类重写
func _set_value(_value:Variant) -> void:
	pass


## 供子类重写
func _autofocus() -> void:
	pass

#endregion


func set_value(value:Variant) -> void:
	_set_value(value)


func take_autofocus() -> void:
	_autofocus()
