extends DialogicSubsystem

## 负责显示对话文本（含文本效果与修饰符）、名称标签和下一句指示器的子系统

#region 信号

## 当到达文本事件或即将显示新的文本段落时发出。
## 提供一个包含以下键的字典：[br]
## [br]
## 键          |   值类型      | 值 [br]
## ----------- | ------------- | ----- [br]
## `text`      | [type String] | 正在显示的文本。[br]
## `character` | [type DialogicCharacter]  | 说出这段文本的角色。[br]
## `portrait`  | [type String] | 角色将要使用的立绘名称。[br]
## `append`    | [type bool]   | 文本是否追加到之前的文本之后。[br]
@warning_ignore("unused_signal") # 由文本事件发出。
signal about_to_show_text(info:Dictionary)
## 当文本事件（或新的文本段落）开始显示时发出。
## 这发生在文本框动画之后，而 [signal about_to_show_text] 在动画之前。
## 提供的字典与 [signal about_to_show_text] 的值相同
@warning_ignore("unused_signal") # 由文本事件发出。
signal text_started(info:Dictionary)
## 当文本逐字显示完毕时。
## 提供包含 text 和 character 键的字典。
signal text_finished(info:Dictionary)
## 当说话者发生变化时发出。
signal speaker_updated(character:DialogicCharacter)
## 当文本框显示或隐藏时发出。
signal textbox_visibility_changed(visible:bool)

## 当文本框出现时发出。
## 可与动画子系统一起使用来实现动画。
## 如果你启动了一个动画，并希望 Dialogic 等它结束再显示文本，
## 请调用 Dialogic.Animations.start_animating()，并在动画完成后调用 Dialogic.animation_finished()。
signal animation_textbox_show
## 当文本框正在隐藏时发出。用法同 [signal animation_textbox_show]。
signal animation_textbox_hide
## 当新的文本开始时发出。用法同 [signal animation_textbox_show]。
signal animation_textbox_new_text

## 当鼠标悬停在任意 DialogText 节点上的元文本时发出。
@warning_ignore("unused_signal") # 这些由 NodeDialogText 发出
signal meta_hover_started(meta:Variant)
## 当鼠标不再悬停在任意 DialogText 节点上的元文本时发出。
@warning_ignore("unused_signal") # 这些由 NodeDialogText 发出
signal meta_hover_ended(meta:Variant)
## 当点击任意 DialogText 节点上的元文本时发出。
@warning_ignore("unused_signal") # 这些由 NodeDialogText 发出
signal meta_clicked(meta:Variant)

#endregion

@export_group("State")
## 当前的对话文本。使用 [method update_dialog_text] 来更改它。
@export var dialog_text := ""
## 当前的对话文本，但其中的变量、修饰符和效果已被解析。
@export var dialog_text_parsed := ""
## 当前说话者的标识符。
@export var speaker_identifier := ""
#@export var textbox_visible := false
@export var reveal_skippable := {"enabled":false, "temp_enabled":false}
@export var text_sub_index := -1
@export var active_textbox := ""

# 用于给名称着色，避免每次都搜索所有角色
var character_colors := {}
var color_regex := RegEx.new()

var text_effects := {}
var parsed_text_effect_info: Array[Dictionary] = []
var text_effects_regex := RegEx.new()
enum ParserModes {ALL=-1, TEXT_ONLY=0, CHOICES_ONLY=1}
enum TextTypes {DIALOG_TEXT, CHOICE_TEXT}
var text_modifiers := []


## 由 [speed] 效果设置，会乘以字母速度和 [pause] 效果
var _speed_multiplier := 1.0
## 保存纯字母速度（未乘倍数）
var _pure_letter_speed := 0.1
var _letter_speed_absolute := false

var _voice_synced_text := false

var _autopauses := {}

var parse_stack: Array[Dictionary] = []


#region 状态
####################################################################################################

func _ready() -> void:
	dialogic.event_handled.connect(hide_next_indicators)

	_autopauses = {}
	var autopause_data: Dictionary = ProjectSettings.get_setting('dialogic/text/autopauses', {})
	for i in autopause_data.keys():
		_autopauses[RegEx.create_from_string(r"(?<!(\[|\{))["+i+r"](?!([^{}\[\]]*[\]\}]|$))")] = autopause_data[i]


func _post_install() -> void:
	dialogic.Settings.connect_to_change('text_speed', _update_user_speed)

	collect_text_effects()
	collect_text_modifiers()


