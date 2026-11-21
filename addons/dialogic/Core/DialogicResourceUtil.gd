@tool
class_name DialogicResourceUtil

static var label_cache := {}
static var event_cache: Array[DialogicEvent] = []
static var channel_cache := {}

static var special_resources := {}


static func update() -> void:
	update_directory('.dch')
	update_directory('.dtl')
	update_label_cache()
	update_audio_channel_cache()
	DialogicStylesUtil.build_style_directory()


#region 资源目录
################################################################################

static func get_directory(extension:String) -> Dictionary:
	extension = extension.trim_prefix('.')
	if Engine.has_meta(extension+'_directory'):
		return Engine.get_meta(extension+'_directory', {})

	var directory: Dictionary = ProjectSettings.get_setting("dialogic/directories/"+extension+'_directory', {})
	Engine.set_meta(extension+'_directory', directory)
	return directory


static func set_directory(extension:String, directory:Dictionary) -> void:
	extension = extension.trim_prefix('.')
	if Engine.is_editor_hint():
		ProjectSettings.set_setting("dialogic/directories/"+extension+'_directory', directory)
		ProjectSettings.save()
	Engine.set_meta(extension+'_directory', directory)


static func update_directory(extension:String) -> void:
	var directory := get_directory(extension)

	for resource in list_resources_of_type(extension):
		if not resource in directory.values():
			directory = add_resource_to_directory(resource, directory)

	var keys_to_remove := []
	for key in directory:
		if not ResourceLoader.exists(directory[key]):
			keys_to_remove.append(key)
	for key in keys_to_remove:
		directory.erase(key)

	set_directory(extension, directory)


static func add_resource_to_directory(file_path:String, directory:Dictionary) -> Dictionary:
	var suggested_name := file_path.get_file().trim_suffix("."+file_path.get_extension())
	var temp := suggested_name
	while suggested_name in directory:
		suggested_name = file_path.trim_suffix("/"+suggested_name+"."+file_path.get_extension()).get_file().path_join(suggested_name)
		if suggested_name == temp:
			break
		temp = suggested_name
	directory[suggested_name] = file_path
	return directory


## 返回给定资源路径的唯一标识符。
## 若未找到标识符则返回空字符串。
static func get_unique_identifier_by_path(file_path:String) -> String:
	if not file_path: return ""
	var identifier: Variant = get_directory(file_path.get_extension()).find_key(file_path)
	if typeof(identifier) == TYPE_STRING:
		return identifier
	return ""


static func get_resource_path_from_identifier(identifier:String, extension:String) -> String:
	var value: Variant = get_directory(extension).get(identifier, '')
	if value is String:
		return value
	return ""


## 返回与给定唯一标识符关联的资源。
## 需要提供预期的扩展名，以便使用正确的目录。
static func get_resource_from_identifier(identifier:String, extension:String) -> Resource:
	var value: Variant = get_directory(extension).get(identifier, '')
	if typeof(value) == TYPE_STRING and ResourceLoader.exists(value):
		return load(value)
	elif value is Resource:
		return value
	return null


## 返回一个布尔值，表示该资源是否存在。
## 需要提供预期的扩展名，以便使用正确的目录。
static func resource_exists_from_identifier(identifier:String, extension:String) -> bool:
	var value: Variant = get_directory(extension).get(identifier, '')
	if typeof(value) == TYPE_STRING:
		return ResourceLoader.exists(value)
	return value is Resource


## 仅编辑器
static func change_unique_identifier(file_path:String, new_identifier:String) -> void:
	var directory := get_directory(file_path.get_extension())
	var key: Variant = directory.find_key(file_path)
	while key != null:
		if key == new_identifier:
			break
		directory.erase(key)
		directory[new_identifier] = file_path
		key = directory.find_key(file_path)
	set_directory(file_path.get_extension(), directory)


static func change_resource_path(old_path:String, new_path:String) -> void:
	var directory := get_directory(new_path.get_extension())
	var key: Variant = directory.find_key(old_path)
	while key != null:
		directory[key] = new_path
		key = directory.find_key(old_path)
	set_directory(new_path.get_extension(), directory)


static func remove_resource(file_path:String) -> void:
	var directory := get_directory(file_path.get_extension())
	var key: Variant = directory.find_key(file_path)
	while key != null:
		directory.erase(key)
		key = directory.find_key(file_path)
	set_directory(file_path.get_extension(), directory)


static func is_identifier_unused(extension:String, identifier:String) -> bool:
	return not identifier in get_directory(extension)


## 虽然目录通常将标识符映射到路径，但此方法（只应在运行时使用）
## 允许将未保存的资源映射到一个标识符上。
static func register_runtime_resource(resource:Resource, identifier:String, extension:String) -> void:
	var directory := get_directory(extension)
	directory[identifier] = resource
	set_directory(extension, directory)


static func get_runtime_unique_identifier(resource:Resource, extension:String) -> String:
	var identifier: Variant = get_directory(extension).find_key(resource)
	if typeof(identifier) == TYPE_STRING:
		return identifier
	return ""

#endregion

#region 标签缓存
################################################################################
# 标签缓存仅供编辑器使用，这样我们就不必扫描所有时间线
# 来提供标签建议。它在游戏中无用，而且并不总是完美。

static func get_label_cache() -> Dictionary:
	if not label_cache.is_empty():
		return label_cache

	label_cache = DialogicUtil.get_editor_setting('label_ref', {})
	return label_cache


static func set_label_cache(cache:Dictionary) -> void:
	label_cache = cache


