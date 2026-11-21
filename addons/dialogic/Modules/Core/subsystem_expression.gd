extends DialogicSubsystem

## 允许执行字符串（使用 Expression 类）的子系统。
## 条件会用到它，也用于允许把表达式当作变量使用。


#region 主要方法
####################################################################################################

func execute_string(string:String, default: Variant = null, no_warning := false) -> Variant:
	# Expression 类不支持某些方法，但它们非常有用。
	# 因此下面重新实现了它们，并偷偷地加入。
	string = string.replace('range(', 'd_range(')
	string = string.replace('len(', 'd_len(')
	string = string.replace('regex(', 'd_regex(')


	var regex: RegEx = RegEx.create_from_string('{([^{}]*)}')

	for res in regex.search_all(string):
		var value: Variant = dialogic.VAR.get_variable(res.get_string())
		string = string.replace(res.get_string(), var_to_str(value))

	if string.begins_with("{") and string.ends_with('}') and string.count("{") == 1:
		string = string.trim_prefix("{").trim_suffix("}")

	var expr := Expression.new()

	var autoloads := []
	var autoload_names := []
	for c in get_tree().root.get_children():
		autoloads.append(c)
		autoload_names.append(c.name)

	if expr.parse(string, autoload_names) != OK:
		if not no_warning:
			printerr('[Dialogic] 表达式 "{0}" 解析失败：{1}'.format([string, expr.get_error_text()]))
			dialogic.print_debug_moment()
		return default

	var result: Variant = expr.execute(autoloads, self)
	if expr.has_execute_failed():
		if not no_warning:
			printerr('[Dialogic] 表达式 "{0}" 解析失败：{1}'.format([string, expr.get_error_text()]))
			dialogic.print_debug_moment()
		return default
	return result


func execute_condition(condition:String) -> bool:
	if execute_string(condition, false):
		return true
	return false


var condition_modifier_regex := RegEx.create_from_string(r"(?(DEFINE)(?<nobraces>([^{}]|\{(?P>nobraces)\})*))\[if *(?<condition>(\{(?P>nobraces)\}|true\b|false\b))(?<truetext>(\\\]|\\\/|[^\]\/])*)(\/(?<falsetext>(\\\]|[^\]])*))?\]")
func modifier_condition(text:String) -> String:
	for find in condition_modifier_regex.search_all(text):
		var insert := ""
		if execute_condition(find.get_string("condition")):
			insert = find.get_string("truetext")
		else:
			insert = find.get_string("falsetext")

		# 避免在插入内容为空时，插入位置出现两个连续空格。
		if not insert.strip_edges() and " "+find.get_string()+" " in text:
			text = text.replace(find.get_string()+" ", insert.strip_edges())
		else:
			text = text.replace(find.get_string(), insert.strip_edges())

	return text
#endregion


#region 辅助方法
####################################################################################################
func d_range(a1, a2=null,a3=null,a4=null) -> Array:
	if !a2:
		return range(a1)
	elif !a3:
		return range(a1, a2)
	elif !a4:
		return range(a1, a2, a3)
	else:
		return range(a1, a2, a3, a4)

func d_len(arg:Variant) -> int:
	return len(arg)


# 检查基于正则模式字符串的输入中是否存在匹配。
func d_regex(input: String, pattern: String, offset: int = 0, end: int = -1) -> bool:
	var regex: RegEx = RegEx.create_from_string(pattern)
	regex.compile(pattern)
	var match := regex.search(input, offset, end)
	if match:
		return true
	else:
		return false

#endregion
