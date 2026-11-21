@tool
class_name DialogicTimelineFormatSaver
extends ResourceFormatSaver


func _get_recognized_extensions(_resource: Resource) -> PackedStringArray:
	return PackedStringArray(["dtl"])


## 如果该资源应作为 DialogicTimeline 加载，则返回 true
func _recognize(resource: Resource) -> bool:
	# 使用类型转换而不是 "is" 关键字，以防它是子类
	resource = resource as DialogicTimeline

	if resource:
		return true

	return false


## 保存资源
func _save(resource: Resource, path: String = '', _flags: int = 0) -> Error:
	if resource.get_meta("timeline_not_saved", false):
		var timeline_as_text: String = resource.as_text()

		var file := FileAccess.open(path, FileAccess.WRITE)
		if not file:
			print("[Dialogic] 打开文件出错：", FileAccess.get_open_error())
			return ERR_CANT_OPEN
		file.store_string(timeline_as_text)
		file.close()

	return OK
