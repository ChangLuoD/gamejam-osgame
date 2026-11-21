@tool
class_name DialogicEvent
extends Resource

## 所有 Dialogic 事件的基类。
## 实现基础属性、翻译、短代码保存，以及用于构建
## 编辑器 UI 的实用方法。


## 当事件开始时发出。
## 该信号发出时附带事件资源 [code]event_resource[/code]
signal event_started(event_resource:DialogicEvent)

## 当事件结束时发出。
## 该信号发出时附带事件资源 [code]event_resource[/code]
signal event_finished(event_resource:DialogicEvent)


### 主要事件属性 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## 将在编辑器中显示的事件名称。
var event_name := "Event"
## 用于可翻译事件的唯一标识符。
var _translation_id := ""
## 执行期间对 dialogic 的引用，用法与 Dialogic（自动加载单例的引用）相同
var dialogic: DialogicGameHandler = null


### 特殊事件属性 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
### （这些属性保存此事件如何影响时间线的缩进与流程）

## 若为 true，此事件不能位于顶层（例如选项）
var needs_indentation := false
## 若为 true，此事件会与一个结束分支事件一同生成，并增加缩进
var can_contain_events := false
## 若 [can_contain_events] 为 true，这是对结束分支事件的引用
var end_branch_event: DialogicEndBranchEvent = null
## 若为 true，此事件会与其他同类事件分组（与选项的做法相同）。
var wants_to_group := false


### 保存/加载属性 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## 以文本格式存储该事件。不会自动更新。
var event_node_as_text := ""
## 标记该事件是否已处理，或仅以文本形式存储
var event_node_ready := false
## 此事件之前有多少个空行
var empty_lines_above: int = 0


### 编辑器 UI 属性 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## 在编辑器提示中显示的描述。
var event_description := ""
## 事件节点在编辑器中采用的事件颜色
var event_color := Color("FBB13C"):
	get:
		if dialogic_color_name:
			return DialogicUtil.get_color(dialogic_color_name)
		return event_color
## 如果你使用的是默认调色板
var dialogic_color_name: = ""
## 用于对编辑器中显示的按钮排序。索引越小越靠分类顶部
var event_sorting_index: int = 0
## 若为 true，此事件在可视化编辑器侧边栏中不会有按钮
var disable_editor_button := false
## 若为 false，此事件默认（加载时）隐藏其主体。建议大多数事件如此
var expand_by_default := false
## 若为 true，此事件创建时隐藏其主体。默认为 false，即添加后事件是展开的。
var collapse_on_create := false
## 选择右键 > 文档时打开的 URL
var help_page_path := ""
## 该事件块是否由按钮创建？
var created_by_button := false

## 对表示此事件的节点的引用。只在可视化编辑器模式下有效。
## 请谨慎使用。
var editor_node: Control = null

## 分类以及它被放入哪个分类（在可视化编辑器侧边栏中）
var event_category := "Other"


### 编辑器 UI 构建 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

## 用于区分应放入头部和主体的字段
enum Location {HEADER, BODY}

## 用于区分可视化编辑器中事件属性的不同字段类型
enum ValueType {
	# 字符串
	MULTILINE_TEXT, SINGLELINE_TEXT, CONDITION, FILE,
	# 布尔值
	BOOL, BOOL_BUTTON,
	# 选项列表
	DYNAMIC_OPTIONS, FIXED_OPTIONS,
	# 容器
	ARRAY, DICTIONARY,
	# 数字
	NUMBER,
	VECTOR2, VECTOR3, VECTOR4,
	# 其他
	CUSTOM, BUTTON, LABEL, COLOR, AUDIO_PREVIEW, IMAGE_PREVIEW
}
## 存储编辑器字段的列表
var editor_list: Array = []

var this_folder: String = get_script().resource_path.get_base_dir()

## 通知可视化编辑器事件块更新的信号
@warning_ignore("unused_signal")
signal ui_update_needed
@warning_ignore("unused_signal")
signal ui_update_warning(text:String)


## 使此资源可被打印。
func _to_string() -> String:
	return "[{name}:{id}]".format({"name":event_name, "id":get_instance_id()})

#endregion


#region 执行
################################################################################

## 执行事件行为。在子类中应重写 [_execute]（而不是此方法）！
func execute(_dialogic_game_handler) -> void:
	event_started.emit(self)
	dialogic = _dialogic_game_handler
	call_deferred("_execute")


## 结束事件行为。
func finish() -> void:
	event_finished.emit(self)


## 在执行下一个事件之前，或在 clear(any flags) / load_full_state() 之前调用。
##
## 如果事件在某处（例如某个子系统上）存储了临时状态，或者需要在运行另一个事件前做其他清理，
## 则应重写此方法。
func _clear_state() -> void:
	pass


## 由子类重写。
func _execute() -> void:
	finish()

