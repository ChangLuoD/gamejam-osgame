extends DialogicSubsystem
## 处理输入、自动前进与跳过的子系统。
##
## 该子系统可通过 GDScript 访问：`Dialogic.Inputs`。


## 当 [method handle_input] 被触发时发出。
## 你可以监听该信号，并把 [member action_was_consumed] 设为 `true`，
## 以使用该输入并阻止 Dialogic 继续使用它。
signal dialogic_action_priority
## 当 [method handle_input] 被触发，且该动作尚未被其他对象消费时发出。
## 各个子系统用它来推进时间线。
signal dialogic_action

## 每当自动跳过计时器结束时，会发出该信号。
## 通过 [member auto_skip] 配置自动跳过设置。
signal autoskip_timer_finished

const _SETTING_INPUT_ACTION := "dialogic/text/input_action"
const _SETTING_INPUT_ACTION_DEFAULT := "dialogic_default_action"

## 该计时器运行期间，输入会被阻止。可与 [method block_input] 配合使用。
var input_block_timer := Timer.new()
var _auto_skip_timer_left: float = 0.0

## 当你想阻止后续动作时，在响应 [signal dialogic_action_priority] 时设置该方法。
var action_was_consumed := false
## 如果你（在响应 [signal dialogic_action] 或 [signal dialogic_priority_action] 时）
## 当前处理的输入是由鼠标按钮产生的，则该值为 `true`。
## 会在 [method handle_action] 结束时重置。
var input_was_mouse_input := false

## 所使用的 [DialogicAutoSkip] 对象。
var auto_skip: DialogicAutoSkip = null
## 所使用的 [DialogicAutoAdvance] 对象。
var auto_advance: DialogicAutoAdvance = null
## 所使用的 [DialogicManualAdvance] 对象。
var manual_advance: DialogicManualAdvance = null

@export_group("State")
@export var manual_advance_info := {
	DialogicManualAdvance.ENABLED_STATE_KEY: true,
	DialogicManualAdvance.DISABLED_UNTIL_NEXT_EVENT_STATE_KEY: false}

#region 子系统方法
################################################################################

func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	if not is_node_ready():
		await ready

	manual_advance.disabled_until_next_event = false
	manual_advance.system_enabled = true


func _pause() -> void:
	auto_advance.autoadvance_timer.paused = true
	input_block_timer.paused = true
	set_process(false)


func _resume() -> void:
	auto_advance.autoadvance_timer.paused = false
	input_block_timer.paused = false
	var is_autoskip_timer_done := _auto_skip_timer_left > 0.0
	set_process(not is_autoskip_timer_done)


func _post_install() -> void:
	auto_skip = DialogicAutoSkip.new()
	auto_advance = DialogicAutoAdvance.new()
	manual_advance = DialogicManualAdvance.new()

	dialogic.Settings.connect_to_change("autoadvance_delay_modifier", auto_advance._update_autoadvance_delay_modifier)
	auto_skip.toggled.connect(_on_autoskip_toggled)
	auto_skip._init()
	add_child(input_block_timer)
	input_block_timer.one_shot = true


#endregion


#region 主要方法
################################################################################

## 当调用 Dialogic 动作时会调用该方法。
## 如果你想模拟一次点击，可以自行调用它。[br][br]
## 如果 Dialogic 已暂停，或输入被之前某次 [method block_input] 调用阻止，则该方法不会做任何事。[br][br]
## 该方法会先发出信号 [signal dialogic_priority_action]，然后
## 如果期间 [member action_was_consumed] 没有被设为 `true`，
## 再发出 [signal dialogic_action]。
func handle_input() -> void:
	if dialogic.paused or is_input_blocked():
		return

	if not action_was_consumed:
		# 我们想停止会在用户输入时取消的自动前进。
		if (auto_advance.is_enabled()
			and auto_advance.enabled_until_user_input):
			auto_advance.enabled_until_user_input = false
			action_was_consumed = true

		# 如果自动跳过已启用、我们正在监听
		# 用户输入，且它不是瞬时跳过，则要停止自动跳过。
		if (auto_skip.disable_on_user_input
		and auto_skip.enabled):
			auto_skip.enabled = false
			action_was_consumed = true


	dialogic_action_priority.emit()

	if action_was_consumed:
		action_was_consumed = false
		return

	dialogic_action.emit()
	input_was_mouse_input = false


## 所有非鼠标类输入都在此处处理。
## 鼠标类输入由 InputCatcher 和 Textbox 节点调用 [method handle_node_gui_input] 处理。
## 会调用 [method handle_input]。
func _unhandled_input(event:InputEvent) -> void:
	if is_input_pressed(event, true):
		if event is InputEventMouse or event is InputEventScreenTouch:
			return
		input_was_mouse_input = false
		handle_input()


