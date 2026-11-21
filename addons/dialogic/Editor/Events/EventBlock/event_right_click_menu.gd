@tool
extends PopupMenu

var current_event: Node = null

func _ready() -> void:
	if owner.get_parent() is SubViewport:
		return
	clear()
	add_icon_item(get_theme_icon("Duplicate", "EditorIcons"), "复制", 0)
	add_separator()
	add_icon_item(get_theme_icon("PlayStart", "EditorIcons"), "从此处播放", 1)
	add_separator()
	add_icon_item(get_theme_icon("Help", "EditorIcons"), "文档", 2)
	add_icon_item(get_theme_icon("CodeHighlighter", "EditorIcons"), "打开代码", 3)
	add_separator()
	add_icon_item(get_theme_icon("ArrowUp", "EditorIcons"), "上移", 4)
	add_icon_item(get_theme_icon("ArrowDown", "EditorIcons"), "下移", 5)
	add_separator()
	add_icon_item(get_theme_icon("Remove", "EditorIcons"), "删除", 6)

	var menu_background := StyleBoxFlat.new()
	menu_background.bg_color = get_parent().get_theme_color("base_color", "Editor")
	add_theme_stylebox_override("panel", menu_background)
	add_theme_stylebox_override("hover", get_theme_stylebox("FocusViewport", "EditorStyles"))
