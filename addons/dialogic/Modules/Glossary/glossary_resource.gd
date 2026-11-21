@tool
## 用于存储术语表条目的资源。可以保存到磁盘，并作为术语表使用。
## 在术语表编辑器中添加/创建术语表
class_name DialogicGlossary
extends Resource

## 存储该术语表的所有条目。
##
## 值可以是一个代表条目的字典，也可以是一个
## 字符串，代表所用键对应的实际键。
## 字符串键值对是别名键，它们可以重定向
## 到实际的术语表条目。
@export var entries := {}

## 若为 false，该术语表的条目都不会显示
@export var enabled: bool = true

## 指该资源在 CSV 翻译文件中使用的翻译类型。
const RESOURCE_NAME := "Glossary"
## 术语表条目的名称，其值是 [member entries] 中的键。
## 该常量用于 CSV 翻译文件。
const NAME_PROPERTY := "name"
## 术语表条目中的属性。条目名称的别名。
const ALTERNATIVE_PROPERTY := "alternatives"
## 术语表条目中的属性。
const TITLE_PROPERTY := "title"
## 术语表条目中的属性。
const TEXT_PROPERTY := "text"
## 术语表条目中的属性。
const EXTRA_PROPERTY := "extra"
## 术语表条目中的属性。该条目的翻译 ID。
## 若该条目尚未翻译，可能为空。
const TRANSLATION_PROPERTY := "_translation_id"
## 术语表条目中的属性。
const REGEX_OPTION_PROPERTY := "regex_options"
## 条目中私有属性使用的前缀。
## 翻译条目时会被忽略。
const PRIVATE_PROPERTY_PREFIX := "_"


## 该术语表被翻译时分配的私有 ID。
@export var _translation_id := ""

## 用于查找术语表条目翻译 ID 的私有查找表。
## 键（String）是所有可能触发某个术语表条目显示的
## 已翻译词语。
## 值（String）是翻译 ID。
@export var _translation_keys := {}



## 从术语表中移除一个条目及其所有别名
## （别名属性）。
## [param entry_key] 可以是条目名称或别名。
##
## 若找到与给定 [param entry_key] 匹配的条目，则返回 true。
func remove_entry(entry_key: String) -> bool:
	var entry: Dictionary = get_entry(entry_key)

	if entry.is_empty():
		return false

	var aliases: Array = entry.get(ALTERNATIVE_PROPERTY, [])

	for alias: String in aliases:
		_remove_entry_alias(alias)

	entries.erase(entry_key)

	return true


## 这是一个内部方法。
## 根据给定的 [param entry_key] 删除一个条目别名键。
##
## 若 [param entry_key] 指向某个值，且该值
## 是一个别名，则返回 true。
##
## 该方法不会更新条目的别名属性。
func _remove_entry_alias(entry_key: String) -> bool:
	var value: Variant = entries.get(entry_key, null)

	if value == null or value is Dictionary:
		return false

	entries.erase(entry_key)

	return true


## 更新术语表条目的名称及相关别名键。
## [param old_entry_key] 是该条目原来的唯一名称。
## [param new_entry_key] 是该条目新的唯一名称。
##
## 若 [param old_entry_key] 不存在，该方法会失败。

## 不要用它来更新别名。
## 若要更新别名，请先用
## [method _remove_entry_alias] 全部删除，再用
## [method _add_entry_key_alias] 重新添加。
func replace_entry_key(old_entry_key: String, new_entry_key: String) -> void:
	var entry := get_entry(old_entry_key)

	if entry == null:
		return

	entry.name = new_entry_key

	entries.erase(old_entry_key)
	entries[new_entry_key] = entry


## 获取给定 [param entry_key] 对应的术语表条目。
## 若没有匹配的条目，将返回一个空 Dictionary。
## 有效的术语表条目字典永远不会为空。
func get_entry(entry_key: String) -> Dictionary:
	var entry: Variant = entries.get(entry_key, {})

	# 处理别名值。
	if entry is String:
		entry = entries.get(entry, {})

	return entry


## 这是一个内部方法。
## [param entry_key] 必须是某个条目的有效条目键。
## 把 [param alias] 添加为该条目的有效条目键。
##
## 返回该条目的索引，条目不存在时返回 -1。
func _add_entry_key_alias(entry_key: String, alias: String) -> bool:
	var entry := get_entry(entry_key)
	var alias_entry := get_entry(alias)

	if not entry.is_empty() and alias_entry.is_empty():
		entries[alias] = entry_key
		return true

	return false


## 若该条目不存在，把 [param entry] 添加到术语表。
## 若已存在，则返回 false。
func try_add_entry(entry: Dictionary) -> bool:
	var entry_key: String = entry[NAME_PROPERTY]

	if entries.has(entry_key):
		return false

	entries[entry_key] = entry

	for alternative: String in entry.get(ALTERNATIVE_PROPERTY, []):
		entries[alternative.strip_edges()] = entry_key

	return true


