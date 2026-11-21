extends DialogicSubsystem

## 负责管理历史记录存储的子系统。

signal open_requested
signal close_requested


## 存储有限信息的简单历史记录
## 用于历史记录显示
var simple_history_enabled := false
var simple_history_save := false
@export var simple_history_content : Array[Dictionary] = []
signal simple_history_changed

## 是否保留遇到的每个 Dialogic 事件的历史记录。
var full_event_history_enabled := false
var full_event_history_save := false

## 所有遇到的 Dialogic 事件的完整历史记录。
## 需要 [member full_event_history_enabled] 为 true。
@export var full_event_history_content: Array[String] = []

## 当有新事件插入完整事件历史记录时发出。
signal full_event_history_changed

## 已读文本历史记录
## 保存哪些文本事件和选项已经被访问过
var visited_event_history_enabled := false

## 已访问的 Dialogic 事件的历史记录。
var visited_event_history_content := {}

## 上一个事件是否是首次遇到。
var _visited_last_event := false

## 当遇到的时间线事件被插入已访问
## 事件历史记录时发出。
##
## 每个唯一的事件实例只会触发一次。
signal visited_event

## 当遇到的时间线事件此前未被访问过时发出。
signal unvisited_event

## 用于把 [member visited_event_history_content] 存入全局信息文件。
## 如果你想在全局存档信息文件中使用另一个键，
## 可以把它改成自定义名称。
var visited_event_save_key := "visited_event_history_content"

## 是否在自动保存时自动保存已访问历史记录。
var save_visited_history_on_autosave := false:
	set(value):
		save_visited_history_on_autosave = value
		_update_saved_connection(value)


## 是否在手动保存时自动保存已访问历史记录。
var save_visited_history_on_save := false:
	set(value):
		save_visited_history_on_save = value
		_update_saved_connection(value)


## 建立和断开与 [subsystem Save] 子系统的 [signal saved] 信号的连接。
func _update_saved_connection(to_connect: bool) -> void:
	if to_connect:
		if not DialogicUtil.autoload().Save.saved.is_connected(_on_save):
			DialogicUtil.autoload().Save.saved.connect(_on_save)

	else:
		if DialogicUtil.autoload().Save.saved.is_connected(_on_save):
			DialogicUtil.autoload().Save.saved.disconnect(_on_save)


#region 初始化
####################################################################################################

func _ready() -> void:
	dialogic.event_handled.connect(store_full_event)
	dialogic.event_handled.connect(_check_seen)

	simple_history_enabled = ProjectSettings.get_setting('dialogic/history/simple_history_enabled', simple_history_enabled)
	simple_history_save = ProjectSettings.get_setting('dialogic/history/simple_history_save', simple_history_save)
	full_event_history_enabled = ProjectSettings.get_setting('dialogic/history/full_history_enabled', full_event_history_enabled)
	full_event_history_save = ProjectSettings.get_setting('dialogic/history/full_history_save', full_event_history_save)
	visited_event_history_enabled = ProjectSettings.get_setting('dialogic/history/visited_event_history_enabled', visited_event_history_enabled)



func _on_save(info: Dictionary) -> void:
	var is_autosave: bool = info["is_autosave"]

	var save_on_autosave := save_visited_history_on_autosave and is_autosave
	var save_on_save := save_visited_history_on_save and not is_autosave

	if save_on_save or save_on_autosave:
		save_visited_history()


func _post_install() -> void:
	save_visited_history_on_autosave = ProjectSettings.get_setting('dialogic/history/save_on_autosave', save_visited_history_on_autosave)
	save_visited_history_on_save = ProjectSettings.get_setting('dialogic/history/save_on_save', save_visited_history_on_save)


