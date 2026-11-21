class_name DialogicAnimation
extends Node

## 可用于为立绘播放动画的类。可以通过继承它来创建新的动画。

enum AnimationType {IN=1, OUT=2, ACTION=3, CROSSFADE=4}

signal finished_once
signal finished

## 在运行时设置，表示要播放动画的节点。
var node: Node

## 在运行时设置，表示动画的时长。
var time: float

## 在运行时设置，表示节点的基础位置。
## 视具体动画而定，它可能是起点、终点或两者兼具。
var base_position: Vector2
## 在运行时设置，表示节点的基础缩放。
var base_scale: Vector2

## 用于设定动画重复播放的次数。
var repeats: int
var repeat_forever : bool = false

## 如果为 `true`，动画将反向播放。
## 这需要各个动画自行实现，否则不会产生任何效果。
var is_reversed: bool = false


func _ready() -> void:
	finished_once.connect(finished_one_loop)


## 需要被重写。在这里执行实际的动画/补间操作。
## 可以使用 [member node]、[member time]、[member base_position] 等属性。
func animate() -> void:
	pass


## 此方法控制是否重复播放动画。
## 动画在完成一次播放后必须调用此方法。
func finished_one_loop() -> void:
	repeats -= 1

	if repeats > 0 or repeat_forever:
		animate()

	else:
		finished.emit()
		queue_free()


func pause() -> void:
	if node:
		node.process_mode = Node.PROCESS_MODE_DISABLED


func resume() -> void:
	if node:
		node.process_mode = Node.PROCESS_MODE_INHERIT


func _get_named_variations() -> Dictionary:
	return {}


## 如果动画想要修改 modulation，此方法
## 将返回需要修改的属性名。
##
## [class CanvasGroup] 可以使用 `self_modulate` 而不是 `modulate`，
## 以统一改变所有子节点的 modulation，避免以叠加方式
## 逐层覆盖各自的 modulation。
func get_modulation_property() -> String:
	if node is CanvasGroup:
		return "self_modulate"
	else:
		return "modulate"


## 尝试返回要播放动画的节点的大小。
## 对于立绘，这会使用立绘容器的大小。
## 如果你的动画依赖节点大小，这会很有用。
func get_node_size() -> Vector2:
	if not node:
		return Vector2()
	if node.get_parent() is DialogicNode_PortraitContainer:
		return node.get_parent().size
	if "size" in node:
		return node.size * node.scale
	return node.get_viewport().size


func get_node_origin() -> Vector2:
	if not node:
		return Vector2()
	if node.get_parent() is DialogicNode_PortraitContainer:
		return node.get_parent().current_settings._get_origin_position()
	return Vector2()


func get_viewport_size() -> Vector2:
	return node.get_viewport().get_visible_rect().size
