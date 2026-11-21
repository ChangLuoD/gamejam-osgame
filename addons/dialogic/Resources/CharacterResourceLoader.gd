@tool
class_name DialogicCharacterFormatLoader
extends ResourceFormatLoader



## 返回所有接受的扩展名
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["dch"])


## 若此文件能/应由此脚本加载，则返回 "Resource"
func _get_resource_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "dch":
		return "Resource"

	return ""


## 返回与某资源关联的脚本类
func _get_resource_script_class(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "dch":
		return "DialogicCharacter"

	return ""


## 若处理此类型则返回 true
func _handles_type(typename: StringName) -> bool:
	return ClassDB.is_parent_class(typename, "Resource")


## 解析文件并返回资源
func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
#	print('[Dialogic] 正在重新导入角色 "' , path, '"')
	var file := FileAccess.open(path, FileAccess.READ)

	if not file:
		# 目前只是让编辑器知道，由于某种原因你无法
		# 读取该文件。
		print("[Dialogic] 打开文件出错：", FileAccess.get_open_error())
		return FileAccess.get_open_error()

	return dict_to_inst(str_to_var(file.get_as_text()))


func _get_dependencies(path:String, _add_type:bool) -> PackedStringArray:
	var depends_on: PackedStringArray = []
	var character: DialogicCharacter = load(path)
	for p in character.portraits.values():
		if 'scene' in p and p.scene:
			depends_on.append(p.scene)
		for i in p.get("export_overrides", []):
			if typeof(p.export_overrides[i]) == TYPE_STRING and "://" in p.export_overrides[i]:
				depends_on.append(p.export_overrides[i].trim_prefix('"').trim_suffix('"'))
	return depends_on


func _rename_dependencies(path: String, renames: Dictionary) -> Error:
	var character: DialogicCharacter = load(path)
	for p in character.portraits.values():
		if 'scene' in p and p.scene in renames:
			p.scene = renames[p.scene]

		for i in p.get("export_overrides", []):
			if typeof(p.export_overrides[i]) == TYPE_STRING and "://" in p.export_overrides[i]:
				var i_path := str(p.export_overrides[i]).trim_prefix('"').trim_suffix('"')
				if i_path in renames:
					p.export_overrides[i] = '"'+renames[i_path]+'"'

	ResourceSaver.save(character, path)
	return OK
