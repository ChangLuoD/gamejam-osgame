@tool
extends Window

## 该窗口负责与其内部的替换管理器通信。
## 其他脚本可以调用 add_ref_change() 方法直接登记改动，
##   或使用辅助方法 add_variable_ref_change() 与 add_portrait_ref_change()

@onready var editors_manager := get_node("../EditorsManager")
@onready var broken_manager := get_node("Manager/Tabs/BrokenReferences")
enum Where {EVERYWHERE, BY_CHARACTER, TEXTS_ONLY}
enum Types {TEXT, VARIABLE, PORTRAIT, CHARACTER_NAME, TIMELINE_NAME}

var icon_button: Button = null


func _ready() -> void:
	if owner.get_parent() is SubViewport:
		return

	$Manager.theme = owner.get_theme()

	icon_button = editors_manager.add_button(
		get_theme_icon("Unlinked", "EditorIcons"),
		"",
		"引用管理器",
		null,
		editors_manager.ButtonPlacement.SIDEBAR_LEFT_OF_FILTER)
	icon_button.pressed.connect(open)

	var dot := Sprite2D.new()
	dot.texture = get_theme_icon("GuiGraphNodePort", "EditorIcons")
	dot.scale = Vector2(0.8, 0.8)
	dot.z_index = 10
	dot.position = Vector2(icon_button.size.x*0.8, icon_button.size.x*0.2)
	dot.modulate = get_theme_color("warning_color", "Editor").lightened(0.5)

	icon_button.add_child(dot)

	var old_changes: Array = DialogicUtil.get_editor_setting('reference_changes', [])
	if !old_changes.is_empty():
		broken_manager.reference_changes = old_changes

	update_indicator()

	hide()

	EditorInterface.get_file_system_dock().files_moved.connect(_on_file_moved)
	EditorInterface.get_file_system_dock().file_removed.connect(_on_file_removed)
	get_parent().get_node('ResourceRenameWarning').confirmed.connect(open)


func add_ref_change(old_name:String, new_name:String, type:Types, where:=Where.TEXTS_ONLY, character_names:=[],
					whole_words:=false, case_sensitive:=false, previous:Dictionary = {}) -> void:
	var regexes := []
	var category_name := ""
	match type:
		Types.TEXT:
			category_name = "Texts"
			if '<replace>' in old_name:
				regexes = [old_name]
			else:
				regexes = [
					r'(?<replace>%s)' % old_name.replace('/', '\\/')
					]
				if !case_sensitive:
					regexes[0] = '(?i)'+regexes[0]
				if whole_words:
					regexes = ['\\b'+regexes[0]+'\\b']

		Types.VARIABLE:
			regexes = [
				r'{(?<replace>\s*%s\s*)}' 			% old_name.replace("/", "\\/"),
				r'var\s*=\s*"(?<replace>\s*%s\s*)"' % old_name.replace("/", "\\/")
				]
			category_name = "Variables"

		Types.PORTRAIT:
			regexes = [
				r'(?m)^[^:(\n]*\((?<replace>%s)\)' 			% old_name.replace('/', '\\/'),
				r'\[\s*portrait\s*=(?<replace>\s*%s\s*)\]' 	% old_name.replace('/', '\\/')
				]
			category_name = "Portraits by "+character_names[0]

		Types.CHARACTER_NAME:
			# for reference: ((join|leave|update) )?(?<replace>NAME)(?!\B)(?(1)|(?!([^:\n]|\\:)*(\n|$)))
			regexes = [
				r'((join|leave|update) )?(?<replace>%s)(?!\B)(?(1)|(?!([^:\n]|\\:)*(\n|$)))' % old_name
				]
			category_name = "Renamed Character Files"

		Types.TIMELINE_NAME:
			regexes = [
				r'timeline ?= ?" ?(?<replace>%s) ?"' % old_name
				]
			category_name = "Renamed Timeline Files"

	if where != Where.BY_CHARACTER:
		character_names = []

	# previous 只有在编辑已有条目时才会传入
	# 这种情况下会先移除旧的那条
	var idx := len(broken_manager.reference_changes)
	if previous in broken_manager.reference_changes:
		idx = broken_manager.reference_changes.find(previous)
		broken_manager.reference_changes.erase(previous)

	if _check_for_ref_change_cycle(old_name, new_name, category_name):
		update_indicator()
		return

	broken_manager.reference_changes.insert(idx,
		{'what':old_name,
		'forwhat':new_name,
		'regex': regexes,
		'regex_replacement':new_name,
		'category':category_name,
		'character_names':character_names,
		'texts_only':where == Where.TEXTS_ONLY,
		'type':type,
		'case_sensitive':case_sensitive,
		'whole_words':whole_words,
		})

	update_indicator()

	if visible:
		$Manager.open()
		broken_manager.open()


