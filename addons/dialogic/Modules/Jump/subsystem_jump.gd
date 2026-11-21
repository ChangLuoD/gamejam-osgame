extends DialogicSubsystem

## 包含跳转到指定标签、或返回上一次跳转的方法的子系统。


#region 信号
@warning_ignore("unused_signal") # 该信号由跳转事件发出
## 当跳转事件从一个时间线切换到另一个时间线时发出。提供一个包含以下键的字典：
## [br]
## 键                   | 值类型                  | 值 [br]
## -------------------- | ----------------------- | ----- [br]
## `previous_timeline`  | [type DialogicTimeline] | 之前所在的时间线。[br]
## `timeline`           | [type DialogicTimeline] | 当前所在的时间线。[br]
## `label`              | [type String]           | 跳转到的标签（若从头开始则为空）。[br]
signal switched_timeline(info:Dictionary)

## 当跳转事件跳转到某个标签时发出。提供一个包含以下键的字典：
## [br]
## 键          | 值类型                  | 值 [br]
## ----------- | ----------------------- | ----- [br]
## `timeline`  | [type DialogicTimeline] | 当前所在的时间线。[br]
## `label`     | [type String]           | 跳转到的标签（若从头开始则为空）。[br]
signal jumped_to_label(info:Dictionary)

## 当触发返回事件且存在可返回的时间线时发出。提供一个包含以下键的字典：
## [br]
## 键              | 值类型                  | 值 [br]
## --------------- | ----------------------- | ----- [br]
## `sub_timeline`  | [type DialogicTimeline] | 之前所在的时间线。[br]
## `label`         | [type String]           | 返回到的标签（若从头开始则为空）。[br]
signal returned_from_jump(info:Dictionary)

## 当标签事件被执行时发出（通常没有其他作用）。提供一个包含以下键的字典：
## [br]
## 键                  | 值类型                  | 值 [br]
## ------------------- | ----------------------- | ----- [br]
## `identifier`        | [type String]           | 标签事件的标识符。[br]
## `display_name`      | [type String]           | 显示名称，可能已翻译。[br]
## `display_name_orig` | [type String]           | 未翻译的显示名称。[br]
## `timeline`          | [type String]           | 当前所在时间线的标识符。[br]
signal passed_label(info:Dictionary)
#endregion

@export_group("状态")
@export var jump_stack := []
@export var last_label := {}


#region 状态
####################################################################################################

func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	jump_stack = []
	last_label = {}


func _load_state(_load_flag:=LoadFlags.FULL_LOAD) -> void:
	pass

#endregion


#region 主要方法：跳转
####################################################################################################

func jump_to_label(label:String) -> void:
	if label.is_empty():
		dialogic.current_event_idx = 0
		jumped_to_label.emit({'timeline':dialogic.current_timeline, 'label':""})
		return

	## 允许标签使用变量，从而让跳转事件可以是动态的
	label = str(dialogic.VAR.parse_variables(label))

	var idx: int = -1
	while true:
		idx += 1
		var event: Variant = dialogic.current_timeline.get_event(idx)
		if not event:
			printerr("[Dialogic] 找不到用于跳转的标签「%s」（所在时间线「%s」）。" % [label, dialogic.current_timeline.get_identifier()])
			idx = dialogic.current_event_idx + 1
			break
		if event is DialogicLabelEvent and event.name == label:
			break
	dialogic.current_event_idx = idx-1
	jumped_to_label.emit({'timeline':dialogic.current_timeline, 'label':label})


func push_to_jump_stack() -> void:
	jump_stack.push_back({'timeline':dialogic.current_timeline, 'index':dialogic.current_event_idx, 'label':dialogic.current_timeline_events[dialogic.current_event_idx].label_name})


func resume_from_last_jump() -> void:
	var sub_timeline: DialogicTimeline = dialogic.current_timeline
	var stack_info: Dictionary = jump_stack.pop_back()
	dialogic.start_timeline(stack_info.timeline, stack_info.index+1)
	returned_from_jump.emit({'sub_timeline':sub_timeline, 'label':stack_info.label})


func is_jump_stack_empty() -> bool:
	return len(jump_stack) < 1

#endregion


#region 主要方法：标签
####################################################################################################

func _ready() -> void:
	passed_label.connect(_on_passed_label)


func _on_passed_label(info:Dictionary) -> void:
	last_label = info


## 返回最后一个经过的标签的标识符名称
func get_last_label_identifier() -> String:
	return last_label.get("identifier", "")


## 返回最后一个经过的标签的显示名称（若启用了翻译则返回译文）
func get_last_label_name() -> String:
	return last_label.get("display_name", "")
#endregion
