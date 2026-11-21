@tool
class_name DialogicTextEvent
extends DialogicEvent

## 存储文本的事件。可由角色说出。
## 应由 DialogicNode_DialogText 显示。


### 设置

## 这是文本事件的内容。
## 它应由 DialogicNode_DialogText 节点显示。
## 这意味着你可以使用 bbcode，也可以使用一些自定义命令。
@export var text := ""
## 若此项不为 null，给定的角色（作为资源）将与该事件关联。
## DialogicNode_NameLabel 会显示角色的 display_name。如果设置了打字音效，
## 就会播放。
@export var character: DialogicCharacter = null
## 如果设置了角色，此设置可以更改该角色的立绘。
## 如果创建的是运行时角色，立绘也可以是一个颜色（十六进制或颜色名）。
@export var portrait := ""

### 辅助

## 用于从唯一名称标识符设置角色资源，或反向获取
var character_identifier: String:
	get:
		if character and not "{" in character_identifier:
			var identifier := character.get_identifier()
			if not identifier.is_empty():
				return identifier
		return character_identifier
	set(value):
		character_identifier = value
		character = DialogicResourceUtil.get_character_resource(value)
		if Engine.is_editor_hint() and ((not character) or (character and not portrait in character.portraits)) and not (not character and (character_identifier or character_identifier.begins_with("{"))):
			portrait = ""
			ui_update_needed.emit()

var regex := RegEx.create_from_string(r'\s*((")?(?<name>(?(2)[^"\n]*|[^(: \n]*))(?(2)"|)(\W*(?<portrait>\(.*\)))?\s*(?<!\\):)?(?<text>(.|\n)*)')
var split_regex := RegEx.create_from_string(r"((\[n\]|\[n\+\])?((?!(\[n\]|\[n\+\]))(.|\n))+)")

enum States {REVEALING, IDLE, DONE}
var state := States.IDLE
signal advance


#region 执行
################################################################################

func _clear_state() -> void:
	dialogic.Text.text_sub_index = -1
	_disconnect_signals()


