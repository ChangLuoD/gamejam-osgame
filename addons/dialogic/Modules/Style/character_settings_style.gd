@tool
extends DialogicCharacterEditorMainSection

## 角色编辑器标签页，用于为角色设置自定义样式。

func _init() -> void:
	hint_text = '如果设置了角色样式，那么该角色说话时 Dialogic 会切换到该样式。 \n为此最好使用同一布局的变体，以避免大量实例化。'

func _get_title() -> String:
	return "Style"


## 界面显示标题（标识仍保持英文，仅显示用中文）
func _get_display_title() -> String:
	return "样式"


func _ready() -> void:
	%StyleName.resource_icon = get_theme_icon("PopupMenu", "EditorIcons")
	%StyleName.suggestions_func = get_style_suggestions


func _load_character(character:DialogicCharacter) -> void:
	%StyleName.set_value(character.custom_info.get('style', ''))


func _save_changes(character:DialogicCharacter) -> DialogicCharacter:
	character.custom_info['style'] = %StyleName.current_value
	return character


func get_style_suggestions(filter:String="") -> Dictionary:
	var styles: Array = ProjectSettings.get_setting('dialogic/layout/style_list', [])
	var suggestions := {}
	suggestions["无样式"] = {'value': "", 'editor_icon': ["EditorHandleDisabled", "EditorIcons"]}
	for i in styles:
		var style: DialogicStyle = load(i)
		suggestions[style.name] = {'value': style.name, 'editor_icon': ["PopupMenu", "EditorIcons"]}
	return suggestions
