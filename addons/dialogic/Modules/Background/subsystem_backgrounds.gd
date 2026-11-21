extends DialogicSubsystem
## 用于管理背景的子系统。
##
## 该子系统提供了许多用于管理背景的辅助方法。
## 例如，你可以通过
## [signal background_changed] 监听背景变化。


## 每当设置新的背景时，会发出该信号，其中包含一个
## 字典，键如下：[br]
## [br]
## 键          |   值类型      | 说明 [br]
## ----------- | ------------- | ----- [br]
## `scene`     | [type String] | 新背景的场景路径。[br]
## `argument`  | [type String] | 在更新例程中传给背景的信息。[br]
## `fade_time` | [type float]  | 背景过渡进入可能需要的时长。[br]
## `same_scene`| [type bool]   | 新背景是否使用同一个 Godot 场景。[br]
signal background_changed(info: Dictionary)

@export_group("State")
@export var scene := ""
@export var argument := ""

## Dialogic 将使用的默认背景场景。
var default_background_scene: PackedScene = load(get_script().resource_path.get_base_dir().path_join('DefaultBackgroundScene/default_background.tscn'))
## Dialogic 将使用的默认过渡。
var default_transition: String = get_script().resource_path.get_base_dir().path_join("Transitions/Defaults/simple_fade.gd")


#region 状态
####################################################################################################

## 清空当前的背景状态。
func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	update_background()


## 从当前状态信息中加载背景状态。
func _load_state(_load_flag := LoadFlags.FULL_LOAD) -> void:
	update_background(scene, argument, 0.0, default_transition, true)

	if get_background_node():
		get_background_node()._load_state(get_extra_state())


func _pack_extra_state() -> Dictionary:
	if get_background_node():
		return get_background_node()._get_state()
	return {}

#endregion


#region 主要方法
####################################################################################################

## 将给定场景作为 DialogicNode_BackgroundHolder 的子节点添加的方法。
## 它会用给定参数 [argument] 在该场景上调用 [_update_background()]。
## 它会用给定的淡入时长在该场景上调用 [_fade_in()]。
## 会对先前的背景场景调用 fade_out。
##
## 如果场景与上一个背景相同，你可以跳过一次实例化
## 而直接使用同一个场景。
## 为此请在自定义背景场景上实现 [_should_do_background_update()]。
## 之后 [_update_background()] 将直接在那个先前的场景上调用。
func update_background(new_scene := "", new_argument := "", fade_time := 0.0, transition_path:=default_transition, force := false) -> void:
	var background_holder: DialogicNode_BackgroundHolder
	if dialogic.has_subsystem('Styles'):
		background_holder = dialogic.Styles.get_first_node_in_layout('dialogic_background_holders')
	else:
		background_holder = get_tree().get_first_node_in_group('dialogic_background_holders')

	var info := {'scene':new_scene, 'argument':new_argument, 'fade_time':fade_time, 'same_scene':false}
	if background_holder == null:
		background_changed.emit(info)
		return


	var bg_set := false

	# 先尝试仅更新现有场景。
	if new_scene == scene:

		if not force and new_argument == argument:
			return

		for old_bg in background_holder.get_children():
			if not old_bg.has_meta('node') or not old_bg.get_meta('node') is DialogicBackground:
				continue

			var prev_bg_node: DialogicBackground = old_bg.get_meta('node')
			if prev_bg_node._should_do_background_update(new_argument):
				prev_bg_node._update_background(new_argument, fade_time)
				bg_set = true
				info['same_scene'] = true

	scene = new_scene
	argument = new_argument

	if bg_set:
		background_changed.emit(info)
		return

	var old_viewport: SubViewportContainer = null
	if background_holder.has_meta('current_viewport'):
		old_viewport = background_holder.get_meta('current_viewport', null)

	var new_viewport: SubViewportContainer

	if scene.ends_with('.tscn') and ResourceLoader.exists(scene):
		new_viewport = add_background_node(load(scene), background_holder)
	elif argument:
		new_viewport = add_background_node(default_background_scene, background_holder)
	else:
		new_viewport = null

	# 如果仍有过渡正在进行，立即停止它
	for node in get_children():
		if node is DialogicBackgroundTransition:
			node.queue_free()


	var trans_script: Script = load(DialogicResourceUtil.guess_special_resource("BackgroundTransition", transition_path, {"path":default_transition}).path)
	var trans_node := Node.new()
	trans_node.set_script(trans_script)
	trans_node = (trans_node as DialogicBackgroundTransition)
	trans_node.bg_holder = background_holder
	trans_node.time = fade_time

	if old_viewport:
		old_viewport.name = "OldBackground"
		trans_node.prev_scene = old_viewport.get_meta('node', null)
		trans_node.prev_texture = old_viewport.get_child(0).get_texture()
		old_viewport.get_meta('node')._custom_fade_out(fade_time)
		old_viewport.hide()
		# TODO 由于 https://github.com/godotengine/godot/issues/23729 我们不得不在这里再调用一次
		old_viewport.get_child(0).render_target_update_mode = SubViewport.UPDATE_ALWAYS
		trans_node.transition_finished.connect(old_viewport.queue_free)
	if new_viewport:
		new_viewport.name = "NewBackground"
		trans_node.next_scene = new_viewport.get_meta('node', null)
		trans_node.next_texture = new_viewport.get_child(0).get_texture()
		new_viewport.get_meta('node')._update_background(argument, fade_time)
		new_viewport.get_meta('node')._custom_fade_in(fade_time)
	else:
		background_holder.remove_meta('current_viewport')

	add_child(trans_node)
	if fade_time == 0:
		trans_node.transition_finished.emit()
		_on_transition_finished(background_holder, trans_node)
	else:
		trans_node.transition_finished.connect(_on_transition_finished.bind(background_holder, trans_node))
		# 如果 background_holder 在过渡期间被移除，我们需要断开这个连接
		background_holder.tree_exited.connect(trans_node.disconnect.bind("transition_finished", _on_transition_finished))
		trans_node._fade()

	background_changed.emit(info)