func _execute() -> void:
	if text.is_empty():
		finish()
		return

	## 如果说话者以表达式形式提供，则在此处解析。
	if "{" in character_identifier:
		character = null
		var character_name: String = dialogic.Expressions.execute_string(character_identifier)
		get_or_create_character(character_name)

	## 更改立绘与当前说话者
	if dialogic.has_subsystem("Portraits"):
		if character:
			dialogic.Portraits.change_speaker(character, portrait)

			if portrait and dialogic.Portraits.is_character_joined(character):
				dialogic.Portraits.change_character_portrait(character, portrait)
		else:
			dialogic.Portraits.change_speaker(null)

	## 更改语音情绪与打字音效
	if character:
		dialogic.Text.update_name_label(character)

		var current_portrait: String = portrait
		if portrait.is_empty():
			current_portrait = dialogic.Portraits.portraits.get(character.get_identifier(), {}).get("portrait", "")

		var current_portrait_sound_mood: String = character.portraits.get(current_portrait, {}).get("sound_mood", "")
		dialogic.Text.update_typing_sound_mood_from_character(character, current_portrait_sound_mood)

	else:
		dialogic.Text.update_name_label(null)
		dialogic.Text.update_typing_sound_mood()


	## 处理样式变更
	if dialogic.has_subsystem("Styles"):
		var current_base_style: String = dialogic.Styles.base_style
		var current_style: String = dialogic.Styles.style
		var character_style: String = "" if not character else character.custom_info.get("style", "")

		## 如果当前使用的是其他角色的样式，则切回基础样式
		if character_style.is_empty() and current_base_style != current_style:
			dialogic.Styles.change_style(current_base_style)
			await dialogic.get_tree().process_frame

		## 如果该角色有自己的样式，则切换成它的样式
		elif character and not character_style.is_empty():
			dialogic.Styles.change_style(character_style, false)
			await dialogic.get_tree().process_frame

	_connect_signals()

	var character_name_text := dialogic.Text.get_character_name_parsed(character)
	var final_text: String = get_property_translated('text')
	if ProjectSettings.get_setting('dialogic/text/split_at_new_lines', false):
		match ProjectSettings.get_setting('dialogic/text/split_at_new_lines_as', 0):
			0:
				final_text = final_text.replace('\n', '[n]')
			1:
				final_text = final_text.replace('\n', '[n+][br]')

	var split_text := []
	for i in split_regex.search_all(final_text):
		split_text.append([i.get_string().trim_prefix('[n]').trim_prefix('[n+]')])
		split_text[-1].append(i.get_string().begins_with('[n+]'))

	var reveal_next_segment: bool = dialogic.Text.text_sub_index == -1

	for section_idx in range(min(max(0, dialogic.Text.text_sub_index), len(split_text)-1), len(split_text)):
		dialogic.Inputs.block_input(ProjectSettings.get_setting('dialogic/text/text_reveal_skip_delay', 0.1))

		if reveal_next_segment:
			dialogic.Text.hide_next_indicators()

			dialogic.Text.text_sub_index = section_idx

			var section_text: String = split_text[section_idx][0]
			var is_append: bool = split_text[section_idx][1]

			if character:
				var character_prefix: String = character.custom_info.get(DialogicCharacterPrefixSuffixSection.PREFIX_CUSTOM_KEY, DialogicCharacterPrefixSuffixSection.DEFAULT_PREFIX)
				var character_suffix: String = character.custom_info.get(DialogicCharacterPrefixSuffixSection.SUFFIX_CUSTOM_KEY, DialogicCharacterPrefixSuffixSection.DEFAULT_SUFFIX)

				if len(split_text) == 1 or section_idx == 0 or not is_append:
					section_text = character_prefix + section_text
				if len(split_text) == 1 or section_idx == len(split_text)-1 or not split_text[section_idx+1][1]:
					section_text = section_text + character_suffix

			if len(split_text) == 1 or section_idx == 0 or not is_append:
				section_text = ProjectSettings.get_setting("dialogic/text/dialog_text_prefix", "")+section_text

			final_text = dialogic.Text.parse_text(section_text, 0)

			if final_text.is_empty():
				continue

			dialogic.Text.about_to_show_text.emit({"text":final_text, "character":character, "portrait":portrait, "append": is_append})

			await dialogic.Text.textbox_handle_auto_visibility(final_text)

			state = States.REVEALING
			_try_play_current_line_voice()
			final_text = dialogic.Text.update_dialog_text(final_text, false, is_append)

			dialogic.Text.text_started.emit({"text":final_text, "character":character, "portrait":portrait, "append": is_append})

			_mark_as_read(character_name_text, final_text)

			# 在可能因选项事件而提前返回之前，
			# 我们必须先跳过文本动画。
			if dialogic.Inputs.auto_skip.enabled:
				dialogic.Text.skip_text_reveal()
			else:
				await dialogic.Text.text_finished

			state = States.IDLE
		else:
			reveal_next_segment = true

		# 处理可能的选项事件。
		if section_idx == len(split_text)-1 and dialogic.has_subsystem('Choices') and dialogic.Choices.is_question(dialogic.current_event_idx):
			dialogic.Text.show_next_indicators(true)

			finish()
			return

		elif dialogic.Inputs.auto_advance.is_enabled():
			dialogic.Text.show_next_indicators(false, true)
			dialogic.Inputs.auto_advance.start()
		else:
			dialogic.Text.show_next_indicators()

		if section_idx == len(split_text)-1:
			state = States.DONE

		# 如果启用了自动跳过，且这段文本有多个部分，
		# 就需要在针对每个事件设定的时间后跳过文本。
		if dialogic.Inputs.auto_skip.enabled:
			await dialogic.Inputs.start_autoskip_timer()

			# 检查自动跳过是否仍然启用。
			if not dialogic.Inputs.auto_skip.enabled:
				await advance

		else:
			await advance


	finish()


func _mark_as_read(character_name_text: String, final_text: String) -> void:
	if dialogic.has_subsystem('History'):
		if character:
			dialogic.History.store_simple_history_entry(final_text, event_name, {'character':character_name_text, 'character_color':character.color})
		else:
			dialogic.History.store_simple_history_entry(final_text, event_name)
		dialogic.History.mark_event_as_visited()


func _connect_signals() -> void:
	if not dialogic.Inputs.dialogic_action.is_connected(_on_dialogic_input_action):
		dialogic.Inputs.dialogic_action.connect(_on_dialogic_input_action)

		dialogic.Inputs.auto_skip.toggled.connect(_on_auto_skip_enable)

	if not dialogic.Inputs.auto_advance.autoadvance.is_connected(_on_dialogic_input_autoadvance):
		dialogic.Inputs.auto_advance.autoadvance.connect(_on_dialogic_input_autoadvance)


