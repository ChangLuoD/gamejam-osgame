@tool
class_name DialogicEditor
extends Control

## 所有 Dialogic 编辑器的基类。

# 当 current_resource_state 变化时，这些信号会自动发出。
signal resource_saved()
signal resource_unsaved()

@warning_ignore("unused_signal")# 该信号由编辑器管理器发出
signal opened

var current_resource: Resource

## 当前资源的状态
enum ResourceStates {SAVED, UNSAVED}
var current_resource_state: ResourceStates:
	set(value):
		current_resource_state = value
		if value == ResourceStates.SAVED:
			resource_saved.emit()
		else:
			resource_unsaved.emit()

var editors_manager: Control
# 在无资源编辑器中，显示在当前资源标签上的文本
var alternative_text: String = ""

## 覆盖。在此处向编辑器管理器注册。
func _register() -> void:
	pass


## 用于标签页
func _get_icon() -> Texture:
	return null

## 用于标签页
func _get_title() -> String:
	return ""


## 如果该编辑器支持编辑资源，在这里加载它们（在子类中覆盖）
func _open_resource(_resource:Resource) -> void:
	pass


## 如果该编辑器支持编辑资源，在这里保存它们（在子类中覆盖）
func _save() -> void:
	pass


## 覆盖。当该编辑器被显示时调用。（不必调用 show()）
func _open(_extra_info:Variant = null) -> void:
	pass


## 覆盖。当另一个编辑器被打开时调用。（不必调用 hide()）
func _close() -> void:
	pass


## 覆盖。用于清除编辑器中的所有当前状态和资源。
## 虽然很少用到，但有时你就是想让所有时间线都不处于打开状态。
func _clear() -> void:
	pass
