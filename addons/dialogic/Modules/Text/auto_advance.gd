class_name DialogicAutoAdvance
extends RefCounted
## 该类保存自动前进功能的设置。
## 修改变量会改变自动前进的行为。
##
## 自动前进是一项在玩家设定的时长之后自动推进时间线的功能。
## 该时长由玩家决定。
## 对于希望玩家无需按键即可阅读文本的视觉小说来说，
## 这一功能非常有用。
##
## 与 [class DialogicAutoSkip] 不同，自动前进使用多个启用标志，
## 以便记录是哪些地方启用了自动前进。
## 例如，如果某个时间线事件强制启用了自动前进，而随后
## 又将其禁用，那么只要玩家没有取消它，自动前进
## 仍会保持启用状态。

signal autoadvance
signal toggled(enabled: bool)

var autoadvance_timer := Timer.new()

var fixed_delay: float = 1.0
var delay_modifier: float = 1.0

var per_word_delay: float = 0.0
var per_character_delay: float = 0.1

var ignored_characters_enabled := false
var ignored_characters := {}

var await_playing_voice := true

var override_delay_for_current_event: float = -1.0

## 私有变量，用于记录上一次的自动前进状态。
## 将用于发出 [signal toggled] 信号。
var _last_enable_state := false

## 若为 true，自动前进会一直生效，直到下一个事件。
##
## 用这个标志可以创建一个临时的自动前进模式。
## 你可以利用 [variable override_delay_for_current_event] 为该事件
## 设置临时的自动前进延迟。
##
## 可与 [variable enabled_forced] 和 [variable enabled_until_user_input] 叠加使用。
var enabled_until_next_event := false :
	set(enabled):
		enabled_until_next_event = enabled
		_try_emit_toggled()

## 若为 true，自动前进会一直保持启用，直到该值被设为 false。
##
## 这个布尔值可用于实现自动播放文本。
##
## 可与 [variable enabled_until_next_event] 和 [variable enabled_until_user_input] 叠加使用。
var enabled_forced := false :
	set(enabled):
		enabled_forced = enabled
		_try_emit_toggled()

## 若为 true，自动前进会一直生效，直到玩家按下按钮。
##
## 当玩家想要启用自动前进时，使用这个标志。
##
## 可与 [variable enabled_forced] 和 [variable enabled_until_next_event] 叠加使用。
var enabled_until_user_input := false :
	set(enabled):
		enabled_until_user_input = enabled
		_try_emit_toggled()


func _init() -> void:
	DialogicUtil.autoload().Inputs.add_child(autoadvance_timer)
	autoadvance_timer.one_shot = true
	autoadvance_timer.timeout.connect(_on_autoadvance_timer_timeout)
	toggled.connect(_on_toggled)

	enabled_forced = ProjectSettings.get_setting("dialogic/text/autoadvance_enabled", false)
	fixed_delay = ProjectSettings.get_setting("dialogic/text/autoadvance_fixed_delay", 1)
	per_word_delay = ProjectSettings.get_setting("dialogic/text/autoadvance_per_word_delay", 0)
	per_character_delay = ProjectSettings.get_setting("dialogic/text/autoadvance_per_character_delay", 0.1)
	ignored_characters_enabled = ProjectSettings.get_setting("dialogic/text/autoadvance_ignored_characters_enabled", true)
	ignored_characters = ProjectSettings.get_setting("dialogic/text/autoadvance_ignored_characters", {})

#region 自动推进内部实现

func start() -> void:
	if not is_enabled():
		return

	var parsed_text: String = DialogicUtil.autoload().Text.dialog_text_parsed
	var delay := _calculate_autoadvance_delay(parsed_text)

	await DialogicUtil.autoload().get_tree().process_frame
	if delay == 0:
		_on_autoadvance_timer_timeout()
	else:
		autoadvance_timer.start(delay)


