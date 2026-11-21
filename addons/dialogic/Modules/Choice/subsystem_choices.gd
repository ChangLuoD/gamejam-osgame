extends DialogicSubsystem

## 负责显示与激活选项的子系统。

## 当某个选项按钮被按下时发出。Info 中包含 'button_index'、'text'、'event_index' 这些键。
signal choice_selected(info:Dictionary)
## 当到达并显示一组选项时发出。
## Info 中包含 'choices' 键（一个字典数组，包含所有选项的信息）。
signal question_shown(info:Dictionary)
## 当到达的问题没有可用选项时发出（全部被隐藏或禁用）。
signal invalid_question_reached

## 包含最近一个问题的信息。内容说明见 [method get_current_question_info]。
var last_question_info := {}

## 文本显示完毕到选项出现之间的延迟
var reveal_delay := 0.0
## 为 true 时，玩家必须点击才能让到达的选项显示出来
var reveal_by_input := false
## 选项从可见到可点击之间的延迟。可以防止误选。
var block_delay := 0.2
## 为 true 时，第一个（最上面的）选项会被聚焦
var autofocus_first_choice := true
## 为 true 时，使用 Dialogic 输入动作来触发选项。
## 但无论如何，鼠标事件都会被忽略。
var use_input_action := false

enum FalseBehaviour {HIDE=0, DISABLE=1}
## 条件为假且 else_action 设为 DEFAULT 的选项的行为。
var default_false_behaviour := FalseBehaviour.HIDE

enum HotkeyBehaviour {NONE, NUMBERS}
## 如果不为 HotkeyBehaviour.NONE，则会为选项添加一些快捷键。
var hotkey_behaviour := HotkeyBehaviour.NONE

enum InvalidChoiceBehaviour {NOTHING, AUTO_SKIP}
var invalid_choice_behaviour := InvalidChoiceBehaviour.AUTO_SKIP
### 内部实现

## 用于在若干秒内阻止选项被点击（如果在设置里配置了延迟）。
var _choice_blocker := Timer.new()

#region 状态
####################################################################################################

func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	hide_all_choices()


func _ready() -> void:
	_choice_blocker.one_shot = true
	DialogicUtil.update_timer_process_callback(_choice_blocker)
	add_child(_choice_blocker)

	reveal_delay = float(ProjectSettings.get_setting('dialogic/choices/reveal_delay', reveal_delay))
	reveal_by_input = ProjectSettings.get_setting('dialogic/choices/reveal_by_input', reveal_by_input)
	block_delay = ProjectSettings.get_setting('dialogic/choices/delay', block_delay)
	autofocus_first_choice = ProjectSettings.get_setting('dialogic/choices/autofocus_first', autofocus_first_choice)
	use_input_action = ProjectSettings.get_setting('dialogic/choices/use_input_action', use_input_action)
	hotkey_behaviour = ProjectSettings.get_setting('dialogic/choices/hotkey_behaviour', hotkey_behaviour)
	default_false_behaviour = ProjectSettings.get_setting('dialogic/choices/def_false_behaviour', default_false_behaviour)


func _post_install() -> void:
	dialogic.Inputs.dialogic_action.connect(_on_dialogic_action)

#endregion


#region 主要方法
####################################################################################################

## 隐藏所有选项按钮。
func hide_all_choices() -> void:
	for node in get_tree().get_nodes_in_group('dialogic_choice_button'):
		node.hide()
		if node.choice_selected.is_connected(_on_choice_selected):
			node.choice_selected.disconnect(_on_choice_selected)


