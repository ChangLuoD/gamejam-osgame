@tool
class_name DialogicLabelEvent
extends DialogicEvent

## 用作锚点的事件。你可以使用 DialogicJumpEvent 跳转到这个位置。


### 设置

## 用于标识该标签。同一时间线中若有重名，则总是选择第一个。
@export var name := ""
## 可在游戏中使用的可翻译属性。
## 会传给 [signal Dialogic.Jump.passed_label] 信号，最后一个可以通过 [method Dialogic.Jump.get_last_label_name] 获取。
@export var display_name := ""


#region 执行
################################################################################

func _execute() -> void:
	# 此事件主要在 Jump 子系统中实现。
	dialogic.Jump.passed_label.emit(
		{
			"identifier": name,
			"display_name": get_property_translated("display_name"),
			"display_name_orig": display_name,
			"timeline": dialogic.current_timeline.get_identifier()
		})
	finish()


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Label"
	event_description = "提供一个可供跳转事件跳转到的位置。可用于把时间线分割成若干段落。"
	set_default_color('Color4')
	event_category = "Flow"
	event_sorting_index = 3
	help_page_path = "https://docs.dialogic.pro/jump-event.html"
	collapse_on_create = true


func _get_icon() -> Resource:
	return load(self.get_script().get_path().get_base_dir().path_join('icon_label.png'))

#endregion


#region 保存/加载
################################################################################
func to_text() -> String:
	if display_name.is_empty():
		return "label "+name
	else:
		return "label "+name+ " ("+display_name+")"



func from_text(string:String) -> void:
	var regex := RegEx.create_from_string(r'label +(?<name>[^(]+)(\((?<display_name>.+)\))?')
	var result := regex.search(string.strip_edges())
	if result:
		name = result.get_string('name').strip_edges()
		display_name = result.get_string('display_name').strip_edges()


func is_valid_event(string:String) -> bool:
	if string.strip_edges().begins_with("label"):
		return true
	return false


# 这里只是为了提供一份默认值列表
# 这样模块管理器才能为这个事件添加自定义的默认覆盖值。
func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 	: property_info
		"name" 			: {"property": "name", "default": ""},
		"display" 		: {"property": "display_name", "default": ""},
	}


func _get_translatable_properties() -> Array:
	return ["display_name"]


func _get_property_original_translation(property_name:String) -> String:
	match property_name:
		'display_name':
			return display_name
	return ''

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('name', ValueType.SINGLELINE_TEXT, {'left_text':'标签', 'autofocus':true})
	add_body_edit('display_name', ValueType.SINGLELINE_TEXT, {'left_text':'显示名称：'})

#endregion


#region 代码补全
################################################################################

func _get_start_code_completion(_CodeCompletionHelper:Node, TextNode:TextEdit) -> void:
	TextNode.add_code_completion_option(CodeEdit.KIND_PLAIN_TEXT, 'label', 'label ', event_color.lerp(TextNode.syntax_highlighter.normal_color, 0.3))

#endregion


#region 语法高亮
################################################################################

func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, line:String) -> Dictionary:
	dict[line.find('label')] = {"color":event_color.lerp(Highlighter.normal_color, 0.3)}
	dict[line.find('label')+5] = {"color":event_color.lerp(Highlighter.normal_color, 0.5)}
	return dict

#endregion
