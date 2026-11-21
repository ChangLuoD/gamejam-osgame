@tool
class_name DialogicTimelineFormatLoader
extends ResourceFormatLoader


## 返回所有可接受的扩展名
func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["dtl"])


## 如果此文件可以/应该由该脚本加载，则返回 "Resource"
func _get_resource_type(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "dtl":
		return "Resource"

	return ""


## 返回与某个 Resource 关联的脚本类
func _get_resource_script_class(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "dtl":
		return "DialogicTimeline"

	return ""


## 如果处理该类型，则返回 true
func _handles_type(typename: StringName) -> bool:
	return ClassDB.is_parent_class(typename, "Resource")


## 解析文件并返回资源
func _load(path: String, _original_path: String, _use_sub_threads: bool, _cache_mode: int) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)

	if not file:
		# 目前只是让编辑器知道，由于某种原因
		# 你无法读取该文件。
		print("[Dialogic] 打开文件出错：", FileAccess.get_open_error())
		return FileAccess.get_open_error()

	var tml := DialogicTimeline.new()
	tml.from_text(file.get_as_text())
	return tml


func _get_dependencies(path: String, _add_types: bool) -> PackedStringArray:
	var deps := PackedStringArray()

	var tml: DialogicTimeline = load(path)
	tml.process()

	for ev in tml.events:
		deps += ev.get_dependencies()

	var clean_deps := PackedStringArray()

	for i in deps:
		var clean := i
		if clean.begins_with("res://"):
			clean = ResourceUID.id_to_text(ResourceLoader.get_resource_uid(clean))
		if not clean.is_empty() and not clean in clean_deps:
			clean_deps.append(clean)

	return clean_deps
