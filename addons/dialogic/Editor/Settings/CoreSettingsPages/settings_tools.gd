@tool
extends Node

var tool_thread : Thread
var tool_progress := 1.0
var tool_progress_mutex : Mutex
signal tool_finished_signal


func _ready() -> void:
	for button in %ToolButtons.get_children():
		button.queue_free()

	for i in get_children():
		var button := Button.new()
		button.text = i.button_text
		button.tooltip_text = i.tooltip
		button.pressed.connect(execute_tool.bind(i.method))
		%ToolButtons.add_child(button)


func execute_tool(method:Callable) -> void:
	for button in %ToolButtons.get_children():
		button.disabled = true

	var prev_timeline := close_active_timeline()
	await get_tree().process_frame
	if tool_thread and tool_thread.is_alive():
		tool_thread.wait_to_finish()

	tool_thread = Thread.new()
	tool_progress_mutex = Mutex.new()
	tool_thread.start(method)

	await tool_finished_signal
	silently_open_timeline(prev_timeline)
	for button in %ToolButtons.get_children():
		button.disabled = false


func _process(_delta: float) -> void:
	if (tool_thread and tool_thread.is_alive()) or %ToolProgress.value < 1:
		if tool_progress_mutex: tool_progress_mutex.lock()
		%ToolProgress.value = tool_progress
		if tool_progress_mutex: tool_progress_mutex.unlock()
		%ToolProgress.show()
		if %ToolProgress.value == 1:
			tool_finished_signal.emit()
			%ToolProgress.hide()


func _exit_tree() -> void:
	if tool_thread:
		tool_thread.wait_to_finish()



#region 辅助方法

## 关闭 Dialogic 编辑器中当前打开的时间线，并以资源
## 形式返回该时间线。
## 如果没有已打开的时间线，则返回 null。
func close_active_timeline() -> Resource:
	var timeline_node: DialogicEditor = get_parent().settings_editor.editors_manager.editors['Timeline']['node']
	# 我们会关闭这条时间线，以确保它能正确地更新。
	# 通过保存这个引用，我们之后可以再次打开它。
	var current_timeline := timeline_node.current_resource
	# 清理当前编辑器，这同时也会关闭时间线。
	get_parent().settings_editor.editors_manager.clear_editor(timeline_node, true)

	return current_timeline


## 在 Dialogic 编辑器中打开该时间线资源。
## 如果时间线为 null，则什么也不做。
func silently_open_timeline(timeline_to_open: Resource) -> void:
	if timeline_to_open != null:
		get_parent().settings_editor.editors_manager.edit_resource(timeline_to_open, true, true)

#endregion
