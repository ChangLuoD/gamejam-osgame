@tool
extends DialogicIndexer


func _get_portrait_scene_presets() -> Array[Dictionary]:
	return [
		{
			"path": this_folder.path_join("simple_highlight_portrait.tscn"),
			"name": "简单高亮立绘",
			"description": "一种简单的立绘场景，只显示一张图片，但当此角色说话时会改变颜色并移到最前面。",
			"author":"Dialogic",
			"type": "General",
			"icon":"",
			"preview_image":[this_folder.path_join("highlight_portrait_thumbnail.png")],
			"documentation":"",
		},
	]
