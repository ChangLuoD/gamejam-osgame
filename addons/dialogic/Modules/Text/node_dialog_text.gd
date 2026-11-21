@tool
@icon("node_dialog_text_icon.svg")
class_name DialogicNode_DialogText
extends RichTextLabel

## 能以给定速度（可更改）逐字显示文本的 Dialogic 节点。

signal started_revealing_text()
signal continued_revealing_text(new_character : String)
signal finished_revealing_text()
enum Alignment {LEFT, CENTER, RIGHT}

@export var enabled := true
@export var identifier := "main"
@export var alignment := Alignment.LEFT
@export var textbox_root: Node = self


## 若为 true，此节点会在 ready 时调用 Text 子系统的 [method hide_textbox]。
## 注意：文本框可见性由标识符相同的文本框共享。
@export var start_hidden := true
## 若为 true，Dialogic 在更改文本时会自动调用 [method textbox_update_visibility]。
@export var auto_visibility := true

var revealing := false
var base_visible_characters := 0

# 每个显示字符所用的速度。
# 在将显示速度与语音同步时可能被覆盖。
var active_speed: float = 0.01

var speed_counter: float = 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# 加入必要的分组
	add_to_group('dialogic_dialog_text')
	meta_hover_ended.connect(_on_meta_hover_ended)
	meta_hover_started.connect(_on_meta_hover_started)
	meta_clicked.connect(_on_meta_clicked)
	gui_input.connect(on_gui_input)
	bbcode_enabled = true

	if textbox_root == null:
		textbox_root = self

	if start_hidden:
		textbox_root.hide()

	text = ""

	var custom_bbcode_effects: Array = ProjectSettings.get_setting("dialogic/text/custom_bbcode_effects", "").split(",", false)
	for i in custom_bbcode_effects:
		var x: Resource = load(i.strip_edges())
		if x is RichTextEffect:
			custom_effects.append(x.duplicate())


## 由 [subsytem Text] 调用，用于设置文本，并按 [member active_speed] 播放逐字显示动画。
func reveal_text(_text: String, keep_previous:=false) -> void:
	if not enabled:
		return

	show()
	custom_fx_reset()

	if not keep_previous:
		text = _text
		base_visible_characters = 0

		if alignment == Alignment.CENTER:
			text = '[center]'+text
		elif alignment == Alignment.RIGHT:
			text = '[right]'+text
		visible_characters = 0

	else:
		base_visible_characters = len(text)
		visible_characters = len(get_parsed_text())
		custom_fx_update()
		text = text + _text

		# 如果启用了自动跳过，而我们是追加文本（keep_previous），
		# 就可以跳过逐字显示，直接一次性全部显示。
		if DialogicUtil.autoload().Inputs.auto_skip.enabled:
			visible_characters = 1
			return

	revealing = true
	speed_counter = 0
	started_revealing_text.emit()


func set_speed(delay_per_character:float) -> void:
	if DialogicUtil.autoload().Text.is_text_voice_synced() and DialogicUtil.autoload().Voice.is_running():
		var total_characters := get_total_character_count() as float
		var remaining_time: float = DialogicUtil.autoload().Voice.get_remaining_time()
		var synced_speed :=  remaining_time / total_characters
		active_speed = synced_speed

	else:
		active_speed = delay_per_character


## 再显示一个字符。
func continue_reveal() -> void:
	if visible_characters <= get_total_character_count():
		revealing = false

		var current_index := visible_characters - base_visible_characters
		await DialogicUtil.autoload().Text.execute_effects(current_index, self, false)

		if visible_characters == -1:
			return

		revealing = true
		visible_characters += 1

		if visible_characters > -1 and visible_characters <= len(get_parsed_text()):
			continued_revealing_text.emit(get_parsed_text()[visible_characters-1])

		custom_fx_update()
	else:
		finish_text(true)
		# 如果文本是自然结束的，就加入一小段输入封锁
		# 这样可以避免在你以为文本更长时意外跳过
		DialogicUtil.autoload().Inputs.block_input(ProjectSettings.get_setting('dialogic/text/advance_delay', 0.1))


## 立即显示全部文本。
func finish_text(is_organic := false) -> void:
	visible_ratio = 1
	custom_fx_update()
	if not is_organic:
		custom_fx_skip()
	DialogicUtil.autoload().Text.execute_effects(-1, self, true)
	revealing = false
	DialogicUtil.autoload().current_state = DialogicGameHandler.States.IDLE

	finished_revealing_text.emit()


## 检查文本中的下一个字符是否可以显示。
func _process(delta: float) -> void:
	if !revealing or DialogicUtil.autoload().paused:
		return

	speed_counter += delta

	while speed_counter > active_speed and revealing and !DialogicUtil.autoload().paused:
		speed_counter -= active_speed
		continue_reveal()



func _on_meta_hover_started(_meta:Variant) -> void:
	DialogicUtil.autoload().Inputs.action_was_consumed = true

func _on_meta_hover_ended(_meta:Variant) -> void:
	DialogicUtil.autoload().Inputs.action_was_consumed = false

func _on_meta_clicked(_meta:Variant) -> void:
	DialogicUtil.autoload().Inputs.action_was_consumed = true


## 处理鼠标输入
func on_gui_input(event:InputEvent) -> void:
	DialogicUtil.autoload().Inputs.handle_node_gui_input(event)


func custom_fx_update() -> void:
	for effect:RichTextEffect in custom_effects:
		if "visible_characters" in effect:
			effect.visible_characters = visible_characters


func custom_fx_reset() -> void:
	for effect in custom_effects:
		if effect.has_method("reset"):
			effect.reset()


func custom_fx_skip() -> void:
	for effect in custom_effects:
		if effect.has_method("skip"):
			effect.skip()
