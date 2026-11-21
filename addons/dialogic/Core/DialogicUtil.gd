@tool
class_name DialogicUtil

## 包含编辑器与游戏运行时共用辅助方法的脚本。
## 当插件不同部分需要同一功能时使用。

#region 编辑器

## 应使用此方法代替 EditorInterface.get_editor_scale()，因为如果使用后者，
## 在编辑器中运行完全正常，但游戏导出后会崩溃。
static func get_editor_scale() -> float:
	if Engine.is_editor_hint():
		return get_dialogic_plugin().get_editor_interface().get_editor_scale()
	return 1.0


## 尽管此方法实际上总是返回一个 EditorPlugin 节点，
##  但该类在导出后并不存在，在此引用它会导致崩溃。
static func get_dialogic_plugin() -> Node:
	for child in Engine.get_main_loop().get_root().get_children():
		if child.get_class() == "EditorNode":
			return child.get_node("DialogicPlugin")
	return null

#endregion


## 游戏运行时返回该自动加载节点。
static func autoload() -> DialogicGameHandler:
	if Engine.is_editor_hint():
		return null
	if not Engine.get_main_loop().root.has_node("Dialogic"):
		return null
	return Engine.get_main_loop().root.get_node("Dialogic")


#region 文件系统
################################################################################
static func listdir(path: String, files_only:= true, _throw_error:= true, full_file_path:= false, include_imports := false) -> Array:
	var files: Array = []
	if path.is_empty(): path = "res://"
	if DirAccess.dir_exists_absolute(path):
		var dir := DirAccess.open(path)
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				if files_only:
					if not dir.current_is_dir() and (not file_name.ends_with('.import') or include_imports):
						if full_file_path:
							files.append(path.path_join(file_name))
						else:
							files.append(file_name)
				else:
					if full_file_path:
						files.append(path.path_join(file_name))
					else:
						files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return files


static func get_module_path(name:String, builtin:=true) -> String:
	if builtin:
		return "res://addons/dialogic/Modules".path_join(name)
	else:
		return ProjectSettings.get_setting('dialogic/extensions_folder', 'res://addons/dialogic_additions').path_join(name)


## 这是一个私有且仅在编辑器中可用的函数。
##
## 通过直接操作文件内容并重新导入文件，为 [class DialogicGameHandler]
## 填充新的自定义子系统。
static func _update_autoload_subsystem_access() -> void:
	if not Engine.is_editor_hint():
		printerr("[Dialogic] 该函数仅在编辑器内可用。")
		return

	var script: Script = load("res://addons/dialogic/Core/DialogicGameHandler.gd")
	var new_subsystem_access_list := "#region SUBSYSTEMS\n"
	var subsystems_sorted := []

	for indexer: DialogicIndexer in get_indexers(true, true):

		for subsystem: Dictionary in indexer._get_subsystems().duplicate(true):
			subsystems_sorted.append(subsystem)

	subsystems_sorted.sort_custom(func (a: Dictionary, b: Dictionary) -> bool:
		return a.name < b.name
	)

	for subsystem: Dictionary in subsystems_sorted:
		new_subsystem_access_list += '\nvar {name} := preload("{script}").new():\n\tget: return get_subsystem("{name}")\n'.format(subsystem)

	new_subsystem_access_list += "\n#endregion"
	script.source_code = RegEx.create_from_string(r"#region SUBSYSTEMS\n#*\n((?!#endregion)(.*\n))*#endregion").sub(script.source_code, new_subsystem_access_list)
	ResourceSaver.save(script)
	Engine.get_singleton("EditorInterface").get_resource_filesystem().reimport_files(["res://addons/dialogic/Core/DialogicGameHandler.gd"])


static func get_indexers(include_custom := true, force_reload := false) -> Array[DialogicIndexer]:
	if Engine.get_main_loop().has_meta('dialogic_indexers') and not force_reload:
		return Engine.get_main_loop().get_meta('dialogic_indexers')

	var indexers: Array[DialogicIndexer] = []
	for file in listdir(DialogicUtil.get_module_path(''), false):
		var possible_script: String = DialogicUtil.get_module_path(file).path_join("index.gd")
		if ResourceLoader.exists(possible_script):
			indexers.append(load(possible_script).new())

	if include_custom:
		var extensions_folder: String = ProjectSettings.get_setting('dialogic/extensions_folder', "res://addons/dialogic_additions/")
		for file in listdir(extensions_folder, false, false):
			var possible_script: String = extensions_folder.path_join(file + "/index.gd")
			if ResourceLoader.exists(possible_script):
				indexers.append(load(possible_script).new())

	Engine.get_main_loop().set_meta('dialogic_indexers', indexers)
	return indexers



## 将 [param file_path] 从 `some_file.png` 转换成 `Some File`。
static func pretty_name(file_path: String) -> String:
	var _name := file_path.get_file().trim_suffix("." + file_path.get_extension())
	_name = _name.replace('_', ' ')
	_name = _name.capitalize()

	return _name

