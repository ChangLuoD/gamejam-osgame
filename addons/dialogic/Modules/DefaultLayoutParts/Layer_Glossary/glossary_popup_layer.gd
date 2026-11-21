@tool
extends DialogicLayoutLayer

## 提供一个显示术语表信息的弹出层的图层，
## 当鼠标悬停在文本节点上的术语表条目时显示。


@export_group('文本')
enum Alignment {LEFT, CENTER, RIGHT}
@export var title_alignment: Alignment = Alignment.LEFT
@export var text_alignment: Alignment = Alignment.LEFT
@export var extra_alignment: Alignment = Alignment.RIGHT

@export_subgroup("颜色")
enum TextColorModes {GLOBAL, ENTRY, CUSTOM}
@export var title_color_mode: TextColorModes = TextColorModes.ENTRY
@export var title_custom_color: Color = Color.WHITE
@export var text_color_mode: TextColorModes = TextColorModes.ENTRY
@export var text_custom_color: Color = Color.WHITE
@export var extra_color_mode: TextColorModes = TextColorModes.ENTRY
@export var extra_custom_color: Color = Color.WHITE


@export_group("字体")
@export var font_use_global: bool = true
@export_file('*.ttf', '*.tres') var font_custom: String = ""

@export_subgroup('大小')
@export var font_title_size: int = 18
@export var font_text_size: int = 17
@export var font_extra_size: int = 15


@export_group("方框")
@export_subgroup("颜色")
enum ModulateModes {BASE_COLOR_ONLY, ENTRY_COLOR_ON_BOX, GLOBAL_BG_COLOR}
@export var box_modulate_mode: ModulateModes = ModulateModes.ENTRY_COLOR_ON_BOX
@export var box_base_modulate: Color = Color.WHITE
@export_subgroup("大小")
@export var box_width: int = 200

const MISSING_INDEX := -1
func get_pointer() -> Control:
	return $Pointer


func get_title() -> Label:
	return %Title


func get_text() -> RichTextLabel:
	return %Text


func get_extra() -> RichTextLabel:
	return %Extra


func get_panel() -> PanelContainer:
	return %Panel


func get_panel_point() -> PanelContainer:
	return %PanelPoint


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	get_pointer().hide()
	var text_system: Node = DialogicUtil.autoload().get(&'Text')
	var _error: int = 0
	_error = text_system.connect(&'animation_textbox_hide', get_pointer().hide)
	_error = text_system.connect(&'meta_hover_started', _on_dialogic_display_dialog_text_meta_hover_started)
	_error = text_system.connect(&'meta_hover_ended', _on_dialogic_display_dialog_text_meta_hover_ended)


## 显示该气泡并填入信息的方法
func _on_dialogic_display_dialog_text_meta_hover_started(meta: String) -> void:
	var entry_info := DialogicUtil.autoload().Glossary.get_entry(meta)

	if entry_info.is_empty():
		return

	get_pointer().show()
	get_title().text = entry_info.title
	get_text().text = entry_info.text
	get_text().text = ['', '[center]', '[right]'][text_alignment] + get_text().text
	get_extra().text = entry_info.extra
	get_extra().text = ['', '[center]', '[right]'][extra_alignment] + get_extra().text
	get_pointer().global_position = get_pointer().get_global_mouse_position()

	if title_color_mode == TextColorModes.ENTRY:
		get_title().add_theme_color_override(&"font_color", entry_info.color)
	if text_color_mode == TextColorModes.ENTRY:
		get_text().add_theme_color_override(&"default_color", entry_info.color)
	if extra_color_mode == TextColorModes.ENTRY:
		get_extra().add_theme_color_override(&"default_color", entry_info.color)

	match box_modulate_mode:
		ModulateModes.ENTRY_COLOR_ON_BOX:
			get_panel().self_modulate = entry_info.color
			get_panel_point().self_modulate = entry_info.color


## 在可见时让气泡保持在鼠标位置的方法
func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var pointer: Control = get_pointer()
	if pointer.visible:
		pointer.global_position = pointer.get_global_mouse_position()


## 隐藏该气泡的方法
func _on_dialogic_display_dialog_text_meta_hover_ended(_meta:String) -> void:
	get_pointer().hide()



func _apply_export_overrides() -> void:
	# 应用字体
	var font: Font
	var global_font_setting: String = get_global_setting(&"font", '')
	if font_use_global and ResourceLoader.exists(global_font_setting):
		font = load(global_font_setting)
	elif ResourceLoader.exists(font_custom):
		font = load(font_custom)

	var title: Label = get_title()
	if font:
		title.add_theme_font_override(&"font", font)
	title.horizontal_alignment = title_alignment as HorizontalAlignment

	# 应用字体与字号
	title.add_theme_font_size_override(&"font_size", font_title_size)
	var labels: Array[RichTextLabel] = [get_text(), get_extra()]
	var sizes: PackedInt32Array = [font_text_size, font_extra_size]
	for i : int in len(labels):
		if font:
			labels[i].add_theme_font_override(&'normal_font', font)

		labels[i].add_theme_font_size_override(&"normal_font_size", sizes[i])
		labels[i].add_theme_font_size_override(&"bold_font_size", sizes[i])
		labels[i].add_theme_font_size_override(&"italics_font_size", sizes[i])
		labels[i].add_theme_font_size_override(&"bold_italics_font_size", sizes[i])
		labels[i].add_theme_font_size_override(&"mono_font_size", sizes[i])


	# 应用文本颜色
	# 这里应用全局颜色或自定义颜色，条目颜色在悬停时应用
	var controls: Array[Control] = [get_title(), get_text(), get_extra()]
	var settings: Array[StringName] = [&'font_color', &'default_color', &'default_color']
	var color_modes: Array[TextColorModes] = [title_color_mode, text_color_mode, extra_color_mode]
	var custom_colors: PackedColorArray = [title_custom_color, text_custom_color, extra_custom_color]
	for i : int in len(controls):
		match color_modes[i]:
			TextColorModes.GLOBAL:
				controls[i].add_theme_color_override(settings[i], get_global_setting(&'font_color', custom_colors[i]) as Color)
			TextColorModes.CUSTOM:
				controls[i].add_theme_color_override(settings[i], custom_colors[i])

	# 应用方框大小
	var panel: PanelContainer = get_panel()
	panel.size.x = box_width
	panel.position.x = -box_width/2.0

	# 应用方框着色
	match box_modulate_mode:
		ModulateModes.BASE_COLOR_ONLY:
			panel.self_modulate = box_base_modulate
			get_panel_point().self_modulate = box_base_modulate
		ModulateModes.GLOBAL_BG_COLOR:
			panel.self_modulate = get_global_setting(&'bg_color', box_base_modulate)
			get_panel_point().self_modulate = get_global_setting(&'bg_color', box_base_modulate)