## 输入用于所有鼠标类输入。
## 如果存在任何 DialogicInputNode，则此处不会做任何事（因为那时由该节点处理 MouseInput）。
func _input(event:InputEvent) -> void:
	if is_input_pressed(event):
		if not event is InputEventMouse:
			return
		if get_tree().get_nodes_in_group("dialogic_input").any(func(node):return node.is_visible_in_tree()):
			return
		input_was_mouse_input = true
		handle_input()


## 用于快速检查该事件是否为所设置的那个输入动作。
func is_input_pressed(event: InputEvent, exact := false) -> bool:
	var action: String = ProjectSettings.get_setting(_SETTING_INPUT_ACTION, _SETTING_INPUT_ACTION_DEFAULT)
	return (event is InputEventAction and event.action == action) or Input.is_action_just_pressed(action, exact)


## 由 InputCatcher 和 DialogText 节点的 `_gui_input` 调用。
## 会调用 [method handle_input]。
func handle_node_gui_input(event:InputEvent) -> void:
	if Input.is_action_just_pressed(ProjectSettings.get_setting(_SETTING_INPUT_ACTION, _SETTING_INPUT_ACTION_DEFAULT)):
		if event is InputEventMouseButton and event.pressed:
			input_was_mouse_input = true
			handle_input()


## 如果之前某次 [method block_input] 调用仍在生效，则返回 true。
func is_input_blocked() -> bool:
	return input_block_timer.time_left > 0.0 and not auto_skip.enabled


## 在给定时间内阻止输入。Dialogic 会在某些时刻自动这样做，
## 例如文本揭示结束后会阻止几毫秒。
## 你也可以自行调用它。
func block_input(time:=0.1) -> void:
	if time > 0:
		input_block_timer.wait_time = max(time, input_block_timer.time_left)
		input_block_timer.start()



func _ready() -> void:

	# 我们使用 process 方法来为 auto-start_autoskip_timer 计时器倒计时。
	set_process(false)


## 停止该子系统的所有计时器。由文本子系统使用。
func stop_timers() -> void:
	auto_advance.autoadvance_timer.stop()
	input_block_timer.stop()
	_auto_skip_timer_left = 0.0

#endregion


#region 自动跳过
################################################################################

## 该方法会依据自动跳过设置推进时间线。
## 会自动跳过是否启用这一状态被忽略。
func start_autoskip_timer() -> void:
	_auto_skip_timer_left = auto_skip.time_per_event
	set_process(true)
	await autoskip_timer_finished


## 如果自动跳过被禁用，我们就要停止计时器。
func _on_autoskip_toggled(enabled: bool) -> void:
	if not enabled:
		_auto_skip_timer_left = 0.0


## 处理细粒度的自动跳过逻辑。
## [method _process] 方法可以提供比
## [Timer] 类更精确的计时器。
func _process(delta: float) -> void:
	if _auto_skip_timer_left > 0:
		_auto_skip_timer_left -= delta

		if _auto_skip_timer_left <= 0:
			autoskip_timer_finished.emit()

	else:
		autoskip_timer_finished.emit()
		set_process(false)

#endregion

#region 文本特效
################################################################################

## 输入效果（`[input]`）会暂停文本，直到收到一次 Dialogic 输入。
## 表面上这似乎与 [n+] 类似，但工作原理很不一样。
func effect_input(_text_node:Control, skipped:bool, _argument:String) -> void:
	if skipped:
		return
	dialogic.Text.show_next_indicators()
	await dialogic.Inputs.dialogic_action_priority
	dialogic.Text.hide_next_indicators()
	dialogic.Inputs.action_was_consumed = true


## 不跳过效果（`[ns]`）会为一个事件禁用跳过与手动前进，并为一个事件启用自动前进。
## 可以给出参数来控制自动前进的时机。
func effect_noskip(text_node:Control, skipped:bool, argument:String) -> void:
	dialogic.Text.set_text_reveal_skippable(false, true)
	manual_advance.disabled_until_next_event = true
	effect_autoadvance(text_node, skipped, argument)


## 不跳过揭示效果（`[nrs]`）会为一个事件禁用跳过揭示。
func effect_norevealskip(_text_node:Control, _skipped:bool, _argument:String) -> void:
	dialogic.Text.set_text_reveal_skippable(false, true)


## 自动前进效果（`[aa]`）会为一个事件启用自动前进（同时仍允许手动前进与跳过）。
## 可以给出参数来控制自动前进的延迟。
## 如果参数以 `?` 结尾，该效果不会启用自动前进，只会为已启用的自动前进设置延迟。
func effect_autoadvance(_text_node: Control, _skipped:bool, argument:String) -> void:
	if argument.ends_with("?"):
		argument = argument.trim_suffix("?")
	else:
		auto_advance.enabled_until_next_event = true

	if argument.is_valid_float():
		auto_advance.override_delay_for_current_event = float(argument)

#endregion
