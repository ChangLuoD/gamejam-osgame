@tool
## 分层立绘场景。
##
## 父类带有 character 与 portrait 两个变量。
extends DialogicPortrait

## 用于隐藏图层的命令词。
const _HIDE_COMMAND := "hide"
## 用于显示图层的命令词。
const _SHOW_COMMAND := "show"
## 用于将某个图层设为唯一可见图层的命令词。
const _SET_COMMAND := "set"

## 所有可用图层命令的集合。
const _OPERATORS = [_HIDE_COMMAND, _SHOW_COMMAND, _SET_COMMAND]

static var _OPERATORS_EXPRESSION := "|".join(_OPERATORS)
static var _REGEX_STRING := "(" + _OPERATORS_EXPRESSION + ") (\\S+)"
static var _REGEX := RegEx.create_from_string(_REGEX_STRING)

var _initialized := false

var _is_coverage_rect_cached := false
var _cached_coverage_rect := Rect2(0, 0, 0, 0)


@export_group("Private")
## 尝试根据第一个子节点修正偏移量
@export var fix_offset := true

## 覆盖 [class DialogicPortrait] 的方法。
##
## 加载与给定角色和立绘相关的所有内容
func _update_portrait(passed_character: DialogicCharacter, passed_portrait: String) -> void:
	if not _initialized:
		_apply_layer_adjustments()
		_initialized = true

	apply_character_and_portrait(passed_character, passed_portrait)


## 调整所有图层，使其适配立绘预览，
## 并在立绘容器中正确显示。
##
## 此方法不会修改场景本身，仅用于
## Dialogic 编辑器的预览以及游戏内渲染。
func _apply_layer_adjustments() -> void:
	var coverage := _find_largest_coverage_rect()
	var offset_fix := Vector2()
	if fix_offset and get_child_count():
		offset_fix = -get_child(0).position
		if "centered" in get_child(0) and get_child(0).centered:
			offset_fix += get_child(0).get_rect().size/2.0

	for node: Node in get_children():
		var node_position: Vector2 = node.position
		node_position += offset_fix
		node.position = _reposition_with_rect(coverage, node_position)


## 根据 [param rect] 的尺寸，返回 Dialogic 期望该
## 场景部件所处的坐标。[br]
## 如果节点有偏移或额外位置，请通过 [param node_offset] 传入。
func _reposition_with_rect(rect: Rect2, node_offset := Vector2(0.0, 0.0)) -> Vector2:
	return rect.size  * Vector2(-0.5, -1.0) + node_offset


