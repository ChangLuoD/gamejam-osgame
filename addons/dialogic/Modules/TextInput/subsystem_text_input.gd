extends DialogicSubsystem

## 负责显示输入提示的子系统。

## 确认按钮被按下时发出的信号。
@warning_ignore("unused_signal") # 由 DialogTextInput 节点发出
signal input_confirmed(input:String)

signal input_shown(info:Dictionary)


#region 状态
####################################################################################################

func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	hide_text_input()

#endregion


#region 主要方法
####################################################################################################

func show_text_input(text:= "", default:= "", placeholder:= "", allow_empty:= false) -> void:
	for node in get_tree().get_nodes_in_group('dialogic_text_input'):
		node.show()
		if node.has_method('set_allow_empty'): node.set_allow_empty(allow_empty)
		if node.has_method('set_text'): node.set_text(text)
		if node.has_method('set_default'): node.set_default(default)
		if node.has_method('set_placeholder'): node.set_placeholder(placeholder)
	input_shown.emit({'text':text, 'default':default, 'placeholder':placeholder, 'allow_empty':allow_empty})


func hide_text_input() -> void:
	for node in get_tree().get_nodes_in_group('dialogic_text_input'):
		node.hide()

#endregion
