@tool
extends HSplitContainer

## 处理样式编辑器的脚本。


var current_style: DialogicStyle = null

var customization_editor_info := {}

## 当前选中图层的 id。
## "" 表示基础场景。
var current_layer_id := ""

var _minimum_tree_item_height: int

@onready var tree: Tree = %LayerTree

#region 设置项的中文显示名（zh-cn 汉化分支新增）
####### 设置项的中文显示名 #####################################################
# 导出分组与导出属性的名字是脚本里的标识符（分组名还用于截掉属性名前缀），
# 因此保持英文，仅在显示时换成中文。未登记的名字原样使用。

## 导出分组（图层设置顶部的标签页）。
const GROUP_DISPLAY_NAMES := {
	"General": "常规",
	"Global": "全局",
	"Main": "主要",
	"Main ": "主要",
	"State": "状态",
	"Private": "私有",
}

## 导出属性（图层设置里的每一行）。
const SETTING_DISPLAY_NAMES := {
	# 基础布局
	"canvas_layer": "画布层",
	"follow_viewport": "跟随视口",
	"global_bg_color": "全局背景色",
	"global_font_color": "全局字体颜色",
	"global_font_size": "全局字体大小",
	# 全屏背景
	"bg_texture_filter": "背景纹理过滤",
	"bg_texture_repeat": "背景纹理重复",
	# 弹出术语表
	"title_alignment": "标题对齐",
	"text_alignment": "文本对齐",
	"extra_alignment": "附加内容对齐",
	"title_color_mode": "标题颜色模式",
	"title_custom_color": "标题自定义颜色",
	"text_color_mode": "文本颜色模式",
	"text_custom_color": "文本自定义颜色",
	"extra_color_mode": "附加内容颜色模式",
	"extra_custom_color": "附加内容自定义颜色",
	"font_use_global": "使用全局字体",
	"font_title_size": "标题字体大小",
	"font_text_size": "文本字体大小",
	"font_extra_size": "附加内容字体大小",
	"box_modulate_mode": "方框调制模式",
	"box_base_modulate": "方框基础调制",
	"box_width": "方框宽度",
	# 历史记录浮层
	"font_use_global_size": "使用全局字体大小",
	"font_custom_size": "自定义字体大小",
	"font_use_global_fonts": "使用全局字体",
	"show_open_button": "显示打开按钮",
	"show_close_button": "显示关闭按钮",
	"show_all_choices": "显示所有选项",
	"show_join_and_leave": "显示加入与离开",
	"scroll_to_bottom": "滚动到底部",
	"show_name_colors": "显示名字颜色",
	"name_delimeter": "名字分隔符",
	"HistoryItem": "历史条目场景",
	# 带立绘的文本框
	"text_use_global_size": "文本使用全局大小",
	"text_custom_size": "文本自定义大小",
	"text_use_global_color": "文本使用全局颜色",
	"use_global_fonts": "使用全局字体",
	"name_label_color_mode": "名字标签颜色模式",
	"name_label_custom_color": "名字标签自定义颜色",
	"name_label_alignment": "名字标签对齐",
	"name_label_hide_when_no_character": "无角色时隐藏名字标签",
	"name_label_use_global_size": "名字标签使用全局大小",
	"name_label_custom_size": "名字标签自定义大小",
	"name_label_use_global_font": "名字标签使用全局字体",
	"box_modulate_global_color": "方框使用全局颜色",
	"box_modulate_custom_color": "方框自定义颜色",
	"box_size": "方框大小",
	"box_distance": "方框距离",
	"portrait_stretch_factor": "立绘拉伸系数",
	"portrait_position": "立绘位置",
	"portrait_bg_modulate": "立绘背景调制",
	# 气泡图层
	"text_size": "文本大小",
	"text_color": "文本颜色",
	"text_max_width": "文本最大宽度",
	"box_modulate": "方框调制",
	"box_modulate_by_character_color": "按角色颜色调制方框",
	"box_padding": "方框内边距",
	"behaviour_distance": "气泡距离",
	"behaviour_direction": "气泡方向",
	"behaviour_mouse_filter": "鼠标过滤",
	"name_label_enabled": "启用名字标签",
	"name_label_font_size": "名字标签字体大小",
	"name_label_use_character_color": "名字标签使用角色颜色",
	"name_label_color": "名字标签颜色",
	"name_label_box_modulate": "名字标签方框调制",
	"name_label_box_modulate_use_character_color": "名字标签方框使用角色颜色",
	"name_label_padding": "名字标签内边距",
	"name_label_offset": "名字标签偏移",
	"choices_text_size": "选项文本大小",
	"choices_text_color": "选项文本颜色",
	"choices_text_color_hover": "选项文本颜色（悬停）",
	"choices_text_color_focus": "选项文本颜色（聚焦）",
	"choices_text_color_disabled": "选项文本颜色（禁用）",
	"choices_layout_alignment": "选项布局对齐",
	"choices_layout_force_lines": "选项布局强制换行",
	"maximum_choices": "最大选项数",
	# 居中选项
	"font_size_use_global": "使用全局字体大小",
	"font_size_custom": "自定义字体大小",
	"text_color_use_global": "使用全局文本颜色",
	"text_color_custom": "自定义文本颜色",
	"text_color_pressed": "文本颜色（按下）",
	"text_color_hovered": "文本颜色（悬停）",
	"text_color_disabled": "文本颜色（禁用）",
	"text_color_focused": "文本颜色（聚焦）",
	"boxes_v_separation": "选项框垂直间距",
	"boxes_fill_width": "选项框填满宽度",
	"boxes_min_size": "选项框最小尺寸",
	"boxes_offset": "选项框偏移",
	# 立绘图层
	"portrait_size_mode": "立绘尺寸模式",
	# 视觉小说文本框
	"text_use_global_font": "文本使用全局字体",
	"box_color_use_global": "方框使用全局颜色",
	"box_color_custom": "方框自定义颜色",
	"box_margin_bottom": "方框底部边距",
	"box_animation_in": "方框入场动画",
	"box_animation_out": "方框出场动画",
	"box_animation_new_text": "方框新文本动画",
	"name_label_use_global_color": "名字标签使用全局颜色",
	"name_label_use_global_font_size": "名字标签使用全局字体大小",
	"name_label_custom_font_size": "名字标签自定义字体大小",
	"name_label_box_use_global_color": "名字标签方框使用全局颜色",
	"name_label_box_offset": "名字标签方框偏移",
	"next_indicator_enabled": "启用下一句指示器",
	"next_indicator_show_on_questions": "问题中显示下一句指示器",
	"next_indicator_show_on_autoadvance": "自动前进时显示下一句指示器",
	"next_indicator_size": "下一句指示器大小",
	"next_indicator_position_offset": "下一句指示器位置偏移",
	"autoadvance_progressbar": "自动前进进度条",
	"typing_sounds_enabled": "启用打字音效",
	"typing_sounds_mode": "打字音效模式",
	"typing_sounds_ignore_characters": "打字音效忽略字符",
	# 字体文件
	"global_font": "全局字体",
	"normal_font": "常规字体",
	"bold_font": "粗体字体",
	"italic_font": "斜体字体",
	"bold_italic_font": "粗斜体字体",
	"italics_font": "斜体字体",
	"bold_italics_font": "粗斜体字体",
	"custom_normal_font": "自定义常规字体",
	"custom_bold_font": "自定义粗体字体",
	"custom_italic_font": "自定义斜体字体",
	"custom_bold_italic_font": "自定义粗斜体字体",
	"font_custom": "自定义字体",
	"font_custom_normal": "自定义常规字体",
	"font_custom_bold": "自定义粗体字体",
	"font_custom_italics": "自定义斜体字体",
	"name_label_font": "名字标签字体",
	"name_label_customfont": "名字标签自定义字体",
	"choices_text_font": "选项文本字体",
	# 样式框与面板
	"box_panel": "方框面板",
	"name_label_box_panel": "名字标签方框面板",
	"boxes_stylebox_normal": "选项框样式（常态）",
	"boxes_stylebox_hovered": "选项框样式（悬停）",
	"boxes_stylebox_pressed": "选项框样式（按下）",
	"boxes_stylebox_disabled": "选项框样式（禁用）",
	"boxes_stylebox_focused": "选项框样式（聚焦）",
	"box_corner_radius": "方框圆角半径",
	"box_wobble_speed": "方框抖动速度",
	"box_wobble_amount": "方框抖动幅度",
	"box_wobble_detail": "方框抖动细节",
	"choices_base_theme": "选项基础主题",
	"choices_custom_button": "选项自定义按钮",
	"bubble_count": "气泡数量",
	"disabled": "禁用",
	"apply_overrides_on_ready": "初始化时应用覆盖",
	# 指示器与音效
	"next_indicator_animation": "下一句指示器动画",
	"next_indicator_texture": "下一句指示器纹理",
	"sounds_volume": "音效音量",
	"sounds_pressed": "按下音效",
	"sounds_hover": "悬停音效",
	"sounds_focus": "聚焦音效",
	"typing_sounds_sounds_folder": "打字音效文件夹",
	"typing_sounds_end_sound": "打字音效结束音",
	"typing_sounds_every_nths_character": "每 N 个字符播放",
	"typing_sounds_pitch": "打字音效音高",
	"typing_sounds_pitch_variance": "打字音效音高浮动",
	"typing_sounds_volume": "打字音效音量",
	"typing_sounds_volume_variance": "打字音效音量浮动",
}

