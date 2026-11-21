@tool
class_name DialogicCharacterEditorMainSection
extends Control

## 所有角色编辑器主要设置区块的基类。方法应被覆盖。

## 当有内容发生变化时，发出此信号
@warning_ignore("unused_signal") # 此信号由扩展脚本使用
signal changed

## 指向角色编辑器的引用，在实例化时设置
var character_editor: Control

## 若非空，则会在区块标题旁添加一个提示图标。
var hint_text := ""


## 覆盖此方法以设置本区块的标识（同时被用作节点名与查找键，请保持英文）
func _get_title() -> String:
	return "MainSection"


## 覆盖此方法以设置本区块在界面上显示的标题
## （覆盖了 _get_title() 的区块应一并覆盖此方法；此处仅负责本地化默认占位标题）
func _get_display_title() -> String:
	if _get_title() == "MainSection":
		return "主要区块"
	return _get_title()


## 覆盖此方法以设置区块标题是否可见
func _show_title() -> bool:
	return true


## 覆盖此方法以设置此区块初始是否展开。
func _start_opened() -> bool:
	return false


## 覆盖此方法以把角色中的全部信息加载到本区块。
func _load_character(_resource:DialogicCharacter) -> void:
	pass


## 覆盖此方法以把本区块中的所有改动保存到资源中。
## 在自定义区块中，你多半会保存到 [resource.custom_info]
##  字典中。
func _save_changes(resource:DialogicCharacter) -> DialogicCharacter:
	return resource