## 根据设置与文本计算自动前进的时间。
##
## 会考虑以下因素：
## - 临时的延迟时间覆盖
## - 每个单词的延迟
## - 每个字符的延迟
## - 固定延迟
## - 文本显示所花的时间
## - 自动前进延迟修正值
## - 语音音频
func _calculate_autoadvance_delay(text: String = "") -> float:
	var delay := 0.0

	# 检查是否有临时的时长覆盖
	if override_delay_for_current_event >= 0:
		delay = override_delay_for_current_event
	else:
		# 累加每单词与每字符的延迟
		delay = _calculate_per_word_delay(text) + _calculate_per_character_delay(text)

		delay *= delay_modifier
		# 最后再应用固定延迟，使其不受延迟修正值影响
		delay += fixed_delay

		delay = max(0, delay)

	# 等待语音片段结束（如果它比当前延迟更长）
	if await_playing_voice and DialogicUtil.autoload().has_subsystem("Voice") and DialogicUtil.autoload().Voice.is_running():
		delay = max(delay, DialogicUtil.autoload().Voice.get_remaining_time())

	return delay


## 检查以空白字符分隔文本时能找到多少个单词。
##   （目前使用 ` ` 也就是空格，将来可以扩展）
func _calculate_per_word_delay(text: String) -> float:
	return float(text.split(' ', false).size() * per_word_delay)


## 通过逐字符遍历来统计字符数。
func _calculate_per_character_delay(text: String) -> float:
	var calculated_delay: float = 0

	if per_character_delay > 0:
		# 如果有需要忽略的字符，就逐个遍历字符。
		if ignored_characters_enabled:
			for character in text:
				if character in ignored_characters:
					continue
				calculated_delay += per_character_delay

		# 否则，直接把文本长度乘以延迟即可。
		else:
			calculated_delay = text.length() * per_character_delay

	return calculated_delay


func _on_autoadvance_timer_timeout() -> void:
	autoadvance.emit()
	autoadvance_timer.stop()


## 根据 [param enabled] 打开或关闭自动前进模式。
func _on_toggled(enabled: bool) -> void:
	# 如果自动前进已启用且我们尚未处于自动前进中，
	# 就启动自动前进模式。
	if (enabled and !is_advancing()
	and DialogicUtil.autoload().current_state == DialogicGameHandler.States.IDLE
	and not DialogicUtil.autoload().Text.dialog_text.is_empty()):
		start()

	# 如果自动前进被禁用而正处于自动前进中，
	# 就要取消自动前进模式。
	elif !enabled and is_advancing():
		DialogicUtil.autoload().Inputs.stop_timers()
#endregion

#region 自动推进辅助
func is_advancing() -> bool:
	return !autoadvance_timer.is_stopped()


func get_time_left() -> float:
	return autoadvance_timer.time_left


func get_time() -> float:
	return autoadvance_timer.wait_time


## 返回自动前进当前是否被视为已启用。
## 自动前进使用三个不同的启用标志：
## - enabled_until_user_input（在任何 Dialogic 输入动作后变为 false）
## - enabled_until_next_event（在每个文本事件后变为 false）
## - enabled_forced（仅在代码中禁用时变为 false）
##
## 三者都可以用各自的方法设置。
func is_enabled() -> bool:
	return (enabled_until_next_event
		or enabled_until_user_input
		or enabled_forced)


## 更新 [member _autoadvance_enabled] 变量，以便正确检测该值是否发生变化。
## 若发生变化，则发出 [member toggled] 信号。
func _try_emit_toggled() -> void:
	var old_autoadvance_state := _last_enable_state
	_last_enable_state = is_enabled()

	if old_autoadvance_state != _last_enable_state:
		toggled.emit(_last_enable_state)


## 连接到「延迟修正值」设置变更的内部方法。
func _update_autoadvance_delay_modifier(delay_modifier_value: float) -> void:
	delay_modifier = delay_modifier_value


## 返回自动前进计时器的进度，范围为 0 到 1。
## 数值越高，表示计时器越接近结束。
## 如果自动前进已被禁用，则返回 -1。
func get_progress() -> float:
	if !is_advancing():
		return -1

	var total_time: float = get_time()
	var time_left: float = get_time_left()
	var progress: float = (total_time - time_left) / total_time

	return progress
#endregion
