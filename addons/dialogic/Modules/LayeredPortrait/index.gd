@tool
extends DialogicIndexer


func _get_portrait_scene_presets() -> Array[Dictionary]:
	return [
		{
			"path": this_folder.path_join("layered_portrait.tscn"),
			"name": "分层立绘",
			"description": "由多个精灵拼成的角色的基础场景。可以通过角色事件的额外数据显示、切换和隐藏各个图层。",
			"author":"Cake for Dialogic",
			"type": "Preset",
			"icon":"",
			"preview_image":[this_folder.path_join("layered_portrait_thumbnail.png")],
			"documentation":"https://docs.dialogic.pro/layered-portraits.html",
		},
	]
