extends DialogicSubsystem

## 管理变量并允许访问这些变量的子系统。

## 当 Dialogic 变量发生变化时发出，提供一个包含以下键的字典：[br]
## [br]
## 键          |   值类型      | 值 [br]
## ----------- | ------------- | ----- [br]
## `variable`  | [type String] | 正在被修改的变量的名称。[br]
## `new_value` | [type Variant]| 变量在修改后具有的值（结果）。[br]
signal variable_changed(info:Dictionary)

## 在设置变量事件时发出，提供一个包含以下键的字典：[br]
## [br]
## 键          |   值类型      | 值 [br]
## ----------- | ------------- | ----- [br]
## `variable`  | [type String] | 正在被修改的变量的名称。[br]
## `orig_value`| [type Variant]| 变量在修改前具有的值。[br]
## `new_value` | [type Variant]| 变量在修改后具有的值（结果）。[br]
## `value`     | [type Variant]| 变量被修改成的值/用于修改的值。[br]
## `value_str` | [type String] | 提供的原始值（不作解释，因此变量也只是一个字符串）。[br]
@warning_ignore("unused_signal") # 该信号由变量事件发出
signal variable_was_set(info:Dictionary)

@export_group("State")
@export var var_storage := {}

#region 状态
####################################################################################################

func _clear_state(clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR):
	# 加载默认变量
	if not clear_flag & DialogicGameHandler.ClearFlags.KEEP_VARIABLES:
		reset()


func _load_state(load_flag:=LoadFlags.FULL_LOAD):
	if load_flag == LoadFlags.ONLY_DNODES:
		return
	var_storage = merge_folder(var_storage, ProjectSettings.get_setting('dialogic/variables', {}).duplicate(true))

#endregion


#region 主要方法
####################################################################################################

## 此函数会尝试获取花括号内给出的变量的值，
## 并用这些值替换它们。
## 它会：
## - 查找需要替换的字符串
## - 搜索所有自动加载
## - 尝试从上下文中获取值
##
## 因此，如果你提供类似 `Hello, how are you doing {Game.player_name}
## 这样的字符串，它会尝试搜索名为 `Game` 的自动加载，并获取 `player_name`
## 的值来替换它。
func parse_variables(text:String) -> String:
	# 先做一些粗略检查以避免解析
	if not '{' in text:
		return text

	# 尝试从文本中提取花括号
	var regex := RegEx.new()
	regex.compile(r"(?<!\\)\{(?<variable>([^{}]|\{[^}]*\})*)\}")

	var parsed := text.replace('\\{', '{')
	for result in regex.search_all(text):
		var value: Variant = get_variable(result.get_string('variable'), "<NOT FOUND>")
		parsed = parsed.replace("{"+result.get_string('variable')+"}", str(value))

	return parsed


func set_variable(variable_name: String, value: Variant) -> bool:
	variable_name = variable_name.trim_prefix('{').trim_suffix('}')

	# 首先假定这是一个普通的 Dialogic 变量
	if has(variable_name):
		DialogicUtil._set_value_in_dictionary(variable_name, var_storage, value)
		variable_changed.emit({'variable':variable_name, 'new_value':value})
		return true

	# 其次假定这是一个自动加载变量
	elif '.' in variable_name:
		var from := variable_name.get_slice('.', 0)
		var variable := variable_name.trim_prefix(from+'.')

		var autoloads := get_autoloads()
		var object: Object = null
		if from in autoloads:
			object = autoloads[from]
			while variable.count("."):
				from = variable.get_slice('.', 0)
				if from in object and object.get(from) is Object:
					object = object.get(from)
				variable = variable.trim_prefix(from+'.')

		if object:
			var sub_idx := ""
			if '[' in variable:
				sub_idx = variable.substr(variable.find('['))
			variable = variable.trim_suffix(sub_idx)
			sub_idx = sub_idx.trim_prefix('[').trim_suffix(']')

			if variable in object:
				match typeof(object.get(variable)):
					TYPE_ARRAY:
						if not sub_idx:
							if typeof(value) == TYPE_ARRAY:
								object.set(variable, value)
								return true
						elif sub_idx.is_valid_float():
							object.get(variable).remove_at(int(sub_idx))
							object.get(variable).insert(int(sub_idx), value)
							return true
					TYPE_DICTIONARY:
						if not sub_idx:
							if typeof(value) == TYPE_DICTIONARY:
								object.set(variable, value)
								return true
						else:
							object.get(variable).merge({str_to_var(sub_idx):value}, true)
							return true
					_:
						object.set(variable, value)
						return true

	printerr("[Dialogic] 尝试设置不存在的变量 '"+variable_name+"'。")
	return false


