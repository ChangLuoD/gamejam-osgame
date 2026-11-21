extends DialogicSubsystem
## 用于保存和读取游戏状态的子系统。
##
## 本子系统提供了许多辅助方法，可将 Dialogic 数据或自定义
## 游戏数据保存到具名存档位。
##
## 你可以通过 [signal saved] 监听保存事件。 \
## 如果你想要保存，可以调用 [method save]。 \


## 当发生保存时发出，附带以下信息：
## [br]
## 键            |   值类型      | 值 [br]
## -----------   | ------------- | ----- [br]
## `slot_name`   | [type String] | 游戏状态被保存到的存档位名称。[br]
## `is_autosave` | [type bool]   | 如果这是一次自动存档，则为 `true`。[br]
signal saved(info: Dictionary)

## 当发生读取时发出，附带以下信息：
## [br]
## 键            |   值类型      | 值 [br]
## -----------   | ------------- | ----- [br]
## `slot_name`   | [type String] | 游戏状态被读取时所来自的存档位名称。[br]
signal loaded(info: Dictionary)



## 保存的目标目录。
const SAVE_SLOTS_DIR := "user://dialogic/saves/"

## 自动存档开关对应的项目设置键。
const AUTO_SAVE_SETTINGS := "dialogic/save/autosave"

## 自动存档模式对应的项目设置键。
const AUTO_SAVE_MODE_SETTINGS := "dialogic/save/autosave_mode"

## 自动存档延迟对应的项目设置键。
const AUTO_SAVE_TIME_SETTINGS := "dialogic/save/autosave_delay"

## 使用 [take_slot_image()] 时临时存放截取的屏幕画面。
enum ThumbnailMode {NONE, TAKE_AND_STORE, STORE_ONLY}
var latest_thumbnail: Image = null


## 自动存档的不同触发类型。
## 如果游戏中出现其中一种情况，且 [member autosave_enabled]
## 为 `true`，则可能会触发自动存档。
enum AutoSaveMode {
	## 包含时间线的开始、结束和跳转事件。
	ON_TIMELINE_JUMPS = 0,
	## 每隔一定时间间隔保存。
	ON_TIMER = 1,
	## 在每个文本事件后保存。
	ON_TEXT_EVENT = 2
}

## 是否启用自动存档功能。
## 初始值可在 Dialogic 编辑器的项目设置中设置。
##
## 可以在游戏过程中切换。
var autosave_enabled := false:
	set(enabled):
		autosave_enabled = enabled

		if enabled:
			autosave_timer.start()
		else:
			autosave_timer.stop()


## 当 [member autosave_enabled] 为 `true` 时，自动存档的
## 触发条件。
var autosave_mode := AutoSaveMode.ON_TIMELINE_JUMPS

## 在 [member autosave_enabled] 为 `true` 且 [member autosave_mode] 为
## `AutoSaveMode.ON_TIMER` 时，自动存档将在多长时间间隔后
## 触发。
var autosave_time := 60:
	set(timer_time):
		autosave_time = timer_time
		autosave_timer.wait_time = timer_time


var _debug_save_as_tres := false

#region 状态
####################################################################################################

## 内置方法，由 DialogicGameHandler 调用。
func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	_make_sure_slot_dir_exists()


## 内置方法，由 DialogicGameHandler 调用。
func _pause() -> void:
	autosave_timer.paused = true


## 内置方法，由 DialogicGameHandler 调用。
func _resume() -> void:
	autosave_timer.paused = false

#endregion


#region 主要方法
####################################################################################################

## 将当前状态保存到指定存档位。
## 如果未指定存档位，则使用默认存档位。你可以在
## Dialogic 编辑器中修改该名称。
## 如果你想保存到上次使用的存档位，可以用
## [method get_latest_slot()] 方法获取其存档位名称。
func save(slot_name := "", is_autosave := false, thumbnail_mode := ThumbnailMode.TAKE_AND_STORE, slot_info := {}) -> Error:
	# 如果这是自动存档，检查是否需要保存
	if is_autosave and !autosave_enabled:
		return OK

	if slot_name.is_empty():
		slot_name = get_default_slot()

	set_latest_slot(slot_name)

	if _debug_save_as_tres:
		var save_path := SAVE_SLOTS_DIR.path_join(slot_name).path_join('state.tres')
		ResourceSaver.save(dialogic.get_full_state(), save_path)
		return OK

	var save_error := save_file(slot_name, 'state.txt', dialogic.get_full_state())

	if save_error:
		return save_error

	if thumbnail_mode == ThumbnailMode.TAKE_AND_STORE:
		take_thumbnail()
		save_slot_thumbnail(slot_name)
	elif thumbnail_mode == ThumbnailMode.STORE_ONLY:
		save_slot_thumbnail(slot_name)

	if slot_info:
		set_slot_info(slot_name, slot_info)

	saved.emit({"slot_name": slot_name, "is_autosave": is_autosave})
	print('[Dialogic] 已保存到存档位 "'+slot_name+'"。')
	return OK


