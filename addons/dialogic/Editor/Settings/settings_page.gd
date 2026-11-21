@tool
extends Control
class_name DialogicSettingsPage

@export_multiline var short_info := ""
@onready var settings_editor: Control = find_parent('Settings')

## 获取页面标识（同时被用作文本节点名与查找键，请保持英文，勿翻译）
func _get_title() -> String:
	return name


## 获取页面在界面上显示的标题（默认与标识相同，需要中文时覆盖此方法）
func _get_display_title() -> String:
	return _get_title()


## 获取页面排序权重时调用
func _get_priority() -> int:
	return 0


## 判断是否应放入「功能」区域时调用
func _is_feature_tab() -> bool:
	return false


## 设置编辑器打开时调用
func _refresh() -> void:
	pass


## 设置编辑器关闭前调用（即将打开另一个编辑器）
## 可用于保存数据
func _about_to_close() -> void:
	pass


## 返回一个包含信息的区域。
func _get_info_section() -> Control:
	return null
