class_name DialogicCsvFile
extends RefCounted
## 处理把 [class DialogicTimeline] 转换为 CSV 文件。

var lines: Array[PackedStringArray] = []
## 原文件中的行字典。
## 键：String，值：PackedStringArray
var old_lines: Dictionary = {}

## 加载后 CSV 文件具有的列数。
## 用于给新行补上末尾的逗号。
var column_count := 0

## 该 CSV 文件是否是从一个确定的
## 文件路径加载而来的。
var is_new_file: bool = false

## 用于读写该 CSV 文件的底层文件。
var file: FileAccess

## 用于加载该 CSV 文件的文件路径。
var used_file_path: String

## 在该 CSV 文件中被更新的事件数量。
var updated_rows: int = 0

## 被添加到该 CSV 文件的事件数量。
var new_rows: int = 0

## 该 CSV 处理器是否应在各区块之间添加空行作为分隔。
## 区块可以是单个项目文件中的新角色、
## 新时间线或新术语表条目。
var add_separator: bool = false

enum PropertyType {
	String = 0,
	Array = 1,
	Other = 2,
}

## 用于术语表条目翻译的翻译属性。
const TRANSLATION_ID := DialogicGlossary.TRANSLATION_PROPERTY

## 尝试从 [param file_path] 加载该 CSV 文件。
## 若文件不存在，则会向 [member lines]
## 数组添加一条记录。
## [param separator_enabled] 决定是否为
## 单项目文件添加空行作为分隔。这有助于提高可读性。
func _init(file_path: String, original_locale: String, separator_enabled: bool) -> void:
	used_file_path = file_path
	add_separator = separator_enabled

	# 第一条记录必须是语言行。
	# [method collect_lines_from_timeline] 会添加其余的语言行（如果有）。
	var locale_array_line := PackedStringArray(["keys", original_locale])
	lines.append(locale_array_line)

	if not ResourceLoader.exists(file_path):
		is_new_file = true

		# 新文件中只有 "keys" 和原始语言这两列。
		# 例如："keys, en"
		column_count = 2
		return

	file = FileAccess.open(file_path, FileAccess.READ)

	var locale_csv_row := file.get_csv_line()
	column_count = locale_csv_row.size()
	var locale_key := locale_csv_row[0]

	old_lines[locale_key] = locale_csv_row

	_read_file_into_lines()


## 私有函数，用于把该 CSV 文件读入 [member lines] 数组。
## 不可对新建的文件调用。
func _read_file_into_lines() -> void:
	while not file.eof_reached():
		var line := file.get_csv_line()
		var row_key := line[0]

		old_lines[row_key] = line


## 从给定的 [param characters] 收集名称并添加到
## [member lines] 中。
##
## 如果这是角色名 CSV 文件，请用此方法
## 接收其他 [class DialogicCsvFile] 已收集的角色。
func collect_lines_from_characters(characters: Dictionary) -> void:
	for character: DialogicCharacter in characters.values():
		# 添加显示名称所在的行。
		var name_property := DialogicCharacter.TranslatedProperties.NAME
		var display_name_key: String = character.get_property_translation_key(name_property)
		var line_value: String = character.display_name
		var array_line := PackedStringArray([display_name_key, line_value])
		lines.append(array_line)

		var nicknames: Array = character.nicknames

		if not nicknames.is_empty():
			var nick_name_property := DialogicCharacter.TranslatedProperties.NICKNAMES
			var nickname_string: String = ",".join(nicknames)
			var nickname_name_line_key: String = character.get_property_translation_key(nick_name_property)
			var nick_array_line := PackedStringArray([nickname_name_line_key, nickname_string])
			lines.append(nick_array_line)

		# 新角色条目，如需分隔则添加。
		if add_separator:
			_append_empty()


## 向 [member lines] 数组追加一个空行。
func _append_empty() -> void:
	var empty_line := PackedStringArray(["", ""])
	lines.append(empty_line)


