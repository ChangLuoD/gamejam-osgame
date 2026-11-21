@tool
extends DialogicEvent

# 在此定义事件的全部属性
# var MySetting: String = ""

func _execute() -> void:
	# 我也不知道这个事件是怎么工作的 ;)
	finish()


#region 初始化
################################################################################

# 在此设置所有永远不应改变的值
func _init() -> void:
	event_name = "Default"
	event_color = Color("#ffffff")
	event_category = "Main"
	event_sorting_index = 0

#endregion


#region 保存/加载
################################################################################
func get_shortcode() -> String:
	return "default_shortcode"


func get_shortcode_parameters() -> Dictionary:
	return {
		#参数名 	: 属性名
		#"arg_name"		: "NameOfProperty",
	}

# 你也可以改为覆盖这 3 个函数：
# - to_text(),
# - from_text(),
# - is_valid_event()

#endregion


#region 编辑器展示
################################################################################

func build_event_editor() -> void:
	pass

#endregion
