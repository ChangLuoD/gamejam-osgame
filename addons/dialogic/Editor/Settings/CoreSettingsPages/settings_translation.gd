@tool
extends DialogicSettingsPage

## 此设置标签页用于启用并更新翻译 csv 文件。


enum TranslationModes {PER_PROJECT, PER_TIMELINE, NONE}
enum SaveLocationModes {INSIDE_TRANSLATION_FOLDER, NEXT_TO_TIMELINE, NONE}

var loading := false

## 默认 CSV 文件名，其中包含角色
## 属性的翻译。
const DEFAULT_CHARACTER_CSV_NAME := "dialogic_character_translations.csv"
## 默认 CSV 文件名，其中包含时间线的翻译。
## 仅在所有时间线都要翻译到同一个文件时使用。
const DEFAULT_TIMELINE_CSV_NAME := "dialogic_timeline_translations.csv"

const DEFAULT_GLOSSARY_CSV_NAME := "dialogic_glossary_translations.csv"

const _USED_LOCALES_SETTING := "dialogic/translation/locales"

## 包含上次更新期间所做的翻译改动。

## 更新 CSV 文件后会被写入的唯一语言区域。
var _unique_locales := []

func _get_icon() -> Texture2D:
	return get_theme_icon("Translation", "EditorIcons")


func _is_feature_tab() -> bool:
	return true


func _ready() -> void:
	%TransEnabled.toggled.connect(store_changes)
	%OrigLocale.suggestions_func = get_locales
	%OrigLocale.resource_icon = get_theme_icon("Translation", "EditorIcons")
	%OrigLocale.value_changed.connect(store_changes)
	%TestingLocale.suggestions_func = get_locales
	%TestingLocale.resource_icon = get_theme_icon("Translation", "EditorIcons")
	%TestingLocale.value_changed.connect(store_changes)
	%TransFolderPicker.value_changed.connect(store_changes)
	%AddSeparatorEnabled.toggled.connect(store_changes)

	%SaveLocationMode.item_selected.connect(store_changes)
	%TransMode.item_selected.connect(store_changes)

	%UpdateCsvFiles.pressed.connect(_on_update_translations_pressed)
	%UpdateCsvFiles.icon = get_theme_icon("Add", "EditorIcons")

	%CollectTranslations.pressed.connect(collect_translations)
	%CollectTranslations.icon = get_theme_icon("File", "EditorIcons")

	%TransRemove.pressed.connect(_on_erase_translations_pressed)
	%TransRemove.icon = get_theme_icon("Remove", "EditorIcons")

	%UpdateConfirmationDialog.add_button("保留旧的并生成新的", false, "generate_new")

	%UpdateConfirmationDialog.custom_action.connect(_on_custom_action)

	_verify_translation_file()


func _on_custom_action(action: String) -> void:
	if action == "generate_new":
		update_csv_files()


func _refresh() -> void:
	loading = true

	%TransEnabled.button_pressed = ProjectSettings.get_setting('dialogic/translation/enabled', false)
	%TranslationSettings.visible = %TransEnabled.button_pressed
	%OrigLocale.set_value(ProjectSettings.get_setting('dialogic/translation/original_locale', TranslationServer.get_tool_locale()))
	%TransMode.select(ProjectSettings.get_setting('dialogic/translation/file_mode', 1))
	%TransFolderPicker.set_value(ProjectSettings.get_setting('dialogic/translation/translation_folder', ''))
	%TestingLocale.set_value(ProjectSettings.get_setting('internationalization/locale/test', ''))
	%AddSeparatorEnabled.button_pressed = ProjectSettings.get_setting('dialogic/translation/add_separator', false)

	_verify_translation_file()

	loading = false


func store_changes(_fake_arg: Variant = null, _fake_arg2: Variant = null) -> void:
	if loading:
		return

	_verify_translation_file()

	ProjectSettings.set_setting('dialogic/translation/enabled', %TransEnabled.button_pressed)
	%TranslationSettings.visible = %TransEnabled.button_pressed
	ProjectSettings.set_setting('dialogic/translation/original_locale', %OrigLocale.current_value)
	ProjectSettings.set_setting('dialogic/translation/file_mode', %TransMode.selected)
	ProjectSettings.set_setting('dialogic/translation/translation_folder', %TransFolderPicker.current_value)
	ProjectSettings.set_setting('internationalization/locale/test', %TestingLocale.current_value)
	ProjectSettings.set_setting('dialogic/translation/save_mode', %SaveLocationMode.selected)
	ProjectSettings.set_setting('dialogic/translation/add_separator', %AddSeparatorEnabled.button_pressed)
	ProjectSettings.save()