## 检查引用是否成环或成链。
## 例如，你先把这个立绘从 "happy" 改名为 "happy1"，再改名为 "Happy/happy1"
## 这样可以保证只记住 "happy" -> "Happy/happy1" 这一次改动
## 这对正确完成替换非常重要
func _check_for_ref_change_cycle(old_name:String, new_name:String, category:String) -> bool:
	for ref in broken_manager.reference_changes:
		if ref['forwhat'] == old_name and ref['category'] == category:
			if new_name == ref['what']:
				broken_manager.reference_changes.erase(ref)
			else:
				broken_manager.reference_changes[broken_manager.reference_changes.find(ref)]['forwhat'] = new_name
				broken_manager.reference_changes[broken_manager.reference_changes.find(ref)]['regex_replacement'] = new_name
			return true
	return false


## 添加变量引用改动的辅助方法
func add_variable_ref_change(old_name:String, new_name:String) -> void:
	add_ref_change(old_name, new_name, Types.VARIABLE, Where.EVERYWHERE)


## 添加立绘引用改动的辅助方法
func add_portrait_ref_change(old_name:String, new_name:String, character_names:PackedStringArray) -> void:
	add_ref_change(old_name, new_name, Types.PORTRAIT, Where.BY_CHARACTER, character_names)


## 添加角色名引用改动的辅助方法
func add_character_name_ref_change(old_name:String, new_name:String) -> void:
	add_ref_change(old_name, new_name, Types.CHARACTER_NAME, Where.EVERYWHERE)


## 添加时间线名引用改动的辅助方法
func add_timeline_name_ref_change(old_name:String, new_name:String) -> void:
	add_ref_change(old_name, new_name, Types.TIMELINE_NAME, Where.EVERYWHERE)


func open() -> void:
	DialogicResourceUtil.update_directory('dch')
	DialogicResourceUtil.update_directory('dtl')
	popup_centered_ratio(0.5)
	grab_focus()


func _on_close_requested() -> void:
	hide()
	broken_manager.close()


func get_change_count() -> int:
	return len(broken_manager.reference_changes)


func update_indicator() -> void:
	icon_button.get_child(0).visible = !broken_manager.reference_changes.is_empty()


## 文件管理：
func _on_file_moved(old_file:String, new_file:String) -> void:
	if old_file.ends_with('.dch') and new_file.ends_with('.dch'):
		DialogicResourceUtil.change_resource_path(old_file, new_file)
		if old_file.get_file() != new_file.get_file():
			get_parent().get_node('ResourceRenameWarning').popup_centered()
	elif old_file.ends_with('.dtl') and new_file.ends_with('.dtl'):
		DialogicResourceUtil.change_resource_path(old_file, new_file)
		if old_file.get_file() != new_file.get_file():
			get_parent().get_node('ResourceRenameWarning').popup_centered()


func _on_file_removed(file:String) -> void:
	if file.get_extension() in ['dch', 'dtl']:
		DialogicResourceUtil.remove_resource(file)