#endregion


#region 分支事件
################################################################################
## 本节内容只应在 [member can_contain_events] 为 `true` 时使用。


## 由子类重写。仅在 [member can_contain_events] 为 `true` 时调用。
## 返回一个应显示在结束分支节点上的控件。
func _get_end_branch_control() -> Control:
	return null


## 由子类重写。如果即使先前已有分支执行过、此事件仍应执行，则返回 `true`。
## 例如 IF 事件返回 true，而 ELIF 和 ELSE 不返回。一个问题中的第一个选项会这样，其他的不会。
func _is_branch_starter() -> bool:
	return false


## 返回此事件对应结束分支事件的索引（仅在 can_contain_events 为 true 时使用）。
func get_end_branch_index() -> int:
	var idx: int = dialogic.current_timeline_events.find(self)
	while true:
		idx += 1
		var event: DialogicEvent = dialogic.current_timeline.get_event(idx)
		if not event:
			break
		if event.can_contain_events:
			idx = event.get_end_branch_index()
		if event is DialogicEndBranchEvent:
			break
	return idx


#endregion


#region 翻译
################################################################################

## 如果此事件需要翻译，请重写。
func _get_translatable_properties() -> Array:
	return []


## 如果此事件需要翻译，请重写。
func _get_property_original_translation(_property_name:String) -> String:
	return ''


## 如果此事件中有任意可翻译属性，则返回 true。
## 重写 [_get_translatable_properties()] 可以改变该行为。
func can_be_translated() -> bool:
	return !_get_translatable_properties().is_empty()


## 此方法会被自动调用，无需手动使用。
func add_translation_id() -> String:
	_translation_id = DialogicUtil.get_next_translation_id()
	return _translation_id


func remove_translation_id() -> void:
	_translation_id = ""


func get_property_translation_key(property_name:String) -> String:
	return event_name.path_join(_translation_id).path_join(property_name)


## 每当你使用可翻译属性时调用此方法
func get_property_translated(property_name:String) -> String:
	if !_translation_id.is_empty() and ProjectSettings.get_setting('dialogic/translation/enabled', false):
		var translation := tr(get_property_translation_key(property_name))
		# 如果找不到翻译，tr() 会返回 id，但我们希望回退到原文
		return translation if translation != get_property_translation_key(property_name) else _get_property_original_translation(property_name)
	else:
		return _get_property_original_translation(property_name)

#endregion


#region 保存 / 加载（内部使用，勿覆写）
################################################################################
### 这些函数由时间线加载器/保存器使用
### 它们主要使用下面的可重写行为，但会强制保存 unique_id

## 由时间线保存器使用。
func _store_as_string() -> String:
	if !_translation_id.is_empty() and can_be_translated():
		return to_text() + ' #id:'+str(_translation_id)
	else:
		return to_text()


## 如果你更新了事件并希望保存改动，请调用此方法。
func update_text_version() -> void:
	event_node_as_text = _store_as_string()


## 由时间线处理器使用。
func _load_from_string(string:String) -> void:
	_load_custom_defaults()
	if '#id:' in string and can_be_translated():
		_translation_id = string.get_slice('#id:', 1).strip_edges()
		from_text(string.get_slice('#id:', 0))
	else:
		from_text(string)
	event_node_ready = true


## 应用自定义默认值
func _load_custom_defaults() -> void:
	for default_prop in DialogicUtil.get_custom_event_defaults(event_name):
		if default_prop in self:
			set(default_prop, DialogicUtil.get_custom_event_defaults(event_name)[default_prop])


## 由时间线处理器使用。
func _test_event_string(string:String) -> bool:
	if '#id:' in string and can_be_translated():
		return is_valid_event(string.get_slice('#id:', 0))
	return is_valid_event(string.strip_edges())


func get_dependencies() -> PackedStringArray:
	var deps := PackedStringArray()
	var params := get_shortcode_parameters()
	for i in params:
		if params[i].has("ext_file"):
			var path: String = get(params[i].property)
			if path.begins_with("res://") or path.begins_with("uid://"):
				deps.append(path)
			elif i == "character":
				deps.append(DialogicResourceUtil.get_resource_path_from_identifier(path, "dch"))
			elif i == "timeline":
				deps.append(DialogicResourceUtil.get_resource_path_from_identifier(path, "dtl"))
	return deps

#endregion


#region 保存 / 加载
################################################################################
### 所有这些函数都可以/应该由子类重写

## 如果使用短代码格式，请返回短代码。
func get_shortcode() -> String:
	return 'default_shortcode'


## 如果使用短代码格式，请返回参数及其对应的属性名。
func get_shortcode_parameters() -> Dictionary:
	return {}