func _on_transition_finished(background_node:DialogicNode_BackgroundHolder, transition_node:DialogicBackgroundTransition) -> void:
	if background_node.has_meta("current_viewport"):
		if background_node.get_meta("current_viewport").get_meta("node", null) == transition_node.next_scene:
			background_node.get_meta("current_viewport").show()
	background_node.material = null
	background_node.color = Color.TRANSPARENT
	transition_node.queue_free()


## 将给定背景场景的子视口作为子节点添加到
## Dialogic 场景。
func add_background_node(new_scene:PackedScene, parent:DialogicNode_BackgroundHolder) -> SubViewportContainer:
	var v_con := SubViewportContainer.new()
	var viewport := SubViewport.new()
	var b_scene := new_scene.instantiate()
	if not b_scene is DialogicBackground:
		printerr("[Dialogic] 给定的背景场景不是 DialogicBackground 类型！请确保该场景的脚本继承自 DialogicBackground。")
		v_con.queue_free()
		viewport.queue_free()
		b_scene.queue_free()
		return null

	parent.add_child(v_con)
	v_con.hide()
	v_con.stretch = true
	v_con.size = parent.size
	v_con.set_anchors_preset(Control.PRESET_FULL_RECT)

	v_con.add_child(viewport)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	if parent.get_parent().get("bg_texture_filter") != null and parent.get_parent().bg_texture_filter > -1:
		viewport.canvas_item_default_texture_filter = parent.get_parent().bg_texture_filter
	else:
		viewport.canvas_item_default_texture_filter = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")

	if parent.get_parent().get("bg_texture_repeat") != null and parent.get_parent().bg_texture_repeat > -1:
		viewport.canvas_item_default_texture_repeat = parent.get_parent().bg_texture_repeat
	else:
		viewport.canvas_item_default_texture_repeat = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_repeat")

	viewport.add_child(b_scene)
	b_scene.viewport = viewport
	b_scene.viewport_container = v_con

	parent.set_meta('current_viewport', v_con)
	v_con.set_meta('node', b_scene)

	return v_con


## 是否已设置背景。
func has_background() -> bool:
	return not (scene.is_empty() and argument.is_empty())


func get_background_node() -> DialogicBackground:
	var background_holder := get_tree().get_first_node_in_group("dialogic_background_holders")
	if not background_holder or background_holder.get_child_count() == 0:
		return null
	return background_holder.get_child(-1).get_child(0).get_child(0)

#endregion
