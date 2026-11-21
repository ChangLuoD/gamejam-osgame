@tool
class_name DialogicReturnEvent
extends DialogicEvent

## 会让 dialogic 跳回上一个跳转点的事件。



#region 执行
################################################################################

func _execute() -> void:
	if not dialogic.Jump.is_jump_stack_empty():
		dialogic.Jump.resume_from_last_jump()
	else:
		dialogic.end_timeline()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Return"
	event_description = "返回到上一个跳转事件；若此前没有发生跳转，则结束时间线。"
	set_default_color('Color4')
	event_category = "Flow"
	event_sorting_index = 5
	help_page_path = "https://docs.dialogic.pro/jump-event.html"


func _get_icon() -> Resource:
	return load(self.get_script().get_path().get_base_dir().path_join('icon_return.svg'))

#endregion


#region 保存/加载
################################################################################
func to_text() -> String:
	return "return"


func from_text(_string:String) -> void:
	pass


func is_valid_event(string:String) -> bool:
	if string.strip_edges() == "return":
		return true
	return false

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_label('返回')

#endregion


#region 代码补全
################################################################################

func _get_start_code_completion(_CodeCompletionHelper:Node, TextNode:TextEdit) -> void:
	TextNode.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, 'return', 'return\n', event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.3))

#endregion


#region 语法高亮
################################################################################

func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, line:String) -> Dictionary:
	dict[line.find('return')] = {"color":event_color.lerp(Highlighter.normal_color, 0.3)}
	dict[line.find('return')+6] = {"color":event_color.lerp(Highlighter.normal_color, 0.5)}
	return dict

#endregion
