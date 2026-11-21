@tool
class_name DialogicCharacterEditorPortraitSection
extends Control

## 所有立绘设置区块的基类。方法应被覆盖。
## 通过此类区块中的字段所做的改动应立即「保存」
##  到立绘项的元数据中，之后会从那里保存到资源里。

## 当有内容发生变化时，发出此信号
signal changed
## 当预览需要重新加载时，发出此信号
signal update_preview

## 指向角色编辑器的引用，在实例化时设置
var character_editor: Control
## 指向当前选中立绘项的引用。
##  `selected_item.get_metadata(0)` 可访问立绘数据
var selected_item: TreeItem = null

## 若非空，则会在区块标题旁添加一个提示图标
var hint_text := ""


## 覆盖此方法以设置本区块的标识（同时被用作节点名与查找键，请保持英文）
func _get_title() -> String:
	return "CustomSection"


## 覆盖此方法以设置本区块在界面上显示的标题
## （覆盖了 _get_title() 的区块应一并覆盖此方法；此处仅负责本地化默认占位标题）
func _get_display_title() -> String:
	if _get_title() == "CustomSection":
		return "自定义区块"
	return _get_title()


## 覆盖此方法以设置区块标题是否可见
func _show_title() -> bool:
	return true


## 覆盖此方法以设置此区块初始是否展开。
func _start_opened() -> bool:
	return false


## 覆盖此方法以把角色中的全部信息加载到本区块。
func _load_portrait_data(data:Dictionary) -> void:
	pass


## 覆盖此方法以重新检查本区块的可见性以及各字段的内容。
## 每当预览更新时都会调用此方法，因此可以借此响应其他
##  立绘区块中的重大改动。
func _recheck(data:Dictionary) -> void:
	pass