func _clear_state(clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	if clear_flag != DialogicGameHandler.ClearFlags.FULL_CLEAR:
		return

	simple_history_content = []
	full_event_history_content = []


func _load_state(_load_flag := LoadFlags.FULL_LOAD) -> void:
	pass


func open_history() -> void:
	open_requested.emit()


func close_history() -> void:
	close_requested.emit()

#endregion


#region 精简历史
####################################################################################################

func store_simple_history_entry(text:String, event_type:String, extra_info := {}) -> void:
	if not simple_history_enabled: return
	extra_info["text"] = text
	extra_info["event_type"] = event_type
	simple_history_content.append(extra_info)
	simple_history_changed.emit()


func get_simple_history() -> Array:
	return simple_history_content

#endregion


#region 完整事件历史
####################################################################################################

## 每个事件都会调用。
func store_full_event(event: DialogicEvent) -> void:
	if not full_event_history_enabled: return
	full_event_history_content.append(event.to_text())
	full_event_history_changed.emit()


#region 已读历史
####################################################################################################

## 获取当前时间线事件并为其生成唯一键。
## 同时使用时间线资源路径。
func _current_event_key() -> String:
	var resource_path := dialogic.current_timeline.resource_path
	var event_index := dialogic.current_event_idx
	var event_key := _get_event_key(event_index, resource_path)

	return event_key

## 用事件索引和时间线路径组合出事件键。
## 如果其中任一变量处于无效状态，生成的
## 键可能是错误的。
## 这里没有任何安全检查。
func _get_event_key(event_index: int, timeline_path: String) -> String:
	var event_idx := str(event_index)
	var event_key := timeline_path + event_idx

	return event_key


## 在事件被标记为已访问时调用。
func mark_event_as_visited(event_index := dialogic.current_event_idx, timeline := dialogic.current_timeline) -> void:
	if not visited_event_history_enabled:
		return

	var event_key := _get_event_key(event_index, timeline.resource_path)

	visited_event_history_content[event_key] = event_index


## 每个事件都会调用，但只筛选文本事件。
func _check_seen(event: DialogicEvent) -> void:
	if not visited_event_history_enabled:
		return

	# 此时我们只关心文本事件。
	# 也许有更优雅的事件筛选方式。
	# 尤其是自定义事件也要求使用这个事件名。
	if event.event_name != "Text":
		return

	var event_key := _current_event_key()

	if event_key in visited_event_history_content:
		visited_event.emit()
		_visited_last_event = true

	else:
		unvisited_event.emit()
		_visited_last_event = false


## 上一个事件是否首次被访问。
## 对每个唯一的时间线事件实例，这里只会在第一次返回 `true`。
func has_last_event_been_visited() -> bool:
	return _visited_last_event


## 如果调用时不传参数，方法会返回上一个
## 遇到的事件此前是否被访问过。
##
## 否则，如果传入了 [param event_index] 和 [param timeline]，
## 方法会检查该给定时间线中的
## 事件是否已被访问。
##
## 如果没有传入 [param timeline]，则使用当前时间线。
## 如果没有当前时间线，将返回 `false`。
##
## 如果没有传入 [param event_index]，则使用当前事件索引。
func has_event_been_visited(event_index := dialogic.current_event_idx, timeline := dialogic.current_timeline) -> bool:
	if timeline == null:
		return false

	var event_key := _get_event_key(event_index, timeline.resource_path)
	var visited := event_key in visited_event_history_content

	return visited


## 把所有已见事件保存到全局信息文件。
## 当玩家保存游戏时这会很有用。
## 在视觉小说中，在路线结束时调用它可以很有用，因为
## 玩家可能不会保存游戏。
##
## 注意，这不会新增任何事件，而是完全覆盖已保存的事件。
##
## 依赖 [subsystem Save] 子系统。
func save_visited_history() -> void:
	DialogicUtil.autoload().Save.set_global_info(visited_event_save_key, visited_event_history_content)


## 从全局信息存档文件中读取已见事件。
## 在游戏被读取时调用它会很有用。
##
## 依赖 [subsystem Save] 子系统。
func load_visited_history() -> void:
	visited_event_history_content = get_saved_visited_history()


## 返回全局信息存档文件中保存的已访问历史记录。
## 如果全局信息文件中没有，则返回空字典。
##
## 依赖 [subsystem Save] 子系统。
func get_saved_visited_history() -> Dictionary:
	return DialogicUtil.autoload().Save.get_global_info(visited_event_save_key, {})


## 重置全局信息存档文件中的已访问历史记录。
## 如果 [param reset_property] 为 true，还会重置
## Dialogic 自动加载中的已访问历史记录。
##
## 依赖 [subsystem Save] 子系统。
func reset_visited_history(reset_property := true) -> void:
	DialogicUtil.autoload().Save.set_global_info(visited_event_save_key, {})

	if reset_property:
		visited_event_history_content = {}

#endregion
