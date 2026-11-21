class_name DialogicAutoSkip
extends RefCounted
## 该类保存自动跳过功能的设置。
## 修改变量会改变自动跳过的行为。
##
## 自动跳过必须由每个事件自行实现。

## 每当自动跳过状态从 `true` 变为 `false` 或反之
## 时，都会发出该信号。
signal toggled(is_enabled: bool)

## 自动跳过是否已启用。
## 如果称自动跳过为[i]已禁用[/i]，指的是把
## 该变量设为 `false`。
## 该变量变化时会自动发出 [signal autoskip_changed] 信号。
var enabled := false : set = _set_enabled

## 若为 `true`，当用户按下可识别的输入动作时，
## 自动跳过将被禁用。
var disable_on_user_input := true

## 若为 `true`，当时间线推进到未读的文本事件
## 或需要用户输入的事件时，自动跳过将被禁用。
var disable_on_unread_text := false

## 若为 `true`，当时间线推进到之前访问过的
## 文本事件时，自动跳过将被启用。
## 如果玩家总是想跳过已访问过的文本事件，这会很有用。
var enable_on_visited := false

## 若为 `true`，自动跳过会跳过语音事件而不是播放它们。
var skip_voice := true

## 每个事件可能消耗的秒数。
## 此值不会被强制执行，每个事件必须自行实现该行为。
var time_per_event: float = 0.1


## 初始化自动跳过。
func _init() -> void:
	time_per_event = ProjectSettings.get_setting('dialogic/text/autoskip_time_per_event', time_per_event)

	if DialogicUtil.autoload().has_subsystem("History") and not DialogicUtil.autoload().History.visited_event.is_connected(_handle_seen_event):
		DialogicUtil.autoload().History.visited_event.connect(_handle_seen_event)
		DialogicUtil.autoload().History.unvisited_event.connect(_handle_unseen_event)


## 在自动跳过启用或禁用时调用。
## 如果状态发生变化，则发出 [signal autoskip_changed] 信号。
func _set_enabled(is_enabled: bool) -> void:
	var previous_enabled := enabled
	enabled = is_enabled

	if enabled != previous_enabled:
		toggled.emit(enabled)


func _handle_seen_event() -> void:
	# 如果自动跳过已禁用，但它会对已访问事件做出反应，
	# 我们就启用自动跳过。
	if not enabled and enable_on_visited:
		enabled = true


func _handle_unseen_event() -> void:
	if not enabled:
		return

	if disable_on_unread_text:
		enabled = false
