@tool
extends Control

## 管理编辑器、工具栏与侧边栏的节点。

signal resource_opened(resource)
signal editor_changed(previous, current)

### 引用
@onready var hsplit := $HSplit
@onready var sidebar := $HSplit/Sidebar
@onready var editors_holder := $HSplit/VBox/Editors
@onready var toolbar := $HSplit/VBox/Toolbar
@onready var tabbar := $HSplit/VBox/Toolbar/EditorTabBar

var reference_manager: Node:
	get:
		return get_node("../ReferenceManager")

## 关于受支持的资源扩展名与已注册编辑器的信息
var current_editor: DialogicEditor = null
var previous_editor: DialogicEditor = null
var editors := {}
var supported_file_extensions := []
enum ButtonPlacement {TOOLBAR_MAIN, SIDEBAR_LEFT_OF_FILTER, SIDEBAR_RIGHT_OF_FILTER}


################################################################################
## 						注册编辑器
################################################################################

## 请求编辑器容器的所有子节点进行注册
func _ready() -> void:
	if owner.get_parent() is SubViewport:
		return

	tabbar.clear_tabs()

	# 加载基础编辑器
	_add_editor("res://addons/dialogic/Editor/HomePage/home_page.tscn")
	_add_editor("res://addons/dialogic/Editor/TimelineEditor/timeline_editor.tscn")
	_add_editor("res://addons/dialogic/Editor/CharacterEditor/character_editor.tscn")

	# 加载自定义编辑器
	for indexer in DialogicUtil.get_indexers():
		for editor_path in indexer._get_editors():
			_add_editor(editor_path)
	_add_editor("res://addons/dialogic/Editor/Settings/settings_editor.tscn")

	tabbar.tab_clicked.connect(_on_editors_tab_changed)

	# 必须在这里完成，以确保执行注册调用时该节点已经就绪
	for editor in editors_holder.get_children():
		editor.editors_manager = self
		editor._register()

	DialogicResourceUtil.update()

	await get_parent().ready
	await get_tree().process_frame

	load_saved_state()

	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_file_system_dock().file_removed.connect(_on_file_removed)

	hsplit.set("theme_override_constants/separation", get_theme_constant("base_margin", "Editor") * DialogicUtil.get_editor_scale())


func _add_editor(path:String) -> void:
	var editor: DialogicEditor = load(path).instantiate()
	editors_holder.add_child(editor)
	editor.hide()
	tabbar.add_tab(editor._get_title(), editor._get_icon())


## 调用以注册编辑带有自定义扩展名的资源的编辑器/标签页。
func register_resource_editor(resource_extension:String, editor:DialogicEditor) -> void:
	editors[editor.name] = {"node":editor, "buttons":[], "extension": resource_extension}
	supported_file_extensions.append(resource_extension)
	editor.resource_saved.connect(_on_resource_saved.bind(editor))
	editor.resource_unsaved.connect(_on_resource_unsaved.bind(editor))


## 调用以注册不编辑任何资源的编辑器/标签页
func register_simple_editor(editor:DialogicEditor) -> void:
	editors[editor.name] = {"node": editor,  "buttons":[]}


## 调用以添加按钮。
func add_button(icon:Texture, label:String, tooltip:String, editor:DialogicEditor=null, placement = ButtonPlacement.TOOLBAR_MAIN) -> Node:
	var button: Button
	match placement:
		ButtonPlacement.TOOLBAR_MAIN:
			button = toolbar.add_button(icon, label, tooltip, placement)
		ButtonPlacement.SIDEBAR_LEFT_OF_FILTER, ButtonPlacement.SIDEBAR_RIGHT_OF_FILTER:
			button = sidebar.add_button(icon, label, tooltip, placement)

	if editor != null:
		editors[editor.name]["buttons"].append(button)
	return button


func can_edit_resource(resource:Resource) -> bool:
	return resource.resource_path.get_extension() in supported_file_extensions


################################################################################
## 						打开/关闭
################################################################################


func _on_editors_tab_changed(tab:int) -> void:
	open_editor(editors_holder.get_child(tab))


func edit_resource(resource:Resource, save_previous:bool = true, silent:= false) -> void:
	if not resource:
		# 资源不存在，显示错误
		print("[Dialogic] 你尝试编辑的资源已不存在。")
		return

	if current_editor and save_previous:
		current_editor._save()

	## 打开正确的编辑器
	var extension: String = resource.resource_path.get_extension()
	for editor in editors.values():
		if editor.get("extension", "") == extension:
			editor["node"]._open_resource(resource)
			if not silent:
				open_editor(editor["node"], false)
	if not silent:
		resource_opened.emit(resource)



