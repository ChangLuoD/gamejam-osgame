extends RefCounted
class_name DialogicManualAdvance
## 此类保存手动推进功能的设置。
## 修改变量会改变手动推进时间线的行为，
## 例如使用输入动作时。

## 当前状态信息中表示启用状态的键。
const ENABLED_STATE_KEY := "enabled"
## 当前状态信息中表示临时事件状态的键。
const DISABLED_UNTIL_NEXT_EVENT_STATE_KEY := "temp_disabled"


## 若为 `true`，手动推进将保持启用，直到此项被设为 `false`。
##
## 用此标志启用或禁用手动推进模式。
##
## 可被 [variable disabled_until_next_event] 临时覆盖。
var system_enabled := true :
	set(enabled):
		system_enabled = enabled
		DialogicUtil.autoload().Inputs.manual_advance_info[ENABLED_STATE_KEY] = enabled


## 若为 `true`，手动推进将被停用，直到下一个事件。
##
## 用此标志创建一次临时的手动推进阻断。
##
## 为 true 时覆盖 [variable system_enabled]。
var disabled_until_next_event := false :
	set(enabled):
		disabled_until_next_event = enabled
		DialogicUtil.autoload().Inputs.manual_advance_info[DISABLED_UNTIL_NEXT_EVENT_STATE_KEY] = enabled


## 检查当前状态信息中是否有手动推进设置。
## 如果没有，就用默认设置填充当前状态信息。
func _init() -> void:
	var manual_advance: Dictionary = DialogicUtil.autoload().Inputs.manual_advance_info

	disabled_until_next_event = manual_advance.get(DISABLED_UNTIL_NEXT_EVENT_STATE_KEY, disabled_until_next_event)
	system_enabled = manual_advance.get(ENABLED_STATE_KEY, system_enabled)


#region 手动推进辅助

## 玩家是否可以使用手动推进来推进时间线。
func is_enabled() -> bool:
	return system_enabled and not disabled_until_next_event

#endregion
