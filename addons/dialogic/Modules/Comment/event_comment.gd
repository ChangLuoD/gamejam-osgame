@tool
class_name DialogicCommentEvent
extends DialogicEvent

## 除了保存一段注释字符串外什么也不做的事件。在调试构建中会打印该注释。


### 设置

## 注释内容。
@export var text := ""


#region 执行
################################################################################

func _execute() -> void:
	print("[Dialogic Comment] #",  text)
	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Comment"
	event_description = "对游戏流程没有影响，但可以帮助你整理时间线。"
	event_sorting_index = 10
	set_default_color('Color9')
	event_category = "Other"
	event_sorting_index = 0

#endregion


#region 保存/加载
################################################################################

func to_text() -> String:
	return "# "+text


func from_text(string:String) -> void:
	text = string.trim_prefix("# ")


func is_valid_event(string:String) -> bool:
	if string.strip_edges().begins_with('#'):
		return true
	return false

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('text', ValueType.SINGLELINE_TEXT, {'left_text':'#', 'autofocus':true})

#endregion


#region 语法高亮
################################################################################

func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, _line:String) -> Dictionary:
	dict[0] = {'color':event_color.lerp(Highlighter.normal_color, 0.3)}
	return dict

#endregion
