class_name DialogicGameHandler
extends Node

## 用作 Dialogic 自动加载的类。

## 自动加载脚本，可让你与 Dialogic 的所有系统交互：[br]
## - 保存 Dialogic 当前状态的所有重要信息。[br]
## - 提供对所有子系统的访问。[br]
## - 提供启动/结束时间线的方法。[br]


## 表示对话不同阶段的状态。
enum States {
	IDLE, 				## Dialogic 正在等待输入以推进。
	REVEALING_TEXT, 	## Dialogic 正在逐字显示文本。
	ANIMATING, 			## 正在播放某段动画。
	AWAITING_CHOICE, 	## Dialogic 正在等待某个选项被选中
	WAITING 			## Dialogic 正在等待某件事。
	}

## 表示调用 [method clear] 时应清空哪些内容的标志。
enum ClearFlags {
	FULL_CLEAR = 0, 		## 清空所有子系统
	KEEP_VARIABLES = 1, 	## 清空所有子系统与信息，但保留变量
	TIMELINE_INFO_ONLY = 2 	## 不清空子系统，只清空当前时间线与索引
	}

## 当前正在执行的时间线的引用。
var current_timeline: DialogicTimeline = null
## [member current_timeline] 事件的副本。
var current_timeline_events: Array = []
## 时间线处理当前所在的事件索引。
var current_event_idx: int = 0

## 当前状态（参见 [member States] 枚举）。
var current_state := States.IDLE:
	get:
		return current_state

	set(new_state):
		current_state = new_state
		state_changed.emit(new_state)

## 当 [member current_state] 改变时发出。
signal state_changed(new_state:States)

## 当为 `true` 时，许多 Dialogic 流程会一直等待，直到它再次变为 `false`。
var paused := false:
	set(value):
		paused = value
		if paused:
			for subsystem in get_children():
				if subsystem is DialogicSubsystem:
					(subsystem as DialogicSubsystem)._pause()

			dialogic_paused.emit()

		else:
			for subsystem in get_children():
				if subsystem is DialogicSubsystem:
					(subsystem as DialogicSubsystem)._resume()

			dialogic_resumed.emit()

## 对话结束时将播放的时间线。
## 默认情况下该时间线只包含一个清空事件。
var dialog_ending_timeline: DialogicTimeline

## 当 [member paused] 变为 `true` 时发出。
signal dialogic_paused
## 当 [member paused] 变为 `false` 时发出。
signal dialogic_resumed


## 当通过调用 [method start]
## 或 [method start_timeline] 启动时间线时发出。
signal timeline_started
## 当时间线结束时发出。
## 这可能是时间线自然结束，也可能是调用了 [method end_timeline]。
signal timeline_ended
## 当一个事件开始执行时发出。
## 此时该事件可能尚未执行完毕。
signal event_handled(resource: DialogicEvent)

## 当抵达 [class SignalEvent] 事件时发出。
@warning_ignore("unused_signal") # 该信号由信号事件发出。
signal signal_event(argument: Variant)

## 当从 [class TextEvent] 事件中触发信号事件时发出。
@warning_ignore("unused_signal") # 该信号由文本子系统发出。
signal text_signal(argument: String)


# 注意：本节会在某些时刻被自动重新填充。
#region 子系统

const AnimationSubsystem = preload("res://addons/dialogic/Modules/Core/subsystem_animation.gd")
var Animations: AnimationSubsystem:
	get: return get_subsystem("Animations")

const AudioSubsystem = preload("res://addons/dialogic/Modules/Audio/subsystem_audio.gd")
var Audio: AudioSubsystem:
	get: return get_subsystem("Audio")

const BackgroundsSubsystem = preload("res://addons/dialogic/Modules/Background/subsystem_backgrounds.gd")
var Backgrounds: BackgroundsSubsystem:
	get: return get_subsystem("Backgrounds")

const ChoicesSubsystem = preload("res://addons/dialogic/Modules/Choice/subsystem_choices.gd")
var Choices: ChoicesSubsystem:
	get: return get_subsystem("Choices")

const ExpressionSubsystem = preload("res://addons/dialogic/Modules/Core/subsystem_expression.gd")
var Expressions: ExpressionSubsystem:
	get: return get_subsystem("Expressions")

const GlossarySubsystem = preload("res://addons/dialogic/Modules/Glossary/subsystem_glossary.gd")
var Glossary: GlossarySubsystem:
	get: return get_subsystem("Glossary")

const HistorySubsystem = preload("res://addons/dialogic/Modules/History/subsystem_history.gd")
var History: HistorySubsystem:
	get: return get_subsystem("History")

const InputsSubsystem = preload("res://addons/dialogic/Modules/Core/subsystem_input.gd")
var Inputs: InputsSubsystem:
	get: return get_subsystem("Inputs")