## 返回给定 [param key] 的属性类型。
func _get_key_type(key: String) -> PropertyType:
	if key.ends_with(DialogicGlossary.NAME_PROPERTY):
		return PropertyType.String

	if key.ends_with(DialogicGlossary.ALTERNATIVE_PROPERTY):
		return PropertyType.Array

	return PropertyType.Other


func _process_line_into_array(csv_values: PackedStringArray, property_type: PropertyType) -> Array[String]:
	const KEY_VALUE_INDEX := 0
	var values_as_array: Array[String] = []

	for i in csv_values.size():

		if i == KEY_VALUE_INDEX:
			continue

		var csv_value := csv_values[i]

		if csv_value.is_empty():
			continue

		match property_type:
			PropertyType.String:
				values_as_array = [csv_value]

			PropertyType.Array:
				var split_values := csv_value.split(",")

				for value in split_values:
					values_as_array.append(value)

	return values_as_array


func _add_keys_to_glossary(glossary: DialogicGlossary, names: Array) -> void:
	var glossary_prefix_key := glossary._get_glossary_translation_id_prefix()
	var glossary_translation_id_prefix := _get_glossary_translation_key_prefix(glossary)

	for glossary_line: PackedStringArray in names:

		if glossary_line.is_empty():
			continue

		var csv_key := glossary_line[0]

		# CSV 行分隔符会为空。
		if not csv_key.begins_with(glossary_prefix_key):
			continue

		var value_type := _get_key_type(csv_key)

		# String 和 Array 是唯一有效的类型。
		if (value_type == PropertyType.Other
		or not csv_key.begins_with(glossary_translation_id_prefix)):
			continue

		var new_line_to_add := _process_line_into_array(glossary_line, value_type)

		for name_to_add: String in new_line_to_add:
			glossary._translation_keys[name_to_add.strip_edges()] = csv_key



## 读取所有 [member lines]，并把它们添加到给定 [param glossary]
## 内部的「词语到翻译键」映射集合中。
##
## 在此之前，请先用 [method collect_lines_from_glossary]
## 填充该 CSV 的各行。
func add_translation_keys_to_glossary(glossary: DialogicGlossary) -> void:
	glossary._translation_keys.clear()
	_add_keys_to_glossary(glossary, lines)
	_add_keys_to_glossary(glossary, old_lines.values())


## 返回给定 [param glossary_translation_id] 的翻译键前缀。
## 生成的格式大致如下：Glossary/a2/
## 你可以用它找出 [member lines] 中属于某个术语表的条目。
func _get_glossary_translation_key_prefix(glossary: DialogicGlossary) -> String:
	return (
		DialogicGlossary.RESOURCE_NAME
			.path_join(glossary._translation_id)
	)


## 返回 [param value_b] 是否大于 [param value_a]。
##
## 此方法用于按重要性对术语表条目的属性排序，
## 与编辑器中的顺序保持一致。
##
## TODO: 允许 Dialogic 用户自定义排序。
func _sort_glossary_entry_property_keys(property_key_a: String, property_key_b: String) -> bool:
	const GLOSSARY_CSV_LINE_ORDER := {
		DialogicGlossary.NAME_PROPERTY: 0,
		DialogicGlossary.ALTERNATIVE_PROPERTY: 1,
		DialogicGlossary.TEXT_PROPERTY: 2,
		DialogicGlossary.EXTRA_PROPERTY: 3,
	}
	const UNKNOWN_PROPERTY_ORDER := 100

	var value_a: int = GLOSSARY_CSV_LINE_ORDER.get(property_key_a, UNKNOWN_PROPERTY_ORDER)
	var value_b: int = GLOSSARY_CSV_LINE_ORDER.get(property_key_b, UNKNOWN_PROPERTY_ORDER)

	return value_a < value_b