## 返回一个可触发术语表弹出层的词语数组。
## 该方法会遵循是否启用了翻译。
## 词语可能是：条目键与别名词语。
func _get_word_options(entry_key: String) -> Array:
	var word_options: Array = []

	var translation_enabled: bool = ProjectSettings.get_setting("dialogic/translation/enabled", false)

	if not translation_enabled:
		word_options.append(entry_key)

		for alternative: String in get_entry(entry_key).get(ALTERNATIVE_PROPERTY, []):
			word_options.append(alternative.strip_edges())

		return word_options

	var translation_entry_key_id: String = get_property_translation_key(entry_key, NAME_PROPERTY)

	if translation_entry_key_id.is_empty():
		return []

	var translated_entry_key := tr(translation_entry_key_id)

	if not translated_entry_key == translation_entry_key_id:
		word_options.append(translated_entry_key)

	var translation_alternatives_id: String = get_property_translation_key(entry_key, ALTERNATIVE_PROPERTY)
	var translated_alternatives_str := tr(translation_alternatives_id)

	if not translated_alternatives_str == translation_alternatives_id:
		var translated_alternatives := translated_alternatives_str.split(",")

		for alternative: String in translated_alternatives:
			word_options.append(alternative.strip_edges())

	return word_options


## 获取给定 [param entry_key] 的正则选项。
## 若该正则选项不存在，将自动生成。
##
## 正则选项是可触发术语表弹出层的有效词语
## 的汇总。
##
## [param entry_key] 必须有效，否则会发生错误。
func get_set_regex_option(entry_key: String) -> String:
	var entry: Dictionary = get_entry(entry_key)

	var regex_options: Dictionary = entry.get(REGEX_OPTION_PROPERTY, {})

	if regex_options.is_empty():
		entry[REGEX_OPTION_PROPERTY] = regex_options

	var locale_key: String = TranslationServer.get_locale()
	var regex_option: String = regex_options.get(locale_key, "")

	if not regex_option.is_empty():
		return regex_option

	var word_options: Array = _get_word_options(entry_key)
	regex_option = "|".join(word_options)

	regex_options[locale_key] = regex_option

	return regex_option


#region 添加与清除翻译键

## 这是自动调用的，无需手动使用。
func add_translation_id() -> String:
	_translation_id = DialogicUtil.get_next_translation_id()
	return _translation_id


## 移除该术语表的翻译 ID。
func remove_translation_id() -> void:
	_translation_id = ""


## 移除所有术语表条目的翻译 ID。
func remove_entry_translation_ids() -> void:
	for entry: Variant in entries.values():

		# 忽略别名。
		if entry is String:
			continue

		if entry.has(TRANSLATION_PROPERTY):
			entry[TRANSLATION_PROPERTY] = ""


## 清空使用翻译键的查找表。
func clear_translation_keys() -> void:
	const RESOURCE_NAME_KEY := RESOURCE_NAME + "/"

	for translation_key: String in entries.keys():

		if translation_key.begins_with(RESOURCE_NAME_KEY):
			entries.erase(translation_key)

	_translation_keys.clear()

#endregion


#region 获取与设置翻译 ID 和键

## 返回一个用于在翻译 CSV 文件中引用该术语表的键。
##
## 时间复杂度：O(1)
func get_property_translation_key(entry_key: String, property: String) -> String:
	var entry := get_entry(entry_key)

	if entry == null:
		return ""

	var entry_translation_key: String = entry.get(TRANSLATION_PROPERTY, "")

	if entry_translation_key.is_empty() or _translation_id.is_empty():
		return ""

	var glossary_csv_key := (RESOURCE_NAME
		.path_join(_translation_id)
		.path_join(entry_translation_key)
		.path_join(property))

	return glossary_csv_key



## 返回该术语表的翻译键前缀。
## 生成的格式类似这样：Glossary/a2/
## 该前缀可用于查找该术语表的翻译。
func _get_glossary_translation_id_prefix() -> String:
	return (
		DialogicGlossary.RESOURCE_NAME
			.path_join(_translation_id)
	)


## 返回给定 [param glossary_translation_id] 与
## [param entry_translation_id] 对应的翻译键。
##
## 这里的键，指的是每个翻译条目中唯一的属性名。
##
## 生成的格式类似这样：Glossary/a2/b4/name
func _get_glossary_translation_key(entry_translation_id: String, property: String) -> String:
	return (
		DialogicGlossary.RESOURCE_NAME
			.path_join(_translation_id)
			.path_join(entry_translation_id)
			.path_join(property)
	)


## 尝试获取该术语表条目的翻译 ID。
## 若不存在，将生成一个新的。
func get_set_glossary_entry_translation_id(entry_key: String) -> String:
	var glossary_entry: Dictionary = get_entry(entry_key)
	var entry_translation_id := ""

	var glossary_translation_id: String = glossary_entry.get(TRANSLATION_PROPERTY, "")

	if glossary_translation_id.is_empty():
		entry_translation_id = DialogicUtil.get_next_translation_id()
		glossary_entry[TRANSLATION_PROPERTY] = entry_translation_id

	else:
		entry_translation_id = glossary_entry[TRANSLATION_PROPERTY]

	return entry_translation_id


## 尝试获取该术语表的翻译 ID。
## 若不存在，将生成一个新的。
func get_set_glossary_translation_id() -> String:
	if _translation_id == null or _translation_id.is_empty():
		add_translation_id()

	return _translation_id

#endregion