## 检查翻译文件夹路径是否为必填。
## 若为必填，则禁用「更新 CSV 文件」按钮并显示一条警告。
##
## 满足以下任一条件时，翻译文件夹路径为必填：
## - 翻译模式设为「按项目」。
## - 保存位置模式设为「翻译文件夹内」。
func _verify_translation_file() -> void:
	var translation_folder: String = %TransFolderPicker.current_value
	var file_mode: TranslationModes = %TransMode.selected

	if file_mode == TranslationModes.PER_PROJECT:
		%SaveLocationMode.disabled = true
	else:
		%SaveLocationMode.disabled = false

	var valid_translation_folder := (!translation_folder.is_empty()
		and DirAccess.dir_exists_absolute(translation_folder))

	%UpdateCsvFiles.disabled = not valid_translation_folder

	var status_message := ""

	if not valid_translation_folder:
		status_message += "⛔ 需要有效的翻译文件夹才能翻译角色名"

		if file_mode == TranslationModes.PER_PROJECT:
			status_message += "以及项目 CSV 文件。"
		else:
			status_message += "。"

	%StatusMessage.text = status_message


func get_locales(_filter: String) -> Dictionary:
	var suggestions := {}
	suggestions['默认'] = {'value':'', 'tooltip':"将使用项目设置中配置的备用语言区域。"}
	suggestions[TranslationServer.get_tool_locale()] = {'value':TranslationServer.get_tool_locale()}

	var used_locales: Array = ProjectSettings.get_setting(_USED_LOCALES_SETTING, TranslationServer.get_all_languages())

	for locale: String in used_locales:
		var language_name := TranslationServer.get_language_name(locale)

		# 无效的语言区域会返回空字符串。
		if language_name.is_empty():
			continue

		suggestions[locale] = { 'value': locale, 'tooltip': language_name }

	return suggestions


func _on_update_translations_pressed() -> void:
	var save_mode: SaveLocationModes = %SaveLocationMode.selected
	var file_mode: TranslationModes = %TransMode.selected
	var translation_folder: String = %TransFolderPicker.current_value

	var old_save_mode: SaveLocationModes = ProjectSettings.get_setting('dialogic/translation/intern/save_mode', save_mode)
	var old_file_mode: TranslationModes = ProjectSettings.get_setting('dialogic/translation/intern/file_mode', file_mode)
	var old_translation_folder: String = ProjectSettings.get_setting('dialogic/translation/intern/translation_folder', translation_folder)

	if (old_save_mode == save_mode
	and old_file_mode == file_mode
	and old_translation_folder == translation_folder):
		update_csv_files()
		return

	%UpdateConfirmationDialog.popup_centered()


## 由对话框调用，用于告知设置已被更改。
func _delete_and_update() -> void:
	erase_translations()
	update_csv_files()