## 如果事件已结束，此方法可以清理信号连接。
func _disconnect_signals() -> void:
	if dialogic.Inputs.dialogic_action.is_connected(_on_dialogic_input_action):
		dialogic.Inputs.dialogic_action.disconnect(_on_dialogic_input_action)
	if dialogic.Inputs.auto_advance.autoadvance.is_connected(_on_dialogic_input_autoadvance):
		dialogic.Inputs.auto_advance.autoadvance.disconnect(_on_dialogic_input_autoadvance)
	if dialogic.Inputs.auto_skip.toggled.is_connected(_on_auto_skip_enable):
		dialogic.Inputs.auto_skip.toggled.disconnect(_on_auto_skip_enable)


## 尝试为当前行播放语音片段。
func _try_play_current_line_voice() -> void:
	# 如果启用了自动跳过，而我们又要跳过语音片段，那就不播放。
	if (dialogic.Inputs.auto_skip.enabled
	and dialogic.Inputs.auto_skip.skip_voice):
		return

	# 播放当前行的音频区域。
	if (dialogic.has_subsystem('Voice')
	and dialogic.Voice.is_voiced(dialogic.current_event_idx)):
		dialogic.Voice.play_voice()


func _on_dialogic_input_action() -> void:
	match state:
		States.REVEALING:
			if dialogic.Text.is_text_reveal_skippable():
				dialogic.Text.skip_text_reveal()
				dialogic.Inputs.stop_timers()
		_:
			if dialogic.Inputs.manual_advance.is_enabled():
				advance.emit()
				dialogic.Inputs.stop_timers()


func _on_dialogic_input_autoadvance() -> void:
	if state == States.IDLE or state == States.DONE:
		advance.emit()


func _on_auto_skip_enable(enabled: bool) -> void:
	if not enabled:
		return

	match state:
		States.DONE:
			await dialogic.Inputs.start_autoskip_timer()

			# 如果自动跳过仍然启用，则推进文本。
			if dialogic.Inputs.auto_skip.enabled:
				advance.emit()

		States.REVEALING:
			dialogic.Text.skip_text_reveal()

#endregion


#region 初始化
################################################################################

func _init() -> void:
	event_name = "Text"
	event_description = "显示文本。可由角色说出。可包含各种 bbcode、文本效果或变量。"
	set_default_color('Color1')
	event_category = "Main"
	event_sorting_index = 0
	expand_by_default = true
	help_page_path = "https://docs.dialogic.pro/writing-texts.html"



#region 保存/加载
################################################################################

func to_text() -> String:
	var result := text.replace('\n', '\\\n').strip_edges(false).trim_suffix("\\")
	result = result.replace(':', '\\:')
	if result.is_empty():
		result = "<Empty Text Event>"

	if character or character_identifier:
		var name := character_identifier
		if character:
			name = character.get_identifier()
		if name.count(" ") > 0:
			name = '"' + name + '"'
		if not portrait.is_empty():
			result =  name+" ("+portrait+"): "+result
		else:
			result = name+": "+result
	for event in DialogicResourceUtil.get_event_cache():
		if not event is DialogicTextEvent and event.is_valid_event(result):
			result = '\\'+result
			break

	return result


func from_text(string:String) -> void:
	# 加载默认角色
	# 只有在默认值被覆盖时才有意义（通常不会）
	character = DialogicResourceUtil.get_character_resource(character_identifier)

	var result := regex.search(string.trim_prefix('\\'))

	if result.get_string('portrait'):
		portrait = result.get_string('portrait').strip_edges().trim_prefix('(').trim_suffix(')')

	if result and not result.get_string('name').is_empty():
		var name := result.get_string('name').strip_edges()

		if name == '_':
			character = null
		elif "{" in name:
			## 如果是表达式，我们在 _execute 中加载角色。
			character_identifier = name
			character = null
		else:
			get_or_create_character(name)

	if not result:
		return

	text = result.get_string('text').replace("\\\n", "\n").replace('\\:', ':').strip_edges().trim_prefix('\\')
	if text == '<Empty Text Event>':
		text = ""


func get_or_create_character(name:String) -> void:
	character = DialogicResourceUtil.get_character_resource(name)

	if character == null:
		if Engine.is_editor_hint() == false:
			character = DialogicCharacter.new()
			character.display_name = name
			character.set_identifier(name)
			if portrait:
				if "{" in portrait:
					character.color = Color(dialogic.Expressions.execute_string(portrait))
				else:
					character.color = Color(portrait)
		else:
			character_identifier = name