func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	dialog_text = ""
	dialog_text_parsed = ""
	speaker_identifier = ""
	active_textbox = ""

	textbox_reset_visibility("")
	update_dialog_text("", true)
	update_name_label(null)

	set_text_reveal_skippable(ProjectSettings.get_setting('dialogic/text/initial_text_reveal_skippable', true))


func _load_state(_load_flag := LoadFlags.FULL_LOAD) -> void:
	var extra_state := get_extra_state()
	var textbox_visiblity: Dictionary = extra_state.get("textbox_visibility", {})
	for identifier in textbox_visiblity:
		textbox_update_visibility(textbox_visiblity[identifier], true, identifier)

	update_dialog_text(dialog_text, true)

	var character: DialogicCharacter = get_current_speaker()
	if character:
		update_name_label(character, true)


func _pack_extra_state() -> Dictionary:
	var textbox_visiblity: Dictionary[String, bool] = {}
	for i in get_textboxes(""):
		textbox_visiblity[i.identifier] = i.textbox_root.visible
	return {"textbox_visibility": textbox_visiblity}

#endregion


#region 文本解析
####################################################################################################

## 对文本应用修饰符、效果和着色。
## 使用在 [method load_parse_stack()] 中创建并排序的解析栈。
func parse_text(text:String, type:int=TextTypes.DIALOG_TEXT) -> String:
	if parse_stack.is_empty():
		load_parse_stack()

	for i in parse_stack:
		if i.type != ParserModes.ALL and type != -1 and i.type != type:
			continue
		text = i.method.call(text)

	return text


## 创建并排序一个方法栈，其中的方法接收文本并返回文本。
## 包括：变量、文本修饰符、文本效果、名称自动着色和术语表。
func load_parse_stack() -> void:
	parse_stack.clear()

	if dialogic.has_subsystem('VAR'):
		parse_stack.append(
			{
				"method":dialogic.VAR.parse_variables,
				"type": ParserModes.ALL,
				"order": 30,
			})

	parse_stack.append(
		{
			"method": parse_text_effects,
			"type": ParserModes.TEXT_ONLY,
			"order": 50,
		})
	for i in text_modifiers:
		parse_stack.append(i)
	parse_stack.append(
		{
			"method": color_character_names,
			"type": ParserModes.TEXT_ONLY,
			"order": 90,
		})
	parse_stack.append(
		{
			"method": dialogic.Glossary.parse_glossary,
			"type": ParserModes.TEXT_ONLY,
			"order": 95,
		})

	parse_stack.sort_custom(func(a,b):return a["order"] < b["order"])

#endregion


#region 文本框
################################################################################

## 返回当前存在的、具有给定 [param identifier] 的所有文本框节点；若 [param identifier] 为空则返回全部。
func get_textboxes(identifier:="") -> Array[Node]:
	return get_tree().get_nodes_in_group("dialogic_dialog_text").filter(func(x): return x.identifier == identifier or identifier.is_empty() if "identifier" in x else false)


## 当事件更新所说的文本时，这里可以调整
## 对话文本框的状态。
## 此方法是异步的。
func textbox_update_visibility(visible := true, instant := false, identifier:=active_textbox) -> void:
	if visible:
		await show_textbox(instant, identifier)

		if not dialog_text.is_empty():
			animation_textbox_new_text.emit()

			if dialogic.Animations.is_animating():
				await dialogic.Animations.finished
	else:
		await hide_textbox(instant, identifier)


func textbox_handle_auto_visibility(text: String, identifier:=active_textbox) -> void:
	if get_textboxes(identifier) and get_textboxes(identifier)[0].auto_visibility:
		await textbox_update_visibility(not text.is_empty(), false, identifier)


func textbox_reset_visibility(identifier:=active_textbox) -> void:
	for node:DialogicNode_DialogText in get_textboxes(identifier):
		node.textbox_root.visible = not node.start_hidden


## instant 会跳过信号，从而跳过可能的动画
func show_textbox(instant:=false, identifier:=active_textbox) -> void:
	var emitted := instant
	for text_node in get_textboxes(identifier):
		if not text_node.enabled:
			continue
		if not text_node.textbox_root.visible and not emitted:
			animation_textbox_show.emit()
			text_node.textbox_root.show()
		else:
			text_node.textbox_root.show()
	if dialogic.Animations.is_animating():
		await dialogic.Animations.finished
		textbox_visibility_changed.emit(true)
		emitted = true