## 创建或更新术语表 CSV 文件。
func _handle_glossary_translation(
	csv_data: CsvUpdateData,
	save_location_mode: SaveLocationModes,
	translation_mode: TranslationModes,
	translation_folder_path: String,
	orig_locale: String) -> void:

	var glossary_csv: DialogicCsvFile = null
	var glossary_paths: Array = ProjectSettings.get_setting('dialogic/glossary/glossary_files', [])
	var add_separator_lines: bool = ProjectSettings.get_setting('dialogic/translation/add_separator', false)

	for glossary_path: String in glossary_paths:

		if glossary_csv == null:
			var csv_name := ""

			# 获取术语表 CSV 文件名。
			match translation_mode:
				TranslationModes.PER_PROJECT:
					csv_name = DEFAULT_GLOSSARY_CSV_NAME

				TranslationModes.PER_TIMELINE:
					var glossary_name: String = glossary_path.trim_suffix('.tres')
					var path_parts := glossary_name.split("/")
					var file_name := path_parts[-1]
					csv_name = "dialogic_" + file_name + '_translation.csv'

			var glossary_csv_path := ""
			# 获取术语表 CSV 文件路径。
			match save_location_mode:
				SaveLocationModes.INSIDE_TRANSLATION_FOLDER:
					glossary_csv_path = translation_folder_path.path_join(csv_name)

				SaveLocationModes.NEXT_TO_TIMELINE:
					glossary_csv_path = glossary_path.get_base_dir().path_join(csv_name)

			# 创建或更新术语表 CSV 文件。
			glossary_csv = DialogicCsvFile.new(glossary_csv_path, orig_locale, add_separator_lines)

			if (glossary_csv.is_new_file):
				csv_data.new_glossaries += 1
			else:
				csv_data.updated_glossaries += 1

		var glossary: DialogicGlossary = load(glossary_path)
		glossary_csv.collect_lines_from_glossary(glossary)
		glossary_csv.add_translation_keys_to_glossary(glossary)
		ResourceSaver.save(glossary)

		# 如果使用按文件模式，就保存这个 csv 并开始新的一个
		if translation_mode == TranslationModes.PER_TIMELINE:
			glossary_csv.update_csv_file_on_disk()
			glossary_csv = null

	# 如果还有一个按项目的术语表处于打开状态，就需要把它保存。
	if glossary_csv != null:
		glossary_csv.update_csv_file_on_disk()
		glossary_csv = null


## 保存新增与更新的 CSV 行数，以及哪些
## 资源被填入了翻译 ID 的信息。
## 最终数据可用于显示状态消息。
class CsvUpdateData:
	var new_events := 0
	var updated_events := 0

	var new_timelines := 0
	var updated_timelines := 0

	var new_names := 0
	var updated_names := 0

	var new_glossaries := 0
	var updated_glossaries := 0

	var new_glossary_entries := 0
	var updated_glossary_entries := 0