#endregion


#region 编辑器设置与颜色
################################################################################

const SETTING_HIDDEN_BUTTONS_DEFAULT := ["Setting", "History", "Save"]
const SETTING_BUTTON_SECTION_ORDER := ["Main", "Flow", "Audio", "Visuals", "Logic", "Other"]

static func set_editor_setting(setting:String, value:Variant) -> void:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists("user://dialogic/editor_settings.cfg"):
		cfg.load("user://dialogic/editor_settings.cfg")

	cfg.set_value("DES", setting, value)

	if not DirAccess.dir_exists_absolute("user://dialogic"):
		DirAccess.make_dir_absolute("user://dialogic")
	cfg.save("user://dialogic/editor_settings.cfg")


static func get_editor_setting(setting:String, default:Variant=null) -> Variant:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists("user://dialogic/editor_settings.cfg"):
		return default

	if not cfg.load("user://dialogic/editor_settings.cfg") == OK:
		return default

	return cfg.get_value("DES", setting, default)


static func get_color_palette(default:bool = false) -> Dictionary:
	var defaults := {
		'Color1': Color('#3b8bf2'), # 蓝色
		'Color2': Color('#00b15f'), # 绿色
		'Color3': Color('#e868e2'), # 粉色
		'Color4': Color('#9468e8'), # 紫色
		'Color5': Color('#574fb0'), # 深紫色
		'Color6': Color('#1fa3a3'), # 碧绿色
		'Color7': Color('#fa952a'), # 橙色
		'Color8': Color('#de5c5c'), # 红色
		'Color9': Color('#7c7c7c'), # 灰色
	}
	if default:
		return defaults
	return get_editor_setting('color_palette', defaults)


static func get_color(value:String) -> Color:
	var colors := get_color_palette()
	return colors[value]

#endregion


#region 计时器处理模式
################################################################################
static func is_physics_timer() -> bool:
	return ProjectSettings.get_setting('dialogic/timer/process_in_physics', false)


static func update_timer_process_callback(timer:Timer) -> void:
	timer.process_callback = Timer.TIMER_PROCESS_PHYSICS if is_physics_timer() else Timer.TIMER_PROCESS_IDLE

#endregion


#region 多重补间
################################################################################
static func multitween(tweened_value:Variant, item:Node, property:String, part:String) -> void:
	var parts: Dictionary = item.get_meta(property+'_parts', {})
	parts[part] = tweened_value

	if not item.has_meta(property+'_base_value') and not 'base' in parts:
		item.set_meta(property+'_base_value', item.get(property))

	var final_value: Variant = parts.get('base', item.get_meta(property+'_base_value', item.get(property)))

	for key in parts:
		if key == 'base':
			continue
		else:
			final_value += parts[key]

	item.set(property, final_value)
	item.set_meta(property+'_parts', parts)

#endregion


#region 翻译
################################################################################

static func get_next_translation_id() -> String:
	ProjectSettings.set_setting('dialogic/translation/id_counter', ProjectSettings.get_setting('dialogic/translation/id_counter', 16)+1)
	return '%x' % ProjectSettings.get_setting('dialogic/translation/id_counter', 16)

#endregion


#region 变量
################################################################################

enum VarTypes {ANY, STRING, FLOAT, INT, BOOL}


static func get_default_variables() -> Dictionary:
	return ProjectSettings.get_setting('dialogic/variables', {})


# 辅助函数：把嵌套的变量字典转换成带路径的数组
static func list_variables(dict:Dictionary, path := "", type:=VarTypes.ANY) -> Array:
	var array := []
	for key in dict.keys():
		if typeof(dict[key]) == TYPE_DICTIONARY:
			array.append_array(list_variables(dict[key], path+key+".", type))
		else:
			if type == VarTypes.ANY or get_variable_value_type(dict[key]) == type:
				array.append(path+key)
	return array


static func get_variable_value_type(value:Variant) -> VarTypes:
	match typeof(value):
		TYPE_STRING:
			return VarTypes.STRING
		TYPE_FLOAT:
			return VarTypes.FLOAT
		TYPE_INT:
			return VarTypes.INT
		TYPE_BOOL:
			return VarTypes.BOOL
	return VarTypes.ANY


static func get_variable_type(path:String, dict:Dictionary={}) -> VarTypes:
	if dict.is_empty():
		dict = get_default_variables()
	return get_variable_value_type(_get_value_in_dictionary(path, dict))


## 这会设置字典（或基于路径的子字典）中的某个值
## 例如可以把 "Something.Something.Something" 设置到 {'Something':{'Something':{'Someting':"value"}}} 中
static func _set_value_in_dictionary(path:String, dictionary:Dictionary, value):
	if '.' in path:
		var from := path.split('.')[0]
		if from in dictionary.keys():
			dictionary[from] = _set_value_in_dictionary(path.trim_prefix(from+"."), dictionary[from], value)
	else:
		if path in dictionary.keys():
			dictionary[path] = value
	return dictionary