## 遍历 [param start_node] 的所有子节点（含其子孙节点），
## 查找带有纹理（非 `null`）的 [class Sprite2D] 节点。
## 所有找到的精灵会以数组返回，
## 最终返回场景中的全部精灵。
func _find_sprites_recursively(start_node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []

	# 遍历当前节点的子节点
	for child: Node in start_node.get_children():

		if child is Sprite2D:
			var sprite := child as Sprite2D

			if sprite.texture:
				sprites.append(sprite)


		var sub := _find_sprites_recursively(child)
		sprites.append_array(sub)

	return sprites


## 一条命令会为分层立绘施加一种效果。
class LayerCommand:
	# 各种不同的效果类型。
	enum CommandType {
		## 以叠加方式显示指定图层。
		SHOW_LAYER,
		## 以叠加方式隐藏指定图层。
		HIDE_LAYER,
		## 独占显示指定图层，并隐藏其他同级图层。
		## 同级图层指共享同一父节点的图层。
		SET_LAYER,
	}

	var _path: String
	var _type: CommandType

	## 根据 [enum CommandType] 执行该图层的效果。
	func _execute(root: Node) -> void:
		var target_node := root.get_node(_path)

		if target_node == null:
			printerr("分层立绘没有与该节点路径匹配的节点：'", _path, "'。")
			return

		if not target_node is Node2D and not target_node is Sprite2D:
			printerr("分层立绘的目标路径 '", _path, "' 不是 Sprite2D 或 Node2D 类型。")
			return

		match _type:
			CommandType.SHOW_LAYER:
				target_node.show()

			CommandType.HIDE_LAYER:
				target_node.hide()

			CommandType.SET_LAYER:
				var target_parent := target_node.get_parent()

				for child: Node in target_parent.get_children():

					if child is Sprite2D:
						var sprite_child := child as Sprite2D
						sprite_child.hide()

				target_node.show()


## 将输入转换为单个 [class LayerCommand] 对象。
## 如果输入无法解析为 [class LayerCommand]，则返回 `null`。
func _parse_layer_command(input: String) -> LayerCommand:
	var regex_match: RegExMatch = _REGEX.search(input)

	if regex_match == null:
		print("[Dialogic] 分层立绘收到了无效命令：", input)
		return null

	var _path: String = regex_match.get_string(2)
	var operator: String = regex_match.get_string(1)

	var command := LayerCommand.new()

	match operator:
		_SET_COMMAND:
			command._type = LayerCommand.CommandType.SET_LAYER

		_SHOW_COMMAND:
			command._type = LayerCommand.CommandType.SHOW_LAYER

		_HIDE_COMMAND:
			command._type = LayerCommand.CommandType.HIDE_LAYER

		_SET_COMMAND:
			command._type = LayerCommand.CommandType.SET_LAYER

	## 清理转义符号并去除首尾空格。
	command._path = _path.replace("\\", "").strip_edges()

	return command


## 将 [param input] 解析为 [class LayerCommand] 对象组成的数组。
func _parse_input_to_layer_commands(input: String) -> Array[LayerCommand]:
	var commands: Array[LayerCommand] = []
	var command_parts := input.split(",")

	for command_part: String in command_parts:

		if command_part.is_empty():
			continue

		var _command := _parse_layer_command(command_part.strip_edges())

		if not _command == null:
			commands.append(_command)

	return commands



## 覆盖 [class DialogicPortrait] 的方法。
##
## 额外数据会被转换为图层命令并依次执行。
func _set_extra_data(data: String) -> void:
	var commands := _parse_input_to_layer_commands(data)

	for _command: LayerCommand in commands:
		_command._execute(self)


## 覆盖 [class DialogicPortrait] 的方法。
##
## 处理所有图层的水平翻转状态。
func _set_mirror(is_mirrored: bool) -> void:
	for child: Node in get_children():

		if is_mirrored:
			child.position.x = child.position.x * -1
			child.scale.x = -child.scale.x


## 扫描此场景中的所有节点，找出能
## 包围全部精灵的最大矩形。
func _find_largest_coverage_rect() -> Rect2:
	if _is_coverage_rect_cached:
		return _cached_coverage_rect

	var coverage_rect := Rect2(0, 0, 0, 0)

	for sprite: Sprite2D in _find_sprites_recursively(self):
		var sprite_size := sprite.get_rect().size
		var sprite_position: Vector2 = sprite.global_position-self.global_position

		if sprite.centered:
			sprite_position -= sprite_size/2

		var sprite_width := sprite_size.x * sprite.scale.x
		var sprite_height := sprite_size.y * sprite.scale.y

		var texture_rect := Rect2(
			sprite_position.x,
			sprite_position.y,
			sprite_width,
			sprite_height
		)
		coverage_rect = coverage_rect.merge(texture_rect)

	coverage_rect.position = _reposition_with_rect(coverage_rect)

	_is_coverage_rect_cached = true
	_cached_coverage_rect = coverage_rect

	return coverage_rect


## 覆盖 [class DialogicPortrait] 的方法。
##
## 当需要显示立绘时由 Dialogic 调用。
## 例如在 Dialogic 编辑器中或游戏内。
func _get_covered_rect() -> Rect2:
	var needed_rect := _find_largest_coverage_rect()

	return needed_rect


func _get_state() -> Dictionary:
	var sprite_visibilities := {}
	for i in _find_sprites_recursively(self):
		sprite_visibilities[get_path_to(i)] = i.visible
	return sprite_visibilities


func _load_state(state:Dictionary) -> void:
	for i in _find_sprites_recursively(self):
		i.visible = state.get(get_path_to(i), false)
