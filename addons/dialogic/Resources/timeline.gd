@tool
@icon("uid://j7ym07anlusi")
extends "res://addons/dialogic/Resources/dialogic_identifiable_resource.gd"
class_name DialogicTimeline

## 定义一个事件列表的资源。
## 可以把它们存储为文本，也能从文本中加载。


var events: Array = []
var events_processed := false
var text_lines_indexed := {}
var indent_format := "\t"


func _get_extension() -> String:
	return "dtl"


func _get_resource_name() -> String:
	return "DialogicTimeline"


## 辅助方法
func get_event(index:int) -> Variant:
	if index >= len(events):
		return null
	return events[index]


## 将各行解析为独立的事件并插入数组，
## 以便之后处理时转换为 DialogicEvent
func from_text(text:String) -> void:
	events = text.split('\n', true)
	events_processed = false

	## 先对缩进格式做一个初步猜测
	## 因为文本编辑器需要它，却不会调用 _process()
	for ev in events:
		indent_format = ev.substr(0, len(ev) - len(ev.strip_edges(true, false)))
		if indent_format:
			break


## 将所有事件按其文本格式存储，并以字符串返回
func as_text() -> String:
	var result := ""

	if events_processed:
		var indent := 0
		for idx in range(0, len(events)):
			var event: DialogicEvent = events[idx]

			if event.event_name == 'End Branch':
				indent -= 1
				continue

			if event != null:
				for i in event.empty_lines_above:
					result += indent_format.repeat(indent)+"\n"
				result += indent_format.repeat(indent)+event.event_node_as_text.replace('\n', "\n"+indent_format.repeat(indent)) + "\n"
			if event.can_contain_events:
				indent += 1
			if indent < 0:
				indent = 0
	else:
		for event in events:
			result += str(event)+"\n"

		result.trim_suffix('\n')

	return result.strip_edges()


## 返回特定行所对应事件的索引
func get_index_from_text_line(text:String, line) -> int:
	from_text(text)
	process()
	return text_lines_indexed[line]

## 返回给定事件索引在之前加载的文本中对应的行索引。
## 对于跨多行的事件，返回哪一行可能是随机的。
func get_text_line_from_index(index:int) -> int:
	var line: Variant = text_lines_indexed.find_key(index)
	return line if typeof(line) is int else -1


## 从字符串中加载所有事件资源的方法（如果之前没有加载过）
func process() -> void:
	if len(events) == 0:
		return

	if typeof(events[0]) == TYPE_STRING:
		events_processed = false

	# 如果时间线已经处理过
	if events_processed:
		for event in events:
			event.event_node_ready = true
		return

	var event_cache := DialogicResourceUtil.get_event_cache()
	var end_event := DialogicEndBranchEvent.new()

	var prev_indent := ""
	indent_format = ""
	var processed_events := []
	text_lines_indexed = {}

	# 这是必要的：即使条件/选项为空，也要添加一个结束分支事件
	var prev_was_opener := false

	var lines := events
	var idx := -1
	var empty_lines := 0
	while idx < len(lines)-1:
		idx += 1
		text_lines_indexed[idx] = len(processed_events)

		# 确保使用字符串版本，以防这个事件已经被转换过
		var line := ""
		if typeof(lines[idx]) == TYPE_STRING:
			line = lines[idx]
		else:
			line = lines[idx].event_node_as_text

		## 忽略空行，但把它们记录到 @empty_lines
		var line_stripped: String = line.strip_edges(true, false)
		if line_stripped.is_empty():
			empty_lines += 1
			continue

		## 如果缩进比之前更小，就添加一个结束事件
		var indent: String = line.substr(0,len(line)-len(line_stripped))
		if indent and ((not indent_format) or not (indent_format in indent)):
			if not indent_format.is_empty():
				printerr("时间线包含不一致的缩进。找到 {0}，而期望是 {1}。".format([indent, indent_format]))
			else:
				indent_format = indent
		if len(indent) < len(prev_indent):
			@warning_ignore("integer_division")
			for i in range(len(prev_indent)/len(indent_format)-len(indent)/len(indent_format)):
				processed_events.append(end_event.duplicate())
		## 如果缩进相同但前一个是开启型事件，也添加一个结束事件
		## （例如一个空的选项）
		if prev_was_opener and len(indent) <= len(prev_indent):
			processed_events.append(end_event.duplicate())

		prev_indent = indent

		## 现在把该事件处理成资源
		## 方法是让每个事件检查自己是否能识别这个字符串
		var event_content: String = line_stripped
		var event: DialogicEvent = event_from_string(event_content, event_cache)

		event.empty_lines_above = empty_lines
		# 追加后续行，直到事件表示已完整，或遇到空行为止
		while not event.is_string_full_event(event_content):
			idx += 1
			text_lines_indexed[idx] = len(processed_events)
			if idx == len(lines):
				break

			var following_line_stripped: String = lines[idx].strip_edges(true, false)

			if following_line_stripped.is_empty():
				break

			event_content += "\n"+following_line_stripped

		event.event_node_as_text = event_content
		event._load_from_string(event_content)

		processed_events.append(event)
		prev_was_opener = event.can_contain_events
		empty_lines = 0

	if not prev_indent.is_empty():
		for i in range(len(prev_indent)):
			processed_events.append(end_event.duplicate())

	events = processed_events
	events_processed = true

	if indent_format.is_empty():
		indent_format = "\t"



## 此方法确保时间线中的所有事件都被正确重置
func clean() -> void:
	if not events_processed:
		return
	reference()
	# 这是必要的，否则 GODOT 内部的 ONESHOT 连接
	# 会在它们自行断开之前就被断开。
	await Engine.get_main_loop().process_frame

	for event:DialogicEvent in events:
		for con_in in event.get_incoming_connections():
			con_in.signal.disconnect(con_in.callable)

		for sig in event.get_signal_list():
			for con_out in event.get_signal_connection_list(sig.name):
				con_out.signal.disconnect(con_out.callable)
	unreference()


static func event_from_string(event_content:String, event_cache:Array) -> DialogicEvent:
	for i in event_cache:
		if i._test_event_string(event_content):
			return i.duplicate()
	return DialogicTextEvent.new()
