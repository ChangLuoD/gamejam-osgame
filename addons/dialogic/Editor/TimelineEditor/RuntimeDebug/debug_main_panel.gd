extends PanelContainer


func _ready() -> void:
	%PortraitContainers.button_pressed = owner.settings.get("portrait_container_debug", false)

	Dialogic.event_handled.connect(_update_timeline_info_label)
	Dialogic.state_changed.connect(_update_state_label)



func _update_timeline_info_label(_ignore="") -> void:
	if Dialogic.current_timeline == null:
		%TimelineInfo.text = "时间线：< 无时间线 >"
	else:
		%TimelineInfo.text = "时间线："+Dialogic.current_timeline.get_identifier()
		%TimelineInfo.text += "\n事件 "+str(Dialogic.current_event_idx)+"："+DialogicUtil.get_event_display_name(Dialogic.current_timeline_events[Dialogic.current_event_idx].event_name)


func _update_state_label(new_state:int) -> void:
	%StateInfo.text = "状态："+["空闲", "逐字显示", "动画中", "等待选择", "等待"][new_state]
