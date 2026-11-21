@tool
extends HBoxContainer

var parent_resource: DialogicEvent = null


func _ready() -> void:
	$AddElif.icon = get_theme_icon("Add", "EditorIcons")
	$AddElse.icon = get_theme_icon("Add", "EditorIcons")
	$AddElif.button_up.connect(add_elif)
	$AddElse.button_up.connect(add_else)


func refresh() -> void:
	if parent_resource is DialogicConditionEvent:
		# 在 ELSE 事件上隐藏「添加 elif」和「添加 else」按钮
		$AddElif.visible = parent_resource.condition_type != DialogicConditionEvent.ConditionTypes.ELSE
		$AddElse.visible = parent_resource.condition_type != DialogicConditionEvent.ConditionTypes.ELSE
		$Label.text = "结束于 "+["IF", "ELIF", "ELSE"][parent_resource.condition_type]+"（"+parent_resource.condition+"）"

		# 如果后面紧跟 ELIF 或 ELSE 事件，则隐藏「添加 else」按钮
		var timeline_editor := find_parent('VisualEditor')
		if timeline_editor:
			var next_event: DialogicEvent = null
			if timeline_editor.get_block_below(get_parent()):
				next_event = timeline_editor.get_block_below(get_parent()).resource
				if next_event is DialogicConditionEvent:
					if next_event.condition_type != DialogicConditionEvent.ConditionTypes.IF:
						$AddElse.hide()
		if parent_resource.condition_type == DialogicConditionEvent.ConditionTypes.ELSE:
			$Label.text = "结束于 ELSE"
	else:
		hide()


func add_elif() -> void:
	var timeline := find_parent('VisualEditor')
	if timeline:
		var resource := DialogicConditionEvent.new()
		resource.condition_type = DialogicConditionEvent.ConditionTypes.ELIF
		timeline.add_event_undoable(resource, get_parent().get_index()+1)
		timeline.indent_events()
		timeline.something_changed()


func add_else() -> void:
	var timeline := find_parent('VisualEditor')
	if timeline:
		var resource := DialogicConditionEvent.new()
		resource.condition_type = DialogicConditionEvent.ConditionTypes.ELSE
		timeline.add_event_undoable(resource, get_parent().get_index()+1)
		timeline.indent_events()
		timeline.something_changed()