func get_variable(variable_path:String, default: Variant = null, no_warning := false) -> Variant:
	if variable_path.begins_with('{') and variable_path.ends_with('}') and variable_path.count('{') == 1:
		variable_path = variable_path.trim_prefix('{').trim_suffix('}')

	# 首先假定这只是一个单独的变量
	var value: Variant = DialogicUtil._get_value_in_dictionary(variable_path, var_storage)
	if value != null:
		return value

	# 其次假定这是一个表达式。
	else:
		value = dialogic.Expressions.execute_string(variable_path, null, no_warning)
		if value != null:
			return value

	return default


## 将所有变量或指定变量重置为变量编辑器中定义的值
func reset(variable:="") -> void:
	if variable.is_empty():
		var_storage = ProjectSettings.get_setting("dialogic/variables", {}).duplicate(true)
	else:
		DialogicUtil._set_value_in_dictionary(variable, var_storage, DialogicUtil._get_value_in_dictionary(variable, ProjectSettings.get_setting('dialogic/variables', {})))


## 如果存在给定路径的变量则返回 true
func has(variable:="") -> bool:
	return DialogicUtil._get_value_in_dictionary(variable, var_storage) != null



## 允许设置 Dialogic 内置变量
func _set(property, value) -> bool:
	property = str(property)
	var vars: Dictionary = var_storage
	if property in vars.keys():
		if typeof(vars[property]) != TYPE_DICTIONARY:
			vars[property] = value
			return true
		if value is VariableFolder:
			return true
	return false


## 允许获取 Dialogic 内置变量
func _get(property):
	property = str(property)
	if property in var_storage.keys():
		if typeof(var_storage[property]) == TYPE_DICTIONARY:
			return VariableFolder.new(var_storage[property], property, self)
		else:
			return DialogicUtil.logical_convert(var_storage[property])
	return null


func folders() -> Array:
	var result := []
	for i in var_storage.keys():
		if var_storage[i] is Dictionary:
			result.append(VariableFolder.new(var_storage[i], i, self))
	return result


func variables(_absolute:=false) -> Array:
	var result := []
	for i in var_storage.keys():
		if not var_storage[i] is Dictionary:
			result.append(i)
	return result
#endregion

#region 辅助方法
################################################################################

func get_autoloads() -> Dictionary:
	var autoloads := {}
	for node: Node in get_tree().root.get_children():
		autoloads[node.name] = node
	return autoloads


func merge_folder(new:Dictionary, defs:Dictionary) -> Dictionary:
	# 同时遍历此文件夹中的所有分组
	for x in new.keys():
		if x in defs and typeof(new[x]) == TYPE_DICTIONARY:
			new[x] = merge_folder(new[x], defs[x])
	# 添加所有新变量
	for x in defs.keys():
		if not x in new:
			new[x] = defs[x]
	return new

#endregion

#region 变量文件夹
################################################################################
class VariableFolder:
	var data := {}
	var path := ""
	var outside: DialogicSubsystem

	func _init(_data:Dictionary, _path:String, _outside:DialogicSubsystem):
		data = _data
		path = _path
		outside = _outside


	func _get(property:StringName):
		property = str(property)
		if property in data:
			if typeof(data[property]) == TYPE_DICTIONARY:
				return VariableFolder.new(data[property], path+"."+property, outside)
			else:
				return DialogicUtil.logical_convert(data[property])
		return null


	func _set(property:StringName, value:Variant) -> bool:
		property = str(property)
		if not value is VariableFolder:
			DialogicUtil._set_value_in_dictionary(path+"."+property, outside.var_storage, value)
		return true


	func has(key:String) -> bool:
		return key in data


	func folders() -> Array:
		var result := []
		for i in data.keys():
			if data[i] is Dictionary:
				result.append(VariableFolder.new(data[i], path+"."+i, outside))
		return result


	func variables(absolute:=false) -> Array:
		var result := []
		for i in data.keys():
			if not data[i] is Dictionary:
				if absolute:
					result.append(path+'.'+i)
				else:
					result.append(i)
		return result

#endregion
