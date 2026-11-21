@tool
class_name DialogicStyleEvent
extends DialogicEvent

## 允许改变当前显示样式的事件。


### 设置

## 要切换到的样式名称。可以在 DialogicNode_Style 上设置。
@export var style_name := ""


#region 执行
################################################################################

func _execute() -> void:
	dialogic.Styles.change_style(style_name)
	# 需要等待新布局就绪后再继续
	await dialogic.get_tree().process_frame
	finish()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Change Style"
	event_description = "切换到样式编辑器中配置的某个样式。"
	set_default_color('Color8')
	event_category = "Visuals"
	event_sorting_index = 1

#endregion


#region 保存/加载
################################################################################
func get_shortcode() -> String:
	return "style"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 ：属性信息
		"name" 		: {"property": "style_name", "default": "", 'suggestions':get_style_suggestions},
	}

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	add_header_edit('style_name', ValueType.DYNAMIC_OPTIONS, {
			'left_text'			:'使用样式',
			'placeholder'		: '默认',
			'suggestions_func' 	: get_style_suggestions,
			'editor_icon' 		: ["PopupMenu", "EditorIcons"],
			'autofocus'			: true})


func get_style_suggestions(_filter := "") -> Dictionary:
	var styles: Array = ProjectSettings.get_setting('dialogic/layout/style_list', [])

	var suggestions := {}
	suggestions['<默认样式>'] = {'value':'', 'editor_icon':["MenuBar", "EditorIcons"]}
	for i in styles:
		var style: DialogicStyle = load(i)
		suggestions[style.name] = {'value': style.name, 'editor_icon': ["PopupMenu", "EditorIcons"]}
	return suggestions

#endregion
