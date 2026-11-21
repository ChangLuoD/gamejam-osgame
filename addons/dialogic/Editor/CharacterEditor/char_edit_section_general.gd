@tool
extends DialogicCharacterEditorMainSection

var min_width := 200

## 角色常规设置面板
func _get_title() -> String:
	return "General"


## 界面显示标题（标识仍保持英文，仅显示用中文）
func _get_display_title() -> String:
	return "常规"


func _start_opened() -> bool:
	return true


func _ready() -> void:
	# 连接所有必需的信号
	%ColorPickerButton.custom_minimum_size.x = DialogicUtil.get_editor_scale() * 30
	%ColorPickerButton.color_changed.connect(character_editor.something_changed)
	%DisplayNameLineEdit.text_changed.connect(character_editor.something_changed)
	%NicknameLineEdit.text_changed.connect(character_editor.something_changed)
	%DescriptionTextEdit.text_changed.connect(character_editor.something_changed)
	min_width = get_minimum_size().x
	resized.connect(_on_resized)

func _load_character(resource:DialogicCharacter) -> void:
	%DisplayNameLineEdit.text = resource.display_name
	%ColorPickerButton.color = resource.color

	%NicknameLineEdit.text = ""
	for nickname in resource.nicknames:
		%NicknameLineEdit.text += nickname +", "
	%NicknameLineEdit.text = %NicknameLineEdit.text.trim_suffix(', ')

	%DescriptionTextEdit.text = resource.description


func _save_changes(resource:DialogicCharacter) -> DialogicCharacter:
	resource.display_name = %DisplayNameLineEdit.text
	resource.color = %ColorPickerButton.color
	var nicknames := []
	for n_name in %NicknameLineEdit.text.split(','):
		nicknames.append(n_name.strip_edges())
	resource.nicknames = nicknames
	resource.description = %DescriptionTextEdit.text

	return resource


func _on_resized() -> void:
	if size.x > min_width+20:
		self.columns = 2
	else:
		self.columns = 1