#endregion


func _ready() -> void:
	if owner.get_parent() is SubViewport:
		return

	# 样式设置
	%AddLayerButton.icon = get_theme_icon("Add", "EditorIcons")
	%DeleteLayerButton.icon = get_theme_icon("Remove", "EditorIcons")
	%ReplaceLayerButton.icon = get_theme_icon("Loop", "EditorIcons")
	%MakeCustomButton.icon = get_theme_icon("FileAccess", "EditorIcons")
	%ExpandLayerInfo.icon = get_theme_icon("CodeFoldDownArrow", "EditorIcons")

	%AddLayerButton.get_popup().index_pressed.connect(_on_add_layer_menu_pressed)
	%ReplaceLayerButton.get_popup().index_pressed.connect(_on_replace_layer_menu_pressed)
	%MakeCustomButton.get_popup().index_pressed.connect(_on_make_custom_menu_pressed)
	%LayerTree.item_selected.connect(_on_layer_selected)
	_minimum_tree_item_height = int(DialogicUtil.get_editor_scale() * 32)
	%LayerTree.add_theme_constant_override("icon_max_width", _minimum_tree_item_height)


func load_style(style:DialogicStyle) -> void:
	current_style = style

	if current_style.has_meta("_latest_layer"):
		current_layer_id = str(current_style.get_meta("_latest_layer", ""))
	else:
		current_layer_id = ""

	%AddLayerButton.disabled = style.inherits_anything()
	%ReplaceLayerButton.disabled = style.inherits_anything()
	%MakeCustomButton.disabled = style.inherits_anything()
	%DeleteLayerButton.disabled = style.inherits_anything()

	load_style_layer_list()


