@tool
class_name DialogicTextInputEvent
extends DialogicEvent

## 显示一个输入框，并将输入内容写入 Dialogic 变量的事件。


### 设置

## 要显示的提示语。
@export var text := "Please enter some text:"
## 要设置的变量名称/路径。
@export var variable := ""
## 在单行输入框中显示的占位文本。
@export var placeholder := ""
## 单行输入框中默认应显示的值。
@export var default := ""
## 若为 true，玩家什么都不输入也可以继续。
@export var allow_empty := false


#region 执行
################################################################################

func _execute() -> void:
	dialogic.Inputs.auto_skip.enabled = false
	dialogic.current_state = DialogicGameHandler.States.WAITING
	dialogic.TextInput.show_text_input(
		get_property_translated("text"),
		get_property_translated("default"),
		get_property_translated("placeholder"), allow_empty)
	dialogic.TextInput.input_confirmed.connect(_on_DialogicTextInput_input_confirmed, CONNECT_ONE_SHOT)


func _on_DialogicTextInput_input_confirmed(input:String) -> void:
	if not dialogic.has_subsystem('VAR'):
		printerr('[Dialogic] TextInput 事件需要变量子系统才能工作。')
		finish()
		return
	dialogic.VAR.set_variable(variable, input)
	dialogic.TextInput.hide_text_input()
	dialogic.current_state = DialogicGameHandler.States.IDLE
	finish()

#endregion


#region 设置
################################################################################

func _init() -> void:
	event_name = "Text Input"
	event_description = "显示文本输入框，并将输入内容存入 Dialogic 变量。"
	set_default_color('Color6')
	event_category = "Logic"
	event_sorting_index = 6

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "text_input"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 	: 属性信息
		"text"			: {"property": "text", 			"default": "Please enter some text:"},
		"var"			: {"property": "variable", 		"default": "", "suggestions":get_var_suggestions},
		"placeholder"	: {"property": "placeholder", 	"default": ""},
		"default"		: {"property": "default", 		"default": ""},
		"allow_empty"	: {"property": "allow_empty",	"default": false},
	}


func _get_translatable_properties() -> Array:
	return ["text", "placeholder", "default"]


func _get_property_original_translation(property_name:String) -> String:
	match property_name:
		"text":
			return text
		"placeholder":
			return placeholder
		"default":
			return default
	return ""

#endregion


#region 编辑器
################################################################################

func build_event_editor() -> void:
	add_header_label('显示一个输入框并存入')
	add_header_edit('variable', ValueType.DYNAMIC_OPTIONS,
			{'suggestions_func'	: get_var_suggestions,
			'icon'		 : load("res://addons/dialogic/Editor/Images/Pieces/variable.svg"),
			'placeholder':'选择变量'})
	add_body_edit('text', ValueType.SINGLELINE_TEXT, {'left_text':'文本：'})
	add_body_edit('placeholder', ValueType.SINGLELINE_TEXT, {'left_text':'占位文本：'})
	add_body_edit('default', ValueType.SINGLELINE_TEXT, {'left_text':'默认值：'})
	add_body_edit('allow_empty', ValueType.BOOL, {'left_text':'允许为空：'})


func get_var_suggestions(filter: String = "") -> Dictionary:
	var suggestions := {}
	if filter:
		suggestions[filter] = {
			'value'			: filter,
			'editor_icon'	: ["GuiScrollArrowRight", "EditorIcons"]}
	var vars: Dictionary = ProjectSettings.get_setting('dialogic/variables', {})
	for var_path in DialogicUtil.list_variables(vars, "", DialogicUtil.VarTypes.STRING):
		suggestions[var_path] = {'value':var_path, 'icon':load("res://addons/dialogic/Editor/Images/Pieces/variable.svg")}
	return suggestions

#endregion
