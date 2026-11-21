@tool
extends DialogicIndexer


func _get_events() -> Array:
	return [this_folder.path_join('event_character.gd')]


func _get_subsystems() -> Array:
	return [{'name':'Portraits', 'script':this_folder.path_join('subsystem_portraits.gd')}, {'name':'PortraitContainers', 'script':this_folder.path_join('subsystem_containers.gd')}]

func _get_settings_pages() -> Array:
	return [this_folder.path_join('settings_portraits.tscn')]

func _get_text_effects() -> Array[Dictionary]:
	return [
		{'command':'portrait', 'subsystem':'Portraits', 'method':'text_effect_portrait', 'arg':true},
		{'command':'extra_data', 'subsystem':'Portraits', 'method':'text_effect_extradata', 'arg':true},
	]


func _get_special_resources() -> Dictionary:
	return {&'PortraitAnimation': list_animations("DefaultAnimations")}


func _get_portrait_scene_presets() -> Array[Dictionary]:
	return [
		{
			"path": "",
			"name": "默认场景",
			"description": "在「设置>立绘」中定义的默认场景。",
			"author":"Dialogic",
			"type": "Default",
			"icon":"",
			"preview_image":[this_folder.path_join("default_portrait_thumbnail.png")],
			"documentation":"",
		},
		{
			"path": "CUSTOM",
			"name": "自定义场景",
			"description": "自定义场景。应继承 DialogicPortrait 并处于 @tool 模式。",
			"author":"Dialogic",
			"type": "Custom",
			"icon":"",
			"preview_image":[this_folder.path_join("custom_portrait_thumbnail.png")],
			"documentation":"https://docs.dialogic.pro/custom-portraits.html",
		},
		{
			"path": this_folder.path_join("default_portrait.tscn"),
			"name": "简单图片立绘",
			"description": "可以将图片显示为立绘，不提供其他功能。",
			"author":"Dialogic",
			"type": "General",
			"icon":"",
			"preview_image":[this_folder.path_join("simple_image_portrait_thumbnail.png")],
			"documentation":"",
		}
	]