## 返回该事件的可读表示形式（存储时即为此形式）。
## 默认使用短代码格式，但可以重写。
func to_text() -> String:
	var shortcode := store_to_shortcode_parameters()
	if shortcode:
		return "[" + self.get_shortcode() + " " + store_to_shortcode_parameters() + "]"
	else:
		return "[" + self.get_shortcode() + "]"


## 从 [method to_text] 存储的字符串中加载变量。
## 默认使用短代码格式，但可以重写。
func from_text(string: String) -> void:
	load_from_shortcode_parameters(string)


## 返回包含所有短代码参数的字符串。
func store_to_shortcode_parameters(params:Dictionary = {}) -> String:
	if params.is_empty():
		params = get_shortcode_parameters()
	var custom_defaults: Dictionary = DialogicUtil.get_custom_event_defaults(event_name)
	var result_string := ""
	for parameter in params.keys():
		var parameter_info: Dictionary = params[parameter]
		var value: Variant = get(parameter_info.property)
		var default_value: Variant = custom_defaults.get(parameter_info.property, parameter_info.default)

		if parameter_info.get('custom_stored', false):
			continue

		if "set_" + parameter_info.property in self and not get("set_" + parameter_info.property):
			continue

		if typeof(value) == typeof(default_value) and value == default_value:
			if not "set_" + parameter_info.property in self or not get("set_" + parameter_info.property):
				continue

		result_string += " " + parameter + '="' + value_to_string(value, parameter_info.get("suggestions", Callable())) + '"'

	return result_string.strip_edges()


func value_to_string(value: Variant, suggestions := Callable()) -> String:
	var value_as_string := ""
	match typeof(value):
		TYPE_OBJECT:
			value_as_string = str(value.resource_path)

		TYPE_STRING:
			value_as_string = value

		TYPE_INT when suggestions.is_valid():
			# 处理枚举的文本替代项
			for option in suggestions.call().values():
				if option.value != value:
					continue

				if option.has('text_alt'):
					value_as_string = option.text_alt[0]
				else:
					value_as_string = var_to_str(option.value)

				break

		TYPE_DICTIONARY:
			value_as_string = JSON.stringify(value)

		_:
			value_as_string = var_to_str(value)

	if not ((value_as_string.begins_with("[") and value_as_string.ends_with("]")) or (value_as_string.begins_with("{") and value_as_string.ends_with("}"))):
		value_as_string.replace('"', '\\"')

	return value_as_string


func load_from_shortcode_parameters(string:String) -> void:
	var data: Dictionary = parse_shortcode_parameters(string)
	var params: Dictionary = get_shortcode_parameters()
	for parameter in params.keys():
		var parameter_info: Dictionary = params[parameter]
		if parameter_info.get('custom_stored', false):
			continue

		if not parameter in data:
			if "set_" + parameter_info.property in self:
				set("set_" + parameter_info.property, false)
			continue

		if "set_" + parameter_info.property in self:
			set("set_" + parameter_info.property, true)

		var param_value: String = data[parameter].replace('\\"', '"')
		var value: Variant
		match typeof(get(parameter_info.property)):
			TYPE_STRING:
				value = param_value

			TYPE_INT:
				# 如果给的是字符串
				if parameter_info.has('suggestions'):
					for option in parameter_info.suggestions.call().values():
						if option.has('text_alt') and param_value in option.text_alt:
							value = option.value
							break

				if not value:
					value = float(param_value)

			_:
				value = str_to_var(param_value)

		set(parameter_info.property, value)

## 如果给定字符串可以被解释为此事件，则必须返回 `true`。
## 默认使用短代码格式，但可以重写。
func is_valid_event(string: String) -> bool:
	if string.strip_edges().begins_with('['+get_shortcode()+' ') or string.strip_edges().begins_with('['+get_shortcode()+']'):
		return true
	return false


## 如果此字符串看起来是这种类型的完整事件，则必须返回 true
## （仅在 is_valid_event() 返回 true 时才测试）
## 如果使用短代码，则当字符串以 ']' 结尾时默认为 true
## 翻译 id 存储在 ']' 之后，因此在测试前会先被移除
func is_string_full_event(string: String) -> bool:
	if get_shortcode() != 'default_shortcode':
		if '#id:' in string and can_be_translated():
			return string.get_slice('#id:', 0).strip_edges().ends_with(']')
		return string.strip_edges().ends_with(']')
	return true