## 从给定 [param glossary] 的术语表条目中收集属性，
## 并把它们添加到 [member lines] 中。
func collect_lines_from_glossary(glossary: DialogicGlossary) -> void:

	for glossary_value: Variant in glossary.entries.values():

		if glossary_value is String:
			continue

		var glossary_entry: Dictionary = glossary_value
		var glossary_entry_name: String = glossary_entry[DialogicGlossary.NAME_PROPERTY]

		var _glossary_translation_id := glossary.get_set_glossary_translation_id()
		var entry_translation_id := glossary.get_set_glossary_entry_translation_id(glossary_entry_name)

		var entry_property_keys := glossary_entry.keys().duplicate()
		entry_property_keys.sort_custom(_sort_glossary_entry_property_keys)

		var entry_name_property: String = glossary_entry[DialogicGlossary.NAME_PROPERTY]

		for entry_key: String in entry_property_keys:
			# 忽略私有键。
			if entry_key.begins_with(DialogicGlossary.PRIVATE_PROPERTY_PREFIX):
				continue

			var item_value: Variant = glossary_entry[entry_key]
			var item_value_str := ""

			if item_value is Array:
				var item_array := item_value as Array
				# 我们在逗号后加一个空格，方便阅读。
				item_value_str = " ,".join(item_array)

			elif not item_value is String or item_value.is_empty():
				continue

			else:
				item_value_str = item_value

			var glossary_csv_key := glossary._get_glossary_translation_key(entry_translation_id, entry_key)

			if (entry_key == DialogicGlossary.NAME_PROPERTY
			or entry_key == DialogicGlossary.ALTERNATIVE_PROPERTY):
				glossary.entries[glossary_csv_key] = entry_name_property

			var glossary_line := PackedStringArray([glossary_csv_key, item_value_str])

			lines.append(glossary_line)

		# 新术语表条目，如需分隔则添加。
		if add_separator:
			_append_empty()



## 从给定 [param timeline] 收集可翻译的事件，
## 并把它们添加到 [member lines] 中。
func collect_lines_from_timeline(timeline: DialogicTimeline) -> void:
	for event: DialogicEvent in timeline.events:

		if event.can_be_translated():

			if event._translation_id.is_empty():
				event.add_translation_id()
				event.update_text_version()

			var properties: Array = event._get_translatable_properties()

			for property: String in properties:
				var line_key: String = event.get_property_translation_key(property)
				var line_value: String = event._get_property_original_translation(property)
				var array_line := PackedStringArray([line_key, line_value])
				lines.append(array_line)

	# 时间线结束，如需分隔则添加。
	if add_separator:
		_append_empty()


## 清空磁盘上的 CSV 文件，并把当前的 [member lines] 数组写入其中。
## 使用 [member old_lines] 字典更新已有的翻译。
## 若某翻译行缺少一列，则会补上一个末尾逗号
## 以符合 CSV 文件格式。
##
## 如果只收集到了语言 CSV 行，则不会创建新文件，
## 也不会更新已存在的翻译。
func update_csv_file_on_disk() -> void:
	# 为空，或仅有语言行。
	if lines.size() < 2:
		print_rich("[color=yellow]该 CSV 文件没有内容行，已跳过：" + used_file_path)

		return

	# 清空当前的 CSV 文件。
	file = FileAccess.open(used_file_path, FileAccess.WRITE)

	for line in lines:
		var row_key := line[0]

		# 以防该行可能已有翻译，
		# 再次把它们追加到末尾（原始语言文本会被替换）。
		if row_key in old_lines:
			var old_line: PackedStringArray = old_lines[row_key]
			var updated_line: PackedStringArray = line + old_line.slice(2)

			var line_columns: int = updated_line.size()
			var line_columns_to_add := column_count - line_columns

			# 补上末尾逗号以匹配列数。
			for _i in range(line_columns_to_add):
				updated_line.append("")

			file.store_csv_line(updated_line)
			updated_rows += 1

		else:
			var line_columns: int = line.size()
			var line_columns_to_add := column_count - line_columns

			# 补上末尾逗号以匹配列数。
			for _i in range(line_columns_to_add):
				line.append("")

			file.store_csv_line(line)
			new_rows += 1

	file.close()
