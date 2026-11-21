extends DialogicSubsystem

## 管理立绘与立绘位置的子系统。

signal character_joined(info:Dictionary)
signal character_left(info:Dictionary)
signal character_portrait_changed(info:Dictionary)
signal character_moved(info:Dictionary)

## 立绘开始播放动画时发出。
#signal portrait_animating(character_node: Node, portrait_node: Node, animation_name: String, animation_length: float)

@export_group("State")
@export var portraits := {}

var character_nodes: Dictionary[String, Node] = {}

## 默认立绘场景。
var default_portrait_scene: PackedScene = load(get_script().resource_path.get_base_dir().path_join('default_portrait.tscn'))


#region 状态
####################################################################################################

func _clear_state(_clear_flag := DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	for character_node in character_nodes.values():
		_remove_character(character_node)
	portraits.clear()
	character_nodes.clear()


func _load_state(_load_flag := LoadFlags.FULL_LOAD) -> void:
	# 加载位置立绘
	var portraits_info: Dictionary = portraits.duplicate()
	portraits = {}
	var portrait_states: Dictionary = get_extra_state().get("portrait_state", {})
	for character_identifier in portraits_info:
		if not portraits_info.get("joined", true):
			continue
		var character_info: Dictionary = portraits_info[character_identifier]
		var character: DialogicCharacter = DialogicResourceUtil.get_character_resource(character_identifier)
		if character:
			var container := dialogic.PortraitContainers.load_position_container(character.get_character_name())
			await add_character(character, container, character_info.portrait, character_info.position_id)
			character_nodes[character.get_identifier()].get_child(-1)._load_state(portrait_states.get(character.get_identifier(), {}))
		else:
			push_error('[Dialogic] 加载角色失败："' + str(character_identifier) + '"。')

	# 加载说话者立绘
	var speaker: Variant = dialogic.Text.speaker_identifier
	var speaker_char: DialogicCharacter = DialogicResourceUtil.get_character_resource(speaker)
	if speaker:
		# TODO ??
		dialogic.Text.speaker_identifier = ""
		change_speaker(speaker_char, portraits_info.get(speaker_char.get_identifier(), {}).get("portrait", ""))

	dialogic.Text.speaker_identifier = speaker


func _pack_extra_state() -> Dictionary:
	var portrait_state := {}
	for i in character_nodes:
		portrait_state[i] = character_nodes[i].get_child(-1)._get_state()
	return {"portrait_state":portrait_state}


func _pause() -> void:
	for node in character_nodes.values():
		if node.has_meta('animation_node'):
			node.get_meta('animation_node').pause()


func _resume() -> void:
	for node in character_nodes.values():
		if node.has_meta('animation_node'):
			node.get_meta('animation_node').resume()


func _ready() -> void:
	if not ProjectSettings.get_setting('dialogic/portraits/default_portrait', '').is_empty():
		default_portrait_scene = load(ProjectSettings.get_setting('dialogic/portraits/default_portrait', ''))


#region 主要方法
####################################################################################################
## 以下方法用于操作立绘。
## 立绘由一个角色节点 [Node2D] 构成，该节点把立绘场景实例化为自己的子节点。
## 角色节点始终是立绘容器的子节点。
## - 位置（PortraitContainer）
## ---- character_node（Node2D）
## --------- portrait_node（例如 default_portrait.tscn，或自定义立绘）
##
## 使用这些主要方法，一个角色可以同时出现多次。
## 对于视觉小说风格，"character" 系列方法（下一节）以角色为单位提供访问。
## -（角色事件使用的正是这些方法）


## 为给定的 [character] 创建新的 [character node]，并将其添加到给定的 [portrait container] 中。
func _create_character_node(character:DialogicCharacter, container:DialogicNode_PortraitContainer) -> Node:
	if container == null:
		return null
	var character_node := Node2D.new()
	character_node.name = character.get_character_name().validate_node_name()
	character_node.set_meta("character", character)
	container.add_child(character_node)
	return character_node


## 更改指定 [character node] 的立绘。
func _change_portrait(character_node: Node2D, portrait: String, fade_animation:="", fade_length := 0.5) -> Dictionary:
	var character: DialogicCharacter = character_node.get_meta('character')

	if portrait.is_empty():
		portrait = character.default_portrait

	var info := {'character':character, 'portrait':portrait, 'same_scene':false}

	if not portrait in character.portraits.keys():
		print_debug('[Dialogic] 切换到不存在的立绘将被忽略！')
		return info

	# 要使用的场景路径。
	var scene_path: String = character.portraits[portrait].get('scene', '')

	var portrait_node: Node = null
	var previous_portrait: Node = null
	var portrait_count := character_node.get_child_count()
	var copy_state_vars := {}

	if portrait_count > 0:
		previous_portrait = character_node.get_child(-1)

	# 检查该场景是否与当前已加载的场景相同。
	if previous_portrait != null and previous_portrait.get_meta("scene", "") == scene_path:
		# 同时检查该场景是否支持切换到指定立绘。
		if previous_portrait is DialogicPortrait:
			for i in previous_portrait.get_property_list():
				if i.name.begins_with("state_"):
					copy_state_vars[i.name] = previous_portrait.get(i.name)
			if previous_portrait._should_do_portrait_update(character, portrait):
				portrait_node = previous_portrait
				info["same_scene"] = true

	if portrait_node == null:
		if previous_portrait: previous_portrait.name = "Previous_Portrait"
		if ResourceLoader.exists(scene_path):
			ResourceLoader.load_threaded_request(scene_path)

			var load_status := ResourceLoader.load_threaded_get_status(scene_path)
			while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				await get_tree().process_frame
				load_status = ResourceLoader.load_threaded_get_status(scene_path)

			if load_status == ResourceLoader.THREAD_LOAD_LOADED:
				var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path)
				if packed_scene:
					portrait_node = packed_scene.instantiate()
				else:
					push_error('[Dialogic] 立绘节点 "' + str(scene_path) + '"（角色 [' + character.display_name + ']）无法加载。你的立绘可能不会显示在屏幕上。请确认路径正确。')
			else:
				push_error('[Dialogic] 加载立绘节点 "' + str(scene_path) + '" 失败（角色 [' + character.display_name + ']）。')

		if not portrait_node:
			portrait_node = default_portrait_scene.instantiate()
			portrait_node.name = portrait.validate_node_name()

		portrait_node.set_meta('scene', scene_path)


	if portrait_node:
		for i in copy_state_vars:
			if i in portrait_node:
				portrait_node.set(i, copy_state_vars[i])

		portrait_node.set_meta('portrait', portrait)
		character_node.set_meta('portrait', portrait)

		DialogicUtil.apply_scene_export_overrides(portrait_node, character.portraits[portrait].get('export_overrides', {}))

		if portrait_node.has_method('_update_portrait'):
			portrait_node._update_portrait(character, portrait)

		if not portrait_node.is_inside_tree():
			character_node.add_child(portrait_node)

		## 处理交叉动画
		if previous_portrait and previous_portrait != portrait_node:
			if not fade_animation.is_empty() and fade_length > 0:
				var fade_out := _animate_node(previous_portrait, fade_animation, fade_length, 1, true)
				var _fade_in := _animate_node(portrait_node, fade_animation, fade_length, 1, false)
				fade_out.finished.connect(previous_portrait.queue_free)
			else:
				previous_portrait.queue_free()

	return info