## 收集当前问题（一组选项）中所有选项的信息。
## 结果是一个这样的字典：
## {'choices':
##	[
##		{'event_index':10, 'button_index':1, 'disabled':false, 'text':"My Choice", 'visible':true},
##		{'event_index':15, 'button_index':2, 'disabled':false, 'text':"My Choice2", 'visible':true},
##	]
## 'invalid':false # 如果所有选项都不可见或被禁用则为 true
## }
func get_current_question_info() -> Dictionary:
	var question_info := {'choices':[]}

	var button_idx := 1
	var any_valid := false
	for choice_index in get_current_choice_indexes():
		var event: DialogicEvent = dialogic.current_timeline_events[choice_index]

		if not event is DialogicChoiceEvent:
			continue

		var choice_event: DialogicChoiceEvent = event
		var choice_info := {}
		choice_info['event_index'] = choice_index
		choice_info['button_index'] = button_idx

		# 检查条件
		var condition: String = choice_event.condition

		if condition.is_empty() or dialogic.Expressions.execute_condition(choice_event.condition):
			any_valid = true
			choice_info['disabled'] = false
			choice_info['text'] = choice_event.get_property_translated('text')
			choice_info['visible'] = true
			button_idx += 1
		else:
			choice_info['disabled'] = true
			if not choice_event.disabled_text.is_empty():
				choice_info['text'] = choice_event.get_property_translated('disabled_text')
			else:
				choice_info['text'] = choice_event.get_property_translated('text')

			var hide := choice_event.else_action == DialogicChoiceEvent.ElseActions.HIDE
			hide = hide or choice_event.else_action == DialogicChoiceEvent.ElseActions.DEFAULT and default_false_behaviour == DialogicChoiceEvent.ElseActions.HIDE
			choice_info['visible'] = not hide

			if not hide:
				button_idx += 1

		choice_info.text = dialogic.Text.parse_text(choice_info.text, 1)

		choice_info.merge(choice_event.extra_data)

		if dialogic.has_subsystem('History'):
			choice_info['visited_before'] = dialogic.History.has_event_been_visited(choice_index)

		question_info['choices'].append(choice_info)

	question_info["invalid"] = not any_valid
	return question_info


## 列出当前所有选项并显示按钮。
func show_current_question(instant:=true) -> void:
	hide_all_choices()
	_choice_blocker.stop()
	last_question_info = get_current_question_info()

	if !instant and (reveal_delay != 0 or reveal_by_input):
		if reveal_delay != 0:
			_choice_blocker.start(reveal_delay)
			_choice_blocker.timeout.connect(show_current_question)
		if reveal_by_input:
			dialogic.Inputs.dialogic_action.connect(show_current_question)
		return

	if _choice_blocker.timeout.is_connected(show_current_question):
		_choice_blocker.timeout.disconnect(show_current_question)
	if dialogic.Inputs.dialogic_action.is_connected(show_current_question):
		dialogic.Inputs.dialogic_action.disconnect(show_current_question)

	var missing_button := false

	var question_info := get_current_question_info()

	for choice in question_info.choices:
		var node: DialogicNode_ChoiceButton = get_choice_button(choice.button_index)

		if not node:
			missing_button = true
			continue

		node._load_info(choice)


		if choice.button_index == 1 and autofocus_first_choice:
			node.grab_focus()

		match hotkey_behaviour:
			## 如果启用，则把 1 到 9 添加为快捷键
			HotkeyBehaviour.NUMBERS:
				if choice.button_index > 0 or choice.button_index < 10:
					var shortcut: Shortcut
					if node.shortcut != null:
						shortcut = node.shortcut
					else:
						shortcut = Shortcut.new()

					var input_key := InputEventKey.new()
					input_key.keycode = OS.find_keycode_from_string(str(choice.button_index))
					shortcut.events.append(input_key)
					node.shortcut = shortcut

		if node.choice_selected.is_connected(_on_choice_selected):
			node.choice_selected.disconnect(_on_choice_selected)
		node.choice_selected.connect(_on_choice_selected.bind(choice))

	_choice_blocker.start(block_delay)
	question_shown.emit(question_info)
	if question_info.invalid:
		invalid_question_reached.emit()
		printerr("[Dialogic] 到达了无效的问题（所有选项都被禁用或不可见）。")
		dialogic.print_debug_moment()
		if invalid_choice_behaviour == InvalidChoiceBehaviour.AUTO_SKIP:
			skip_question()

	# TODO 调查如何在选项可见时跳转到别处后隐藏它们。
	# 文本输入事件可能也有同样的问题

	if missing_button:
		printerr("[Dialogic] 你使用的布局没有足够的选项按钮来显示你尝试展示的选项。")