const JumpSubsystem = preload("res://addons/dialogic/Modules/Jump/subsystem_jump.gd")
var Jump: JumpSubsystem:
	get: return get_subsystem("Jump")

const PortraitContainersSubsystem = preload("res://addons/dialogic/Modules/Character/subsystem_containers.gd")
var PortraitContainers: PortraitContainersSubsystem:
	get: return get_subsystem("PortraitContainers")

const PortraitsSubsystem = preload("res://addons/dialogic/Modules/Character/subsystem_portraits.gd")
var Portraits: PortraitsSubsystem:
	get: return get_subsystem("Portraits")

const SaveSubsystem = preload("res://addons/dialogic/Modules/Save/subsystem_save.gd")
var Save: SaveSubsystem:
	get: return get_subsystem("Save")

const SettingsSubsystem = preload("res://addons/dialogic/Modules/Settings/subsystem_settings.gd")
var Settings: SettingsSubsystem:
	get: return get_subsystem("Settings")

const StylesSubsystem = preload("res://addons/dialogic/Modules/Style/subsystem_styles.gd")
var Styles: StylesSubsystem:
	get: return get_subsystem("Styles")

const TextSubsystem = preload("res://addons/dialogic/Modules/Text/subsystem_text.gd")
var Text: TextSubsystem:
	get: return get_subsystem("Text")

const TextInputSubsystem = preload("res://addons/dialogic/Modules/TextInput/subsystem_text_input.gd")
var TextInput: TextInputSubsystem:
	get: return get_subsystem("TextInput")

const VARSubsystem = preload("res://addons/dialogic/Modules/Variable/subsystem_variables.gd")
var VAR: VARSubsystem:
	get: return get_subsystem("VAR")

const VoiceSubsystem = preload("res://addons/dialogic/Modules/Voice/subsystem_voice.gd")
var Voice: VoiceSubsystem:
	get: return get_subsystem("Voice")

const WaitSubsystem = preload("res://addons/dialogic/Modules/Wait/subsystem_wait.gd")
var Wait: WaitSubsystem:
	get: return get_subsystem("Wait")

#endregion


## 自动加载最先加入，因此这会在游戏启动时非常早地发生。
func _ready() -> void:
	_collect_subsystems()

	clear()

	DialogicResourceUtil.update_event_cache()

	dialog_ending_timeline = DialogicTimeline.new()
	dialog_ending_timeline.from_text("[clear]")

	if OS.is_debug_build():
		instantiate_debug_overlay()


#region 时间线与事件处理
################################################################################

## 启动时间线并确保存在布局场景的方法。
## 参数说明请参见 [method start_timeline]。
## -> 返回布局节点
func start(timeline:Variant, label_or_idx:Variant="") -> Node:
	# 如果没有样式子系统，则默认只调用 start_timeline()
	if not has_subsystem("Styles"):
		printerr("[Dialogic] 你调用了 Dialogic.start()，但样式子系统缺失！")
		clear(ClearFlags.KEEP_VARIABLES)
		start_timeline(timeline, label_or_idx)
		return null

	# 否则确保有一个样式处于激活状态。
	var scene: Node = null
	if not self.Styles.has_active_layout_node():
		scene = self.Styles.load_style()
	else:
		scene = self.Styles.get_layout_node()
		scene.show()

	if not scene.is_node_ready():
		if not scene.ready.is_connected(clear.bind(ClearFlags.KEEP_VARIABLES)):
			scene.ready.connect(clear.bind(ClearFlags.KEEP_VARIABLES))
		if not scene.ready.is_connected(start_timeline.bind(timeline, label_or_idx)):
			scene.ready.connect(start_timeline.bind(timeline, label_or_idx))
	else:
		start_timeline(timeline, label_or_idx)

	return scene


## 在不添加布局场景的情况下启动时间线的方法。
## [param timeline] 可以是已加载的时间线资源，也可以是时间线文件的路径。
## [param label_or_idx] 可以是标签（字符串）或索引（整数），用于立即跳转到该位置。
func start_timeline(timeline:Variant, label_or_idx:Variant = "") -> void:
	# 若只给了路径，则加载该资源
	if typeof(timeline) in [TYPE_STRING, TYPE_STRING_NAME]:
		# 若不是完整文件名，则查询查找表
		if "://" in timeline:
			timeline = load(timeline)
		else:
			timeline = DialogicResourceUtil.get_timeline_resource(timeline)

	if timeline == null:
		printerr("[Dialogic] 加载此时间线时出错。请检查文件名，以及该时间线本身是否有错误")
		return

	(timeline as DialogicTimeline).process()

	current_timeline = timeline
	current_timeline_events = current_timeline.events
	for event in current_timeline_events:
		event.dialogic = self
	current_event_idx = -1

	if typeof(label_or_idx) in [TYPE_STRING, TYPE_STRING_NAME]:
		if label_or_idx:
			if has_subsystem("Jump"):
				Jump.jump_to_label((label_or_idx as String))
	elif typeof(label_or_idx) == TYPE_INT:
		if label_or_idx >-1:
			current_event_idx = label_or_idx -1

	if not current_timeline == dialog_ending_timeline:
		timeline_started.emit()

	handle_next_event()


