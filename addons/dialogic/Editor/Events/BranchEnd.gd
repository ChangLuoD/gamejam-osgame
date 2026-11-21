@tool
extends Control
## 显示在包含其他事件的事件末尾的场景

var resource: DialogicEndBranchEvent

# 引用
var parent_node: Control = null
var end_control: Control = null

# 缩进
var indent_size := 22
var current_indent_level := 1

var selected := false

func _ready() -> void:
	if get_parent() is SubViewport:
		return
	$Icon.icon = get_theme_icon("GuiSpinboxUpdown", "EditorIcons")
	$Spacer.custom_minimum_size.x = 90 * DialogicUtil.get_editor_scale()
	visual_deselect()
	parent_node_changed()


## 由可视化时间线编辑器调用
func visual_select() -> void:
	modulate = get_theme_color("highlighted_font_color", "Editor")
	selected = true


## 由可视化时间线编辑器调用
func visual_deselect() -> void:
	if !parent_node:return
	selected = false
	modulate = parent_node.resource.event_color.lerp(get_theme_color("font_color", "Editor"), 0.3)


func is_selected() -> bool:
	return selected


## 由可视化时间线编辑器调用
func highlight() -> void:
	if !parent_node:return
	modulate = parent_node.resource.event_color.lerp(get_theme_color("font_color", "Editor"), 0.6)


## 由可视化时间线编辑器调用
func unhighlight() -> void:
	modulate = parent_node.resource.event_color


## 由可视化时间线编辑器调用
func set_indent(indent: int) -> void:
	$Indent.custom_minimum_size = Vector2(indent_size * indent * DialogicUtil.get_editor_scale(), 0)
	$Indent.visible = indent != 0
	current_indent_level = indent
	queue_redraw()


## 如果父事件块上被编辑了内容，由可视化时间线编辑器调用
func parent_node_changed() -> void:
	if parent_node and end_control and end_control.has_method('refresh'):
		end_control.refresh()


## 创建时若父事件提供了结束控件则调用
func add_end_control(control:Control) -> void:
	if !control:
		return
	add_child(control)
	control.size_flags_vertical = SIZE_SHRINK_CENTER
	if "parent_resource" in control:
		control.parent_resource = parent_node.resource
	if control.has_method('refresh'):
		control.refresh()
	end_control = control