## Instant 会跳过信号，从而跳过可能的动画
func hide_textbox(instant:=false, identifier:=active_textbox) -> void:
	var emitted := instant
	if not emitted and not get_textboxes(identifier).is_empty() and get_textboxes(identifier)[0].textbox_root.visible:
		animation_textbox_hide.emit()
		if dialogic.Animations.is_animating():
			await dialogic.Animations.finished
	for text_node in get_textboxes(identifier):
		if text_node.textbox_root.visible and !emitted:
			textbox_visibility_changed.emit(false)
			emitted = true
		text_node.textbox_root.hide()


func is_textbox_visible(identifier:="") -> bool:
	return get_textboxes(identifier).any(func(x): return x.textbox_root.visible)

#endregion


#region 对话文本
################################################################################

## 在所有可见的 DialogText 节点上显示给定文本。
## instant 可用于跳过所有逐字显示过程。
## 如果 additional 为 true，则保留之前的文本。
func update_dialog_text(text: String, instant := false, additional := false, textbox_identifier := active_textbox) -> String:
	update_text_speed()

	if not instant:
		dialogic.current_state = dialogic.States.REVEALING_TEXT

	if additional:
		dialog_text += text
	else:
		dialog_text = text

	for text_node in get_textboxes(textbox_identifier):
		connect_meta_signals(text_node)

		if text_node.enabled and (text_node == text_node.textbox_root or text_node.textbox_root.is_visible_in_tree()):

			if instant:
				text_node.text = text

			else:
				text_node.reveal_text(text, additional)

				if not text_node.finished_revealing_text.is_connected(_on_dialog_text_finished):
					text_node.finished_revealing_text.connect(_on_dialog_text_finished)

			dialog_text_parsed = (text_node as RichTextLabel).get_parsed_text()

	if not additional:
		# 重置速度倍数
		update_text_speed(-1, false, 1)
		# 临时重置自动推进和禁止跳过设置：
		dialogic.Inputs.auto_advance.enabled_until_next_event = false
		dialogic.Inputs.auto_advance.override_delay_for_current_event = -1
		dialogic.Inputs.manual_advance.disabled_until_next_event = false

		set_text_reveal_skippable(true, true)

	return text


func _on_dialog_text_finished() -> void:
	text_finished.emit({"text":dialog_text, "character":speaker_identifier})

#endregion


#region 名字标签
################################################################################

## 更新所有名称标签节点上显示的名称。
## 如果名称发生变化，会发出 [signal speaker_updated] 信号。
func update_name_label(character:DialogicCharacter, force := false):
	var character_id := character.get_identifier() if character else ""

	if force:
		speaker_identifier = character_id
	elif character_id != speaker_identifier:
		speaker_updated.emit(character)
		speaker_identifier = character_id
	else:
		return

	var name_label_text := get_character_name_parsed(character)

	for name_label in get_tree().get_nodes_in_group("dialogic_name_label"):
		name_label.text = name_label_text
		if character:
			if not "use_character_color" in name_label or name_label.use_character_color:
				name_label.self_modulate = character.color
		else:
			name_label.self_modulate = Color(1,1,1,1)


## 解析角色的 display_name，并返回应当渲染的
## 文本。注意角色名称中可能包含变量，
## 因此应调用此函数来求值
## 角色名称中可能存在的任何变量。
func get_character_name_parsed(character:DialogicCharacter) -> String:
	if character:
		var translated_display_name := character.get_display_name_translated()
		if dialogic.has_subsystem("VAR"):
			return dialogic.VAR.parse_variables(translated_display_name)
		else:
			return translated_display_name
	return ""


## 返回当前说话者的 [class DialogicCharacter]。
## 如果没有当前说话者或找不到该说话者，则返回 null。
func get_current_speaker() -> DialogicCharacter:
	return DialogicResourceUtil.get_character_resource(speaker_identifier)


#endregion


#region 下一句指示器
################################################################################

## 尝试显示下一句指示器。这取决于当前事件是否为问题，或是否开启了自动推进。
## 在这些情况下是否显示下一句指示器，可以在 NextIndicator 节点上切换。
func show_next_indicators(question:=false, autoadvance:=false) -> void:
	for next_indicator in get_tree().get_nodes_in_group('dialogic_next_indicator'):
		if next_indicator.enabled:
			if (question and 'show_on_questions' in next_indicator and next_indicator.show_on_questions) or \
			(autoadvance and 'show_on_autoadvance' in next_indicator and next_indicator.show_on_autoadvance) or (!question and !autoadvance):
				next_indicator.show()
		else:
			next_indicator.hide()