func is_valid_event(_string:String) -> bool:
	return true


func is_string_full_event(string:String) -> bool:
	return !string.ends_with('\\')


# 这里只是用来提供一份默认值列表
# 这样模块管理器就能为该事件添加自定义的默认值覆盖。
func get_shortcode_parameters() -> Dictionary:
	return {
		#param_name 	: property_info
		"character"		: {"property": "character_identifier", "default": "", "ext_file":true},
		"portrait"		: {"property": "portrait", 				"default": ""},
	}
#endregion


#region 翻译
################################################################################

func _get_translatable_properties() -> Array:
	return ['text']


func _get_property_original_translation(property:String) -> String:
	match property:
		'text':
			return text
	return ''


#endregion


#region 事件编辑器
################################################################################

func _enter_visual_editor(editor:DialogicEditor):
	editor.opened.connect(func(): ui_update_needed.emit())


func build_event_editor() -> void:
	add_header_edit('character_identifier', ValueType.DYNAMIC_OPTIONS,
			{'file_extension' 	: '.dch',
			'mode'				: 2,
			'suggestions_func' 	: get_character_suggestions,
			'placeholder' 		: '（无）',
			'icon' 				: load("res://addons/dialogic/Editor/Images/Resources/character.svg")}, 'do_any_characters_exist()')
	add_header_edit('portrait', ValueType.DYNAMIC_OPTIONS,
			{'suggestions_func' : get_portrait_suggestions,
			'placeholder' 		: "（不更改）",
			'icon' 				: load("res://addons/dialogic/Editor/Images/Resources/portrait.svg"),
			'collapse_when_empty': true,},
			'should_show_portrait_selector()')
	add_body_edit('text', ValueType.MULTILINE_TEXT, {'autofocus':true})


func should_show_portrait_selector() -> bool:
	return (character and not character.portraits.is_empty() and not character.portraits.size() == 1) or \
		(not character and (character_identifier.begins_with("{") or not character_identifier.is_empty()))


func do_any_characters_exist() -> bool:
	return not DialogicResourceUtil.get_character_directory().is_empty()


func get_character_suggestions(search_text:String) -> Dictionary:
	var suggestions := DialogicUtil.get_character_suggestions(search_text, character, true, false, editor_node)
	if search_text and not search_text in suggestions:
		suggestions[search_text] = {
			"value":search_text,
			"tooltip": "临时角色，在使用处即时创建。",
			"editor_icon":["GuiEllipsis", "EditorIcons"]}
	return suggestions


func get_portrait_suggestions(search_text:String) -> Dictionary:
	return DialogicUtil.get_portrait_suggestions(search_text, character, true, "不更改", true)

#endregion


#region 代码补全
################################################################################

var completion_text_character_getter_regex := RegEx.new()
var completion_text_effects := {}
func _get_code_completion(CodeCompletionHelper:Node, TextNode:TextEdit, line:String, _word:String, symbol:String) -> void:
	if completion_text_character_getter_regex.get_pattern().is_empty():
		completion_text_character_getter_regex.compile("(\"[^\"]*\"|[^\\s:]*)")

	if completion_text_effects.is_empty():
		for idx in DialogicUtil.get_indexers():
			for effect in idx._get_text_effects():
				completion_text_effects[effect['command']] = effect

	if not ':' in line.substr(0, TextNode.get_caret_column()) and symbol == '(':
		var completion_character := completion_text_character_getter_regex.search(line).get_string().trim_prefix('"').trim_suffix('"')
		CodeCompletionHelper.suggest_portraits(TextNode, completion_character)

	if symbol == '[':
		suggest_bbcode(TextNode)
		for effect in completion_text_effects.values():
			if effect.get('arg', false):
				TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, effect.command, effect.command+'=', TextNode.syntax_highlighter.normal_color, TextNode.get_theme_icon("RichTextEffect", "EditorIcons"))
			else:
				TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, effect.command, effect.command, TextNode.syntax_highlighter.normal_color, TextNode.get_theme_icon("RichTextEffect", "EditorIcons"), ']')

	if symbol == '{':
		CodeCompletionHelper.suggest_variables(TextNode)

	if symbol == '=':
		if CodeCompletionHelper.get_line_untill_caret(line).ends_with('[portrait='):
			var completion_character := completion_text_character_getter_regex.search(line).get_string('name')
			CodeCompletionHelper.suggest_portraits(TextNode, completion_character, ']')


