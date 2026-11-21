@tool
class_name DialogicBackgroundEvent
extends DialogicEvent

## 用于在背景中显示场景并在场景之间切换的事件。

### 设置

## 要使用的场景。如果为空，则默认为 DefaultBackground.gd 场景。
## 该场景支持图片与淡入淡出。
## 如果将其设置为场景路径，则会实例化该场景。
## 在 Subsystem_Background.gd 的文档中了解有关自定义背景的更多信息。
@export var scene := ""
## 传递给背景场景的参数。
## 对默认场景而言，它是要显示的图片的路径。
@export var argument := "":
	set(a):
		if a != argument:
			argument = a
			if _arg_type == ArgumentTypes.IMAGE:
				ui_update_needed.emit()
## 淡入淡出动画的时长。设为 0 表示立即切换。
@export var fade: float = 0.0
## 要使用的过渡名称。
@export var transition := ""
## 如果为 `true`，将在继续前等待过渡时长。
@export var await_transition := false

## 视觉编辑器的辅助内容
enum ArgumentTypes {IMAGE, COLOR, STRING}
var _arg_type := ArgumentTypes.IMAGE:
	get:
		if argument == "res://" or (argument.begins_with("res://") and argument.get_extension().to_lower() in ["png", "svg", "jpg", "jpeg"]):
			return ArgumentTypes.IMAGE
		elif argument.begins_with("#") and argument.is_valid_html_color():
			return ArgumentTypes.COLOR
		elif argument.is_empty():
			return _arg_type
		else:
			return ArgumentTypes.STRING
	set(value):
		if value == ArgumentTypes.STRING:
			argument = ""
		elif value == ArgumentTypes.COLOR:
			if not (argument.is_valid_html_color() and argument.begins_with("#")):
				argument = "#"+Color.BLACK.to_html()
		elif value == ArgumentTypes.IMAGE:
			if ResourceLoader.exists(argument.strip_edges()):
				argument = argument.strip_edges()
			else:
				argument = "res://"

		_arg_type = value

var _color_arg := Color():
	get():
		return Color.from_string(argument, Color.BLACK)
	set(c):
		_color_arg = c
		if _arg_type == ArgumentTypes.COLOR:
			argument = "#"+c.to_html()

enum SceneTypes {DEFAULT, CUSTOM}
var _scene_type := SceneTypes.DEFAULT :
	get:
		if scene.is_empty():
			return _scene_type
		else:
			return SceneTypes.CUSTOM
	set(value):
		if value == SceneTypes.DEFAULT:
			scene = ""
		_scene_type = value

#region 执行
################################################################################

func _execute() -> void:
	var final_fade_duration := fade

	if dialogic.Inputs.auto_skip.enabled:
		var time_per_event: float = dialogic.Inputs.auto_skip.time_per_event
		final_fade_duration = min(fade, time_per_event)

	dialogic.Backgrounds.update_background(scene, argument, final_fade_duration, transition)

	if await_transition:
		await dialogic.get_tree().create_timer(final_fade_duration).timeout

	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Background"
	event_description = "显示或隐藏背景图片或场景。"
	set_default_color('Color8')
	event_category = "Visuals"
	event_sorting_index = 0

#endregion


#region 保存与加载
################################################################################

func get_shortcode() -> String:
	return "background"


func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 	: property_info
		"scene" 		: {"property": "scene", 			"default": "", "ext_file":true},
		"arg" 			: {"property": "argument", 			"default": "", "ext_file":true},
		"fade" 			: {"property": "fade", 				"default": 0},
		"transition"	: {"property": "transition",		"default": "",
									"suggestions": get_transition_suggestions},
		"wait": 		{"property": "await_transition",	"default": false}
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('_scene_type', ValueType.FIXED_OPTIONS, {
		'left_text' :'显示',
		'options': [
			{
				'label': '背景',
				'value': SceneTypes.DEFAULT,
				'icon': ["GuiRadioUnchecked", "EditorIcons"]
			},
			{
				'label': '场景',
				'value': SceneTypes.CUSTOM,
				'icon': ["PackedScene", "EditorIcons"]
			}
		]})
	#add_header_label("from file", "_scene_type == SceneTypes.DEFAULT")
	add_header_edit("scene", ValueType.FILE,
			{'file_filter':'*.tscn, *.scn; 场景文件',
			'placeholder': "自定义场景",
			'editor_icon': ["PackedScene", "EditorIcons"],
			"type": "BackgroundScene, Background, Scene, Asset",
			}, '_scene_type == SceneTypes.CUSTOM')
	add_header_edit('_arg_type', ValueType.FIXED_OPTIONS, {
		'left_text' : '以',
		'options': [
			{
				'label': '图片',
				'value': ArgumentTypes.IMAGE,
				'icon': ["Image", "EditorIcons"]
			},
			{
				'label': '颜色',
				'value': ArgumentTypes.COLOR,
				'icon': ["Color", "EditorIcons"]
			},
			{
				'label': '参数',
				'value': ArgumentTypes.STRING,
				'icon': ["String", "EditorIcons"]
			}
		]})
	add_header_edit('argument', ValueType.FILE,
			{'file_filter':'*.jpg, *.jpeg, *.png, *.webp, *.tga, *svg, *.bmp, *.dds, *.exr, *.hdr; 支持的图片文件',
			'placeholder': "无图片",
			'editor_icon': ["Image", "EditorIcons"],
			"type":"BackgroundImage, Background, Image, Asset",
			},
			'_arg_type == ArgumentTypes.IMAGE')
	add_header_edit('_color_arg', ValueType.COLOR, {}, '_arg_type == ArgumentTypes.COLOR')
	add_header_edit('argument', ValueType.SINGLELINE_TEXT, {}, '_arg_type == ArgumentTypes.STRING')

	add_body_edit("argument", ValueType.IMAGE_PREVIEW, {'left_text':'预览：'},
		'(_arg_type == ArgumentTypes.IMAGE) and !argument.is_empty()')
	add_body_line_break('(_arg_type == ArgumentTypes.IMAGE) and !argument.is_empty()')

	add_body_edit("transition", ValueType.DYNAMIC_OPTIONS,
			{'left_text':'过渡：',
			'empty_text':'简单淡化',
			'value_display': true,
			'suggestions_func':get_transition_suggestions,
			'editor_icon':["PopupMenu", "EditorIcons"]})
	add_body_edit("fade", ValueType.NUMBER, {'left_text':'淡入淡出时长：'})
	add_body_edit("await_transition", ValueType.BOOL, {'left_text':'等待淡入淡出：', "tooltip":"如果为 true，将在继续前等待过渡时长。"})


func get_transition_suggestions(_filter:String="") -> Dictionary:
	var transitions := DialogicResourceUtil.list_special_resources("BackgroundTransition")
	var suggestions := {}
	for i in transitions:
		var pretty: String = DialogicUtil.pretty_name(i)
		suggestions[DialogicUtil.get_value_display_name(pretty)] = {'value': pretty, 'editor_icon': ["PopupMenu", "EditorIcons"]}
	return suggestions

#endregion