## 隐藏所有下一句指示器节点。
func hide_next_indicators(_fake_arg :Variant= null) -> void:
	for next_indicator in get_tree().get_nodes_in_group('dialogic_next_indicator'):
		next_indicator.hide()

#endregion


#region 打字音效心情
################################################################################

## 在所有 TypeSound 节点上加载给定的语音情绪信息。
## 空字典会清除所有 TypeSound 节点上的情绪。
func update_typing_sound_mood(mood := {}) -> void:
	for typing_sound in get_tree().get_nodes_in_group("dialogic_type_sounds"):
		typing_sound.load_overwrite(mood)


## 在所有 TypeSound 节点上加载给定角色的指定情绪（如果存在）。
func update_typing_sound_mood_from_character(character:DialogicCharacter, mood:String) -> void:
	if character.custom_info.get("sound_moods", {}).is_empty():
		update_typing_sound_mood()
	elif mood in character.custom_info.get("sound_moods", {}):
		update_typing_sound_mood(character.custom_info.get("sound_moods", {})[mood])
	else:
		var default_mood : String = character.custom_info.get("sound_mood_default", "")
		update_typing_sound_mood(character.custom_info.get("sound_moods", {}).get(default_mood, {}))

#endregion


#region 文本速度
################################################################################

## 设置文本逐字显示的速度。
## [br][br]
## [param letter_speed] 是单个文本字符
## 出现在文本框上所需的速度。
## [br][br]
## [param absolute] 会强制文本按给定速度显示，忽略
## 用户的文本速度设置。
## [br][br]
## [param _speed_multiplier] 调整文本速度；若设为 -1，
## 该值不会被更新，当前值将保持不变。
## [br][br]
## [param _user_speed] 调整文本速度；若设为 -1，
## 将使用项目设置 'text_speed'。operator
func update_text_speed(letter_speed: float = -1,
		absolute := false,
		speed_multiplier := _speed_multiplier,
		user_speed: float = dialogic.Settings.get_setting('text_speed', 1)) -> void:

	if letter_speed == -1:
		letter_speed = ProjectSettings.get_setting('dialogic/text/letter_speed', 0.01)

	_pure_letter_speed = letter_speed
	_letter_speed_absolute = absolute
	_speed_multiplier = speed_multiplier

	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		if absolute:
			text_node.set_speed(letter_speed)
		else:
			text_node.set_speed(letter_speed * _speed_multiplier * user_speed)


func _update_user_speed(_user_speed:float) -> void:
	update_text_speed(_pure_letter_speed, _letter_speed_absolute)


## 此方法会在有语音播放时，将文本速度同步到
## 语音音频片段的长度。
## 例如，如果语音播放四秒，文本将在该时间后
## 结束显示。
## 此功能会忽略字母上的自动停顿。通过 BBCode 设置的停顿会导致
## 显示不同步。
func set_text_voice_synced(enabled: bool = true) -> void:
	_voice_synced_text = enabled
	update_text_speed()


## 返回是否启用了语音同步文本。
func is_text_voice_synced() -> bool:
	return _voice_synced_text

#endregion


#region 跳过文本展开

## 如果文本正在逐字显示，则跳过（立即完成）它。
## 如果语音正在播放，也会停止语音。
## 除非你想强制执行，否则调用前应先检查 is_text_reveal_skippable()。
func skip_text_reveal() -> void:
	for text_node in get_tree().get_nodes_in_group('dialogic_dialog_text'):
		if text_node.is_visible_in_tree():
			text_node.finish_text()
	if dialogic.has_subsystem('Voice'):
		dialogic.Voice.stop_audio()


## 设置文本是否可跳过。如果 [param temp] 为 true，此处设置会在下一个文本事件时重置。
## 这样可以临时禁用跳过逐字显示的能力。
func set_text_reveal_skippable(skippable:= true, temp:=false) -> void:
	if temp:
		reveal_skippable.temp_enabled = skippable
	else:
		reveal_skippable.enabled = skippable


## 如果当前文本显示应可跳过，则返回 `true`。
func is_text_reveal_skippable() -> bool:
	return reveal_skippable.enabled and reveal_skippable.temp_enabled

#endregion


#region 文本特效与修饰符
####################################################################################################