## 更改指定角色的镜像。
func _change_portrait_mirror(character_node: Node2D, mirrored := false) -> void:
	dialogic.PortraitContainers.update_container(character_node.get_parent(), "mir="+str(mirrored), 0)


func _change_portrait_extradata(character_node: Node2D, extra_data := "") -> void:
	if not is_instance_valid(character_node):
		push_error("[Dialogic] 提供的角色节点无效。")
		return

	if character_node.get_child_count() > 0:
		var latest_portrait := character_node.get_child(-1)

		if latest_portrait and latest_portrait.has_method("_set_extra_data"):
			latest_portrait._set_extra_data(extra_data)
	else:
		push_warning("[Dialogic] 未找到该角色节点的立绘：" + character_node.name)


## 用指定动画为节点播放动画。
## 既用于角色节点（大多数动画），也用于立绘节点（交叉淡入淡出动画）
func _animate_node(node: Node, animation_path: String, length: float, repeats := 1, is_reversed := false, repeat_forever := false) -> DialogicAnimation:
	if node.has_meta('animation_node') and is_instance_valid(node.get_meta('animation_node')):
		node.get_meta('animation_node').queue_free()

	var anim_script: Script = load(animation_path)
	var anim_node := Node.new()
	anim_node.set_script(anim_script)
	anim_node = (anim_node as DialogicAnimation)
	anim_node.name = node.name +"_"+animation_path.get_file().trim_suffix(".gd").validate_node_name()
	anim_node.node = node
	anim_node.base_position = node.position
	anim_node.base_scale = node.scale
	anim_node.time = length
	anim_node.repeats = repeats
	anim_node.repeat_forever = repeat_forever
	anim_node.is_reversed = is_reversed

	add_child(anim_node)
	anim_node.animate()

	node.set_meta("animation_path", animation_path)
	node.set_meta("animation_length", length)
	node.set_meta("animation_node", anim_node)

	#if not is_silent:
		#portrait_animating.emit(portrait_node.get_parent(), portrait_node, animation_path, length)

	return anim_node


