@tool
@icon("uid://bbea0efx0ybu7")
extends "res://addons/dialogic/Resources/dialogic_identifiable_resource.gd"
class_name DialogicCharacter


## 表示对话中角色的资源。
## 管理/包含立绘、自定义信息以及角色的翻译。

@export var display_name := ""
@export var nicknames := []

@export var color := Color()
@export var description := ""

@export var scale  := 1.0
@export var offset := Vector2()
@export var mirror := false

@export var default_portrait := ""
@export var portraits := {}

@export var custom_info := {}

## 所有可通过翻译访问的有效属性。
enum TranslatedProperties {
	NAME,
	NICKNAMES,
}

var _translation_id := ""


func _get_extension() -> String:
	return "dch"


func _get_resource_name() -> String:
	return "DialogicCharacter"


## 为角色添加一个翻译 ID。
func add_translation_id() -> String:
	_translation_id = DialogicUtil.get_next_translation_id()
	return _translation_id


## 返回角色的翻译 ID。
## 若角色没有翻译 ID，则为其添加一个。
func get_set_translation_id() -> String:
	if _translation_id == null or _translation_id.is_empty():
		return add_translation_id()
	else:
		return _translation_id


## 从角色移除翻译 ID。
func remove_translation_id() -> void:
	_translation_id = ""


## 检查 [param property] 并将其匹配到一个翻译键。
##
## 若传入无效的整数，行为未定义。
func get_property_translation_key(property: TranslatedProperties) -> String:
	var property_key := ""

	match property:
		TranslatedProperties.NAME:
			property_key = "name"
		TranslatedProperties.NICKNAMES:
			property_key = "nicknames"

	return "Character".path_join(_translation_id).path_join(property_key)


## 访问角色的原始文本。
##
## 若传入无效的整数，行为未定义。
func _get_property_original_text(property: TranslatedProperties) -> String:
	match property:
		TranslatedProperties.NAME:
			return display_name
		TranslatedProperties.NICKNAMES:
			return ", ".join(nicknames)

	return ""


## 访问角色的某个属性，若满足条件则尝试
## 翻译该属性。
##
## 必须在项目设置中启用翻译功能。
## 必须设置翻译 ID。
## 否则按原样返回该文本属性。
##
## 若传入无效的整数，行为未定义。
func _get_property_translated(property: TranslatedProperties) -> String:
	var try_translation: bool = (_translation_id != null
		and not _translation_id.is_empty()
		and ProjectSettings.get_setting('dialogic/translation/enabled', false)
	)

	if try_translation:
		var translation_key := get_property_translation_key(property)
		var translated_property := tr(translation_key)

		# 若找不到翻译，tr() 会返回 ID。
		# 但我们希望回退到原始文本。
		if translated_property == translation_key:
			return _get_property_original_text(property)

		return translated_property

	else:
		return _get_property_original_text(property)


## 翻译角色的别名，然后将其作为字符串
## 数组返回。
func get_nicknames_translated() -> Array:
	var translated_nicknames := _get_property_translated(TranslatedProperties.NICKNAMES)
	return (translated_nicknames.split(", ") as Array)


## 翻译并返回角色的显示名称。
func get_display_name_translated() -> String:
	return _get_property_translated(TranslatedProperties.NAME)


## 返回此角色的最佳名称。
func get_character_name() -> String:
	var unique_identifier := get_identifier()
	if not unique_identifier.is_empty():
		return unique_identifier
	if not resource_path.is_empty():
		return resource_path.get_file().trim_suffix('.dch')
	elif not display_name.is_empty():
		return display_name.validate_node_name()
	else:
		return "UnnamedCharacter"


## 返回指定立绘的信息。
## 若指定立绘不存在，则使用默认立绘。
func get_portrait_info(portrait_name:String) -> Dictionary:
	return portraits.get(portrait_name, portraits.get(default_portrait, {}))


## 用于在运行时简化创建立绘的辅助方法。
## 若有更复杂的需求，建议手动写入 portraits 字典。
func add_portrait(name:String, image:String, scene:= "") -> void:
	portraits[name] = {
		"scene": scene,
		"export_overrides": {
			"image": image}
		}