## 从 DialogicGameHandler（Dialogic 自动加载）中的指定存档位读取全部信息。
## 如果未指定存档位，则使用默认存档位。
## 要检查该存档位中是否存有内容，请使用 has_slot()。
## 如果存档位不存在，此方法将失败。
func load(slot_name := "") -> Error:
	if slot_name.is_empty(): slot_name = get_default_slot()

	if not has_slot(slot_name):
		printerr("[Dialogic Error] 尝试从无效存档位 '"+slot_name+"' 读取。")
		return ERR_FILE_NOT_FOUND

	var set_latest_error := set_latest_slot(slot_name)
	if set_latest_error:
		push_error("[Dialogic Error]: 无法将最新存档位写入全局信息。错误 %d '%s'" % [set_latest_error, error_string(set_latest_error)])

	if _debug_save_as_tres:
		var save_path := SAVE_SLOTS_DIR.path_join(slot_name).path_join('state.tres')
		var tres_state: DialogicSaveState = ResourceLoader.load(save_path)
		dialogic.load_full_state(tres_state)
		return OK


	var state: DialogicSaveState = load_file(slot_name, 'state.txt', {})
	dialogic.load_full_state(state)

	loaded.emit({"slot_name": slot_name})
	print('[Dialogic] 已从存档位 "'+slot_name+'" 读取。')

	if not state:
		return FAILED
	else:
		return OK


## 将一个变量保存到指定存档位中的文件。
##
## 注意，[param slot_name] 会被用作文件系统文件夹名。
## 部分操作系统并不支持文件夹名中的某些字符。
## 建议只使用字母、数字和下划线。
##
## 此方法允许你构建自己的保存与读取系统。
## 你可能在找更简单的 [method save] 方法来保存游戏状态。
func save_file(slot_name: String, file_name: String, data: Variant) -> Error:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	if slot_name.is_empty():
		push_error("[Dialogic Error]: 未设置兜底存档位名称。")
		return ERR_FILE_NOT_FOUND

	if !has_slot(slot_name):
		add_empty_slot(slot_name)


	var save_path := SAVE_SLOTS_DIR.path_join(slot_name).path_join(file_name)
	var encryption_password := get_encryption_password()
	var file: FileAccess

	if encryption_password.is_empty():
		file = FileAccess.open(save_path, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(save_path, FileAccess.WRITE, encryption_password)

	if file:
		file.store_var(data, true)
		return OK
	else:
		var error := FileAccess.get_open_error()
		push_error("[Dialogic Error]: 无法将存档位保存到文件。错误：%d '%s'" % [error, error_string(error)])
		return error


## 使用 [param slot_name] 读取文件，并返回其中的信息。
##
## 此方法允许你构建自己的保存与读取系统。
## 你可能在找更简单的 [method load] 方法来读取游戏状态。
func load_file(slot_name: String, file_name: String, default: Variant) -> Variant:
	if slot_name.is_empty(): slot_name = get_default_slot()

	var path := get_slot_path(slot_name).path_join(file_name)
	if FileAccess.file_exists(path):
		var encryption_password := get_encryption_password()
		var file: FileAccess

		if encryption_password.is_empty():
			file = FileAccess.open(path, FileAccess.READ)
		else:
			file = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_password)

		if file:
			return file.get_var(true)
		else:
			push_error(FileAccess.get_open_error())
	return default


## 全局信息中设置的数据可以在与存档位无关的情况下访问。
## 例如，你可能想把游戏设置存在这里，因为它们会
## 全局影响游戏，与所用的存档位无关。
func set_global_info(key: String, value: Variant) -> Error:
	var global_info := ConfigFile.new()
	var encryption_password := get_encryption_password()

	if encryption_password.is_empty():
		var load_error := global_info.load(SAVE_SLOTS_DIR.path_join('global_info.txt'))
		if load_error:
			printerr("[Dialogic Error]: 无法访问全局存档信息文件。")
			return load_error

		else:
			global_info.set_value('main', key, value)
			return global_info.save(SAVE_SLOTS_DIR.path_join('global_info.txt'))

	else:
		var load_error := global_info.load_encrypted_pass(SAVE_SLOTS_DIR.path_join('global_info.txt'), encryption_password)
		if load_error:
			printerr("[Dialogic Error]: 无法访问全局存档信息文件。")
			return load_error

		else:
			global_info.set_value('main', key, value)
			return global_info.save_encrypted_pass(SAVE_SLOTS_DIR.path_join('global_info.txt'), encryption_password)