## 用于将字符串中的所有短代码参数获取为字典。
func parse_shortcode_parameters(shortcode: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile(r'(?<parameter>[^\s=]*)\s*=\s*"(?<value>(\{[^}]*\}|\[[^]]*\]|([^"]|\\")*|))(?<!\\)\"')
	var dict := {}
	for result in regex.search_all(shortcode):
		dict[result.get_string('parameter')] = result.get_string('value')
	return dict

#endregion


#region 编辑器展示
################################################################################

func _get_icon() -> Resource:
	var _icon_file_name := "res://addons/dialogic/Editor/Images/Pieces/closed-icon.svg" # 默认
	# 同时检查 svg 和 png，但优先使用 svg
	if ResourceLoader.exists(self.get_script().get_path().get_base_dir() + "/icon.svg"):
		_icon_file_name = self.get_script().get_path().get_base_dir() + "/icon.svg"
	elif ResourceLoader.exists(self.get_script().get_path().get_base_dir() + "/icon.png"):
		_icon_file_name = self.get_script().get_path().get_base_dir() + "/icon.png"
	return load(_icon_file_name)


func set_default_color(value:Variant) -> void:
	# 在运行中的游戏里跳过
	if not Engine.is_editor_hint():
		return
	dialogic_color_name = value
	event_color = DialogicUtil.get_color(value)


## 当资源被分配给可视化编辑器中的事件块时调用
func _enter_visual_editor(_timeline_editor:DialogicEditor) -> void:
	pass

#endregion


#region 代码补全
################################################################################

## 可以重写此方法为自定义语法实现代码补全
func _get_code_completion(_CodeCompletionHelper:Node, _TextNode:TextEdit, _line:String, _word:String, _symbol:String) -> void:
	pass

## 可以重写此方法为此事件添加起始建议
func _get_start_code_completion(_CodeCompletionHelper:Node, _TextNode:TextEdit) -> void:
	pass

#endregion


#region 语法高亮
################################################################################

func _get_syntax_highlighting(_Highlighter:SyntaxHighlighter, dict:Dictionary, _line:String) -> Dictionary:
	return dict

#endregion


#region 事件字段
################################################################################

func get_event_editor_info() -> Array:
	if Engine.is_editor_hint():
		if editor_list != null:
			editor_list.clear()
		else:
			editor_list = []

		if DialogicUtil.get_editor_setting('show_event_names', false):
			add_header_label(event_name)
		build_event_editor()
		return editor_list
	else:
		return []


## 由子类重写
func build_event_editor() -> void:
	pass

## 以下方法的参数大多相似：
## @variable: 		String 属性名，此字段对应的属性
## @condition: 		String 表达式，会被执行。若为 false
## @editor_type: 	ValueType 之一（见 ValueType 枚举）。定义字段类型。
## @left_text: 		显示在字段左侧的文本
## @right_text: 	显示在字段右侧的文本
## @extra_info: 	允许向字段传递更多信息。
## 					每种字段可传递的信息各不相同

func add_header_label(text:String, condition:= "") -> void:
	editor_list.append({
		"name" 			: "something",
		"type" 			:+ TYPE_STRING,
		"location" 		: Location.HEADER,
		"usage" 		: PROPERTY_USAGE_EDITOR,
		"field_type" : ValueType.LABEL,
		"display_info"  : {"text":text},
		"condition" 	: condition
		})


func add_header_edit(variable:String, editor_type := ValueType.LABEL, extra_info:= {}, condition:= "") -> void:
	editor_list.append({
		"name" 			: variable,
		"type" 			: typeof(get(variable)),
		"location" 		: Location.HEADER,
		"usage" 		: PROPERTY_USAGE_DEFAULT,
		"field_type" : editor_type,
		"display_info" 	: extra_info,
		"left_text" 	: extra_info.get('left_text', ''),
		"right_text" 	: extra_info.get('right_text', ''),
		"condition" 	: condition,
		})


func add_header_button(text:String, callable:Callable, tooltip:String, icon: Variant = null, condition:= "") -> void:
	editor_list.append({
		"name"			: "Button",
		"type" 			: TYPE_STRING,
		"location" 		: Location.HEADER,
		"usage" 		: PROPERTY_USAGE_DEFAULT,
		"field_type" : ValueType.BUTTON,
		"display_info" 	: {'text':text, 'tooltip':tooltip, 'callable':callable, 'icon':icon},
		"condition" 	: condition,
	})


func add_body_edit(variable:String, editor_type := ValueType.LABEL, extra_info:= {}, condition:= "") -> void:
	editor_list.append({
		"name" 			: variable,
		"type" 			: typeof(get(variable)),
		"location" 		: Location.BODY,
		"usage" 		: PROPERTY_USAGE_DEFAULT,
		"field_type" : editor_type,
		"display_info" 	: extra_info,
		"left_text" 	: extra_info.get('left_text', ''),
		"right_text" 	: extra_info.get('right_text', ''),
		"condition" 	: condition,
		})


func add_body_line_break(condition:= "") -> void:
	editor_list.append({
		"name" 		: "linebreak",
		"type" 		: TYPE_BOOL,
		"location" 	: Location.BODY,
		"usage" 	: PROPERTY_USAGE_DEFAULT,
		"condition" : condition,
		})

#endregion