func collect_text_effects() -> void:
	var text_effect_names := ""
	text_effects.clear()
	for indexer in DialogicUtil.get_indexers(true):
		for effect in indexer._get_text_effects():
			text_effects[effect.command] = {}
			if effect.has('subsystem') and effect.has('method'):
				text_effects[effect.command]['callable'] = Callable(dialogic.get_subsystem(effect.subsystem), effect.method)
			elif effect.has('node_path') and effect.has('method'):
				text_effects[effect.command]['callable'] = Callable(get_node(effect.node_path), effect.method)
			else:
				continue
			text_effect_names += effect.command +"|"
	text_effects_regex.compile("(?<!\\\\)\\[\\s*(?<command>"+text_effect_names.trim_suffix("|")+")\\s*(=\\s*(?<value>.+?)\\s*)?\\]")


## 返回移除了所有文本效果的字符串
## 调用后使用 get_parsed_text_effects() 获取所有效果信息
func parse_text_effects(text:String) -> String:
	parsed_text_effect_info.clear()
	var rtl: RichTextLabel = null
	if get_tree().get_first_node_in_group("dialogic_dialog_text"):
		rtl = get_tree().get_first_node_in_group("dialogic_dialog_text").duplicate()
	else:
		rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
	var position_correction := 0
	var bbcode_correction := 0
	for effect_match in text_effects_regex.search_all(text):
		rtl.text = text.substr(0, effect_match.get_start()-position_correction)
		bbcode_correction = effect_match.get_start()-position_correction-len(rtl.get_parsed_text())
		# 将 [index] = [command, value] 追加到效果字典
		parsed_text_effect_info.append({'index':effect_match.get_start()-position_correction-bbcode_correction, 'execution_info':text_effects[effect_match.get_string('command')], 'value': effect_match.get_string('value').strip_edges()})

		text = text.substr(0,effect_match.get_start()-position_correction)+text.substr(effect_match.get_start()-position_correction+len(effect_match.get_string()))

		position_correction += len(effect_match.get_string())
	text = text.replace('\\[', '[')
	rtl.queue_free()
	return text


func execute_effects(current_index:int, text_node:Control, skipping := false) -> void:
	# 可能需要执行多个效果
	while true:
		if parsed_text_effect_info.is_empty():
			return
		if current_index != -1 and current_index < parsed_text_effect_info[0]['index']:
			return
		var effect: Dictionary = parsed_text_effect_info.pop_front()
		var callable: Callable = effect['execution_info']['callable']
		if is_instance_valid(text_node):
			await callable.call(text_node, skipping, effect['value'])


func collect_text_modifiers() -> void:
	text_modifiers.clear()
	for indexer in DialogicUtil.get_indexers(true):
		for modifier in indexer._get_text_modifiers():
			if modifier.has('subsystem') and modifier.has('method'):
				text_modifiers.append({'method':Callable(dialogic.get_subsystem(modifier.subsystem), modifier.method)})
			elif modifier.has('node_path') and modifier.has('method'):
				text_modifiers.append({'method':Callable(get_node(modifier.node_path), modifier.method)})
			text_modifiers[-1]['type'] = modifier.get('mode', ParserModes.TEXT_ONLY)
			text_modifiers[-1]['order'] = modifier.get('order', 40)


#endregion


#region 自动着色名字
################################################################################

## 返回在角色名称周围插入 [color=#.....] bbcode 之后的文本。
func color_character_names(text:String) -> String:
	if not ProjectSettings.get_setting('dialogic/text/autocolor_names', false):
		return text

	collect_character_names()

	var counter := 0
	for result in color_regex.search_all(text):
		text = text.insert(result.get_start("name")+((9+8+8)*counter), '[color=#' + character_colors[result.get_string('name')].to_html() + ']')
		text = text.insert(result.get_end("name")+9+8+((9+8+8)*counter), '[/color]')
		counter += 1

	return text


func collect_character_names() -> void:
	#如果一开始就没有使用名称自动着色，就完全不要做这件事
	if not ProjectSettings.get_setting("dialogic/text/autocolor_names", false):
		return

	character_colors = {}

	for dch_identifier in DialogicResourceUtil.get_character_directory():
		var character := (DialogicResourceUtil.get_character_resource(dch_identifier) as DialogicCharacter)

		if character.display_name:
			if "{" in character.display_name and "}" in character.display_name:
				character_colors[dialogic.VAR.parse_variables(character.display_name)] = character.color
			else:
				character_colors[character.display_name] = character.color

		for nickname in character.get_nicknames_translated():
			nickname = nickname.strip_edges()
			if nickname:
				if "{" in nickname and "}" in nickname:
					character_colors[dialogic.VAR.parse_variables(nickname)] = character.color
				else:
					character_colors[nickname] = character.color

	if dialogic.has_subsystem("Glossary"):
		dialogic.Glossary.color_overrides.merge(character_colors, true)

	var sorted_keys := character_colors.keys()
	sorted_keys.sort_custom(sort_by_length)

	var character_names := ""
	for key in sorted_keys:
		character_names += r"\Q" + key + r"\E|"

	character_names = character_names.trim_suffix("|")
	color_regex.compile(r"(?<=\W|^)(?<name>" + character_names + r")(?=\W|$)")