func load_style_layer_list() -> void:
	tree.clear()

	var root := tree.create_item()

	var base_layer_info := current_style.get_layer_inherited_info("")
	setup_layer_tree_item(base_layer_info, root)

	for layer_id in current_style.get_layer_inherited_list():
		var layer_info := current_style.get_layer_inherited_info(layer_id)
		var layer_item := tree.create_item(root)
		setup_layer_tree_item(layer_info, layer_item)

	select_layer(current_layer_id)


func select_layer(id:String) -> void:
	if id == "":
		tree.get_root().select(0)
	else:
		for child in tree.get_root().get_children():
			if child.get_meta("id", "") == id:
				child.select(0)
				return


func setup_layer_tree_item(info:Dictionary, item:TreeItem) -> void:
	item.custom_minimum_height = _minimum_tree_item_height

	if %StyleBrowser.is_premade_style_part(info.path):
		if ResourceLoader.exists(%StyleBrowser.premade_scenes_reference[info.path].get("icon", "")):
			item.set_icon(0, load(%StyleBrowser.premade_scenes_reference[info.path].get("icon")))
		item.set_text(0, %StyleBrowser.premade_scenes_reference[info.path].get("display_name", %StyleBrowser.premade_scenes_reference[info.path].get("name", "Layer")))

	else:
		item.set_text(0, clean_scene_name(info.path))
		item.add_button(0, get_theme_icon("PackedScene", "EditorIcons"))
		item.set_button_tooltip_text(0, 0, "打开场景")
	item.set_meta("scene", info.path)
	item.set_meta("id", info.id)