## 访问与存档位无关的数据。
## 首先，数据必须已通过 [method set_global_info] 设置。
func get_global_info(key: String, default: Variant) -> Variant:
	var global_info := ConfigFile.new()
	var encryption_password := get_encryption_password()

	if encryption_password.is_empty():

		if global_info.load(SAVE_SLOTS_DIR.path_join('global_info.txt')) == OK:
			return global_info.get_value('main', key, default)

		printerr("[Dialogic Error]: 无法访问全局存档信息文件。")

	elif global_info.load_encrypted_pass(SAVE_SLOTS_DIR.path_join('global_info.txt'), encryption_password) == OK:
		return global_info.get_value('main', key, default)

	return default


## 如果项目设置中已设置加密密码，则获取它。
## 如果未设置密码，则返回空字符串。
func get_encryption_password() -> String:
	if OS.is_debug_build() and ProjectSettings.get_setting('dialogic/save/encryption_on_exports_only', true):
		return ""
	return ProjectSettings.get_setting("dialogic/save/encryption_password", "")

#endregion


#region 存档槽辅助
####################################################################################################
## 返回所有可用存档位的列表。适合遍历所有存档位，
## 例如在构建包含所有存档位的 UI 时。
func get_slot_names() -> Array[String]:
	var save_folders: Array[String] = []

	if DirAccess.dir_exists_absolute(SAVE_SLOTS_DIR):
		var directory := DirAccess.open(SAVE_SLOTS_DIR)
		var _list_dir := directory.list_dir_begin()
		var file_name := directory.get_next()

		while not file_name.is_empty():

			if directory.current_is_dir() and not file_name.begins_with("."):
				save_folders.append(file_name)

			file_name = directory.get_next()

		return save_folders

	return []


## 如果指定存档位存在，则返回 true。
func has_slot(slot_name: String) -> bool:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	return slot_name in get_slot_names()


## 删除指定存档位及其全部信息/文件。
func delete_slot(slot_name: String) -> Error:
	var path := SAVE_SLOTS_DIR.path_join(slot_name)

	if DirAccess.dir_exists_absolute(path):
		var directory := DirAccess.open(path)
		if not directory:
			return DirAccess.get_open_error()
		var _list_dir := directory.list_dir_begin()
		var file_name := directory.get_next()

		while not file_name.is_empty():
			var remove_error := directory.remove(file_name)
			if remove_error:
				push_warning("[Dialogic Error]: 删除 '%s' 时出错：%d\t%s" % [path.path_join(file_name), remove_error, error_string(remove_error)])
			file_name = directory.get_next()

		# 删除该文件夹。
		return directory.remove(SAVE_SLOTS_DIR.path_join(slot_name))

	push_warning("[Dialogic Warning]: 存档位 '%s' 已被删除。" % path)
	return OK


## 添加一个具有指定名称的新存档文件夹
func add_empty_slot(slot_name: String) -> Error:
	if DirAccess.dir_exists_absolute(SAVE_SLOTS_DIR):
		var directory := DirAccess.open(SAVE_SLOTS_DIR)
		if directory:
			return directory.make_dir(slot_name)
		return DirAccess.get_open_error()

	push_error("[Dialogic Error]: 路径 '%s' 不存在。" % SAVE_SLOTS_DIR)
	return ERR_FILE_BAD_PATH


## 重置指定存档文件夹（或默认存档文件夹）的状态
func reset_slot(slot_name := "") -> Error:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	return save_file(slot_name, 'state.txt', {})


## 返回指定存档文件夹的完整路径
func get_slot_path(slot_name: String) -> String:
	return SAVE_SLOTS_DIR.path_join(slot_name)


## 返回 Dialogic 设置中定义的默认存档位名称
func get_default_slot() -> String:
	return ProjectSettings.get_setting('dialogic/save/default_slot', 'Default')


## 返回最新存档位；如果尚未保存过任何内容则返回空字符串
func get_latest_slot() -> String:
	var latest_slot := ""

	if Engine.get_main_loop().has_meta('dialogic_latest_saved_slot'):
		latest_slot = Engine.get_main_loop().get_meta('dialogic_latest_saved_slot', '')

	else:
		latest_slot = get_global_info('latest_save_slot', '')
		Engine.get_main_loop().set_meta('dialogic_latest_saved_slot', latest_slot)


	if !has_slot(latest_slot):
		return ''

	return latest_slot