## 预加载函数：准备一条时间线，并返回一个对象供之后使用
## [param timeline_resource] 可以是路径（字符串）或已加载的时间线（资源）
func preload_timeline(timeline_resource:Variant) -> Variant:
	# 我认为理想情况下这应该放在新线程上，待测试
	if typeof(timeline_resource) in [TYPE_STRING, TYPE_STRING_NAME]:
		if "://" in timeline_resource:
			timeline_resource = load(timeline_resource)
		else:
			timeline_resource = DialogicResourceUtil.get_timeline_resource(timeline_resource)

		if timeline_resource == null:
			printerr("[Dialogic] 预加载此时间线时出错。请检查文件名，以及该时间线本身是否有错误")
			return null

	(timeline_resource as DialogicTimeline).process()

	return timeline_resource


## 清空并停止当前时间线。
## 若 [param skip_ending] 为 `true`，则不会播放 dialog_ending_timeline
func end_timeline(skip_ending := false) -> void:
	if not skip_ending and dialog_ending_timeline and current_timeline != dialog_ending_timeline:
		start(dialog_ending_timeline)
		return

	await clear(ClearFlags.TIMELINE_INFO_ONLY)

	if Styles.has_active_layout_node() and Styles.get_layout_node().is_inside_tree():
		match ProjectSettings.get_setting("dialogic/layout/end_behaviour", 0):
			0:
				Styles.get_layout_node().get_parent().remove_child(Styles.get_layout_node())
				Styles.get_layout_node().queue_free()
			1:
				Styles.get_layout_node().hide()

	timeline_ended.emit()


## 检查时间线是否存在的方法。
## @timeline 可以是已加载的时间线资源，也可以是时间线文件的路径。
func timeline_exists(timeline:Variant) -> bool:
	if typeof(timeline) in [TYPE_STRING, TYPE_STRING_NAME]:
		if "://" in timeline and ResourceLoader.exists(timeline):
			return load(timeline) is DialogicTimeline
		else:
			return DialogicResourceUtil.timeline_resource_exists(timeline)

	return timeline is DialogicTimeline


## 处理下一个事件。
func handle_next_event(_ignore_argument: Variant = "") -> void:
	handle_event(current_event_idx+1)


## 处理给定索引 [param event_index] 处的事件。
## 你可以手动调用它，但若还有另一个事件正在执行，可能会产生意外结果。
func handle_event(event_index:int) -> void:
	if not current_timeline:
		return

	_cleanup_previous_event()

	if paused:
		await dialogic_resumed

	if event_index >= len(current_timeline_events):
		end_timeline()
		return

	# TODO: 检查是否必要。这应该不可能发生。
	# 现在真正处理该事件，因为运行时之前并未处理
	# 这一步必须在我们创建 DialogicEvent 副本变量之前完成，以免未就绪时抛出错误
	if current_timeline_events[event_index].event_node_ready == false:
		current_timeline_events[event_index]._load_from_string(current_timeline_events[event_index].event_node_as_text)

	current_event_idx = event_index

	if not current_timeline_events[event_index].event_finished.is_connected(handle_next_event):
		current_timeline_events[event_index].event_finished.connect(handle_next_event)

	set_meta("previous_event", current_timeline_events[event_index])

	current_timeline_events[event_index].execute(self)
	event_handled.emit(current_timeline_events[event_index])


## 完全或部分重置 Dialogic 的状态。
## 通过使用 [member ClearFlags] 枚举中的清空标志，你可以指定
## 应保留哪些信息。
## 例如在时间线结束时，通常不会清空节点或子系统信息。
func clear(clear_flags := ClearFlags.FULL_CLEAR) -> void:
	_cleanup_previous_event()

	if not clear_flags & ClearFlags.TIMELINE_INFO_ONLY:
		for subsystem in get_children():
			if subsystem is DialogicSubsystem:
				(subsystem as DialogicSubsystem)._clear_state(clear_flags)

	current_event_idx = -1
	current_timeline_events = []
	current_state = States.IDLE

	# 重置变量
	var previous_timeline := current_timeline
	current_timeline = null
	if previous_timeline:
		await previous_timeline.clean()


