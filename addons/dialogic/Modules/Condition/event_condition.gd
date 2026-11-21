@tool
class_name DialogicConditionEvent
extends DialogicEvent

## 允许根据条件为时间线创建分支的事件。

enum ConditionTypes {IF, ELIF, ELSE}

### 设置

## 条件类型（见 [ConditionTypes]）。默认为 if。
@export var condition_type := ConditionTypes.IF
## 以字符串表示的条件。它将作为一个表达式执行。
@export var condition := ""


#region 执行
################################################################################

func _execute() -> void:
	if condition_type == ConditionTypes.ELSE:
		finish()
		return

	if condition.is_empty(): condition = "true"

	var result: bool = dialogic.Expressions.execute_condition(condition)
	if not result:
		dialogic.current_event_idx = get_end_branch_index()

	finish()


func _is_branch_starter() -> bool:
	return condition_type == ConditionTypes.IF

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Condition"
	event_description = "仅当条件为真时，才播放其中包含的事件。"
	set_default_color('Color3')
	event_category = "Flow"
	event_sorting_index = 1
	can_contain_events = true


# 返回一个应显示在「结束分支」节点上的控件节点
func _get_end_branch_control() -> Control:
	return load(get_script().resource_path.get_base_dir().path_join('ui_condition_end.tscn')).instantiate()

#endregion


#region 保存/加载
################################################################################

func to_text() -> String:
	var result_string := ""

	match condition_type:
		ConditionTypes.IF:
			result_string = 'if '+condition+':'
		ConditionTypes.ELIF:
			result_string = 'elif '+condition+':'
		ConditionTypes.ELSE:
			result_string = 'else:'

	return result_string


func from_text(string:String) -> void:
	if string.strip_edges().begins_with('if'):
		condition = string.strip_edges().trim_prefix('if ').trim_suffix(':').strip_edges()
		condition_type = ConditionTypes.IF
	elif string.strip_edges().begins_with('elif'):
		condition = string.strip_edges().trim_prefix('elif ').trim_suffix(':').strip_edges()
		condition_type = ConditionTypes.ELIF
	elif string.strip_edges().begins_with('else'):
		condition = ""
		condition_type = ConditionTypes.ELSE


func is_valid_event(string:String) -> bool:
	if string.strip_edges() in ['if', 'elif', 'else'] or (string.strip_edges().begins_with('if ') or string.strip_edges().begins_with('elif ') or string.strip_edges().begins_with('else')):
		return true
	return false


## 这里只是为了允许在模块设置中设置默认值
func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 	: 属性信息
		"condition" 	: {"property": "condition", 			"default": ""},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('condition_type', ValueType.FIXED_OPTIONS, {
		'options': [
			{
				'label': 'IF',
				'value': ConditionTypes.IF,
			},
			{
				'label': 'ELIF',
				'value': ConditionTypes.ELIF,
			},
			{
				'label': 'ELSE',
				'value': ConditionTypes.ELSE,
			}
		], 'disabled':true})
	add_header_edit('condition', ValueType.CONDITION, {}, 'condition_type != %s'%ConditionTypes.ELSE)

#endregion


#region 代码补全
################################################################################

func _get_code_completion(CodeCompletionHelper:Node, TextNode:TextEdit, line:String, _word:String, symbol:String) -> void:
	if (line.begins_with('if') or line.begins_with('elif')) and symbol == '{':
		CodeCompletionHelper.suggest_variables(TextNode)


func _get_start_code_completion(_CodeCompletionHelper:Node, TextNode:TextEdit) -> void:
	TextNode.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, 'if', 'if ', TextNode.syntax_highlighter.code_flow_color)
	TextNode.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, 'elif', 'elif ', TextNode.syntax_highlighter.code_flow_color)
	TextNode.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, 'else', 'else:\n	', TextNode.syntax_highlighter.code_flow_color)

#endregion


#region 语法高亮
################################################################################


func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, line:String) -> Dictionary:
	var word := line.get_slice(' ', 0)
	dict[line.find(word)] = {"color":Highlighter.code_flow_color}
	dict[line.find(word)+len(word)] = {"color":Highlighter.normal_color}
	dict = Highlighter.color_condition(dict, line)
	return dict

#endregion
