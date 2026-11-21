@tool
extends DialogicPortrait

## 默认立绘场景。
## 父类拥有 character 和 portrait 变量。

@export_group('Main')
@export_file var image := ""


## 加载与给定角色和立绘相关的内容
func _update_portrait(passed_character:DialogicCharacter, passed_portrait:String) -> void:
	apply_character_and_portrait(passed_character, passed_portrait)

	apply_texture($Portrait, image)