## 这会获取字典（或基于路径的子字典）中的某个值
## 例如可以获取 {'Something':{'Something':{'Someting':"value"}}} 中的 "Something.Something.Something"
static func _get_value_in_dictionary(path:String, dictionary:Dictionary, default= null) -> Variant:
	if '.' in path:
		var from := path.split('.')[0]
		if from in dictionary.keys():
			return _get_value_in_dictionary(path.trim_prefix(from+"."), dictionary[from], default)
	else:
		if path in dictionary.keys():
			return dictionary[path]
	return default

#endregion


#region 场景导出覆盖
################################################################################

static func apply_scene_export_overrides(node:Node, export_overrides:Dictionary, apply := true) -> void:
	var default_info := get_scene_export_defaults(node)
	if !node.script:
		return
	var property_info: Array[Dictionary] = node.script.get_script_property_list()
	for i in property_info:
		if i['usage'] & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR:
			if i['name'] in export_overrides:
				if str_to_var(export_overrides[i['name']]) == null and typeof(node.get(i['name'])) == TYPE_STRING:
					node.set(i['name'], export_overrides[i['name']])
				else:
					node.set(i['name'], str_to_var(export_overrides[i['name']]))
			elif i['name'] in default_info:
				node.set(i['name'], default_info.get(i['name']))
	if apply:
		if node.has_method('apply_export_overrides'):
			node.apply_export_overrides()


static func get_scene_export_defaults(node:Node) -> Dictionary:
	if !node.script:
		return {}

	if Engine.get_main_loop().has_meta('dialogic_scene_export_defaults') and \
			node.scene_file_path in Engine.get_main_loop().get_meta('dialogic_scene_export_defaults'):
		return Engine.get_main_loop().get_meta('dialogic_scene_export_defaults')[node.scene_file_path]

	if !Engine.get_main_loop().has_meta('dialogic_scene_export_defaults'):
		Engine.get_main_loop().set_meta('dialogic_scene_export_defaults', {})
	var defaults := {}
	var property_info: Array[Dictionary] = node.script.get_script_property_list()
	for i in property_info:
		if i['usage'] & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR:
			defaults[i['name']] = node.get(i['name'])
	Engine.get_main_loop().get_meta('dialogic_scene_export_defaults')[node.scene_file_path] = defaults
	return defaults

#endregion

#region 创建自定义副本

static func make_file_custom(original_file:String, target_folder:String, new_file_name := "", new_folder_name := "") -> String:
	if not ResourceLoader.exists(original_file):
		push_error("[Dialogic] 无法把路径无效的文件创建为自定义副本！")
		return ""

	if new_folder_name:
		target_folder = target_folder.path_join(new_folder_name)
		DirAccess.make_dir_absolute(target_folder)

	if new_file_name.is_empty():
		new_file_name = "custom_" + original_file.get_file()

	if not new_file_name.ends_with(original_file.get_extension()):
		new_file_name += "." + original_file.get_extension()

	var target_file := target_folder.path_join(new_file_name)

	customize_file(original_file, target_file)

	get_dialogic_plugin().get_editor_interface().get_resource_filesystem().scan_sources()

	return target_file


static func customize_file(original_file:String, target_file:String) -> String:
	#print("\nCUSTOMIZE FILE")
	#printt(original_file, "->", target_file)

	DirAccess.copy_absolute(original_file, target_file)

	var file := FileAccess.open(target_file, FileAccess.READ)
	var file_text := file.get_as_text()
	file.close()

	# 如果正在自定义一个场景，我们会检查该场景使用到的、位于同一文件夹内的资源。
	# 这些资源也会被复制，并且场景会被修改为指向它们。
	if file_text.begins_with('[gd_'):
		var base_path: String = original_file.get_base_dir()

		var remove_uuid_regex := r'\[gd_.* (?<uid>uid="uid:[^"]*")'
		var result := RegEx.create_from_string(remove_uuid_regex).search(file_text)
		if result:
			file_text = file_text.replace(result.get_string("uid"), "")

		# 此正则也会移除指向原始资源的 UID
		var file_regex := r'(uid="[^"]*" )?\Qpath="'+base_path+r'\E(?<file>[^"]*)"'
		result = RegEx.create_from_string(file_regex).search(file_text)
		while result:
			var found_file_name := result.get_string('file')
			var found_file_path := base_path.path_join(found_file_name)
			var target_file_path := target_file.get_base_dir().path_join(found_file_name)

			# 在此文件中找到的文件也会被一并自定义。
			customize_file(found_file_path, target_file_path)

			file_text = file_text.replace(found_file_path, target_file_path)

			result = RegEx.create_from_string(file_regex).search(file_text)

	file = FileAccess.open(target_file, FileAccess.WRITE)
	file.store_string(file_text)
	file.close()

	return target_file

#endregion

