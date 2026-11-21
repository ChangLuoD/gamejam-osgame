@tool
extends DialogicVisualEditorField

## 用于固定选项的事件块字段。可变化的选项请使用ComplexPicker。

var options: Array = []:
	set(o):
		options = o
		if current_value != -1:
			set_value(current_value)

## 若启用，则只显示符号。在下拉菜单中会显示文本。
## 便于简化界面
var symbol_only := false:
	set(value):
		symbol_only = value
		if value: self.text = ""

var current_value: Variant = -1


func _ready() -> void:
	add_theme_color_override("font_disabled_color", get_theme_color("font_color", "MenuButton"))
	self.about_to_popup.connect(insert_options)
	call("get_popup").index_pressed.connect(index_pressed)



func _load_display_info(info:Dictionary) -> void:
	options = info.get('options', [])
	self.disabled = info.get('disabled', false)
	symbol_only = info.get('symbol_only', false)


func _set_value(value:Variant) -> void:
	for option in options:
		if option['value'] == value:
			if typeof(option.get('icon')) == TYPE_ARRAY:
				option.icon = callv('get_theme_icon', option.get('icon'))
			if !symbol_only:
				self.text = option['label']
			self.icon = option.get('icon', null)
	current_value = value


func get_value() -> Variant:
	return current_value


func insert_options() -> void:
	call("get_popup").clear()

	var idx := 0
	for option in options:
		if typeof(option.get('icon')) == TYPE_ARRAY:
			option.icon = callv('get_theme_icon', option.get('icon'))
		call("get_popup").add_icon_item(option.get('icon', null), option['label'])
		call("get_popup").set_item_metadata(idx, option['value'])
		idx += 1


func index_pressed(idx:int) -> void:
	current_value = idx
	if !symbol_only:
		self.text = call("get_popup").get_item_text(idx)
	self.icon  =call("get_popup").get_item_icon(idx)
	value_changed.emit(property_name, call("get_popup").get_item_metadata(idx))
