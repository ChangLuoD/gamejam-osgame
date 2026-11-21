@tool
class_name DialogicLayoutBase
extends Node

## 自定义布局应继承的基类。


## 将节点作为图层添加的方法
func add_layer(layer:DialogicLayoutLayer) -> Node:
	add_child(layer)
	return layer


## 返回指定子节点的方法
func get_layer(index:int) -> Node:
	return get_child(index)


## 返回所有图层的方法
func get_layers() -> Array:
	var layers := []
	for child in get_children():
		if child is DialogicLayoutLayer:
			layers.append(child)
	return layers


## 用于加载导出覆盖的方法。
## 这在样式首次引入时发生，
## 但在使用同一场景切换到其他样式时也会发生！
func apply_export_overrides() -> void:
	_apply_export_overrides()
	for child in get_children():
		if child.has_method("_apply_export_overrides"):
			child._apply_export_overrides()


## 返回此基类上的某个设置。
## 这很有用，可让各图层共享 base_color 等设置。
func get_global_setting(setting:StringName, default:Variant) -> Variant:
	if setting in self:
		return get(setting)

	if str(setting).to_lower() in self:
		return get(setting.to_lower())

	if "global_"+str(setting) in self:
		return get("global_"+str(setting))

	return default


## 供覆写。在此将设置应用到你的场景。
func _apply_export_overrides() -> void:
	pass


#region 处理持久化数据
################################################################################

func _init() -> void:
	_load_persistent_info(Engine.get_meta("dialogic_persistent_style_info", {}))


func _exit_tree() -> void:
	var info: Dictionary = Engine.get_meta("dialogic_persistent_style_info", {})
	info.merge(_get_persistent_info(), true)
	Engine.set_meta("dialogic_persistent_style_info", info)


## 供覆写。返回后续使用的样式可能想知道的任何信息。
func _get_persistent_info() -> Dictionary:
	return {}


## 供覆写。应用之前样式可能已存储、且此样式应使用的任何信息。
func _load_persistent_info(_info: Dictionary) -> void:
	pass

#endregion
