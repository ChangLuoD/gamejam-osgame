class_name DialogicNode_TextInput
extends Control

## 当执行到文本输入事件时会显示的节点。
## 需要连接到一个（通常是子节点的）标签、一个单行输入框和一个按钮才能工作。

## 要使用的 LineEdit。
@export_node_path var input_line_edit: NodePath
## 要使用的 Label。
@export_node_path var text_label: NodePath
## 要使用的 Button。
@export_node_path var confirmation_button: NodePath

# 由子系统设置，用作确认检查。
var _allow_empty := false


func _ready() -> void:
	add_to_group('dialogic_text_input')
	if confirmation_button:
		get_node(confirmation_button).pressed.connect(_on_confirmation_button_pressed)
	if input_line_edit:
		get_node(input_line_edit).text_changed.connect(_on_input_text_changed)
		get_node(input_line_edit).text_submitted.connect(_on_confirmation_button_pressed)
	visible = false


func set_text(text:String) -> void:
	if get_node(text_label) is Label:
		get_node(text_label).text = text


func set_placeholder(placeholder:String) -> void:
	if get_node(input_line_edit) is LineEdit:
		get_node(input_line_edit).placeholder_text = placeholder
		get_node(input_line_edit).grab_focus()


func set_default(default:String) -> void:
	if get_node(input_line_edit) is LineEdit:
		get_node(input_line_edit).text = default
		# 给 `text` 赋值会把光标重置到第 0 列。因此要放在默认值之后，
		# 这样预填的输入框可以立刻输入或退格。
		get_node(input_line_edit).caret_column = default.length()
		_on_input_text_changed(default)


func set_allow_empty(boolean:bool) -> void:
	_allow_empty = boolean


func _on_input_text_changed(text:String) -> void:
	if confirmation_button.is_empty():
		return
	get_node(confirmation_button).disabled = !_allow_empty and text.is_empty()


func _on_confirmation_button_pressed(text:="") -> void:
	if get_node(input_line_edit) is LineEdit:
		if !get_node(input_line_edit).text.is_empty() or _allow_empty:
			DialogicUtil.autoload().TextInput.input_confirmed.emit(get_node(input_line_edit).text)