## 清理上一个事件（如果有）。
func _cleanup_previous_event():
	if has_meta("previous_event") and get_meta("previous_event") is DialogicEvent:
		var event := get_meta("previous_event") as DialogicEvent
		if event.event_finished.is_connected(handle_next_event):
			event.event_finished.disconnect(handle_next_event)
		event._clear_state()
		remove_meta("previous_event")

#endregion


#region 保存与加载
################################################################################


## 返回一个字典，包含之后用 load_full_state 重建相同状态所需的全部信息。
## [subsystem Save] 子系统可能对你更有用。
## 不过，你也可以用它把信息集成到你自己的存档系统中。
func get_full_state() -> DialogicSaveState:
	var state := DialogicSaveState.new()
	if current_timeline:
		state.event_index = current_event_idx
		state.timeline = current_timeline.resource_path
	else:
		state.event_index = -1
		state.timeline = ""

	for subsystem in get_children():
		var sub_state := (subsystem as DialogicSubsystem).get_state()
		if sub_state:
			state.subsystems[subsystem.name] = sub_state

	return state


## 此方法尝试从给定的 [param state_info] 加载状态。
## 若在取用 [method get_full_state] 获取该字典时
## 有正在运行的时间线，则会自动启动它并添加布局。
func load_full_state(state:DialogicSaveState) -> void:
	await clear()

	if state == null:
		printerr("[Dialogic] 尝试加载状态，但给定的状态为 [null]。")
		return

	for subsystem in get_children():
		if subsystem.name in state.subsystems:
			subsystem.unpack_state(state.subsystems[subsystem.name])

	### 样式子系统必须先运行，其他子系统才能正确加载。
	var scene: Node = null
	if has_subsystem("Styles"):
		get_subsystem("Styles").load_state()
		scene = self.Styles.get_layout_node()

	var load_subsystems := func() -> void:
		for subsystem in get_children():
			if subsystem.name == "Styles":
				continue
			(subsystem as DialogicSubsystem).load_state()

	if null != scene and not scene.is_node_ready():
		scene.ready.connect(load_subsystems)
	else:
		await get_tree().process_frame
		load_subsystems.call()
#
	if state.timeline:
		start_timeline(state.timeline, state.event_index)
	else:
		end_timeline.call_deferred(true)

#endregion


#region 下级子系统
################################################################################

func _collect_subsystems() -> void:
	var subsystem_nodes := [] as Array[DialogicSubsystem]
	for indexer in DialogicUtil.get_indexers():
		for subsystem in indexer._get_subsystems():
			var subsystem_node := add_subsystem(str(subsystem.name), str(subsystem.script))
			subsystem_nodes.push_back(subsystem_node)

	for subsystem in subsystem_nodes:
		subsystem._post_install()


## 如果存在名为 [param subsystem_name] 的子系统，则返回 `true`。
func has_subsystem(subsystem_name:String) -> bool:
	return has_node(subsystem_name)


## 返回给定 [param subsystem_name] 的子系统节点，若不存在则返回 null。
func get_subsystem(subsystem_name:String) -> DialogicSubsystem:
	return get_node(subsystem_name)


## 添加一个具有给定 [param subsystem_name] 与 [param script_path] 的子系统节点。
func add_subsystem(subsystem_name:String, script_path:String) -> DialogicSubsystem:
	var existing_subsystem_node = get_node_or_null(subsystem_name)

	# 若两个子系统名称相同，则用新的覆盖已存在的那个
	if is_instance_valid(existing_subsystem_node):
		existing_subsystem_node.set_script(load(script_path))
		existing_subsystem_node.dialogic = self
		existing_subsystem_node._ready()
		return existing_subsystem_node

	var node: Node = Node.new()
	node.name = subsystem_name
	node.set_script(load(script_path))
	node = node as DialogicSubsystem
	node.dialogic = self
	add_child(node)
	return node


#endregion


#region 辅助方法
################################################################################

func print_debug_moment() -> void:
	if not current_timeline:
		return

	printerr("\t> 位于 {timeline_identifier}（{timeline_path}）第 {line} 行，事件 {event_idx}（{event_name} 事件）。".format(
		{
			"event_idx": current_event_idx+1,
			"event_name":current_timeline_events[current_event_idx].event_name,
			"timeline_identifier": current_timeline.get_identifier(),
			"timeline_path":current_timeline.resource_path,
			"line":current_timeline.get_text_line_from_index(current_event_idx+1)
		}))
	print("\n")


func instantiate_debug_overlay() -> void:
	var overlay: Node = load("res://addons/dialogic/Editor/TimelineEditor/dialogic_debug_overlay.tscn").instantiate()
	get_parent().add_child.call_deferred(overlay)

#endregion