func _on_layer_selected() -> void:
	var item: TreeItem = %LayerTree.get_selected()
	load_layer(item.get_meta("id", ""))


func load_layer(layer_id:=""):
	current_layer_id = layer_id
	current_style.set_meta("_latest_layer", current_layer_id)

	var layer_info := current_style.get_layer_inherited_info(layer_id)

	%SmallLayerPreview.hide()
	if %StyleBrowser.is_premade_style_part(layer_info.get("path", "Unkown Layer")):
		var premade_infos = %StyleBrowser.premade_scenes_reference[layer_info.get("path")]
		%LayerName.text = premade_infos.get("display_name", premade_infos.get("name", "Unknown Layer"))
		%SmallLayerAuthor.text = "作者："+premade_infos.get("author", "")
		%SmallLayerDescription.text = premade_infos.get("description", "")

		if premade_infos.get("preview_image", null) and ResourceLoader.exists(premade_infos.get("preview_image")[0]):
			%SmallLayerPreview.texture = load(premade_infos.get("preview_image")[0])
			%SmallLayerPreview.show()

	else:
		%LayerName.text = clean_scene_name(layer_info.get("path", "Unkown Layer"))
		%SmallLayerAuthor.text = "自定义图层"
		%SmallLayerDescription.text = layer_info.get("path", "Unkown Layer")

	%DeleteLayerButton.disabled = layer_id == "" or current_style.inherits_anything()

	%SmallLayerScene.text = layer_info.get("path", "Unkown Layer").get_file()
	%SmallLayerScene.tooltip_text = layer_info.get("path", "")

	var inherited_layer_info := current_style.get_layer_inherited_info(layer_id, true)
	load_layout_scene_customization(
			layer_info.path,
			layer_info.overrides,
			inherited_layer_info.overrides)



func add_layer(scene_path:="", overrides:= {}):
	current_style.add_layer(scene_path, overrides)
	load_style_layer_list()
	await get_tree().process_frame
	%LayerTree.get_root().get_child(-1).select(0)


func delete_layer() -> void:
	if current_layer_id == "":
		return

	current_style.delete_layer(current_layer_id)
	load_style_layer_list()
	%LayerTree.get_root().select(0)


func move_layer(from_idx:int, to_idx:int) -> void:
	current_style.move_layer(from_idx, to_idx)

	load_style_layer_list()
	select_layer(current_style.get_layer_id_at_index(to_idx))


func replace_layer(layer_id:String, scene_path:String) -> void:
	current_style.set_layer_scene(layer_id, scene_path)

	load_style_layer_list()
	select_layer(layer_id)


func _on_add_layer_menu_pressed(index:int) -> void:
	# 添加预设图层
	if index == 2:
		%StyleBrowserWindow.popup_centered_ratio(0.6)
		%StyleBrowser.current_type = 2
		%StyleBrowser.load_parts()
		var picked_info: Dictionary = await %StyleBrowserWindow.get_picked_info()
		if not picked_info.is_empty():
			add_layer(picked_info.get("path", ""))

	# 将自定义场景添加为图层
	else:
		find_parent("EditorView").godot_file_dialog(
			_on_add_custom_layer_file_selected,
			"*.tscn, 场景",
			EditorFileDialog.FILE_MODE_OPEN_FILE,
			"打开自定义图层场景")


