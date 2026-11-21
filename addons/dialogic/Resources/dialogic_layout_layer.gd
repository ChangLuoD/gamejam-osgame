@tool
class_name DialogicLayoutLayer
extends Node

## 自定义 Dialogic 布局图层应继承的基类。

@export_group("图层")
@export_subgroup("已禁用")
## 若为 [code]true[/code]，该图层会被隐藏且其处理被禁用。
@export var disabled := false

@export_group("Private")
## 若为 [code]true[/code]，则在 _ready() 时调用 [method _apply_export_overrides]。[br]
## 当图层被用于某个样式时，样式变更时基类图层会调用
## [method _apply_export_overrides]。但当样式被改为自定义时，
## 你可能希望它们仍被应用（设为 [code]true[/code]），或者今后直接在其节点上编辑设置（设为 [code]false[/code]）。
## 在改为自定义时会自动打开此项。
@export var apply_overrides_on_ready := false

var this_folder: String = get_script().resource_path.get_base_dir()

func _ready() -> void:
	if apply_overrides_on_ready and not Engine.is_editor_hint():
		_apply_export_overrides()



## 覆写此方法并加载你所有的导出设置（将它们应用到场景）
func _apply_export_overrides() -> void:
	pass


func apply_export_overrides() -> void:
	if disabled:
		if "visible" in self:
			set("visible", false)
		process_mode = Node.PROCESS_MODE_DISABLED
	else:
		if "visible" in self:
			set("visible", true)
		process_mode = Node.PROCESS_MODE_INHERIT

	_apply_export_overrides()


## 用它来获取可能的全局设置。
func get_global_setting(setting_name:StringName, default:Variant) -> Variant:
	return get_parent().get_global_setting(setting_name, default)