## 只有在之前打开过另一个编辑器时才有效
func toggle_editor(editor) -> void:
	if editor.visible:
		open_editor(previous_editor, true)
	else:
		open_editor(editor, true)


## 显示给定的编辑器
func open_editor(editor:DialogicEditor, save_previous: bool = true, extra_info:Variant = null) -> void:
	if current_editor and save_previous:
		current_editor._save()

	if current_editor:
		current_editor._close()
		current_editor.hide()

	if current_editor != previous_editor:
		previous_editor = current_editor

	editor._open(extra_info)
	editor.opened.emit()
	current_editor = editor
	editor.show()
	tabbar.current_tab = editor.get_index()

	save_current_state()
	editor_changed.emit(previous_editor, current_editor)


## 很少使用，用于完全清空一个编辑器。
func clear_editor(editor:DialogicEditor, save:bool = false) -> void:
	if save:
		editor._save()

	editor._clear()


## 显示文件选择器。接受后调用 [accept_callable]
func show_add_resource_dialog(accept_callable:Callable, filter:String = "*", title = "新建资源", default_name = "new_character", mode = EditorFileDialog.FILE_MODE_SAVE_FILE) -> void:
	find_parent("EditorView").godot_file_dialog(
		_on_add_resource_dialog_accepted.bind(accept_callable),
		filter,
		mode,
		title,
		default_name,
		true,
		"角色或时间线名称中不要使用 '\"()!;:/\\*# 这些字符！",
		default_name
	)


func _on_add_resource_dialog_accepted(path:String, callable:Callable) -> void:
	var file_name: String = path.get_file().trim_suffix("."+path.get_extension())
	for i in ["#","&","+",";","(",")","!","*","*",""",""","%", "$", ":",".",","]:
		file_name = file_name.replace(i, "")
	callable.call(path.trim_suffix(path.get_file()).path_join(file_name)+"."+path.get_extension())


## 由 plugin.gd 脚本在 CTRL+S 或开始调试游戏时调用
func save_current_resource() -> void:
	if current_editor:
		current_editor._save()


## 改变资源状态
func _on_resource_saved(_editor:DialogicEditor):
	sidebar.set_unsaved_indicator(true)


## 改变资源状态
func _on_resource_unsaved(_editor:DialogicEditor):
	sidebar.set_unsaved_indicator(false)


## 尝试打开上一次的资源
func load_saved_state() -> void:
	var current_resources: Dictionary = DialogicUtil.get_editor_setting("current_resources", {})
	for editor in current_resources.keys():
		editors[editor]["node"]._open_resource(load(current_resources[editor]))

	var loaded_current_editor: String = DialogicUtil.get_editor_setting("current_editor", "HomePage")
	open_editor(editors[loaded_current_editor]["node"])


func save_current_state() -> void:
	DialogicUtil.set_editor_setting("current_editor", current_editor.name)
	var current_resources: Dictionary = {}
	for editor in editors.values():
		if editor["node"].current_resource != null:
			current_resources[editor["node"].name] = editor["node"].current_resource.resource_path
	DialogicUtil.set_editor_setting("current_resources", current_resources)


func _on_file_moved(old_name:String, new_name:String) -> void:
	if not old_name.get_extension() in supported_file_extensions:
		return

	var used_resources_list = DialogicUtil.get_editor_setting("last_resources", [])
	if old_name in used_resources_list:
		used_resources_list.insert(used_resources_list.find(old_name), new_name)
		used_resources_list.erase(old_name)

	sidebar.update_resource_list(used_resources_list)

	for editor in editors:
		if editors[editor].node.current_resource != null and editors[editor].node.current_resource.resource_path == old_name:
			editors[editor].node.current_resource.take_over_path(new_name)
			edit_resource(load(new_name), true, true)

	save_current_state()


func _on_file_removed(file_name:String) -> void:
	var current_resources: Dictionary = DialogicUtil.get_editor_setting("current_resources", {})
	for editor_name in current_resources:
		if current_resources[editor_name] == file_name:
			clear_editor(editors[editor_name].node, false)
			sidebar.update_resource_list()
			save_current_state()



#region 辅助方法
################################################################################


func get_current_editor() -> DialogicEditor:
	return current_editor