func _on_replace_layer_menu_pressed(index:int) -> void:
	# 添加预设图层
	if index == 2:
		%StyleBrowserWindow.popup_centered_ratio(0.6)
		if %LayerTree.get_selected() == %LayerTree.get_root():
			%StyleBrowser.current_type = 3
		else:
			%StyleBrowser.current_type = 2
		%StyleBrowser.load_parts()
		var picked_info: Dictionary = await %StyleBrowserWindow.get_picked_info()
		if not picked_info.is_empty():
			replace_layer(%LayerTree.get_selected().get_meta("id", ""), picked_info.get("path", ""))

	# 将自定义场景添加为图层
	else:
		find_parent("EditorView").godot_file_dialog(
			_on_replace_custom_layer_file_selected,
			"*.tscn, 场景",
			EditorFileDialog.FILE_MODE_OPEN_FILE,
			"打开自定义图层场景")


func _on_add_custom_layer_file_selected(file_path:String) -> void:
	add_layer(file_path)


func _on_replace_custom_layer_file_selected(file_path:String) -> void:
	replace_layer(%LayerTree.get_selected().get_meta("id", ""), file_path)


func _on_make_custom_button_about_to_popup() -> void:
	%MakeCustomButton.get_popup().set_item_disabled(2, false)
	%MakeCustomButton.get_popup().set_item_disabled(3, false)

	if not %StyleBrowser.is_premade_style_part(current_style.get_layer_info(current_layer_id).path):
		%MakeCustomButton.get_popup().set_item_disabled(2, true)


func _on_make_custom_menu_pressed(index:int) -> void:
	# 仅此图层
	if index == 2:
		find_parent("EditorView").godot_file_dialog(
			_on_make_custom_layer_file_selected,
			"",
			EditorFileDialog.FILE_MODE_OPEN_DIR,
			"选择用于存放图层副本的文件夹")
	# 整个布局
	if index == 3:
		find_parent("EditorView").godot_file_dialog(
			_on_make_custom_layout_file_selected,
			"",
			EditorFileDialog.FILE_MODE_OPEN_DIR,
			"选择用于存放新布局场景的文件夹")


func _on_make_custom_layer_file_selected(file:String) -> void:
	make_layer_custom(file)


func _on_make_custom_layout_file_selected(file:String) -> void:
	make_layout_custom(file)


func make_layer_custom(target_folder:String, custom_name := "") -> void:
	var original_file: String = current_style.get_layer_info(current_layer_id).path
	var custom_new_folder := ""

	if custom_name.is_empty():
		custom_name = "custom_"+%StyleBrowser.premade_scenes_reference[original_file].name.to_snake_case()
		custom_new_folder = %StyleBrowser.premade_scenes_reference[original_file].name.to_pascal_case()

	var result_path := DialogicUtil.make_file_custom(
		original_file,
		target_folder,
		custom_name,
		custom_new_folder,
		)

	current_style.set_layer_scene(current_layer_id, result_path)

	load_style_layer_list()

	if %LayerTree.get_selected() == %LayerTree.get_root():
		%LayerTree.get_root().select(0)
	else:
		%LayerTree.get_root().get_child(%LayerTree.get_selected().get_index()).select(0)


func make_layout_custom(target_folder:String) -> void:
	target_folder = target_folder.path_join("Custom" + current_style.name.to_pascal_case())

	DirAccess.make_dir_absolute(target_folder)
	%LayerTree.get_root().select(0)
	make_layer_custom(target_folder, "custom_" + current_style.name.to_snake_case())

	var base_layer_info := current_style.get_layer_info("")
	var target_path: String = base_layer_info.path

	# 加载基础场景
	var base_scene_pck: PackedScene = load(base_layer_info.path).duplicate()
	var base_scene := base_scene_pck.instantiate()
	base_scene.name = "Custom" + clean_scene_name(base_scene_pck.resource_path).to_pascal_case()

	var pckd_scn := PackedScene.new()
	pckd_scn.take_over_path(target_path)

	# 加载图层
	for layer_id in current_style.get_layer_inherited_list():
		var layer_info := current_style.get_layer_inherited_info(layer_id)

		if not ResourceLoader.exists(layer_info.path):
			continue

		var layer_scene: DialogicLayoutLayer = load(layer_info.path).instantiate()

		base_scene.add_layer(layer_scene)
		layer_scene.owner = base_scene
		layer_scene.apply_overrides_on_ready = true

		# 应用图层覆盖
		DialogicUtil.apply_scene_export_overrides(layer_scene, layer_info.overrides, false)

	pckd_scn.pack(base_scene)
	ResourceSaver.save(pckd_scn, target_path)

	current_style.clear()
	current_style.set_layer_scene("", target_path)
	current_style.changed.emit()

	ResourceSaver.save(current_style)

	load_style_layer_list()

	%LayerTree.get_root().select(0)
	EditorInterface.get_resource_filesystem().scan_sources()



