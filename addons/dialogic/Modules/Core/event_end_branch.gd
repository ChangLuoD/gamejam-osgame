@tool
class_name DialogicEndBranchEvent
extends DialogicEvent

## 表示条件或选项（或自定义分支）的结束事件。
## 在文本中不会存储该事件（只体现为缩进的变化）。


#region 执行
################################################################################

func _execute() -> void:
	dialogic.current_event_idx = find_next_index()-1
	finish()


## 返回第一个符合以下条件的事件的索引：
## - 处于相同的「缩进」
## - 不是分支事件（除非它是分支起始事件）
func find_next_index() -> int:
	var idx: int = dialogic.current_event_idx
	while true:
		idx += 1
		var event: DialogicEvent = dialogic.current_timeline.get_event(idx)
		if not event:
			return idx

		if event.can_contain_events:
			if event._is_branch_starter():
				break
			else:
				idx = event.get_end_branch_index()
				break
		else:
			break

	return idx


func get_opening_index() -> int:
	var index: int = dialogic.current_timeline_events.find(self)
	while true:
		index -= 1
		if index < 0:
			break
		var event: DialogicEvent = dialogic.current_timeline_events[index]
		if event is DialogicEndBranchEvent:
			index = event.get_opening_index()
		elif event.can_contain_events:
			return index
	return 0

#endregion

#region 初始化
################################################################################

func _init() -> void:
	event_name = "End Branch"
	disable_editor_button = true

#endregion

#region 保存/加载
################################################################################

## 注意：该事件非常特殊。它几乎不会被存储，通常只是用于
## 移除一层缩进的占位符。
## 但在复制事件时，必须有某种表示形式。因此这里只做了部分实现。
func to_text() -> String:
	return "<<END BRANCH>>"


func from_text(_string:String) -> void:
	pass


func is_valid_event(string:String) -> bool:
	if string.strip_edges().begins_with("<<END BRANCH>>"):
		return true
	return false
