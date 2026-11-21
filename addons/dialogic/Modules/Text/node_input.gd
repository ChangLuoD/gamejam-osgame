class_name DialogicNode_Input
extends Control

## 处理鼠标输入的节点。它可以把鼠标输入限制在
## 特定区域内，避免与其他 UI 元素冲突。
## 如果没有使用 Input 节点，则由输入子系统来处理鼠标输入。

func _ready() -> void:
	add_to_group('dialogic_input')
	gui_input.connect(_on_gui_input)


func _input(_event: InputEvent) -> void:
	if Input.is_action_pressed(ProjectSettings.get_setting('dialogic/text/input_action', 'dialogic_default_action')):
		mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_gui_input(event:InputEvent) -> void:
	DialogicUtil.autoload().Inputs.handle_node_gui_input(event)