## 跳到当前问题的末尾。
func skip_question() -> void:
	if not last_question_info:
		return
	hide_all_choices()
	dialogic.current_state = dialogic.States.IDLE
	dialogic.current_event_idx = dialogic.current_timeline.get_event(last_question_info.choices[0].event_index).get_end_branch_index()-1
	dialogic.handle_next_event()


func focus_choice(button_index:int) -> void:
	var node: DialogicNode_ChoiceButton = get_choice_button(button_index)
	if node:
		node.grab_focus()


func select_choice(button_index:int) -> void:
	var node: DialogicNode_ChoiceButton = get_choice_button(button_index)
	if node:
		node.choice_selected.emit()


func select_focused_choice() -> void:
	if get_viewport().gui_get_focus_owner() is DialogicNode_ChoiceButton:
		(get_viewport().gui_get_focus_owner() as DialogicNode_ChoiceButton).choice_selected.emit()


func get_choice_button(button_index:int) -> DialogicNode_ChoiceButton:
	var idx := 1
	for node: DialogicNode_ChoiceButton in get_tree().get_nodes_in_group('dialogic_choice_button'):
		if !node.get_parent().is_visible_in_tree():
			continue
		if node.choice_index == button_index or (node.choice_index == -1 and idx == button_index):
			return node

		if node.choice_index > 0:
			idx = node.choice_index
		idx += 1
	return null


func _on_choice_selected(choice_info := {}) -> void:
	if dialogic.paused or not _choice_blocker.is_stopped():
		return

	if dialogic.has_subsystem('History'):
		var all_choices: Array = last_question_info['choices']
		if dialogic.has_subsystem('VAR'):
			dialogic.History.store_simple_history_entry(dialogic.VAR.parse_variables(choice_info.text), "Choice", {'all_choices': all_choices})
		else:
			dialogic.History.store_simple_history_entry(choice_info.text, "Choice", {'all_choices': all_choices})
		if dialogic.has_subsystem("History"):
			dialogic.History.mark_event_as_visited(choice_info.event_index)

	choice_selected.emit(choice_info)
	hide_all_choices()
	dialogic.current_state = dialogic.States.IDLE
	dialogic.handle_event(choice_info.event_index + 1)


## 返回与当前问题相关的选项事件的索引。
func get_current_choice_indexes() -> Array:
	var choices := []
	var index := dialogic.current_event_idx-1
	while true:
		index += 1
		if index >= len(dialogic.current_timeline_events):
			break

		var event: DialogicEvent = dialogic.current_timeline_events[index]
		if event is DialogicChoiceEvent:
			choices.append(index)
			index = event.get_end_branch_index()
		else:
			break

	return choices


## 把 Dialogic 动作转发给已聚焦的按钮
func _on_dialogic_action() -> void:
	if use_input_action and not dialogic.Inputs.input_was_mouse_input:
		select_focused_choice()


#endregion


#region 辅助方法
####################################################################################################

## 如果给定索引是问题之前的文本事件，或是某个问题的第一个选项事件，则返回 `true`。
func is_question(index:int) -> bool:
	var event: DialogicEvent = dialogic.current_timeline_events[index]
	if event is DialogicTextEvent:
		if len(dialogic.current_timeline_events)-1 != index:
			var next_event: DialogicEvent = dialogic.current_timeline_events[index+1]
			if next_event is DialogicChoiceEvent:
				return true

	if event is DialogicChoiceEvent:
		if index == 0:
			return true
		var prev_event: DialogicEvent = dialogic.current_timeline_events[index-1]
		if not prev_event is DialogicEndBranchEvent:
			return true
		var prev_event_opener: DialogicEvent = dialogic.current_timeline_events[prev_event.get_opening_index()]
		if prev_event_opener is DialogicChoiceEvent:
			return false
		else:
			return true

	return false

#endregion
