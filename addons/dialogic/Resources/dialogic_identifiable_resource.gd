@tool
extends Resource


func _get_extension() -> String:
	return ""


func _get_resource_name() -> String:
	return "DialogicIdentifiableResource"


func _to_string() -> String:
	return "[{name}:{id}]".format({"name":_get_resource_name(), "id":get_identifier()})


## 返回此角色的最佳名称。
func get_identifier() -> String:
	if resource_path:
		return DialogicResourceUtil.get_unique_identifier_by_path(resource_path)
	if not Engine.is_editor_hint():
		return DialogicResourceUtil.get_runtime_unique_identifier(self, _get_extension())
	return ""


## 设置此资源的唯一标识符字符串。
## 在编辑器中（若资源已保存），标识符会被存储。
## 在游戏中（若资源未存储），该资源会被临时注册。
func set_identifier(new_identifier:String) -> bool:
	if resource_path and Engine.is_editor_hint():
		DialogicResourceUtil.change_unique_identifier(resource_path, new_identifier)
		return true
	if not resource_path and not Engine.is_editor_hint():
		DialogicResourceUtil.register_runtime_resource(self, new_identifier, _get_extension())
		return true
	return false
