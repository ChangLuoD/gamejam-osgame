class_name DialogicSubsystem
extends Node

## Dialogic 内部一个（基本）独立的系统。
##
## 通过 [class DialogicIndexer] 注册的子类会作为 [class DialogicGameHandler] 的子节点实例化。[br]
## 这些系统应提供对其相关逻辑的方法与设置的便捷访问。[br]
## 通过重写类的各个方法，它们应负责该系统自身的保存与读取。[br]
## 子系统上导出的变量会被视为与存档状态相关，因此在保存时它们会被打包，
## 并在读取时、调用 [method _load_state] 之前被解包。
## 额外状态（例如场景中节点产生的状态）可通过 [method _pack_extra_state] 收集。

## 指向该子系统实例所属的 [class DialogicGameHandler] 的引用。
## 目前仅支持 Dialogic 自动加载的 DialogicGameHandler 实例。
var dialogic: DialogicGameHandler = null

enum LoadFlags {FULL_LOAD, ONLY_DNODES}


## 在所有子系统都加入场景树之后调用一次。
## 由子类重写。
func _post_install() -> void:
	pass


## 重置该子系统并清除它对场景树造成的一切影响。
## 在 DialogicGameHandler 就绪、清空以及加载其他状态之前调用。
## 由子类重写。
func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR) -> void:
	pass


## 当 `DialogicGameHandler.paused` 变为 `true` 时调用。暂停所有系统。
## 由子类重写。
func _pause() -> void:
	pass


## 当 `DialogicGameHandler.paused` 变为 `false` 时调用。恢复所有已暂停的系统。
## 由子类重写。
func _resume() -> void:
	pass


## 当 DialogicGameHandler 加载某个状态时调用。
## 调用 [method _load_state]。
## 通常不需要直接访问它。
func load_state(load_flag:=LoadFlags.FULL_LOAD) -> void:
	_load_state(load_flag)


## 请务必根据导出的状态变量（在此之前已完成解包）以及可通过 [method get_extra_state] 访问的「额外状态」重建状态。
## 由子类重写。
func _load_state(_load_flag:=LoadFlags.FULL_LOAD) -> void:
	pass


## 由 DialogGameHandler 调用，以获取该子系统的当前状态。
## 合并 [method pack_exported_state] 与 [method _get_extra_state] 的结果。
func get_state() -> Dictionary:
	return pack_exported_state().merged(pack_extra_state())


## 供 [method get_state] 使用。调用 [method _pack_extra_state]。
func pack_extra_state() -> Dictionary:
	return _pack_extra_state()


## 由子类重写。
## 返回一个字典，包含你希望保存的所有信息（尚未由导出的状态变量表示的部分）。
## 这在保存场景树中元素的状态时特别有用。
## 要在之后的读取中获得该状态，请使用 [method get_extra_state]。
func _pack_extra_state() -> Dictionary:
	return {}


## 若在读取之后调用，将返回由 [method _pack_extra_state] 打包的额外状态字典。
func get_extra_state() -> Dictionary:
	return get_meta("extra_state", {})


## 将所有导出的变量打包进一个字典。
func pack_exported_state() -> Dictionary:
	var info := {}
	for i in self.script.get_script_property_list():
		if i.usage & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR:
			info[i.name] = self.get(i.name)
	return info


## 将给定信息字典中的值解包到导出的变量中。
func unpack_state(info:Dictionary) -> void:
	var leftovers := info.duplicate()
	for i in self.script.get_script_property_list():
		if i.usage & PROPERTY_USAGE_EDITOR == PROPERTY_USAGE_EDITOR:
			if i.name in info:
				self.set(i.name, info[i.name])
				leftovers.erase(i.name)
	set_meta("extra_state", leftovers)