## 将指定立绘移动到指定容器。
func _move_character(character_node: Node2D, transform:="", time := 0.0, easing:= Tween.EASE_IN_OUT, trans:= Tween.TRANS_SINE) -> void:
	var container: DialogicNode_PortraitContainer = character_node.get_parent()
	dialogic.PortraitContainers.update_container(container, transform, time, easing, trans)#, false)


## 更改指定角色的 z_index。
func _change_portrait_z_index(character_node: Node, z_index:int, update_zindex:= true) -> void:
	if update_zindex:
		dialogic.PortraitContainers.update_container(character_node.get_parent(), "z="+str(z_index), 0)


## 检查 [para, character] 是否已加入场景，若是则返回其
## 处于活动状态的 [DialogicPortrait] 节点。
##
## 活动节点与非活动节点的区别在于该节点是否为
## 最新的节点。[br]
## 如果立绘正在从立绘 A 过渡/动画到 B，两者都会
## 存在于场景中，但只有新立绘是活动的，即使它尚未
## 完全可见。
func get_character_portrait(character: DialogicCharacter) -> DialogicPortrait:
	if is_character_joined(character):
		var portrait_node: DialogicPortrait = character_nodes[character.get_identifier()].get_child(-1)
		return portrait_node

	return null


## 移除 [param portrait_node] 的私有方法。
func _remove_portrait(portrait_node: Node) -> void:
	portrait_node.get_parent().remove_child(portrait_node)
	portrait_node.queue_free()



## 移除指定角色的立绘。
## 仅对已加入的角色有效。
func _remove_character(character_node:Node) -> void:
	if is_instance_valid(character_node) and character_node is Node:
		character_left.emit({'character': character_node.get_meta("character")})
		var container := character_node.get_parent()
		container.get_parent().remove_child(container)
		container.queue_free()
		character_node.queue_free()



## 获取角色加入时的默认动画长度
## 若启用了自动跳过，则限制该时长。
func _get_join_default_length() -> float:
	var default_time: float = ProjectSettings.get_setting('dialogic/animations/join_default_length', 0.5)

	if dialogic.Inputs.auto_skip.enabled:
		default_time = min(default_time, dialogic.Inputs.auto_skip.time_per_event)

	return default_time


## 获取角色离开时的默认动画长度
## 若启用了自动跳过，则限制该时长。
func _get_leave_default_length() -> float:
	var default_time: float = ProjectSettings.get_setting('dialogic/animations/leave_default_length', 0.5)

	if dialogic.Inputs.auto_skip.enabled:
		default_time = min(default_time, dialogic.Inputs.auto_skip.time_per_event)

	return default_time


## 检查多种情况，返回可用的有效立绘。
func get_valid_portrait(character:DialogicCharacter, portrait:String) -> String:
	if character == null:
		printerr('[Dialogic] 尝试在 <null> 角色上使用立绘 "', portrait, '"。')
		dialogic.print_debug_moment()
		return ""

	if "{" in portrait and dialogic.has_subsystem("Expressions"):
		var test: Variant = dialogic.Expressions.execute_string(portrait)
		if test:
			portrait = str(test)

	if not portrait in character.portraits:
		if not portrait.is_empty():
			printerr('[Dialogic] 尝试使用无效立绘 "', portrait, '"（角色 "', character.get_character_name(), '"）。将改用默认立绘。')
			dialogic.print_debug_moment()
		portrait = character.default_portrait

	if portrait.is_empty():
		portrait = character.default_portrait

	return portrait

#endregion


#region 角色方法
####################################################################################################
## 以下方法用于按下列规则管理角色立绘：
##   - 使用这些方法时，一个角色只能出现一次。
## 如果角色尚未加入，大多数方法会静默失败。


