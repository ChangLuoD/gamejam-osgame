@tool
class_name DialogicSignalEvent
extends DialogicEvent

## 用参数发出 Dialogic.signal_event 信号的事件。
## 你可以这样连接此信号：`Dialogic.signal_event.connect(myfunc)`


### 设置

enum ArgumentTypes {STRING, DICTIONARY}
## 随信号提供的参数类型。
@export var argument_type := ArgumentTypes.STRING
## 随信号提供的参数。
@export var argument: Variant = ""



#region 执行
################################################################################

func _execute() -> void:
	if argument_type == ArgumentTypes.DICTIONARY:
		var result: Variant = JSON.parse_string(argument)
		if result != null:
			var dict := result as Dictionary
			dict.make_read_only()
			dialogic.emit_signal('signal_event', dict)
		else:
			push_error("[Dialogic] 信号事件中遇到无效的字典。")
	else:
		dialogic.emit_signal('signal_event', argument)
	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Signal"
	event_description = "用给定参数发出 Dialogic.signal_event 信号。你可以通过连接该信号在代码中响应它。"
	set_default_color('Color6')
	event_category = "Logic"
	event_sorting_index = 8
	help_page_path = "https://docs.dialogic.pro/dialogic-signals.html#1-signal-event"

#endregion


#region 保存/加载
################################################################################

func get_shortcode() -> String:
	return "signal"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 ：属性信息
		"arg_type"	: {"property": "argument_type", "default": ArgumentTypes.STRING,
										"suggestions": func(): return {"String":{'value':ArgumentTypes.STRING, 'text_alt':['string']}, "Dictionary":{'value':ArgumentTypes.DICTIONARY, 'text_alt':['dict', 'dictionary']}}},
		"arg"		: {"property": "argument", "default": ""}
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_label("用参数发出 Dialogic 信号")
	add_header_label("（字典在正文中）", 'argument_type == ArgumentTypes.DICTIONARY')
	add_header_edit('argument', ValueType.SINGLELINE_TEXT, {}, 'argument_type == ArgumentTypes.STRING')
	add_body_edit('argument_type',ValueType.FIXED_OPTIONS, {'left_text':'参数类型：', 'options': [
			{
				'label': '字符串',
				'value': ArgumentTypes.STRING,
			},
			{
				'label': '字典',
				'value': ArgumentTypes.DICTIONARY,
			}
		]})
	add_body_line_break('argument_type == ArgumentTypes.DICTIONARY')
	add_body_edit('argument', ValueType.DICTIONARY, {'left_text': '字典'},'argument_type == ArgumentTypes.DICTIONARY')

#endregion
