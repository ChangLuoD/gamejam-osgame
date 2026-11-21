@tool
extends Resource
class_name DialogicStyle

## 样式表示图层与设置的集合。
## 一个样式可以继承自另一个样式。


@export var name := "Style":
	get:
		if name.is_empty():
			return "Unkown Style"
		return name

@export var inherits: DialogicStyle = null

## 存储图层顺序
@export var layer_list: Array[String] = []
## 存储图层信息
@export var layer_info := {
	"" : DialogicStyleLayer.new()
}


func _init(_name := "") -> void:
	if not _name.is_empty():
		name = _name


#region 基础方法
# 这些方法是本地的，意味着它们不考虑继承。

func clear() -> void:
	layer_list = []
	layer_info = {"" : DialogicStyleLayer.new()}
	inherits = null


## 返回图层数量（不包含基础图层）。
func get_layer_count() -> int:
	return layer_list.size()


## 返回图层列表中 [param id] 图层的索引。
## 对于基础图层（id==""）返回 -1，因为它不在图层列表中。
func get_layer_index(id:String) -> int:
	return layer_list.find(id)


## 若 [param id] 是图层的有效 id，则返回 `true`。
func has_layer(id:String) -> bool:
	return id in layer_info or id == ""


## 若 [param index] 是图层的有效索引，则返回 `true`。
func has_layer_index(index:int) -> bool:
	return index < layer_list.size()


## 返回位于 [param index] 的图层的 id。
func get_layer_id_at_index(index:int) -> String:
	if index == -1:
		return ""
	if has_layer_index(index):
		return layer_list[index]
	return ""


func get_layer_info(id:String) -> Dictionary:
	var info := {"id": id, "path": "", "overrides": {}}

	if has_layer(id):
		var layer_resource: DialogicStyleLayer = layer_info[id]

		if layer_resource.scene != null:
			info.path = layer_resource.scene.resource_path
		elif id == "":
			info.path = DialogicStylesUtil.get_default_layout_base().resource_path

		info.overrides = layer_resource.overrides.duplicate()

	return info

#endregion


#region 修改方法
# 这些方法会修改此样式的图层。


## 返回一个尚未使用的新图层 id。
func get_new_layer_id() -> String:
	var i := 16
	while String.num_int64(i, 16) in layer_info:
		i += 1
	return String.num_int64(i, 16)


## 用给定的场景与覆盖添加一个图层。
## 返回新图层的 id。
func add_layer(scene:String, overrides:Dictionary = {}, id:= "##") -> String:
	if id == "##":
		id = get_new_layer_id()
	layer_info[id] = DialogicStyleLayer.new(scene, overrides)
	layer_list.append(id)
	changed.emit()
	return id


## 删除给定 id 的图层。
## 不允许删除基础图层。
func delete_layer(id:String) -> void:
	if not has_layer(id) or id == "":
		return

	layer_info.erase(id)
	layer_list.erase(id)

	changed.emit()


## 将位于 [param from_index] 的图层移动到 [param to_index]。
func move_layer(from_index:int, to_index:int) -> void:
	if not has_layer_index(from_index) or not has_layer_index(to_index-1):
		return

	var id: String = layer_list.pop_at(from_index)
	layer_list.insert(to_index, id)

	changed.emit()


## 修改位于 [param layer_id] 的 DialogicStyleLayer 资源的 scene 属性。
func set_layer_scene(layer_id:String, scene:String) -> void:
	if not has_layer(layer_id):
		return
	layer_info[layer_id].scene = load(scene)
	changed.emit()


func set_layer_overrides(layer_id:String, overrides:Dictionary) -> void:
	if not has_layer(layer_id):
		return

	layer_info[layer_id].overrides = overrides
	changed.emit()


## 修改位于 [param layer_id] 的 DialogicStyleLayer 资源的某个覆盖。
func set_layer_setting(layer_id:String, setting:String, value:Variant) -> void:
	if not has_layer(layer_id):
		return

	layer_info[layer_id].overrides[setting] = value
	changed.emit()