## 在指定位置添加角色并设置其立绘。
## 如果该角色已经加入，则只更新立绘、位置等。
func join_character(character:DialogicCharacter, portrait:String,  position_id:String, mirrored:= false, z_index:= 0, extra_data:= "", animation_name:= "", animation_length:= 0.0, animation_wait := false) -> Node:
	if is_character_joined(character):
		change_character_portrait(character, portrait)

		if animation_name.is_empty():
			animation_length = _get_join_default_length()

		if animation_wait:
			dialogic.current_state = DialogicGameHandler.States.ANIMATING
			await get_tree().create_timer(animation_length).timeout
			dialogic.current_state = DialogicGameHandler.States.IDLE
		move_character(character, position_id, animation_length)
		change_character_mirror(character, mirrored)
		return

	var container := dialogic.PortraitContainers.add_container(character.get_character_name())
	var character_node := await add_character(character, container, portrait, position_id)
	if character_node == null:
		return null

	portraits[character.get_identifier()] = {"portrait":portrait, "position_id":position_id, "joined":true}
	character_nodes[character.get_identifier()] = character_node

	_change_portrait_mirror(character_node, mirrored)
	_change_portrait_extradata(character_node, extra_data)
	_change_portrait_z_index(character_node, z_index)

	var info := {'character':character}
	info.merge(portraits[character.get_identifier()])
	character_joined.emit(info)

	if animation_name.is_empty():
		animation_name = ProjectSettings.get_setting('dialogic/animations/join_default', "Fade In Up")
		animation_length = _get_join_default_length()
		animation_wait = ProjectSettings.get_setting('dialogic/animations/join_default_wait', true)

	animation_name = DialogicPortraitAnimationUtil.guess_animation(animation_name, DialogicPortraitAnimationUtil.AnimationType.IN)

	if animation_name and animation_length > 0:
		var anim: DialogicAnimation = _animate_node(character_node, animation_name, animation_length)
		if animation_wait:
			dialogic.current_state = DialogicGameHandler.States.ANIMATING
			await anim.finished
			dialogic.current_state = DialogicGameHandler.States.IDLE

	return character_node


func add_character(character: DialogicCharacter, container: DialogicNode_PortraitContainer, portrait: String, transform: String) -> Node:
	if is_character_joined(character):
		printerr('[DialogicError] 无法添加已加入的角色。如果这是有意为之，请手动调用 _create_character_node。')
		return null

	portrait = get_valid_portrait(character, portrait)

	if portrait.is_empty():
		return null

	if not character:
		printerr('[DialogicError] 无法用空角色调用 add_character()。')
		return null

	var character_node := _create_character_node(character, container)

	if character_node == null:
		printerr('[Dialogic] 无法将角色加入位置 ', transform, "。找不到位置容器。")
		return null

	portraits[character.get_identifier()] = {"portrait": portrait, "position_id": transform, "joined":true}
	character_nodes[character.get_identifier()] = character_node

	_move_character(character_node, transform)
	await _change_portrait(character_node, portrait)

	return character_node


## 更改角色的立绘。仅对已加入的角色有效。
func change_character_portrait(character: DialogicCharacter, portrait: String, fade_animation:="", fade_length := -1.0) -> void:
	if not is_character_joined(character):
		return

	portrait = get_valid_portrait(character, portrait)

	if portraits[character.get_identifier()].portrait == portrait:
		return

	if fade_animation == "":
		fade_animation = ProjectSettings.get_setting('dialogic/animations/cross_fade_default', "Fade Cross")
		fade_length = ProjectSettings.get_setting('dialogic/animations/cross_fade_default_length', 0.5)

	fade_animation = DialogicPortraitAnimationUtil.guess_animation(fade_animation, DialogicPortraitAnimationUtil.AnimationType.CROSSFADE)

	var info := await _change_portrait(character_nodes[character.get_identifier()], portrait, fade_animation, fade_length)
	portraits[character.get_identifier()].portrait = info.portrait
	character_portrait_changed.emit(info)


## 更改指定角色的镜像。仅对已加入的角色有效
func change_character_mirror(character:DialogicCharacter, mirrored:= false) -> void:
	if not is_character_joined(character):
		return

	_change_portrait_mirror(character_nodes[character.get_identifier()], mirrored)


## 更改角色的 z_index。仅对已加入的角色有效
func change_character_z_index(character:DialogicCharacter, z_index:int, update_zindex:= true) -> void:
	if not is_character_joined(character):
		return

	_change_portrait_z_index(character_nodes[character.get_identifier()], z_index, update_zindex)
	if update_zindex:
		portraits[character.get_identifier()]['z_index'] = z_index