#region 检查器字段
################################################################################

static func setup_script_property_edit_node(property_info: Dictionary, value:Variant, property_changed:Callable) -> Control:
	var input: Control = null
	match property_info['type']:
		TYPE_BOOL:
			input = CheckBox.new()
			if value != null:
				input.button_pressed = value
			input.toggled.connect(DialogicUtil._on_export_bool_submitted.bind(property_info.name, property_changed))
		TYPE_COLOR:
			input = ColorPickerButton.new()
			if value != null:
				input.color = value
			input.color_changed.connect(DialogicUtil._on_export_color_submitted.bind(property_info.name, property_changed))
			input.custom_minimum_size.x = get_editor_scale() * 50
		TYPE_INT:
			if property_info["hint"] & PROPERTY_HINT_ENUM == PROPERTY_HINT_ENUM:
				input = OptionButton.new()
				var idx := 0
				for x in property_info["hint_string"].split(","):
					var enum_key: String = str(Array(x.split(":"))[0] if ":" in x else x)
					input.add_item(get_enum_display_name(enum_key))
					var id := int(Array(x.split(":"))[1] if ":" in x else idx)
					input.set_item_metadata(idx, id)
					if value == id:
						input.select(idx)

					idx += 1
				input.item_selected.connect(DialogicUtil._on_export_int_enum_submitted.bind(property_info.name, property_changed, input))
			else:
				input = load("res://addons/dialogic/Editor/Events/Fields/field_number.tscn").instantiate()
				input.property_name = property_info['name']
				input.use_int_mode()

				if ',' in property_info.hint_string:
					input.min_value = int(property_info.hint_string.get_slice(',', 0))
					input.max_value = int(property_info.hint_string.get_slice(',', 1))
					if property_info.hint_string.count(',') > 1:
						input.step = int(property_info.hint_string.get_slice(',', 2))
				else:
					input.step = 1
					input.max_value = INF
					input.min_value = -INF

				if value != null:
					input.set_value(value)
				input.value_changed.connect(DialogicUtil._on_export_number_submitted.bind(property_changed))
		TYPE_FLOAT:
			input = load("res://addons/dialogic/Editor/Events/Fields/field_number.tscn").instantiate()
			input.property_name = property_info['name']
			input.use_float_mode()
			input.step = 0.01
			if ',' in property_info.hint_string:
				input.min_value = float(property_info.hint_string.get_slice(',', 0))
				input.max_value = float(property_info.hint_string.get_slice(',', 1))
				if property_info.hint_string.count(',') > 1:
					input.step = float(property_info.hint_string.get_slice(',', 2))
			if value != null:
				input.set_value(value)
			input.value_changed.connect(DialogicUtil._on_export_number_submitted.bind(property_changed))
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			var vectorSize: String = type_string(typeof(value))[-1]
			input = load("res://addons/dialogic/Editor/Events/Fields/field_vector" + vectorSize + ".tscn").instantiate()
			input.property_name = property_info['name']
			input.set_value(value)
			input.value_changed.connect(DialogicUtil._on_export_vector_submitted.bind(property_changed))
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
			var vectorSize: String = type_string(typeof(value))[-2]
			input = load("res://addons/dialogic/Editor/Events/Fields/field_vector" + vectorSize + ".tscn").instantiate()
			input.step = 1
			input.property_name = property_info['name']
			input.set_value(value)
			input.value_changed.connect(DialogicUtil._on_export_vectori_submitted.bind(property_changed))
		TYPE_STRING:
			if property_info['hint'] & PROPERTY_HINT_FILE== PROPERTY_HINT_FILE  or property_info['hint'] & PROPERTY_HINT_DIR == PROPERTY_HINT_DIR:
				input = load("res://addons/dialogic/Editor/Events/Fields/field_file.tscn").instantiate()
				input.show_editing_button = true
				input.file_filter = property_info['hint_string']
				input.file_mode = FileDialog.FILE_MODE_OPEN_FILE
				if property_info['hint'] == PROPERTY_HINT_DIR:
					input.file_mode = FileDialog.FILE_MODE_OPEN_DIR
				input.property_name = property_info['name']
				input.placeholder = "默认"
				input.hide_reset = true
				if value != null:
					input.set_value(value)
				input.value_changed.connect(DialogicUtil._on_export_file_submitted.bind(property_changed))
			elif property_info['hint'] & PROPERTY_HINT_ENUM == PROPERTY_HINT_ENUM:
				input = OptionButton.new()
				var options: PackedStringArray = []
				for x in property_info['hint_string'].split(','):
					options.append(x.split(':')[0].strip_edges())
					input.add_item(options[-1])
				if value != null:
					input.select(options.find(value))
				input.item_selected.connect(DialogicUtil._on_export_string_enum_submitted.bind(property_info.name, options, property_changed))
			else:
				input = LineEdit.new()
				if value != null:
					input.text = value
				input.text_submitted.connect(DialogicUtil._on_export_input_text_submitted.bind(property_info.name, property_changed))
		TYPE_DICTIONARY:
			input = load("res://addons/dialogic/Editor/Events/Fields/field_dictionary.tscn").instantiate()
			input.property_name = property_info["name"]
			input.set_value(value)
			input.value_changed.connect(_on_export_dict_submitted.bind(property_changed))
		TYPE_ARRAY:
			input = load("res://addons/dialogic/Editor/Events/Fields/field_array.tscn").instantiate()
			input.property_name = property_info["name"]
			input.set_value(value)
			input.value_changed.connect(_on_export_array_submitted.bind(property_changed))
		TYPE_OBJECT:
			input = load("res://addons/dialogic/Editor/Common/hint_tooltip_icon.tscn").instantiate()
			input.hint_text = "目前不支持把对象/资源作为设置项。\n请改用 @export_file('*.extension')，在需要时再加载该资源。"

		_:
			input = LineEdit.new()
			if value != null:
				input.text = value
			input.text_submitted.connect(_on_export_input_text_submitted.bind(property_info.name, property_changed))
	return input


