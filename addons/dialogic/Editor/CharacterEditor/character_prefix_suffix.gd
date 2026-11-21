@tool
class_name DialogicCharacterPrefixSuffixSection
extends DialogicCharacterEditorMainSection
## 角色编辑器区块，用于设置角色的前缀和后缀。
##
## 加载并设置角色的前缀和后缀。
## 提供 [const PREFIX_CUSTOM_KEY] 和 [const SUFFIX_CUSTOM_KEY]，用于
## 访问 [class DialogicCharacter] 的 `custom_info` 字典。

@export var prefix_input: LineEdit
@export var suffix_input: LineEdit

## 我们不会强行给玩家加上任何前缀或后缀，
## 以确保他们更新后游戏仍能像以前一样正常工作。
const DEFAULT_PREFIX = ""
const DEFAULT_SUFFIX = ""

## `custom_info` 字典中用于前缀的键。
const PREFIX_CUSTOM_KEY = "prefix"

## `custom_info` 字典中用于前缀的键。
const SUFFIX_CUSTOM_KEY = "suffix"

var suffix := ""
var prefix := ""


func _ready() -> void:
	suffix_input.text_changed.connect(_suffix_changed)
	prefix_input.text_changed.connect(_prefix_changed)


func _suffix_changed(text: String) -> void:
	suffix = text


func _prefix_changed(text: String) -> void:
	prefix = text


func _get_title() -> String:
	return "Character Prefix & Suffix"


## 界面显示标题（标识仍保持英文，仅显示用中文）
func _get_display_title() -> String:
	return "角色前缀与后缀"


func _show_title() -> bool:
	return true


func _start_opened() -> bool:
	return false


func _load_portrait_data(portrait_data: Dictionary) -> void:
	_load_prefix_data(portrait_data)


## 我们从角色的 `custom_info` 字典中加载前缀和后缀。
func _load_character(resource: DialogicCharacter) -> void:
	_load_prefix_data(resource.custom_info)


func _load_prefix_data(data: Dictionary) -> void:
	suffix = data.get(SUFFIX_CUSTOM_KEY, DEFAULT_SUFFIX)
	prefix = data.get(PREFIX_CUSTOM_KEY, DEFAULT_PREFIX)

	suffix_input.text = suffix
	prefix_input.text = prefix


## 每当用户保存角色时，我们便保存前缀和后缀。
func _save_changes(character: DialogicCharacter) -> DialogicCharacter:
	if not character:
		printerr("[Dialogic] 无法保存前缀与后缀，角色缺失。")
		return character

	character.custom_info[PREFIX_CUSTOM_KEY] = prefix
	character.custom_info[SUFFIX_CUSTOM_KEY] = suffix

	return character