func _get_start_code_completion(CodeCompletionHelper:Node, TextNode:TextEdit) -> void:
	CodeCompletionHelper.suggest_characters(TextNode, CodeEdit.KIND_CLASS, self)


func suggest_bbcode(TextNode:CodeEdit):
	for i in [['b（粗体）', 'b'], ['i（斜体）', 'i'], ['color', 'color='], ['字体大小','font_size=']]:
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, i[0], i[1],  TextNode.syntax_highlighter.normal_color, TextNode.get_theme_icon("RichTextEffect", "EditorIcons"),)
		TextNode.add_code_completion_option(CodeEdit.KIND_CLASS, '结束 '+i[0], '/'+i[1],  TextNode.syntax_highlighter.normal_color, TextNode.get_theme_icon("RichTextEffect", "EditorIcons"), ']')
	for i in [['新事件', 'n'],['新事件（同一文本框）', 'n+']]:
		TextNode.add_code_completion_option(CodeEdit.KIND_MEMBER, i[0], i[1],  TextNode.syntax_highlighter.normal_color, TextNode.get_theme_icon("ArrowRight", "EditorIcons"),)

#endregion


#region 语法高亮
################################################################################

var text_effects := ""
var text_effects_regex := RegEx.new()
func load_text_effects() -> void:
	if text_effects.is_empty():
		for idx in DialogicUtil.get_indexers():
			for effect in idx._get_text_effects():
				text_effects+= effect['command']+'|'
		text_effects += "b|i|u|s|code|p|center|left|right|fill|n\\+|n|indent|url|img|font|font_size|opentype_features|color|bg_color|fg_color|outline_size|outline_color|table|cell|ul|ol|lb|rb|br"
	if text_effects_regex.get_pattern().is_empty():
		text_effects_regex.compile("(?<!\\\\)\\[\\s*/?(?<command>"+text_effects+")\\s*(=\\s*(?<value>.+?)\\s*)?\\]")


var text_random_word_regex := RegEx.new()
var text_effect_color := Color('#898276')
func _get_syntax_highlighting(Highlighter:SyntaxHighlighter, dict:Dictionary, line:String) -> Dictionary:
	load_text_effects()
	if text_random_word_regex.get_pattern().is_empty():
		text_random_word_regex.compile(r"(?<!\\)\<[^\>]+(\/[^\>]*)\>")

	var result := regex.search(line)
	if not result:
		return dict
	if Highlighter.mode == Highlighter.Modes.FULL_HIGHLIGHTING:
		if result.get_string('name'):
			dict[result.get_start('name')] = {"color":Highlighter.character_name_color}
			dict[result.get_end('name')] = {"color":Highlighter.normal_color}
		if result.get_string('portrait'):
			dict[result.get_start('portrait')] = {"color":Highlighter.character_portrait_color}
			dict[result.get_end('portrait')] = {"color":Highlighter.normal_color}
	if result.get_string('text'):

		## 为随机选择修饰符上色
		for replace_mod_match in text_random_word_regex.search_all(result.get_string('text')):
			var color: Color = Highlighter.string_color
			color = color.lerp(Highlighter.normal_color, 0.4)
			dict[replace_mod_match.get_start()+result.get_start('text')] = {'color':Highlighter.string_color}
			var offset := 1
			for b:RegExMatch in RegEx.create_from_string(r"(\[[^\]]*\]|[^\/]|\/\/)+").search_all(replace_mod_match.get_string().trim_prefix("<").trim_suffix(">")):
				color.h = wrap(color.h+0.2, 0, 1)
				dict[replace_mod_match.get_start()+result.get_start('text')+offset] = {'color':color}
				offset += len(b.get_string())
				dict[replace_mod_match.get_start()+result.get_start('text')+offset] = {'color':Highlighter.string_color}
				offset += 1
			dict[replace_mod_match.get_end()+result.get_start('text')] = {'color':Highlighter.normal_color}

		## 为 bbcode 与文本效果上色
		var effects_result := text_effects_regex.search_all(line)
		for eff in effects_result:
			var prev_color: Color = Highlighter.dict_get_color_at_column(dict, eff.get_start())
			dict[eff.get_start()] = {"color":text_effect_color.lerp(prev_color, 0.4)}
			dict[eff.get_end()] = {"color":prev_color}
		dict = Highlighter.color_region(dict, Highlighter.variable_color, line, '{', '}', result.get_start('text'))

	return dict

#endregion
