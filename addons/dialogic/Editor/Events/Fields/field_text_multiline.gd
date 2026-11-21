@tool
extends DialogicVisualEditorField

## 允许输入多行文本的事件块字段（主要用于文本事件）。

@onready var code_completion_helper: Node = find_parent('EditorsManager').get_node('CodeCompletionHelper')


#region 主要方法
################################################################################

func _ready() -> void:
	self.text_changed.connect(_on_text_changed)
	self.syntax_highlighter = code_completion_helper.text_syntax_highlighter


func _load_display_info(info:Dictionary) -> void:
	pass


func _set_value(value:Variant) -> void:
	self.text = str(value)


func _autofocus() -> void:
	grab_focus()

#endregion


#region 信号方法
################################################################################

func _on_text_changed(_value := "") -> void:
	value_changed.emit(property_name, self.text)

#endregion


#region 自动补全
################################################################################

## 在输入内容时调用
func _request_code_completion(force:bool):
	code_completion_helper.request_code_completion(force, self, 0)


## 根据已输入的内容筛选所有可能选项的列表
## 不同Kind的用途在[_request_code_completion]中说明
func _filter_code_completion_candidates(candidates:Array) -> Array:
	return code_completion_helper.filter_code_completion_candidates(candidates, self)


## 在代码补全被激活时调用
## 插入所选项
func _confirm_code_completion(replace:bool) -> void:
	code_completion_helper.confirm_code_completion(replace, self)

#endregion


#region 符号点击
################################################################################

## 在点击有效符号时执行操作（例如打开链接）
func _on_symbol_lookup(symbol, line, column):
	code_completion_helper.symbol_lookup(symbol, line, column)


## 用于检测符号是否可点击
func _on_symbol_validate(symbol:String) -> void:
	code_completion_helper.symbol_validate(symbol, self)

#endregion