func update_csv_files() -> void:
	_unique_locales = []
	var orig_locale: String = ProjectSettings.get_setting('dialogic/translation/original_locale', '').strip_edges()
	var save_location_mode: SaveLocationModes = ProjectSettings.get_setting('dialogic/translation/save_mode', SaveLocationModes.NEXT_TO_TIMELINE)
	var translation_mode: TranslationModes = ProjectSettings.get_setting('dialogic/translation/file_mode', TranslationModes.PER_PROJECT)
	var translation_folder_path: String = ProjectSettings.get_setting('dialogic/translation/translation_folder', 'res://')
	var add_separator_lines: bool = ProjectSettings.get_setting('dialogic/translation/add_separator', false)

	var csv_data := CsvUpdateData.new()

	if orig_locale.is_empty():
		orig_locale = ProjectSettings.get_setting('internationalization/locale/fallback')

	ProjectSettings.set_setting('dialogic/translation/intern/save_mode', save_location_mode)
	ProjectSettings.set_setting('dialogic/translation/intern/file_mode', translation_mode)
	ProjectSettings.set_setting('dialogic/translation/intern/translation_folder', translation_folder_path)

	var current_timeline := _close_active_timeline()

	var csv_per_project: DialogicCsvFile = null
	var per_project_csv_path := translation_folder_path.path_join(DEFAULT_TIMELINE_CSV_NAME)

	if translation_mode == TranslationModes.PER_PROJECT:
		csv_per_project = DialogicCsvFile.new(per_project_csv_path, orig_locale, add_separator_lines)

		if (csv_per_project.is_new_file):
			csv_data.new_timelines += 1
		else:
			csv_data.updated_timelines += 1

	# 遍历所有时间线。
	# 创建或更新 CSV 文件。
	# 把时间线转换成可翻译的行，并收集到 CSV 文件中。
	for timeline_path: String in DialogicResourceUtil.list_resources_of_type('.dtl'):
		var csv_file: DialogicCsvFile = csv_per_project

		# 把 CSV 文件切换为按时间线的那一个。
		if translation_mode == TranslationModes.PER_TIMELINE:
			var per_timeline_path: String = timeline_path.trim_suffix('.dtl')
			var path_parts := per_timeline_path.split("/")
			var timeline_name: String = path_parts[-1]

			# 根据翻译位置模式调整文件路径。
			if save_location_mode == SaveLocationModes.INSIDE_TRANSLATION_FOLDER:
				var prefixed_timeline_name := "dialogic_" + timeline_name
				per_timeline_path = translation_folder_path.path_join(prefixed_timeline_name)


			per_timeline_path += '_translation.csv'
			csv_file = DialogicCsvFile.new(per_timeline_path, orig_locale, false)
			csv_data.new_timelines += 1

		# 加载并处理时间线，把事件转换成资源。
		var timeline: DialogicTimeline = load(timeline_path)

		if timeline.events.size() == 0:
			print_rich("[color=yellow]时间线为空，跳过：" + timeline_path + "[/color]")
			continue

		timeline.process()

		# 把时间线收集到 CSV。
		csv_file.collect_lines_from_timeline(timeline)

		# 以防新增了 translation_id，我们再次保存时间线
		timeline.set_meta("timeline_not_saved", true)
		ResourceSaver.save(timeline, timeline_path)

		if translation_mode == TranslationModes.PER_TIMELINE:
			csv_file.update_csv_file_on_disk()

		csv_data.new_events += csv_file.new_rows
		csv_data.updated_events += csv_file.updated_rows

	_handle_glossary_translation(
		csv_data,
		save_location_mode,
		translation_mode,
		translation_folder_path,
		orig_locale
	)

	_handle_character_names(
		csv_data,
		orig_locale,
		translation_folder_path,
		add_separator_lines
	)

	if translation_mode == TranslationModes.PER_PROJECT:
		csv_per_project.update_csv_file_on_disk()

	_silently_open_timeline(current_timeline)

	# 触发重新导入。
	EditorInterface.get_resource_filesystem().scan_sources()

	var status_message := "事件     新建 {new_events}   发现 {updated_events}
		名称     新建 {new_names}   发现 {updated_names}
		CSV      新建 {new_timelines}   发现 {updated_timelines}
		术语表   新建 {new_glossaries}   发现 {updated_glossaries}
		条目     新建 {new_glossary_entries}   发现 {updated_glossary_entries}"

	var status_message_args := {
		'new_events': csv_data.new_events,
		'updated_events': csv_data.updated_events,
		'new_timelines': csv_data.new_timelines,
		'updated_timelines': csv_data.updated_timelines,
		'new_glossaries': csv_data.new_glossaries,
		'updated_glossaries': csv_data.updated_glossaries,
		'new_names': csv_data.new_names,
		'updated_names': csv_data.updated_names,
		'new_glossary_entries': csv_data.new_glossary_entries,
		'updated_glossary_entries': csv_data.updated_glossary_entries,
	}

	%StatusMessage.text = status_message.format(status_message_args)
	ProjectSettings.set_setting(_USED_LOCALES_SETTING, _unique_locales)
	ProjectSettings.save()


## 遍历所有角色资源文件，创建或更新
## 包含角色属性翻译的 CSV 文件。
## 这会把每个角色资源文件保存到磁盘。
func _handle_character_names(
		csv_data: CsvUpdateData,
		original_locale: String,
		translation_folder_path: String,
		add_separator_lines: bool) -> void:
	var names_csv_path := translation_folder_path.path_join(DEFAULT_CHARACTER_CSV_NAME)
	var character_name_csv: DialogicCsvFile = DialogicCsvFile.new(names_csv_path,
		 original_locale,
		 add_separator_lines
	)

	var all_characters := {}

	for character_path: String in DialogicResourceUtil.list_resources_of_type('.dch'):
		var character: DialogicCharacter = load(character_path)

		if character._translation_id.is_empty():
			csv_data.new_names += 1

		else:
			csv_data.updated_names += 1

		var translation_id := character.get_set_translation_id()
		all_characters[translation_id] = character

		ResourceSaver.save(character)

	character_name_csv.collect_lines_from_characters(all_characters)
	character_name_csv.update_csv_file_on_disk()