func _on_delete_layer_button_pressed() -> void:
	delete_layer()


#region 图层设置
####### 图层设置 #########################################################

func load_layout_scene_customization(custom_scene_path:String, overrides:Dictionary = {}, inherited_overrides:Dictionary = {}) -> void:
	for child in %LayerSettingsTabs.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()

	var scene: Node = null
	if !custom_scene_path.is_empty() and ResourceLoader.exists(custom_scene_path):
		var pck_scn := load(custom_scene_path)
		if pck_scn:
			scene = pck_scn.instantiate()

	var settings := []
	if scene and scene.script:
		settings = collect_settings(scene.script.get_script_property_list())

	if settings.is_empty():
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = "该图层没有暴露任何设置。"
		if not %StyleBrowser.is_premade_style_part(custom_scene_path):
			note.text += "\n\n如果要添加设置，请确保根脚本处于 @tool 模式，并暴露一些 @exported 变量，它们才会显示在这里。"
		note.theme_type_variation = "DialogicHintText2"
		%LayerSettingsTabs.add_child(note)
		note.name = "General"
		return

	var current_grid: GridContainer = null

	var label_bg_style := get_theme_stylebox("CanvasItemInfoOverlay", "EditorStyles").duplicate()
	label_bg_style.content_margin_left = 5
	label_bg_style.content_margin_right = 5
	label_bg_style.content_margin_top = 5

	var current_group_name := ""
	var current_subgroup_name := ""
	customization_editor_info = {}

	for i in settings:
		match i["id"]:
			&"GROUP":
				var main_scroll := ScrollContainer.new()
				main_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
				main_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				main_scroll.name = i.get("display_name", i["name"])
				%LayerSettingsTabs.add_child(main_scroll, true)

				current_grid = GridContainer.new()
				current_grid.columns = 3
				current_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				main_scroll.add_child(current_grid)
				current_group_name = i["name"].to_snake_case()
				current_subgroup_name = ""

			&"SUBGROUP":
				# 添加分隔符
				if current_subgroup_name:
					current_grid.add_child(HSeparator.new())
					current_grid.get_child(-1).add_theme_constant_override("separation", 20)
					current_grid.add_child(current_grid.get_child(-1).duplicate())
					current_grid.add_child(current_grid.get_child(-1).duplicate())

				var title_label := Label.new()
				title_label.text = i.get("display_name", i["name"])
				title_label.theme_type_variation = "DialogicSection"
				title_label.size_flags_horizontal = SIZE_EXPAND_FILL
				current_grid.add_child(title_label, true)

				# 在网格中添加间隔
				current_grid.add_child(Control.new())
				current_grid.add_child(Control.new())

				current_subgroup_name = i["name"].to_snake_case()

			&"SETTING":
				var label := Label.new()
				label.text = str(SETTING_DISPLAY_NAMES.get(i["name"], str(i["name"].trim_prefix(current_group_name+"_").trim_prefix(current_subgroup_name+"_")).capitalize()))
				current_grid.add_child(label, true)

				var scene_value: Variant = scene.get(i["name"])
				customization_editor_info[i["name"]] = {}

				if i["name"] in inherited_overrides:
					customization_editor_info[i["name"]]["orig"] = str_to_var(inherited_overrides.get(i["name"]))
				else:
					customization_editor_info[i["name"]]["orig"] = scene_value

				var current_value: Variant
				if i["name"] in overrides:
					current_value = str_to_var(overrides.get(i["name"]))
				else:
					current_value = customization_editor_info[i["name"]]["orig"]

				var input: Node = DialogicUtil.setup_script_property_edit_node(i, current_value, set_export_override)

				input.size_flags_horizontal = SIZE_EXPAND_FILL
				customization_editor_info[i["name"]]["node"] = input

				var reset := Button.new()
				reset.flat = true
				reset.icon = get_theme_icon("Reload", "EditorIcons")
				reset.tooltip_text = "移除自定义"
				customization_editor_info[i["name"]]["reset"] = reset
				reset.disabled = current_value == customization_editor_info[i["name"]]["orig"]
				current_grid.add_child(reset)
				reset.pressed.connect(_on_export_override_reset.bind(i["name"]))
				current_grid.add_child(input)

	if scene:
		scene.queue_free()


