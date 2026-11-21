@tool
extends EditorProperty

var field: Control = null
var button: Button = null
# 该属性的内部值。
var current_value: DialogicTimeline = null
# 用于防止属性更新时的内部改动造成误触发。
var updating = false


func _init() -> void:
	var hbox := HBoxContainer.new()
	add_child(hbox)

	field = load("res://addons/dialogic/Editor/Events/Fields/field_options_dynamic.tscn").instantiate()
	hbox.add_child(field)
	field.placeholder_text = "无时间线"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	field.mode = field.Modes.IDENTIFIER
	field.fit_text_length = false
	field.valid_file_drop_extension = ".dtl"
	field.value_changed.connect(_on_field_value_changed)
	field.suggestions_func = get_timeline_suggestions

	button = Button.new()
	hbox.add_child(button)
	button.hide()
	button.pressed.connect(_on_button_pressed, CONNECT_DEFERRED)


func _on_field_value_changed(_property:String, value:Variant) -> void:
	# 若该属性当前正在更新，则忽略此信号。
	if updating:
		return

	var new_value: DialogicTimeline = null
	if value:
		new_value = DialogicResourceUtil.get_timeline_resource(value)

	if current_value != new_value:
		current_value = new_value
		if current_value:
			button.show()
		else:
			button.hide()
		emit_changed(get_edited_property(), current_value)


func _update_property() -> void:
	field.resource_icon = load("res://addons/dialogic/Editor/Images/Resources/timeline.svg")
	button.icon = get_theme_icon("ExternalLink", "EditorIcons")

	# 从属性中读取当前值。
	var new_value = get_edited_object()[get_edited_property()]
	if (new_value == current_value):
		return

	# 用新值更新控件。
	updating = true
	current_value = new_value
	if current_value:
		field.set_value(current_value.get_identifier())
		button.show()
	else:
		button.hide()
		field.set_value("")
	updating = false


func get_timeline_suggestions(_filter:String) -> Dictionary:
	var suggestions := {}
	var timeline_directory := DialogicResourceUtil.get_timeline_directory()
	for identifier in  timeline_directory.keys():
		suggestions[identifier] = {'value': identifier, 'tooltip':timeline_directory[identifier], 'editor_icon': ["TripleBar", "EditorIcons"]}
	return suggestions


func _on_button_pressed() -> void:
	if current_value:
		EditorInterface.edit_resource(current_value)