static func update_label_cache() -> void:
	var cache := get_label_cache()
	var timelines := get_timeline_directory().values()
	for timeline in cache:
		if !timeline in timelines:
			cache.erase(timeline)
	set_label_cache(cache)

#endregion

#region 音频通道缓存
################################################################################
# 音频通道缓存仅供编辑器使用，这样我们就不必扫描所有时间线
# 来提供通道建议。它在游戏中无用，而且并不总是完美。

static func get_audio_channel_cache() -> Dictionary:
	if not channel_cache.is_empty():
		return channel_cache

	channel_cache = DialogicUtil.get_editor_setting('channel_ref', {})
	return channel_cache


static func get_channel_list() -> Array:
	if channel_cache.is_empty():
		return []

	var cached_names := []
	for timeline in channel_cache:
		for name in channel_cache[timeline]:
			if not cached_names.has(name):
				cached_names.append(name)
	return cached_names


static func set_audio_channel_cache(cache:Dictionary) -> void:
	channel_cache = cache


static func update_audio_channel_cache() -> void:
	var cache := get_audio_channel_cache()
	var timelines := get_timeline_directory().values()
	for timeline in cache:
		if !timeline in timelines:
			cache.erase(timeline)
	set_audio_channel_cache(cache)

#endregion

#region 事件缓存
################################################################################

##  Dialogic 维护一个每个事件只出现一次的列表。此方法用于获取该列表。
static func get_event_cache() -> Array:
	if not event_cache.is_empty():
		return event_cache

	event_cache = update_event_cache()
	return event_cache


static func update_event_cache() -> Array:
	event_cache = []
	for indexer in DialogicUtil.get_indexers():
		# 构建事件缓存
		for event in indexer._get_events():
			if not ResourceLoader.exists(event):
				continue
			if not 'event_end_branch.gd' in event and not 'event_text.gd' in event:
				event_cache.append(load(event).new())

	# 测试事件时会按顺序检查。EndBranch 必须在最前，Text 必须在最后
	event_cache.push_front(DialogicEndBranchEvent.new())
	event_cache.push_back(DialogicTextEvent.new())

	return event_cache

#endregion

#region 特殊资源
################################################################################

static func update_special_resources() -> void:
	special_resources.clear()
	for indexer in DialogicUtil.get_indexers():
		var additions := indexer._get_special_resources()
		for resource_type in additions:
			if not resource_type in special_resources:
				special_resources[resource_type] = {}
			special_resources[resource_type].merge(additions[resource_type])


static func list_special_resources(type:String, filter := {}) -> Dictionary:
	if special_resources.is_empty():
		update_special_resources()
	if type in special_resources:
		if filter.is_empty():
			return special_resources[type]
		else:
			var results := {}
			for i in special_resources[type]:
				if match_resource_filter(special_resources[type][i], filter):
					results[i] = special_resources[type][i]
			return results
	return {}


static func match_resource_filter(dict:Dictionary, filter:Dictionary) -> bool:
	for i in filter:
		if not i in dict:
			return false
		if typeof(filter[i]) == TYPE_ARRAY:
			if not dict[i] in filter[i]:
				return false
		else:
			if not dict[i] == filter[i]:
				return false
	return true


static func guess_special_resource(type: String, string: String, default := {}, filter := {}, ignores:PackedStringArray=[]) -> Dictionary:
	if string.is_empty():
		return default

	if special_resources.is_empty():
		update_special_resources()
	var resources := list_special_resources(type, filter)
	if resources.is_empty():
		printerr("[Dialogic] 未找到任何 ", type, "，但仍尝试使用其中一个。")
		return default

	if string.begins_with('res://'):
		for i in resources.values():
			if i.path == string or i.path == string+'c':
				return i
		printerr("[Dialogic] 无法找到 ", type, "，路径为 '", string, "'。")
		return default

	string = string.to_lower()

	if string in resources:
		return resources[string]

	if not ignores.is_empty():
		var regex := RegEx.create_from_string(r" ?\b(" + "|".join(ignores) + r")\b")
		for name in resources:
			if regex.sub(name, "") == regex.sub(string, ""):
				return resources[name]

	## 最后再尝试在未筛选的列表中检查
	if string in special_resources[type]:
		push_warning("[Dialogic] 在不应使用的情况下使用了 ", type, " '", string,"'。")
		return special_resources[type][string]

	printerr("[Dialogic] 无法识别 ", type, "，依据字符串 '", string, "'。")
	return default

#endregion

#region 辅助方法
################################################################################

static func get_character_directory() -> Dictionary:
	return get_directory('dch')


static func get_timeline_directory() -> Dictionary:
	return get_directory('dtl')


static func timeline_resource_exists(timeline_identifier:String) -> bool:
	return resource_exists_from_identifier(timeline_identifier, 'dtl')


static func get_timeline_resource(timeline_identifier:String) -> DialogicTimeline:
	return get_resource_from_identifier(timeline_identifier, 'dtl')


static func get_character_resource(character_identifier:String) -> DialogicCharacter:
	return get_resource_from_identifier(character_identifier, 'dch')


static func list_resources_of_type(extension:String) -> Array:
	var all_resources := scan_folder('res://', extension)
	return all_resources


static func scan_folder(path:String, extension:String) -> Array:
	var list: Array = []
	if DirAccess.dir_exists_absolute(path) and not FileAccess.file_exists(path + "/" + ".gdignore"):
		var dir := DirAccess.open(path)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				list += scan_folder(path.path_join(file_name), extension)
			else:
				if file_name.ends_with(extension):
					list.append(path.path_join(file_name))
			file_name = dir.get_next()
	return list

#endregion