func set_latest_slot(slot_name:String) -> Error:
	Engine.get_main_loop().set_meta('dialogic_latest_saved_slot', slot_name)
	return set_global_info('latest_save_slot', slot_name)


func _make_sure_slot_dir_exists() -> Error:
	if not DirAccess.dir_exists_absolute(SAVE_SLOTS_DIR):
		var make_dir_result := DirAccess.make_dir_recursive_absolute(SAVE_SLOTS_DIR)
		if make_dir_result:
			return make_dir_result

	var global_info_path := SAVE_SLOTS_DIR.path_join('global_info.txt')

	if not FileAccess.file_exists(global_info_path):
		var config := ConfigFile.new()
		var password := get_encryption_password()

		if password.is_empty():
			return config.save(global_info_path)

		else:
			return config.save_encrypted_pass(global_info_path, password)

	return OK

#endregion


#region 存档槽信息
####################################################################################################

func set_slot_info(slot_name:String, info: Dictionary) -> Error:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	return save_file(slot_name, 'info.txt', info)


func get_slot_info(slot_name := "") -> Dictionary:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	return load_file(slot_name, 'info.txt', {})

#endregion


#region 存档槽图像
####################################################################################################

## 此方法会为当前游戏画面创建缩略图，这样保存游戏时
## 存档位图片上就不会带有 UI。
## 缩略图将存储在 [member latest_thumbnail] 中。
##
## 请在打开你的保存与读取菜单之前调用此方法。
## 之后，使用 [constant ThumbnailMode.STORE_ONLY] 调用 [method save]。
## [method save] 会自动使用已存储的缩略图。
func take_thumbnail() -> void:
	latest_thumbnail = get_viewport().get_texture().get_image()


## 无需从外部调用。
## 用于将最新缩略图存储到指定存档位。
func save_slot_thumbnail(slot_name: String) -> Error:
	if latest_thumbnail:
		var path := get_slot_path(slot_name).path_join('thumbnail.png')
		return latest_thumbnail.save_png(path)

	push_warning("[Dialogic Warning]: 尚未设置缩略图。")
	return OK


## 返回指定存档位的缩略图。
func get_slot_thumbnail(slot_name: String) -> ImageTexture:
	if slot_name.is_empty():
		slot_name = get_default_slot()

	var path := get_slot_path(slot_name).path_join('thumbnail.png')

	if FileAccess.file_exists(path):
		return ImageTexture.create_from_image(Image.load_from_file(path))

	return null

#endregion


#region 自动存档
####################################################################################################
## 自动存档计时器的引用。
var autosave_timer := Timer.new()


func _ready() -> void:
	autosave_timer.one_shot = true
	DialogicUtil.update_timer_process_callback(autosave_timer)
	autosave_timer.name = "AutosaveTimer"
	var _result := autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	add_child(autosave_timer)

	autosave_enabled = ProjectSettings.get_setting(AUTO_SAVE_SETTINGS, autosave_enabled)
	autosave_mode = ProjectSettings.get_setting(AUTO_SAVE_MODE_SETTINGS, autosave_mode)
	autosave_time = ProjectSettings.get_setting(AUTO_SAVE_TIME_SETTINGS, autosave_time)

	_result = dialogic.event_handled.connect(_on_dialogic_event_handled)
	_result = dialogic.timeline_started.connect(_on_start_or_end_autosave)
	_result = dialogic.timeline_ended.connect(_on_start_or_end_autosave)

	if autosave_enabled:
		autosave_timer.start(autosave_time)


func _on_autosave_timer_timeout() -> void:
	if autosave_mode == AutoSaveMode.ON_TIMER:
		perform_autosave()

	autosave_timer.start(autosave_time)


func _on_dialogic_event_handled(event: DialogicEvent) -> void:
	if event is DialogicJumpEvent:

		if autosave_mode == AutoSaveMode.ON_TIMELINE_JUMPS:
			perform_autosave()

	if event is DialogicTextEvent:

		if autosave_mode == AutoSaveMode.ON_TEXT_EVENT:
			perform_autosave()


func _on_start_or_end_autosave() -> void:
	if autosave_mode == AutoSaveMode.ON_TIMELINE_JUMPS:
		perform_autosave()


## 执行一次自动存档。
## 如果启用了自动存档模式，此方法会被自动调用。
func perform_autosave() -> Error:
	return save("", true)

#endregion
