@tool
extends Label

# 当节点首次进入场景树时调用。
func _ready() -> void:
	# 作为场景打开时不加载标签设置
	# 以免产生巨大的差异
	if owner.get_parent() is SubViewport:
		return
	label_settings = LabelSettings.new()
	label_settings.font = get_theme_font("doc_italic", "EditorFonts")
	label_settings.font_size = get_theme_font_size('font_size', 'Label')
	label_settings.font_color = get_theme_color("accent_color", "Editor")
