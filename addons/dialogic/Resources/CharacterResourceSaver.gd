@tool
class_name DialogicCharacterFormatSaver
extends ResourceFormatSaver


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return PackedStringArray(["dch"])


## 若此资源应作为 DialogicCharacter 加载则返回 true
func _recognize(resource: Resource) -> bool:
	# 使用强制转换而非 "is" 关键字，以防它是子类
	resource = resource as DialogicCharacter

	if resource:
		return true

	return false


## 保存资源
func _save(resource: Resource, path: String = '', _flags: int = 0) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if not file:
		# 目前只是让编辑器知道，由于某种原因你无法
		# 读取该文件。
		print("[Dialogic] 打开文件出错：", FileAccess.get_open_error())
		return FileAccess.get_open_error()

	var result := var_to_str(inst_to_dict(resource))
	file.store_string(result)
#	print('[Dialogic] 已保存角色 "' , path, '"')
	return OK