## 更改指定角色的额外数据。仅对已加入的角色有效
func change_character_extradata(character:DialogicCharacter, extra_data:="") -> void:
	if not is_character_joined(character):
		return
	_change_portrait_extradata(character_nodes[character.get_identifier()], extra_data)
	portraits[character.get_identifier()]['extra_data'] = extra_data


## 在指定角色上播放指定动画。仅对已加入的角色有效
func animate_character(character: DialogicCharacter, animation_path: String, length: float, repeats := 1, is_reversed := false, repeat_forever := false) -> DialogicAnimation:
	if not is_character_joined(character):
		return null

	animation_path = DialogicPortraitAnimationUtil.guess_animation(animation_path)

	var character_node: Node = character_nodes[character.get_identifier()]

	return _animate_node(character_node, animation_path, length, repeats, is_reversed, repeat_forever)



## 将指定角色移动到指定位置。仅对已加入的角色有效
func move_character(character:DialogicCharacter, position_id:String, time:= 0.0, easing:=Tween.EASE_IN_OUT, trans:=Tween.TRANS_SINE) -> void:
	if not is_character_joined(character):
		return

	if portraits[character.get_identifier()].position_id == position_id:
		return

	_move_character(character_nodes[character.get_identifier()], position_id, time, easing, trans)
	portraits[character.get_identifier()].position_id = position_id
	character_moved.emit({'character':character, 'position_id':position_id, 'time':time})


## 用指定动画或默认动画移除角色。
func leave_character(character: DialogicCharacter, animation_name:= "", animation_length:= 0.0, animation_wait := false) -> void:
	if not is_character_joined(character):
		return

	var character_node := get_character_node(character)

	# 我们在动画真正结束之前就做这件事
	# 因为角色可能在离开过程中再次加入。
	portraits.erase(character.get_identifier())
	character_nodes.erase(character.get_identifier())

	if animation_name.is_empty():
		animation_name = ProjectSettings.get_setting('dialogic/animations/leave_default', "Fade Out Down")
		animation_length = _get_leave_default_length()
		animation_wait = ProjectSettings.get_setting('dialogic/animations/leave_default_wait', true)

	animation_name = DialogicPortraitAnimationUtil.guess_animation(animation_name, DialogicPortraitAnimationUtil.AnimationType.OUT)

	if not animation_name.is_empty():
		var animation := _animate_node(character_node, animation_name, animation_length, 1, true)
		if animation_length > 0:
			if animation_wait:
				dialogic.current_state = DialogicGameHandler.States.ANIMATING
				await animation.finished
				dialogic.current_state = DialogicGameHandler.States.IDLE
				_remove_character(character_node)
			else:
				animation.finished.connect(_remove_character.bind(character_node))
		else:
			_remove_character(character_node)


## 用指定动画或默认动画移除所有已加入的角色。
func leave_all_characters(animation_name:="", animation_length:=0.0, animation_wait := false) -> void:
	for character in get_joined_characters():
		await leave_character(character, animation_name, animation_length, animation_wait)


## 查找 [param character] 对应的角色节点。
## 若 [param character] 不在场景中，则返回 `null`。
func get_character_node(character: DialogicCharacter) -> Node:
	if is_character_joined(character):
		if is_instance_valid(character_nodes[character.get_identifier()]):
			return character_nodes[character.get_identifier()]
	return null


## 如果指定角色当前已加入，则返回 true。
func is_character_joined(character: DialogicCharacter) -> bool:
	if character == null or not character.get_identifier() in portraits or portraits[character.get_identifier()].get("joined", true) == false:
		return false
	return true


## 返回已加入角色的列表（以资源形式）
func get_joined_characters() -> Array[DialogicCharacter]:
	var chars: Array[DialogicCharacter] = []

	for char_identifier: String in portraits.keys():
		if portraits[char_identifier].get("joined", true):
			continue
		chars.append(DialogicResourceUtil.get_character_resource(char_identifier))

	return chars


## 返回包含指定角色信息的字典。
## 键可以是 [joined, character, node（表示立绘节点）、position_id]
## 未加入的角色只包含 joined（且为 false）
func get_character_info(character:DialogicCharacter) -> Dictionary:
	if is_character_joined(character):
		var info: Dictionary = portraits[character.get_identifier()]
		info["joined"] = true
		return info
	else:
		return {"joined":false}