func collect_settings(properties:Array[Dictionary]) -> Array[Dictionary]:
	var settings: Array[Dictionary] = []

	var current_group := {}
	var current_subgroup := {}

	for i in properties:
		if i["usage"] & PROPERTY_USAGE_CATEGORY == PROPERTY_USAGE_CATEGORY:
			continue

		if i["usage"] & PROPERTY_USAGE_GROUP == PROPERTY_USAGE_GROUP:
			current_group = i
			current_group["added"] = false
			current_group["id"] = &"GROUP"
			current_group["display_name"] = GROUP_DISPLAY_NAMES.get(current_group["name"], current_group["name"])
			current_subgroup = {}

		elif i["usage"] & PROPERTY_USAGE_SUBGROUP == PROPERTY_USAGE_SUBGROUP:
			current_subgroup = i
			current_subgroup["added"] = false
			current_subgroup["id"] = &"SUBGROUP"
			current_subgroup["display_name"] = GROUP_DISPLAY_NAMES.get(current_subgroup["name"], current_subgroup["name"])

		elif i["usage"] & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR:
			if current_group.get("name", "") == "Private":
				continue

			if current_group.is_empty():
				current_group = {"name":"General", "added":false, "id":&"GROUP", "display_name":GROUP_DISPLAY_NAMES.get("General", "General")}

			if current_group.get("added", true) == false:
				settings.append(current_group)
				current_group["added"] = true

			if current_subgroup.is_empty():
				current_subgroup = {"name":current_group["name"], "added":false, "id":&"SUBGROUP", "display_name":current_group.get("display_name", current_group["name"])}

			if current_subgroup.get("added", true) == false:
				settings.append(current_subgroup)
				current_subgroup["added"] = true

			i["id"] = &"SETTING"
			settings.append(i)
	return settings


func set_export_override(property_name:String, value:String = "") -> void:
	if str_to_var(value) != customization_editor_info[property_name]["orig"]:
		current_style.set_layer_setting(current_layer_id, property_name, value)
		customization_editor_info[property_name]["reset"].disabled = false
	else:
		current_style.remove_layer_setting(current_layer_id, property_name)
		customization_editor_info[property_name]["reset"].disabled = true


func _on_export_override_reset(property_name:String) -> void:
	current_style.remove_layer_setting(current_layer_id, property_name)
	customization_editor_info[property_name]["reset"].disabled = true
	var node: Node = customization_editor_info[property_name]["node"]
	DialogicUtil.set_property_edit_node_value(node, customization_editor_info[property_name]["orig"])


#endregion


func _on_expand_layer_info_pressed() -> void:
	if %LayerInfoBody.visible:
		%LayerInfoBody.hide()
		%ExpandLayerInfo.icon = get_theme_icon("CodeFoldedRightArrow", "EditorIcons")
	else:
		%LayerInfoBody.show()
		%ExpandLayerInfo.icon = get_theme_icon("CodeFoldDownArrow", "EditorIcons")


func _on_layer_tree_layer_moved(from: int, to: int) -> void:
	move_layer(from, to)


func _on_layer_tree_button_clicked(item: TreeItem, _column: int, _id: int, _mouse_button_index: int) -> void:
	if ResourceLoader.exists(item.get_meta("scene")):
		EditorInterface.open_scene_from_path(item.get_meta("scene"))
		EditorInterface.set_main_screen_editor("2D")


#region 辅助方法
####### 辅助函数 ################################################################

func clean_scene_name(file_path:String) -> String:
	return file_path.get_file().trim_suffix(".tscn").capitalize()

#endregion
