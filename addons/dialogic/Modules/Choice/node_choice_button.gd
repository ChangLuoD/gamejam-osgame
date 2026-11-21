class_name DialogicNode_ChoiceButton
extends Button
## 此按钮让玩家在 Dialogic 系统中做出选择。
##
## 当遇到选项时，Dialogic 会自动显示 ChoiceButtons 
## 并调用它们的 [code]_load_info()[/code] 方法来显示选项。
## 你需要确保场景树中有足够的选项按钮 
## 来显示所有选项。[br]
## 
## [br]  
## 你可以扩展此节点，并通过重写
## [code]_load_info(info:Dictionary)[/code] 方法来实现一些自定义逻辑。[br]
## [br]
## 若需要富文本支持，可考虑添加一个 RichTextLabel 子节点，并将其设为 [member text_node]。[br]
## 
## [br]
## DialogicChoiceButton 在被悬停时会夺取焦点，以避免 
## 使用鼠标的玩家看到令人困惑的焦点样式。[br]
## 为避免相反的情况——即玩家改变了焦点， 
## 而鼠标仍悬停在另一个按钮上——鼠标指针也会
## 一并移动到当前获得焦点的按钮上。


## 选项被选中时发出。除非被重写，否则即按钮或其快捷键被按下时。
signal choice_selected


## 用于确定把哪些选项放到这个按钮上。若保持 -1，选项将自动分配。
@export var choice_index: int = -1

## 可设置此项，在按下时播放该音效。需要同级的 DialogicNode_ButtonSound 节点。
@export var sound_pressed: AudioStream
## 可设置此项，在鼠标悬停时播放该音效。需要同级的 DialogicNode_ButtonSound 节点。
@export var sound_hover: AudioStream
## 可设置此项，在获得焦点时播放该音效。需要同级的 DialogicNode_ButtonSound 节点。
@export var sound_focus: AudioStream

## 若设置此项，文本将改为设置到该节点的 `text` 属性上。 
## 这可用于使用自定义的文本渲染子节点，例如 RichTextLabel。
@export var text_node: Node


func _ready() -> void:
	add_to_group('dialogic_choice_button')
	shortcut_in_tooltip = false
	hide()
	
	# 对于用鼠标做出选择的玩家，鼠标悬停应当夺取焦点。
	# 否则当鼠标光标悬停在另一个按钮上时，自动获得焦点的那个按钮
	# 会一直显示高亮颜色。
	if not mouse_entered.is_connected(grab_focus):
		mouse_entered.connect(grab_focus)
	if not focus_entered.is_connected(_on_choice_button_focus_entred):
		focus_entered.connect(_on_choice_button_focus_entred.bind(self))


## 自定义选项按钮可重写此方法，以实现选项按钮被按下时的特殊行为。
func _pressed():
	choice_selected.emit()


## 如果自定义选项按钮的行为需要依据事件数据变化，
## 可以重写此方法。如果自定义选项按钮没有重写
## 可见性、禁用状态和选项文本，建议
## 在重写方法的开头调用 super(choice_info)。
##
## choice_info 字典包含以下键：
## - event_index:    该选项事件在时间线中的索引。
## - button_index:   选项的相对索引（从 1 开始）。
## - visible:        该选项是否应可见。
## - disabled:       该选项是否应可被选择。
## - text:           选项的文本。
## - visited_before: 该选项此前是否被选中过。仅在启用历史记录子模块时可用。
## - *:              来自事件额外信息的内容。
func _load_info(choice_info: Dictionary) -> void:
	set_choice_text(choice_info.text)
	visible = choice_info.visible
	disabled = choice_info.disabled


## 文本变化时调用。
func set_choice_text(new_text: String) -> void:
	if text_node:
		text_node.text = new_text
	else:
		text = new_text


## 当焦点变化时，此方法会把鼠标移动到获得焦点的选项上， 
## 前提是此前有选项按钮处于悬停状态。[br]
## 对于同时使用多种设备（鼠标/键盘/手柄等）做出选择的玩家，
## 由键盘/手柄触发的焦点夺取也应改变鼠标光标的
## 位置，否则会有两个按钮显示高亮颜色（一个是
## 由鼠标悬停触发高亮的按钮，另一个是由其他设备的选择触发高亮的按钮）。
func _on_choice_button_focus_entred(focused_button: Button):
	var global_mouse_pos = get_global_mouse_position()
	var focused_button_rect = focused_button.get_global_rect()
	if focused_button_rect.has_point(global_mouse_pos):
		return
	# 仅当未获得焦点的按钮矩形内有光标时，才改变鼠标光标位置。
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		if node is Button:
			if node != focused_button and node.get_global_rect().has_point(global_mouse_pos):
				# 我们倾向于只改变 mouse_position.y 或 mouse_position.x，把
				# 鼠标移动到获得焦点的按钮矩形内，以获得最佳视觉效果。
				var modify_y_pos = Vector2(global_mouse_pos.x, focused_button.get_global_rect().get_center().y)
				if focused_button_rect.has_point(modify_y_pos):
					get_viewport().warp_mouse(modify_y_pos)
					return
					
				var modify_x_pos = Vector2(focused_button.get_global_rect().get_center().x, global_mouse_pos.y)
				if focused_button_rect.has_point(modify_x_pos):
					get_viewport().warp_mouse(modify_x_pos)
					return
					
				# 也许这些按钮并未垂直或水平对齐。
				# 又或者两个按钮之间的长度差过大。
				# 因此我们干脆让光标停在获得焦点的按钮中心。
				get_viewport().warp_mouse(focused_button.get_global_rect().get_center())
				return