func collect_translations() -> void:
	var translation_files := []
	var translation_mode: TranslationModes = ProjectSettings.get_setting('dialogic/translation/file_mode', TranslationModes.PER_PROJECT)

	if translation_mode == TranslationModes.PER_TIMELINE:

		for timeline_path: String in DialogicResourceUtil.list_resources_of_type('.translation'):

			for file: String in DialogicUtil.listdir(timeline_path.get_base_dir()):
				file = timeline_path.get_base_dir().path_join(file)

				if file.ends_with('.translation'):

					if not file in translation_files:
						translation_files.append(file)

	if translation_mode == TranslationModes.PER_PROJECT:
		var translation_folder: String = ProjectSettings.get_setting('dialogic/translation/translation_folder', 'res://')

		for file: String in DialogicUtil.listdir(translation_folder):
			file = translation_folder.path_join(file)

			if file.ends_with('.translation'):

				if not file in translation_files:
					translation_files.append(file)

	var all_translation_files: Array = ProjectSettings.get_setting('internationalization/locale/translations', [])
	var orig_file_amount := len(all_translation_files)

	# 该数组用于记录有效的翻译文件路径。
	var found_file_paths := []
	var removed_translation_files := 0

	for file_path: String in translation_files:
		# 如果文件路径无效，就必须把它清理掉。
		if ResourceLoader.exists(file_path):
			found_file_paths.append(file_path)
		else:
			removed_translation_files += 1
			continue

		if not file_path in all_translation_files:
			all_translation_files.append(file_path)

		var path_without_suffix := file_path.trim_suffix('.translation')
		var locale_part := path_without_suffix.split(".")[-1]
		_collect_locale(locale_part)


	var valid_translation_files := PackedStringArray(all_translation_files)
	ProjectSettings.set_setting('internationalization/locale/translations', valid_translation_files)
	ProjectSettings.save()

	%StatusMessage.text = (
		"已添加翻译文件：" + str(len(all_translation_files)-orig_file_amount)
		+ "\n已移除翻译文件：" + str(removed_translation_files)
		+ "\n翻译文件总数：" + str(len(all_translation_files)))


func _on_erase_translations_pressed() -> void:
	%EraseConfirmationDialog.popup_centered()


## 删除由 [param csv_name] 生成的翻译文件。
## [param csv_name] 中不应包含文件扩展名（.csv）。
##
## 返回一个向量，值 1 是已删除的翻译文件数量。
## 值
func delete_translations_files(translation_files: Array, csv_name: String) -> int:
	var deleted_files := 0

	for file_path: String in DialogicResourceUtil.list_resources_of_type('.translation'):
		var base_name: String = file_path.get_basename()
		var path_parts := base_name.split("/")
		var translation_name: String = path_parts[-1]

		if translation_name.begins_with(csv_name):

			if OK == DirAccess.remove_absolute(file_path):
				var project_translation_file_index := translation_files.find(file_path)

				if project_translation_file_index > -1:
					translation_files.remove_at(project_translation_file_index)

				deleted_files += 1
				print_rich("[color=green]已删除翻译文件：" + file_path + "[/color]")
			else:
				print_rich("[color=yellow]删除翻译文件失败：" + file_path + "[/color]")


	return deleted_files