#endregion


#region 说话者立绘容器
####################################################################################################

## 更新所有设置为 SPEAKER 的立绘容器。
func change_speaker(speaker: DialogicCharacter = null, portrait := "") -> void:
	for container: Node in get_tree().get_nodes_in_group('dialogic_portrait_con_speaker'):
		var just_joined := true
		for character_node: Node in container.get_children():
			if not character_node.get_meta('character') == speaker:
				var leave_animation: String = ProjectSettings.get_setting('dialogic/animations/leave_default', "Fade Out")
				leave_animation = DialogicPortraitAnimationUtil.guess_animation(leave_animation, DialogicPortraitAnimationUtil.AnimationType.OUT)
				var leave_animation_length := _get_leave_default_length()

				if leave_animation and leave_animation_length:
					var animate_out := _animate_node(character_node, leave_animation, leave_animation_length, 1, true)
					await animate_out.finished
					if is_instance_valid(character_node):
						character_node.queue_free()
				else:
					character_node.get_parent().remove_child(character_node)
					if is_instance_valid(character_node):
						character_node.queue_free()
			else:
				just_joined = false

		if speaker == null or speaker.portraits.is_empty():
			continue

		if just_joined:
			_create_character_node(speaker, container)
		elif portrait.is_empty():
			continue

		if portrait.is_empty():
			if speaker.get_identifier() in portraits:
				portrait = portraits[speaker.get_identifier()].get("portrait", "")
		if portrait.is_empty():
			portrait = speaker.default_portrait

		var character_node := container.get_child(-1)

		var fade_animation: String = ProjectSettings.get_setting('dialogic/animations/cross_fade_default', "Fade Cross")
		var fade_length: float = ProjectSettings.get_setting('dialogic/animations/cross_fade_default_length', 0.5)

		fade_animation = DialogicPortraitAnimationUtil.guess_animation(fade_animation, DialogicPortraitAnimationUtil.AnimationType.CROSSFADE)

		if container.portrait_prefix + portrait in speaker.portraits:
			portrait = container.portrait_prefix + portrait

		if not is_character_joined(speaker):
			portraits[speaker.get_identifier()] = {"joined":false}
		portraits[speaker.get_identifier()]["portrait"] = portrait

		await _change_portrait(character_node, portrait, fade_animation, fade_length)

		# 如果角色没有立绘，_change_portrait 实际上不会添加子节点
		if character_node.get_child_count() == 0:
			continue

		if just_joined:
			# 切换说话者是在文本更改之前调用的。
			# 在说话者位于文本框内部的那种样式中，
			# 这意味着立绘容器此时可能还没有正确的尺寸。
			character_node.hide()
			if not container.is_visible_in_tree():
				await get_tree().process_frame

			# 有可能样式已经改变（因为说话者样式），导致角色节点现在已经不存在了。
			# 这种情况下，直接放弃即可。
			if not is_instance_valid(character_node):
				return
			character_node.show()
			var join_animation: String = ProjectSettings.get_setting('dialogic/animations/join_default', "Fade In Up")
			join_animation = DialogicPortraitAnimationUtil.guess_animation(join_animation, DialogicPortraitAnimationUtil.AnimationType.IN)
			var join_animation_length := _get_join_default_length()

			if join_animation and join_animation_length:
				await _animate_node(character_node, join_animation, join_animation_length).finished

	var prev_speaker: DialogicCharacter = dialogic.Text.get_current_speaker()
	if speaker != prev_speaker:
		if is_character_joined(prev_speaker):
			character_nodes[prev_speaker.get_identifier()].get_child(-1)._unhighlight()

		if is_character_joined(speaker):
			character_nodes[speaker.get_identifier()].get_child(-1)._highlight()

#endregion


#region 文本特效
####################################################################################################

## 由 [portrait=something] 文本效果调用。
func text_effect_portrait(_text_node:Control, _skipped:bool, argument:String) -> void:
	if argument:
		var current_speaker := dialogic.Text.get_current_speaker()
		if current_speaker:
			change_character_portrait(current_speaker, argument)
			change_speaker(current_speaker, argument)


## 由 [extra_data=something] 文本效果调用。
func text_effect_extradata(_text_node:Control, _skipped:bool, argument:String) -> void:
	if argument:
		if dialogic.Text.get_current_speaker():
			change_character_extradata(dialogic.Text.get_current_speaker(), argument)
#endregion