## 重置（移除）位于 [param layer_id] 的 DialogicStyleLayer 资源的某个覆盖。
func remove_layer_setting(layer_id:String, setting:String) -> void:
	if not has_layer(layer_id):
		return

	layer_info[layer_id].overrides.erase(setting)
	changed.emit()

#
#endregion


#region 继承方法
# 通常应该使用这些方法来获取关于此样式的信息。


## 若此样式继承自另一个样式，则返回 `true`。
func inherits_anything() -> bool:
	return inherits != null


## 返回此样式所继承的根样式。
func get_inheritance_root() -> DialogicStyle:
	if not inherits_anything():
		return self

	var style: DialogicStyle = self
	while style.inherits_anything():
		style = style.inherits

	return style


## 将某些 [param layer_info] 与其祖先图层的图层信息合并。
func merge_layer_infos(new_layer_info:Dictionary, ancestor_info:Dictionary) -> Dictionary:
	var combined := new_layer_info.duplicate(true)

	combined.path = ancestor_info.path
	combined.overrides.merge(ancestor_info.overrides)

	return combined


## 返回位于 [param id] 的图层的信息，并考虑继承的信息。
## 若 [param inherited_only] 为 `true`，则不包括本地信息。
func get_layer_inherited_info(id:String, inherited_only := false) -> Dictionary:
	var style := self
	var info := {"id": id, "path": "", "overrides": {}}

	if not inherited_only:
		info = get_layer_info(id)

	while style.inherits_anything():
		style = style.inherits
		info = merge_layer_infos(info, style.get_layer_info(id))

	return info


## 返回根样式的图层列表。
func get_layer_inherited_list() -> Array:
	var list := layer_list

	if inherits_anything():
		list = get_inheritance_root().layer_list

	return list


## 将继承的信息应用到本地图层。
## 然后移除继承。
func realize_inheritance() -> void:
	layer_list = get_layer_inherited_list()

	var new_layer_info := {}
	for id in layer_info:
		var info := get_layer_inherited_info(id)
		new_layer_info[id] = DialogicStyleLayer.new(info.get("path", ""), info.get("overrides", {}))

	layer_info = new_layer_info
	inherits = null
	changed.emit()


#endregion

## 用相同设置创建一个全新的样式。
func clone() -> DialogicStyle:
	var style := DialogicStyle.new()
	style.name = name
	style.inherits = inherits

	var base_info := get_layer_info("")
	style.set_layer_scene("", base_info.path)
	style.set_layer_overrides("", base_info.overrides)

	for id in layer_list:
		var info := get_layer_info(id)
		style.add_layer(info.path, info.overrides, id)

	return style


## 开始预加载此样式使用的所有场景。
func prepare() -> void:
	for id in layer_info:
		if layer_info[id].scene:
			ResourceLoader.load_threaded_request(layer_info[id].scene.resource_path)


#region 更新旧样式
# TODO 进入 beta 后废弃

# TODO  已废弃，仅用于 alpha 16 之前的样式！
@export var base_scene: PackedScene = null
# TODO 已废弃，仅用于 alpha 16 之前的样式！
@export var base_overrides := {}
# TODO 已废弃，仅用于 alpha 16 之前的样式！
@export var layers: Array[DialogicStyleLayer] = []

func update_from_pre_alpha16() -> void:
	if not layers.is_empty():
		var idx := 0
		for layer in layers:
			var id := "##"
			if inherits_anything():
				id = get_layer_inherited_list()[idx]
			if layer.scene:
				add_layer(layer.scene.resource_path, layer.overrides, id)
			else:
				add_layer("", layer.overrides, id)
			idx += 1
		layers.clear()

	if not base_scene == null:
		set_layer_scene("", base_scene.resource_path)
		base_scene = null
	if not base_overrides.is_empty():
		set_layer_overrides("", base_overrides)
		base_overrides.clear()


#endregion