func sort_by_length(a:String, b:String) -> bool:
	if a.length() > b.length():
		return true
	return false

#endregion


#region 元信号
####################################################################################################

func connect_meta_signals(text_node: Node) -> void:
	if not text_node.meta_clicked.is_connected(emit_meta_signal):
		text_node.meta_clicked.connect(emit_meta_signal.bind("meta_clicked"))

	if not text_node.meta_hover_started.is_connected(emit_meta_signal):
		text_node.meta_hover_started.connect(emit_meta_signal.bind("meta_hover_started"))

	if not text_node.meta_hover_ended.is_connected(emit_meta_signal):
		text_node.meta_hover_ended.connect(emit_meta_signal.bind("meta_hover_ended"))


func emit_meta_signal(meta:Variant, sig:String) -> void:
	emit_signal(sig, meta)

#endregion


#region 默认文本特效与修饰符
################################################################################

func effect_pause(_text_node:Control, skipped:bool, argument:String) -> void:
	if skipped:
		return

	# We want to ignore pauses if we're skipping.
	if dialogic.Inputs.auto_skip.enabled:
		return

	var text_speed: float = dialogic.Settings.get_setting('text_speed', 1)

	if argument:
		if argument.ends_with('!'):
			await get_tree().create_timer(float(argument.trim_suffix('!'))).timeout

		elif _speed_multiplier != 0 and text_speed != 0:
			await get_tree().create_timer(float(argument) * _speed_multiplier * text_speed).timeout

	elif _speed_multiplier != 0 and text_speed != 0:
		await get_tree().create_timer(0.5 * _speed_multiplier * text_speed).timeout


func effect_speed(_text_node:Control, skipped:bool, argument:String) -> void:
	if skipped:
		return
	if argument:
		update_text_speed(-1, false, float(argument))
	else:
		update_text_speed(-1, false, 1)


func effect_lspeed(_text_node:Control, skipped:bool, argument:String) -> void:
	if skipped:
		return
	if argument:
		if argument.ends_with('!'):
			update_text_speed(float(argument.trim_suffix('!')), true)
		else:
			update_text_speed(float(argument), false)
	else:
		update_text_speed()


func effect_signal(_text_node:Control, _skipped:bool, argument:String) -> void:
	dialogic.text_signal.emit(argument)


func effect_mood(_text_node:Control, _skipped:bool, argument:String) -> void:
	if argument.is_empty(): return
	if get_current_speaker():
		update_typing_sound_mood(
			get_current_speaker().custom_info.get('sound_moods', {}).get(argument, {}))


var modifier_select_regex := RegEx.create_from_string(r"(?<!\\)\<[^\>]+(\/[^\>]*)\>")
var modifier_select_split_regex := RegEx.create_from_string(r"(\[[^\]]*\]|[^\/]|\/\/)+")
func modifier_random_selection(text:String) -> String:
	for replace_mod_match: RegExMatch in modifier_select_regex.search_all(text):
		var string: String = replace_mod_match.get_string().trim_prefix("<").trim_suffix(">")
		var options := []
		for split: RegExMatch in modifier_select_split_regex.search_all(string):
			options.append(split.get_string())
		var item: String = options.pick_random()
		text = text.replace(replace_mod_match.get_string(), item.strip_edges())
	return text


func modifier_break(text:String) -> String:
	return text.replace('[br]', '\n')


func modifier_autopauses(text:String) -> String:
	var absolute: bool = ProjectSettings.get_setting('dialogic/text/absolute_autopauses', false)
	for i in _autopauses.keys():
		var offset := 0
		for result in i.search_all(text):
			if absolute:
				text = text.insert(result.get_end()+offset, '[pause='+str(_autopauses[i])+'!]')
				offset += len('[pause='+str(_autopauses[i])+'!]')
			else:
				text = text.insert(result.get_end()+offset, '[pause='+str(_autopauses[i])+']')
				offset += len('[pause='+str(_autopauses[i])+']')
	return text

#endregion
