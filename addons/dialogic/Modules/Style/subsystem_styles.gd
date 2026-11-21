extends DialogicSubsystem

## 负责加载应用了特定样式的布局的子系统。

signal style_changed(info:Dictionary)

@export_group("状态")
@export var style := ""
@export var base_style := ""


#region 状态
####################################################################################################

func _ready() -> void:
	DialogicStylesUtil.update_style_directory()


func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	pass
	base_style = ""


func _load_state(load_flag := LoadFlags.FULL_LOAD) -> void:
	if load_flag == LoadFlags.ONLY_DNODES:
		return

	if get_extra_state().get("active_layout", false):
		load_style(style)


func _pack_extra_state() -> Dictionary:
	return {"active_layout":has_active_layout_node()}

#endregion


#region 主要方法
####################################################################################################

## 这个辅助方法会调用 load_style，但把 [parameter state_reload] 设为 true，
## 当你预期游戏已经进行中时，通常就需要这样。
func change_style(style_name := "", is_base_style := true) -> Node:
	return load_style(style_name, null, is_base_style, true)


## 加载一个样式。如果已有样式在使用中而你想切换样式，考虑使用更简单的 [method change_style]。
## [br] 如果 [param state_reload] 为 true，当前状态会被加载进新的布局场景节点。
## 这不应该在调用 start() 或 load() 之前进行，因为那样没有必要，或者会导致重复加载。
func load_style(style_name := "", parent: Node = null, is_base_style := true, state_reload := false) -> Node:
	var style_resource := DialogicStylesUtil.get_style(style_name)

	var signal_info := {'style':style_name}
	style = style_name

	# 只有在角色样式这类临时改动中，is_base_style 才应该为 false
	if is_base_style:
		base_style = style_name

	var previous_layout := get_layout_node()
	if is_instance_valid(previous_layout) and previous_layout.has_meta('style'):
		signal_info['previous'] = previous_layout.get_meta('style').name

		# 如果样式和场景都相同，就什么都不做
		if previous_layout.get_meta('style') == style_resource:
			return previous_layout

		# 如果场景设置相同，只需应用新的覆盖项
		elif previous_layout.get_meta('style') == style_resource.get_inheritance_root() or previous_layout.get_meta('style').get_inheritance_root() == style_resource.get_inheritance_root():
			DialogicUtil.apply_scene_export_overrides(previous_layout, style_resource.get_layer_inherited_info("").overrides)
			var index := 0
			for layer in previous_layout.get_layers():
				DialogicUtil.apply_scene_export_overrides(
					layer,
					style_resource.get_layer_inherited_info(style_resource.get_layer_id_at_index(index)).overrides)
				index += 1

			previous_layout.set_meta('style', style_resource)
			style_changed.emit(signal_info)
			return

		else:
			parent = previous_layout.get_parent()

			parent.remove_child(previous_layout)
			previous_layout.queue_free()

	# 如果这是另一个样式：
	var new_layout := create_layout(style_resource, parent)
	if state_reload:
		# 切换样式时保留 process_mode
		if previous_layout:
			new_layout.process_mode = previous_layout.process_mode

		new_layout.ready.connect(reload_current_info_into_new_style)

	style_changed.emit(signal_info)

	return new_layout


## 添加一个包含所有必要图层的布局场景的方法。
## 布局场景会被添加到树根，并被返回。
func create_layout(style_resource: DialogicStyle, parent: Node = null) -> DialogicLayoutBase:

	# 加载基础场景
	var base_scene: DialogicLayoutBase
	var base_layer_info := style_resource.get_layer_inherited_info("")
	if base_layer_info.path.is_empty():
		base_scene = DialogicStylesUtil.get_default_layout_base().instantiate()
	else:
		base_scene = load(base_layer_info.path).instantiate()

	base_scene.name = "DialogicLayout_"+style_resource.name.to_pascal_case()

	# 应用基础场景覆盖项
	DialogicUtil.apply_scene_export_overrides(base_scene, base_layer_info.overrides)

	# 加载图层
	for layer_id in style_resource.get_layer_inherited_list():
		var layer := style_resource.get_layer_inherited_info(layer_id)

		if not ResourceLoader.exists(layer.path):
			continue

		var layer_scene: DialogicLayoutLayer = null

		if ResourceLoader.load_threaded_get_status(layer.path) == ResourceLoader.THREAD_LOAD_LOADED:
			layer_scene = ResourceLoader.load_threaded_get(layer.path).instantiate()
		else:
			layer_scene = load(layer.path).instantiate()

		base_scene.add_layer(layer_scene)

		# 应用图层覆盖项
		DialogicUtil.apply_scene_export_overrides(layer_scene, layer.overrides)

	base_scene.set_meta('style', style_resource)

	if parent == null:
		parent = dialogic.get_parent()
	parent.call_deferred("add_child", base_scene)

	dialogic.get_tree().set_meta('dialogic_layout_node', base_scene)

	return base_scene


## 当切换到另一个布局场景时，
## 我们必须把所有信息重新加载进新布局的节点中。
func reload_current_info_into_new_style() -> void:
	for subsystem in dialogic.get_children():
		subsystem._load_state(LoadFlags.ONLY_DNODES)


## 返回当前正在使用的样式
func get_current_style() -> String:
	if has_active_layout_node():
		var style_resource: DialogicStyle = get_layout_node().get_meta('style', null)
		if style_resource:
			return style_resource.name
	return ''


func has_active_layout_node() -> bool:
	return (
		get_tree().has_meta('dialogic_layout_node')
		and is_instance_valid(get_tree().get_meta('dialogic_layout_node'))
		and not get_tree().get_meta('dialogic_layout_node').is_queued_for_deletion()
	)


func get_layout_node() -> DialogicLayoutBase:
	if has_active_layout_node():
		return get_tree().get_meta('dialogic_layout_node')
	return null


## 类似 get_tree().get_first_node_in_group('group_name')，但只筛选当前活动布局节点的子树
func get_first_node_in_layout(group_name: String) -> Node:
	var layout_node := get_layout_node()
	if null == layout_node:
		return null
	var nodes := get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		if layout_node.is_ancestor_of(node):
			return node
	return null


func preload_style(name_or_path:String = "") -> void:
	DialogicStylesUtil.start_style_preload(name_or_path)

#endregion