## 遍历所有时间线，删除它们的 CSV 以及时间线的
## 翻译 ID。
## 删除按项目的 CSV 文件与角色名 CSV 文件。
func erase_translations() -> void:
	var files: PackedStringArray = ProjectSettings.get_setting('internationalization/locale/translations', [])
	var translation_files := Array(files)
	ProjectSettings.set_setting(_USED_LOCALES_SETTING, [])

	var deleted_csv_files := 0
	var deleted_translation_files := 0
	var cleaned_timelines := 0
	var cleaned_characters := 0
	var cleaned_events := 0
	var cleaned_glossaries := 0

	var current_timeline := _close_active_timeline()

	# 删除所有 Dialogic CSV 文件及其翻译文件。
	for csv_path: String in DialogicResourceUtil.list_resources_of_type(".csv"):
		var csv_path_parts: PackedStringArray = csv_path.split("/")
		var csv_name: String = csv_path_parts[-1].trim_suffix(".csv")

		# 只处理 Dialogic 的 CSV。
		if not csv_name.begins_with("dialogic_"):
			continue

		# 删除该 CSV 文件。
		if OK == DirAccess.remove_absolute(csv_path):
			deleted_csv_files += 1
			print_rich("[color=green]已删除 CSV 文件：" + csv_path + "[/color]")

			deleted_translation_files += delete_translations_files(translation_files, csv_name)
		else:
			print_rich("[color=yellow]删除 CSV 文件失败：" + csv_path + "[/color]")

	# 清理时间线。
	for timeline_path: String in DialogicResourceUtil.list_resources_of_type(".dtl"):

		# 处理时间线。
		var timeline: DialogicTimeline = load(timeline_path)
		timeline.process()
		cleaned_timelines += 1

		# 移除事件的翻译 ID。
		for event: DialogicEvent in timeline.events:

			if event._translation_id and not event._translation_id.is_empty():
				event.remove_translation_id()
				event.update_text_version()
				cleaned_events += 1

				if "character" in event:
					# 移除角色的翻译 ID。
					var character: DialogicCharacter = event.character

					if character != null and not character._translation_id.is_empty():
						character.remove_translation_id()
						cleaned_characters += 1

		timeline.set_meta("timeline_not_saved", true)
		ResourceSaver.save(timeline, timeline_path)

	_erase_glossary_translation_ids()
	_erase_character_name_translation_ids()

	ProjectSettings.set_setting('dialogic/translation/id_counter', 16)
	ProjectSettings.set_setting('internationalization/locale/translations', PackedStringArray(translation_files))
	ProjectSettings.save()

	EditorInterface.get_resource_filesystem().scan_sources()

	var status_message := "已清理时间线 {cleaned_timelines}
		已清理事件 {cleaned_events}
		已清理角色 {cleaned_characters}
		已清理术语表 {cleaned_glossaries}

		已抹除 CSV {erased_csv_files}
		已抹除翻译 {erased_translation_files}"

	var status_message_args := {
		'cleaned_timelines': cleaned_timelines,
		'cleaned_characters': cleaned_characters,
		'cleaned_events': cleaned_events,
		'cleaned_glossaries': cleaned_glossaries,
		'erased_csv_files': deleted_csv_files,
		'erased_translation_files': deleted_translation_files,
	}

	_silently_open_timeline(current_timeline)

	# 触发重新导入。
	EditorInterface.get_resource_filesystem().scan_sources()

	# 清除内部设置。
	ProjectSettings.clear('dialogic/translation/intern/save_mode')
	ProjectSettings.clear('dialogic/translation/intern/file_mode')
	ProjectSettings.clear('dialogic/translation/intern/translation_folder')

	_verify_translation_file()
	%StatusMessage.text = status_message.format(status_message_args)


func _erase_glossary_translation_ids() -> void:
	# 清理术语表。
	var glossary_paths: Array = ProjectSettings.get_setting('dialogic/glossary/glossary_files', [])

	for glossary_path: String in glossary_paths:
		var glossary: DialogicGlossary = load(glossary_path)
		glossary.remove_translation_id()
		glossary.remove_entry_translation_ids()
		glossary.clear_translation_keys()
		ResourceSaver.save(glossary, glossary_path)
		print_rich("[color=green]已清理术语表文件：" + glossary_path + "[/color]")


func _erase_character_name_translation_ids() -> void:
	for character_path: String in DialogicResourceUtil.list_resources_of_type('.dch'):
		var character: DialogicCharacter = load(character_path)

		character.remove_translation_id()
		ResourceSaver.save(character)


## 关闭 Dialogic 编辑器中的当前时间线，并把这条时间线
## 作为资源返回。
## 如果没有打开任何时间线，则返回 null。
func _close_active_timeline() -> Resource:
	var timeline_node: DialogicEditor = settings_editor.editors_manager.editors['Timeline']['node']
	# 我们会关闭这条时间线，以确保它能正确更新。
	# 保存这个引用后，我们就能再次打开它。
	var current_timeline := timeline_node.current_resource
	# 清理当前编辑器，这同时也会关闭该时间线。
	settings_editor.editors_manager.clear_editor(timeline_node)

	return current_timeline


## 在 Dialogic 编辑器中打开该时间线资源。
## 如果时间线为 null，则不做任何事。
func _silently_open_timeline(timeline_to_open: Resource) -> void:
	if timeline_to_open != null:
		settings_editor.editors_manager.edit_resource(timeline_to_open, true, true)


## 检查 [param locale] 是否是尚未添加
## 到 [_unique_locales] 数组中的语言区域。
func _collect_locale(locale: String) -> void:
	if _unique_locales.has(locale):
		return

	_unique_locales.append(locale)


## 界面显示标题（默认使用节点名作标识，仅显示用中文）
func _get_display_title() -> String:
	return "翻译"
