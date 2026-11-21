extends DialogicSubsystem
## 允许设置和获取设置的子系统，这些设置会自动保存且与存档位无关。
##
## 支持存储在项目设置 dialogic/settings 段中的所有设置。
## 例如 text_speed 设置就存储在那里。
## 如何在代码中访问此子系统：
##    ```gd
##        Dialogic.Settings.text_speed = 0.05
##    ```
##
## 存储在那里的设置也可以通过设置事件修改。


var settings := {}
var _connections := {}


#region 主要方法
####################################################################################################

## 内置方法，由 DialogicGameHandler 调用。
func _clear_state(_clear_flag:=DialogicGameHandler.ClearFlags.FULL_CLEAR):
	_reload_settings()


func _reload_settings() -> void:
	settings = {}
	for prop in ProjectSettings.get_property_list():
		if prop.name.begins_with('dialogic/settings'):
			settings[prop.name.trim_prefix('dialogic/settings/')] = ProjectSettings.get_setting(prop.name)

	if dialogic.has_subsystem('Save'):
		for i in settings:
			settings[i] = dialogic.Save.get_global_info(i, settings[i])


func _set(property:StringName, value:Variant) -> bool:
	if not settings.has(property) or settings[property] != value:
		_setting_changed(property, value)
	settings[property] = value
	if dialogic.has_subsystem('Save'):
		dialogic.Save.set_global_info(property, value)
	return true


func _get(property:StringName) -> Variant:
	if property in settings:
		return settings[property]
	return null


func _setting_changed(property:StringName, value:Variant) -> void:
	if !property in _connections:
		return

	for i in _connections[property]:
		if not is_instance_valid(i.get_object()):
			var remove := func(): _connections[property].erase(i)
			remove.call_deferred()
			continue
		i.call(value)

#endregion


#region 便捷方法
####################################################################################################

## 获取名为 `property` 的设置，如果它不存在，则回退到 `default`。
func get_setting(property: StringName, default: Variant) -> Variant:
	return _get(property) if _get(property) != null else default

## 某项设置之前是否已被设置/存储。
func has_setting(property: StringName) -> bool:
	return property in settings


func reset_all() -> void:
	for setting in settings:
		reset_setting(setting)


func reset_setting(property: StringName) -> void:
	if ProjectSettings.has_setting('dialogic/settings/'+property):
		settings[property] = ProjectSettings.get_setting('dialogic/settings/'+property)
		_setting_changed(property, settings[property])
	else:
		settings.erase(property)
		_setting_changed(property, null)


## 如果名为 `property` 的设置值发生变化，将发出 `Callable`。
func connect_to_change(property: StringName, callable: Callable) -> void:
	if not property in _connections:
		_connections[property] = []
	_connections[property].append(callable)

#endregion
