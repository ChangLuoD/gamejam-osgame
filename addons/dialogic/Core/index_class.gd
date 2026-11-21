@tool
class_name DialogicIndexer
extends RefCounted

## 用于索引事件、子系统、设置页面等的脚本。[br]
## 在 "addons/Events" 的每个文件夹中放置一个此类型的脚本。[br]
## 重写这些方法以返回该文件夹中的内容。


var this_folder: String = get_script().resource_path.get_base_dir()

## 如果此模块包含任何事件，请重写此方法。[br]
## 返回一个数组，包含所有事件脚本的路径。[br]
## 你可以使用 [property this_folder].path_join('my_event.gd')
func _get_events() -> Array:
	if ResourceLoader.exists(this_folder.path_join('event.gd')):
		return [this_folder.path_join('event.gd')]
	return []


## 如果此模块包含任何子系统，请重写此方法。
## 应返回一个字典数组，每个字典包含以下键：[br]
## "name" 		-> 此子系统的名称[br]
## "script" 	-> 预览图像数组[br]
func _get_subsystems() -> Array[Dictionary]:
	return []


func _get_editors() -> Array[String]:
	return []


func _get_settings_pages() -> Array:
	return []


func _get_character_editor_sections() -> Array:
	return []


#region 文本效果与修饰器

## 应返回一个字典数组，每个字典包含以下键：[br]
## "command" 	-> 文本，例如 "speed"[br]
## "node_path" 或 "subsystem" -> 包含你的效果方法的那个[br]
## "method" 	-> 效果方法的名称[br]
func _get_text_effects() -> Array[Dictionary]:
	return []


## 应返回一个字典数组，参数与 _get_text_effects() 相同
func _get_text_modifiers() -> Array[Dictionary]:
	return []

#endregion


## 返回资源、脚本等的列表。
## 之后可以通过 DialogicResourceUtil 获取它们。
## 每个字典应包含（至少）"type" 与 "path"。
## 		E.g. {"type":"Animation", "path": "res://..."}
func _get_special_resources() -> Dictionary:
	return {}


## 返回一个字典列表
func _get_portrait_scene_presets() -> Array[Dictionary]:
	return []


#region 辅助函数
################################################################################

func list_dir(subdir:='') -> Array:
	return Array(DirAccess.get_files_at(this_folder.path_join(subdir))).map(func(file):return this_folder.path_join(subdir).path_join(file))


func list_special_resources(subdir:='', extension:="") -> Dictionary:
	var dict := {}
	for i in list_dir(subdir):
		if extension.is_empty() or i.ends_with(extension) or (extension == ".gd" and i.ends_with(".gdc")):
			dict[DialogicUtil.pretty_name(i).to_lower()] = {"path":i}
	return dict


func list_animations(subdir := "") -> Dictionary:
	var full_animation_list := {}
	for path in list_dir(subdir):
		if not path.ends_with(".gd") and not path.ends_with(".gdc"):
			continue
		var anim_object: DialogicAnimation = load(path).new()
		var versions := anim_object._get_named_variations()
		for version_name in versions:
			full_animation_list[version_name] = versions[version_name]
			full_animation_list[version_name]["path"] = path
		anim_object.queue_free()
	return full_animation_list

#endregion


#region 样式与布局
################################################################################

func _get_style_presets() -> Array[Dictionary]:
	return []


## 应返回一个字典数组，每个字典包含以下键：[br]
## "path" 		-> 场景的路径[br]
## "name"		-> 此布局的名称[br]
## "description"-> 此布局的描述。列出支持的功能/事件[br]
## "preview_image"-> 预览图像数组[br]
func _get_layout_parts() -> Array[Dictionary]:
	return []


## 辅助函数，用于扫描可能是布局部件或样式的子目录
func scan_for_layout_parts() -> Array[Dictionary]:
	var dir := DirAccess.open(this_folder)
	var style_list: Array[Dictionary] = []
	if !dir:
		return style_list
	dir.list_dir_begin()
	var dir_name := dir.get_next()
	while dir_name != "":
		if !dir.current_is_dir() or !dir.file_exists(dir_name.path_join('part_config.cfg')):
			dir_name = dir.get_next()
			continue
		var config := ConfigFile.new()
		config.load(this_folder.path_join(dir_name).path_join('part_config.cfg'))
		var default_image_path: String = this_folder.path_join(dir_name).path_join('preview.png')
		# 名称用于显示，同时用于生成自定义副本的文件名，
		# 因此保留英文标识，另提供中文显示名。
		var part_name: String = config.get_value('style', 'name', '未命名布局')
		style_list.append(
			{
				'type': config.get_value('style', 'type', '未知类型'),
				'name': part_name,
				'display_name': config.get_value('style', 'name_zh', part_name),
				'path': this_folder.path_join(dir_name).path_join(config.get_value('style', 'scene', '')),
				'author': config.get_value('style', 'author', '匿名'),
				'description': config.get_value('style', 'description', '无描述'),
				'preview_image': [config.get_value('style', 'image', default_image_path)],
				'style_path':config.get_value('style', 'style_path', ''),
				'icon':this_folder.path_join(dir_name).path_join(config.get_value('style', 'icon', '')),
			})

		if not style_list[-1].style_path.begins_with('res://'):
			style_list[-1].style_path = this_folder.path_join(dir_name).path_join(style_list[-1].style_path)

		dir_name = dir.get_next()

	return style_list

#endregion
