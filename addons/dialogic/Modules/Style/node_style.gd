class_name DialogicNode_StyleLayer
extends Control

## 根据当前 Dialogic 样式隐藏和显示的控件节点。

## 此图层所监听的名称
@export var layer_name: String = 'Default'


func _ready() -> void:
	if layer_name.is_empty():
		layer_name = name
	add_to_group('dialogic_style_layer')
