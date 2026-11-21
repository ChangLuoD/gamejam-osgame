@tool
extends DialogicLayoutLayer

## 一个可以显示 5 个立绘的图层，类似于视觉小说中的做法。

## 立绘所在的画布图层（CanvasLayer）。
@export var portrait_size_mode: DialogicNode_PortraitContainer.SizeModes = DialogicNode_PortraitContainer.SizeModes.FIT_SCALE_HEIGHT


func _apply_export_overrides() -> void:
	# 应用立绘大小
	for child: DialogicNode_PortraitContainer in %Portraits.get_children():
		child.size_mode = portrait_size_mode
