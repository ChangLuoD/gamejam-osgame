class_name DialogicPortrait
extends Node

## 默认立绘类。自定义立绘应继承此类。

## 存储此场景所显示的角色。
var character: DialogicCharacter
## 存储当前立绘的名称。
var portrait: String

#region 主要覆写
################################################################################

## 此函数可以重写。
## 若返回 true，则不会实例化新场景，而是调用
## 此节点上的 [method _update_portrait]。
## 这只在下一个立绘使用同一场景时才有意义。
## 它可用于实现使用同一场景的立绘之间的过渡。
func _should_do_portrait_update(_character: DialogicCharacter, _portrait: String) -> bool:
	return false


## 若自定义立绘接受变更，则在此处理
## 你应把立绘摆放成根节点位于轴心点*。
## 例如对于一个简单的精灵，这段代码即可生效：
## >>> $Sprite.position = $Sprite.get_rect().size * Vector2(-0.5, -1)
##
## * 这取决于立绘容器，但大多数情况下是底部中心（99% 的情况）
func _update_portrait(_passed_character: DialogicCharacter, _passed_portrait: String) -> void:
	pass


## 此函数应实现。它用于
## 角色编辑器预览和立绘容器中的尺寸计算。
## 缩放与偏移将由 Dialogic 应用。
## 例如，一个简单的精灵：
## >>> return Rect2($Sprite.position, $Sprite.get_rect().size)
##
## 只有当立绘被摆放成
## 根节点位于轴心点时，这才会按预期工作。
##
## 如果你使用过 apply_texture，这应当自动生效。
func _get_covered_rect() -> Rect2:
	if has_meta('texture_holder_node') and get_meta('texture_holder_node', null) != null and is_instance_valid(get_meta('texture_holder_node')):
		var node: Node = get_meta('texture_holder_node')
		if node is Sprite2D or node is TextureRect:
			return Rect2(node.position, node.get_rect().size)
	return Rect2()


## 若实现，镜像改变时会调用此函数
func _set_mirror(mirror:bool) -> void:
	if has_meta('texture_holder_node') and get_meta('texture_holder_node', null) != null and is_instance_valid(get_meta('texture_holder_node')):
		var node: Node = get_meta('texture_holder_node')
		if node is Sprite2D or node is TextureRect:
			node.flip_h = mirror


## 接收并使用额外数据的函数（若自定义立绘希望接收）
func _set_extra_data(_data: String) -> void:
	pass

#endregion


#region 保存/加载
################################################################################

## 将被重写。在创建存档时由 [subsystem Portrait] 调用。
func _get_state() -> Dictionary:
	return {}


## 将被重写。在读取存档时由 [subsystem Portrait] 调用。[param _state] 是之前由 [method _get_state] 返回的内容。
func _load_state(_state:Dictionary) -> void:
	pass



#region 高亮覆写
################################################################################

## 当此立绘成为当前说话者时调用
func _highlight() -> void:
	pass


## 当此立绘不再是当前说话者时调用
func _unhighlight() -> void:
	pass
#endregion


#region 辅助方法
################################################################################

## 快速设置并校验角色与立绘的辅助函数。
func apply_character_and_portrait(passed_character:DialogicCharacter, passed_portrait:String) -> void:
	if passed_portrait == "" or not passed_portrait in passed_character.portraits.keys():
		passed_portrait = passed_character.default_portrait

	portrait = passed_portrait
	character = passed_character


func apply_texture(node:Node, texture_path:String) -> void:
	if not character or not character.portraits.has(portrait):
		return

	if not "texture" in node:
		return

	node.texture = null

	if not ResourceLoader.exists(texture_path):
		# 这是 alpha 版遗留的。
		# 删除它会导致 alpha-10 之前制作的立绘失效
		if ResourceLoader.exists(character.portraits[portrait].get('image', '')):
			texture_path = character.portraits[portrait].get('image', '')
		else:
			return

	node.texture = load(texture_path)

	if node is Sprite2D or node is TextureRect:
		if node is Sprite2D:
			node.centered = false
		node.scale = Vector2.ONE
		if node is TextureRect:
			if !is_inside_tree():
				await ready
		node.position = node.get_rect().size * Vector2(-0.5, -1)

	set_meta('texture_holder_node', node)

#endregion