static func _on_export_input_text_submitted(text:String, property_name:String, callable: Callable) -> void:
	callable.call(property_name, var_to_str(text))

static func _on_export_bool_submitted(value:bool, property_name:String, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func _on_export_color_submitted(color:Color, property_name:String, callable: Callable) -> void:
	callable.call(property_name, var_to_str(color))

static func _on_export_int_enum_submitted(item:int, property_name:String, callable: Callable, option_button:OptionButton) -> void:
	callable.call(property_name, var_to_str(option_button.get_item_metadata(item)))

static func _on_export_number_submitted(property_name:String, value:float, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func _on_export_file_submitted(property_name:String, value:String, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func _on_export_string_enum_submitted(value:int, property_name:String, list:PackedStringArray, callable: Callable):
	callable.call(property_name, var_to_str(list[value]))

static func _on_export_vector_submitted(property_name:String, value:Variant, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func _on_export_vectori_submitted(property_name:String, value:Variant, callable: Callable) -> void:
	match typeof(value):
		TYPE_VECTOR2: value = Vector2i(value)
		TYPE_VECTOR3: value = Vector3i(value)
		TYPE_VECTOR4: value = Vector4i(value)
	callable.call(property_name, var_to_str(value))

static func _on_export_dict_submitted(property_name:String, value:Variant, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func _on_export_array_submitted(property_name:String, value:Variant, callable: Callable) -> void:
	callable.call(property_name, var_to_str(value))

static func set_property_edit_node_value(node:Control, value:Variant) -> void:
	if node is CheckBox:
		node.button_pressed = value
	elif node is LineEdit:
		node.text = value
	elif node.has_method("set_value"):
		node.set_value(value)
	elif node is ColorPickerButton:
		node.color = value
	elif node is OptionButton:
		for i in range(node.item_count):
			if node.get_item_metadata(i) == value:
				node.select(i)
	elif node is SpinBox:
		node.value = value


#endregion


#region 事件默认值
################################################################################

static func get_custom_event_defaults(event_name:String) -> Dictionary:
	if Engine.is_editor_hint():
		return ProjectSettings.get_setting('dialogic/event_default_overrides', {}).get(event_name, {})
	else:
		if !Engine.get_main_loop().has_meta('dialogic_event_defaults'):
			Engine.get_main_loop().set_meta('dialogic_event_defaults', ProjectSettings.get_setting('dialogic/event_default_overrides', {}))
		return Engine.get_main_loop().get_meta('dialogic_event_defaults').get(event_name, {})

#endregion


#region 类型转换
################################################################################

static func str_to_bool(boolstring:String) -> bool:
	return true if boolstring == "true" else false


static func logical_convert(value:Variant) -> Variant:
	if typeof(value) == TYPE_STRING:
		if value.is_valid_int():
			return value.to_int()
		if value.is_valid_float():
			return value.to_float()
		if value == 'true':
			return true
		if value == 'false':
			return false
	return value


## 接收 [param source]，并构建一个只以字符为键的字典。
## 其值均为 `null`。
static func str_to_hash_set(source: String) -> Dictionary:
	var dictionary := Dictionary()

	for character in source:
		dictionary[character] = null

	return dictionary

#endregion


static func get_character_suggestions(search_text:String, current_value:DialogicCharacter = null, allow_none := true, allow_all:= false, editor_node:Node = null) -> Dictionary:
	var suggestions := {}

	var icon := load("res://addons/dialogic/Editor/Images/Resources/character.svg")

	if allow_none and current_value:
		suggestions['(No one)'] = {'value':'', 'editor_icon':["GuiRadioUnchecked", "EditorIcons"]}
	
	if "{" in search_text:
		suggestions[search_text] = {'value':search_text, 'editor_icon':["Variant", "EditorIcons"]}

	if allow_all:
		suggestions['ALL'] = {'value':'--All--', 'tooltip':'当前已加入的所有角色都会离开', 'editor_icon':["GuiEllipsis", "EditorIcons"]}

	# 获取当前时间线中的角色，并把它们放在建议列表的顶部。
	if editor_node:
		var recent_characters := []
		var timeline_node := editor_node.get_parent().find_parent("Timeline") as DialogicEditor
		for event_node in timeline_node.find_child("Timeline").get_children():
			if event_node == editor_node:
				break
			if event_node.resource is DialogicCharacterEvent or event_node.resource is DialogicTextEvent:
				recent_characters.append(event_node.resource.character)

		recent_characters.reverse()
		for character in recent_characters:
			if character and not character.get_character_name() in suggestions:
				suggestions[character.get_character_name()] = {'value': character.get_character_name(), 'tooltip': character.resource_path, 'icon': icon.duplicate()}

	var character_directory := DialogicResourceUtil.get_character_directory()
	for resource in character_directory.keys():
		suggestions[resource] = {'value': resource, 'tooltip': character_directory[resource], 'icon': icon}

	return suggestions


static func get_portrait_suggestions(search_text:String, character:DialogicCharacter, allow_empty := false, empty_text := "不改变", allow_anything:=false) -> Dictionary:
	var icon := load("res://addons/dialogic/Editor/Images/Resources/portrait.svg")
	var suggestions := {}

	if allow_empty:
		suggestions[empty_text] = {'value':'', 'editor_icon':["GuiRadioUnchecked", "EditorIcons"]}

	if "{" in search_text:
		suggestions[search_text] = {'value':search_text, 'editor_icon':["Variant", "EditorIcons"]}

	elif allow_anything and search_text:
		suggestions[search_text] = {'value':search_text, 'editor_icon':["Variant", "EditorIcons"]}

	if character != null:
		for portrait in character.portraits:
			suggestions[portrait] = {'value':portrait, 'icon':icon}

	return suggestions


static func get_portrait_position_suggestions(search_text := "") -> Dictionary:
	var icon := load(DialogicUtil.get_module_path("Character").path_join('portrait_position.svg'))

	var setting: String = ProjectSettings.get_setting('dialogic/portraits/position_suggestion_names', 'leftmost, left, center, right, rightmost')

	var suggestions := {}

	if not search_text.is_empty():
		suggestions[search_text] = {'value':search_text.strip_edges(), 'editor_icon':["GuiScrollArrowRight", "EditorIcons"]}

	for position_id in setting.split(','):
		var position_name: String = position_id.strip_edges()
		# 键是显示名，值是存进 .dtl 的位置 id。
		suggestions[DialogicUtil.get_value_display_name(position_name)] = {'value':position_name, 'icon':icon}
		if not search_text.is_empty() and position_id.strip_edges().begins_with(search_text):
			suggestions.erase(search_text)

	return suggestions


static func get_autoload_suggestions(filter:String="") -> Dictionary:
	var suggestions := {}

	for prop in ProjectSettings.get_property_list():
		if prop.name.begins_with('autoload/'):
			var some_autoload: String = prop.name.trim_prefix('autoload/')
			suggestions[some_autoload] = {'value': some_autoload, 'tooltip':some_autoload, 'editor_icon': ["Node", "EditorIcons"]}
			if filter.begins_with(some_autoload):
				suggestions[filter] = {'value': filter, 'editor_icon':["GuiScrollArrowRight", "EditorIcons"]}
	return suggestions


static func get_autoload_script_resource(autoload_name:String) -> Script:
	var script: Script
	if autoload_name and ProjectSettings.has_setting('autoload/'+autoload_name):
		var loaded_autoload := load(ProjectSettings.get_setting('autoload/'+autoload_name).trim_prefix('*'))

		if loaded_autoload is PackedScene:
			var packed_scene: PackedScene = loaded_autoload
			script = packed_scene.instantiate().get_script()

		else:
			script = loaded_autoload
	return script


static func get_autoload_method_suggestions(filter:String, autoload_name:String) -> Dictionary:
	var suggestions := {}

	var script := get_autoload_script_resource(autoload_name)
	if script:
		for script_method in script.get_script_method_list():
			if script_method.name.begins_with('@') or script_method.name.begins_with('_'):
				continue
			suggestions[script_method.name] = {'value': script_method.name, 'tooltip':script_method.name, 'editor_icon': ["Callable", "EditorIcons"]}

	if not filter.is_empty():
		suggestions[filter] = {'value': filter, 'editor_icon':["GuiScrollArrowRight", "EditorIcons"]}

	return suggestions


static func get_autoload_property_suggestions(_filter:String, autoload_name:String) -> Dictionary:
	var suggestions := {}
	var script := get_autoload_script_resource(autoload_name)
	if script:
		for property in script.get_script_property_list():
			if property.name.ends_with('.gd') or property.name.begins_with('_'):
				continue
			suggestions[property.name] = {'value': property.name, 'tooltip':property.name, 'editor_icon': ["MemberProperty", "EditorIcons"]}

	return suggestions


static func get_audio_bus_suggestions(_filter:= "") -> Dictionary:
	var bus_name_list := {}
	for i in range(AudioServer.bus_count):
		var bus_name: String = AudioServer.get_bus_name(i)
		var bus_text: String = DialogicUtil.get_value_display_name(bus_name)
		if i == 0:
			bus_name_list[bus_text] = {'value':''}
		else:
			bus_name_list[bus_text] = {'value':bus_name}
	return bus_name_list


static func get_audio_channel_suggestions(_search_text:String) -> Dictionary:
	var suggestions := {}
	var channel_defaults := DialogicUtil.get_audio_channel_defaults()
	var cached_names := DialogicResourceUtil.get_channel_list()

	for i in channel_defaults.keys():
		if not cached_names.has(i):
			cached_names.append(i)

	cached_names.sort()

	for i in cached_names:
		if i.is_empty():
			continue

		suggestions[i] = {'value': i}

		if i in channel_defaults.keys():
			suggestions[i]["editor_icon"] = ["ProjectList", "EditorIcons"]
			suggestions[i]["tooltip"] = "在设置中定义的默认频道。"

		else:
			suggestions[i]["editor_icon"] = ["AudioStreamPlayer", "EditorIcons"]
			suggestions[i]["tooltip"] = "没有默认值的临时频道。"

	return suggestions


static func get_audio_channel_defaults() -> Dictionary:
	return ProjectSettings.get_setting('dialogic/audio/channel_defaults', {
		"": {
			'volume': 0.0,
			'audio_bus': '',
			'fade_length': 0.0,
			'loop': false,
		},
		"music": {
			'volume': 0.0,
			'audio_bus': '',
			'fade_length': 0.0,
			'loop': true,
		}})


static func validate_audio_channel_name(text: String) -> Dictionary:
	var result := {}
	var channel_name_regex := RegEx.create_from_string(r'(?<dash_only>^-$)|(?<invalid>[^\w-]{1})')
	var matches := channel_name_regex.search_all(text)
	var invalid_chars := []

	for regex_match in matches:
		if regex_match.get_string('dash_only'):
			result['error_tooltip'] = "频道名不能为「-」。"
			result['valid_text'] = ''
		else:
			var invalid_char = regex_match.get_string('invalid')
			if not invalid_char in invalid_chars:
				invalid_chars.append(invalid_char)

	if invalid_chars:
		result['valid_text'] = channel_name_regex.sub(text, '', true)
		result['error_tooltip'] = "频道名不能包含以下字符：" + "".join(invalid_chars)

	return result


#region 事件名的中文显示（zh-cn 汉化分支新增）
################################################################################
## 事件名与分类在 .dtl 里是持久化的英文 key，绝不能被翻译，
## 因此界面上的中文只在这一层做映射：英文 key -> 中文显示名。
## 新增事件时记得同步补登到这两张表。

const EVENT_DISPLAY_NAMES := {
	"Default": "默认",
	"Text": "文本",
	"Character": "角色",
	"Choice": "选项",
	"End": "结束",
	"End Branch": "结束分支",
	"Jump": "跳转",
	"Label": "标签",
	"Return": "返回",
	"Wait": "等待",
	"Wait for Input": "等待输入",
	"Condition": "条件",
	"Comment": "注释",
	"Clear": "清空",
	"Background": "背景",
	"Change Style": "切换样式",
	"Audio": "音频",
	"Voice": "语音",
	"Save": "存档",
	"Setting": "设置",
	"Signal": "信号",
	"Set Variable": "设置变量",
	"Call": "调用",
	"Text Input": "文本输入",
	"Glossary": "词条",
	"History": "历史",
}

const EVENT_CATEGORY_DISPLAY_NAMES := {
	"Main": "主要",
	"Flow": "流程",
	"Logic": "逻辑",
	"Visuals": "画面",
	"Audio": "音频",
	"Other": "其他",
}


## 返回事件的界面显示名。未登记的事件（自定义事件）退回原始英文名。
static func get_event_display_name(event_name: String) -> String:
	return EVENT_DISPLAY_NAMES.get(event_name, event_name)


## 返回事件分类的界面显示名。未登记的分类退回原始英文名。
static func get_event_category_display_name(event_category: String) -> String:
	return EVENT_CATEGORY_DISPLAY_NAMES.get(event_category, event_category)


#region 枚举项的中文显示名（zh-cn 汉化分支新增）
################################################################################
# 枚举常量名是脚本里的标识符，因此保持英文，仅在显示时换成中文。
# Godot 自带的枚举（如 Control.MouseFilter）无法在这里覆盖。

const ENUM_DISPLAY_NAMES := {
	# 纹理过滤 / 重复
	"USE_PROJECT_SETTINGS": "使用项目设置",
	"NEAREST": "最近邻",
	"LINEAR": "线性",
	"LINEAR_WITH_MIPMAPS": "线性（Mipmap）",
	"NEAREST_WITH_MIPMAPS": "最近邻（Mipmap）",
	"DISABLED": "禁用",
	"ENABLED": "启用",
	"REPEAT_MIRROR": "镜像重复",
	# 对齐
	"LEFT": "左",
	"CENTER": "居中",
	"RIGHT": "右",
	# 颜色模式
	"GLOBAL": "全局",
	"ENTRY": "词条",
	"CUSTOM": "自定义",
	"GLOBAL_COLOR": "全局颜色",
	"CHARACTER_COLOR": "角色颜色",
	"CUSTOM_COLOR": "自定义颜色",
	"GLOBAL_BG_COLOR": "全局背景色",
	"BASE_COLOR_ONLY": "仅基础颜色",
	"ENTRY_COLOR_ON_BOX": "词条颜色作用于方框",
	# 动画
	"NONE": "无",
	"POP_IN": "弹入",
	"FADE_UP": "淡入上移",
	"POP_OUT": "弹出",
	"FADE_DOWN": "淡出下移",
	"WIGGLE": "抖动",
	"BOUNCE": "弹跳",
	"BLINK": "闪烁",
	# 立绘尺寸模式
	"KEEP": "保持原样",
	"FIT_STRETCH": "适配拉伸",
	"FIT_IGNORE_SCALE": "适配（忽略缩放）",
	"FIT_SCALE_HEIGHT": "按高度适配",
	# 立绘位置模式
	"POSITION": "按位置",
	"SPEAKER": "按说话者",
	# 打字音效模式
	"INTERRUPT": "打断",
	"ADD": "叠加",
}


#region 资源与选项值的中文显示名（zh-cn 汉化分支新增）
################################################################################
# 这些值会原样存进 .dtl 或用作资源查找键，因此只在界面显示时映射成中文。

const VALUE_DISPLAY_NAMES := {
	# 立绘动画（键为小写，匹配时对值做 to_lower()）
	"bounce": "弹跳",
	"bounce in": "弹跳进入",
	"bounce out": "弹跳退出",
	"fade in": "淡入",
	"fade out": "淡出",
	"fade in down": "自下淡入",
	"fade in up": "自上淡入",
	"fade out down": "向下淡出",
	"fade out up": "向上淡出",
	"fade cross": "交叉淡化",
	"heartbeat": "心跳",
	"instant in": "立即出现",
	"instant out": "立即消失",
	"shake x": "水平抖动",
	"shake y": "垂直抖动",
	"slide in down": "自下滑入",
	"slide in up": "自上滑入",
	"slide out down": "向下滑出",
	"slide out up": "向上滑出",
	"slide from left": "从左滑入",
	"slide from right": "从右滑入",
	"slide to left": "向左滑出",
	"slide to right": "向右滑出",
	"tada": "闪亮登场",
	"zoom in": "放大",
	"zoom out": "缩小",
	"zoom center in": "中心放大进入",
	"zoom center out": "中心缩小退出",
	# 背景过渡
	"simple fade": "简单淡化",
	"push down": "向下推移",
	"push up": "向上推移",
	"push left": "向左推移",
	"push right": "向右推移",
	"swipe diagonal up left": "左上斜向滑动",
	"swipe left to right": "从左向右滑动",
	"swipe right to left": "从右向左滑动",
	# 立绘位置
	"leftmost": "最左",
	"left": "左",
	"center": "居中",
	"right": "右",
	"rightmost": "最右",
	# 常见音频总线
	"master": "主音轨",
	"music": "音乐",
	"sfx": "音效",
	"voice": "人声",
}


## 返回资源名、选项值在界面上的显示名。未登记的项原样返回。
static func get_value_display_name(value: String) -> String:
	if value.is_empty():
		return value
	if value in VALUE_DISPLAY_NAMES:
		return VALUE_DISPLAY_NAMES[value]
	var lower: String = value.to_lower()
	if lower in VALUE_DISPLAY_NAMES:
		return VALUE_DISPLAY_NAMES[lower]
	var spaced: String = lower.replace("_", " ")
	if spaced in VALUE_DISPLAY_NAMES:
		return VALUE_DISPLAY_NAMES[spaced]
	return value


#endregion


## 返回枚举项在界面上的显示名。未登记的项退回 Godot 的默认写法。
static func get_enum_display_name(enum_key: String) -> String:
	if enum_key in ENUM_DISPLAY_NAMES:
		return ENUM_DISPLAY_NAMES[enum_key]
	# 类型化枚举的 hint 常常是 "Use Project Settings" 这种带空格的写法，统一成常量名再查。
	var normalized: String = enum_key.to_upper().replace(" ", "_")
	if normalized in ENUM_DISPLAY_NAMES:
		return ENUM_DISPLAY_NAMES[normalized]
	return enum_key.capitalize()


#endregion
