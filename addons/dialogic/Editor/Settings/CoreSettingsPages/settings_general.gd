@tool
extends DialogicSettingsPage

## 存放 Dialogic 常规设置的设置面板。
var DIALOGIC_RESERVED_WORDS : Array[String] = []

func _get_title() -> String:
	return "General"


## 界面显示标题（标识仍保持英文，仅显示用中文）
func _get_display_title() -> String:
	return "常规"


func _get_priority() -> int:
	return 99

func _ready() -> void:
	var s := DCSS.inline({
		'padding': 5,
		'background': Color(0.545098, 0.545098, 0.545098, 0.211765)
	})
	%ExtensionsFolderPicker.resource_icon = get_theme_icon("Folder", "EditorIcons")

	# 信号
	%ExtensionsFolderPicker.value_changed.connect(_on_ExtensionsFolder_value_changed)
	%PhysicsTimerButton.toggled.connect(_on_physics_timer_button_toggled)

	%NameEdit.text_changed.connect(_on_name_edit_changed)

	# 扩展创建器
	%ExtensionCreator.hide()
	
	# 收集已存在的子系统，供后续使用
	for indexer in DialogicUtil.get_indexers():
		for sub in indexer._get_subsystems():
			DIALOGIC_RESERVED_WORDS.append(sub.name)


func _refresh() -> void:
	%PhysicsTimerButton.button_pressed = DialogicUtil.is_physics_timer()
	%LayoutNodeEndBehaviour.select(ProjectSettings.get_setting('dialogic/layout/end_behaviour', 0))
	%ExtensionsFolderPicker.set_value(ProjectSettings.get_setting('dialogic/extensions_folder', 'res://addons/dialogic_additions'))



func _on_physics_timer_button_toggled(is_toggled: bool) -> void:
	ProjectSettings.set_setting('dialogic/timer/process_in_physics', is_toggled)
	ProjectSettings.save()


func _on_ExtensionsFolder_value_changed(property:String, value:String) -> void:
	if value == null or value.is_empty():
		value = 'res://addons/dialogic_additions'
	ProjectSettings.set_setting('dialogic/extensions_folder', value)
	ProjectSettings.save()


func _on_layout_node_end_behaviour_item_selected(index:int) -> void:
	ProjectSettings.set_setting('dialogic/layout/end_behaviour', index)
	ProjectSettings.save()


################################################################################
## 					扩展创建器
################################################################################

func _on_create_extension_button_pressed() -> void:
	%CreateExtensionButton.hide()
	%ExtensionCreator.show()

	%NameEdit.text = ""
	%NameEdit.grab_focus()


func _on_submit_extension_button_pressed() -> void:
	if %NameEdit.text.is_empty():
		return
	
	var extensions_folder: String = ProjectSettings.get_setting('dialogic/extensions_folder', 'res://addons/dialogic_additions')

	extensions_folder = extensions_folder.path_join(%NameEdit.text.to_pascal_case())
	DirAccess.make_dir_recursive_absolute(extensions_folder)
	var mode: int = %ExtensionMode.selected

	var file: FileAccess
	var indexer_content := "@tool\nextends DialogicIndexer\n\n"
	if mode != 2: # 在「仅子系统」模式下不添加事件
		indexer_content += """func _get_events() -> Array:
	return [this_folder.path_join('event_"""+%NameEdit.text.to_snake_case()+""".gd')]\n\n"""
		file = FileAccess.open(extensions_folder.path_join('event_'+%NameEdit.text.to_snake_case()+'.gd'), FileAccess.WRITE)
		file.store_string(

#region 扩展事件脚本
"""@tool
extends DialogicEvent
class_name Dialogic"""+%NameEdit.text.to_pascal_case()+"""Event

# 在此定义事件的属性

func _execute() -> void:
	# 当事件被触发时会执行这里
	finish() # 调用后继续执行下一个事件


#region 初始化
################################################################################
# 设置该事件的固定配置
func _init() -> void:
	event_name = \""""+%NameEdit.text.capitalize()+"""\"
	event_category = "Other"

\n
#endregion

#region 保存/加载
################################################################################
func get_shortcode() -> String:
	return \""""+%NameEdit.text.to_snake_case()+"""\"

func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 		: property_info
		#"my_parameter"		: {"property": "property", "default": "Default"},
	}

# 你也可以改为重写这 3 个函数：to_text()、from_text()、is_valid_event()
#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	pass

#endregion
""")

#endregion
	if mode != 0: # 在「仅事件」模式下不添加子系统
		indexer_content += """func _get_subsystems() -> Array:
	return [{'name':'"""+%NameEdit.text.to_pascal_case()+"""', 'script':this_folder.path_join('subsystem_"""+%NameEdit.text.to_snake_case()+""".gd')}]"""
		file = FileAccess.open(extensions_folder.path_join('subsystem_'+%NameEdit.text.to_snake_case()+'.gd'), FileAccess.WRITE)
		file.store_string(

# region EXTENDED SUBSYSTEM SCRIPT
"""extends DialogicSubsystem

## 在此描述该子系统的用途。


#region 状态
####################################################################################################

func _clear_state(clear_flag:=Dialogic.ClearFlags.FULL_CLEAR) -> void:
	pass

func _load_state(load_flag:=LoadFlags.FULL_LOAD) -> void:
	pass

#endregion


#region 主要方法
####################################################################################################

# 在此添加一些有用的方法。

#endregion
""")
	file = FileAccess.open(extensions_folder.path_join('index.gd'), FileAccess.WRITE)
	file.store_string(indexer_content)

	%ExtensionCreator.hide()
	%CreateExtensionButton.show()

	EditorInterface.get_resource_filesystem().scan_sources()
	force_event_button_list_reload()


func force_event_button_list_reload() -> void:
	find_parent('EditorsManager').editors['Timeline'].node.get_node('%VisualEditor').load_event_buttons()


func _on_reload_pressed() -> void:
	DialogicUtil._update_autoload_subsystem_access()


func _on_name_edit_changed(new_text: String) -> void:
		if new_text in DIALOGIC_RESERVED_WORDS:
			%WarningMessage.text = str("[color=yellow]警告：扩展 ",new_text," 与已存在的子系统同名。 \
			如果你不打算覆盖基础子系统，请换一个名称。")
			%WarningMessage.visible = true
		else:
			%WarningMessage.visible = false
			
