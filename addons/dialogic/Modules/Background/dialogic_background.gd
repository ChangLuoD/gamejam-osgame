class_name DialogicBackground
extends Node

## 这是 Dialogic 背景的基类。
## 创建自定义背景时，请扩展它并覆盖它的方法。
## 你可以参考默认背景来了解它的工作方式。


## 容纳该背景的子视口容器。实例化时设置。
var viewport_container: SubViewportContainer
## 容纳该背景的视口。实例化时设置。
var viewport: SubViewport


## 在此处加载新的背景。
## 当 [_should_do_background_update] 返回 true 时会传入时间参数
## （此时你需要在这里执行过渡）
func _update_background(_argument:String, _time:float) -> void:
	pass


## 如果在该背景被使用时遇到了使用同一场景的背景事件，
##   这里决定是创建新实例并调用 fade_out，还是仅在该场景上调用 [_update_background]。默认为 false
func _should_do_background_update(_argument:String) -> bool:
	return false


## 首次创建时由 dialogic 调用。
## 如果返回 false（默认），则会尝试对 "modulate" 属性做动画。
func _custom_fade_in(_time:float) -> bool:
	return false


## 移除前由 dialogic 调用（该移除由 dialogic 完成）。
## 如果返回 false（默认），则会尝试对 "modulate" 属性做动画。
func _custom_fade_out(_time:float) -> bool:
	return false


func _get_state() -> Dictionary:
	return {}


func _load_state(_state:Dictionary) -> void:
	pass
