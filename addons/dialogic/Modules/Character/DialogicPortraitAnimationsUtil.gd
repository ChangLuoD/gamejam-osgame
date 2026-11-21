@tool
class_name DialogicPortraitAnimationUtil

enum AnimationType {ALL=-1, IN=1, OUT=2, ACTION=3, CROSSFADE=4}


static func guess_animation(string:String, type := AnimationType.ALL) -> String:
	var default := {}
	var filter := {}
	var ignores := []
	match type:
		AnimationType.ALL:
			pass
		AnimationType.IN:
			filter = {"type":AnimationType.IN}
			ignores = ["in"]
		AnimationType.OUT:
			filter = {"type":AnimationType.OUT}
			ignores = ["out"]
		AnimationType.ACTION:
			filter = {"type":AnimationType.ACTION}
		AnimationType.CROSSFADE:
			filter = {"type":AnimationType.CROSSFADE}
			ignores = ["cross"]
	return DialogicResourceUtil.guess_special_resource(&"PortraitAnimation", string, default, filter, ignores).get("path", "")


static func get_portrait_animations_filtered(type := AnimationType.ALL) -> Dictionary:
	var filter := {"type":type}
	if type == AnimationType.ALL:
		filter["type"] = [AnimationType.IN, AnimationType.OUT, AnimationType.ACTION]
	return DialogicResourceUtil.list_special_resources("PortraitAnimation", filter)


static func get_suggestions(_search_text := "", current_value:= "", empty_text := "默认", action := AnimationType.ALL) -> Dictionary:
	var suggestions := {}

	if empty_text and current_value:
		suggestions[empty_text] = {'value':"", 'editor_icon':["GuiRadioUnchecked", "EditorIcons"]}

	for anim_name in get_portrait_animations_filtered(action):
		var pretty: String = DialogicUtil.pretty_name(anim_name)
		# 键是显示名，值仍是英文动画名（.dtl 与资源查找都用它）。
		suggestions[DialogicUtil.get_value_display_name(pretty)] = {
			'value'			: pretty,
			'editor_icon'	: ["Animation", "EditorIcons"]
			}

	return suggestions
