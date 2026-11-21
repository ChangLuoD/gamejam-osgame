extends Node
class_name SePlayer

static var node: SePlayer

## 调试输出
@export var debug_print: bool = false

@export_group("节点数据")
## 按钮点击音频

func _enter_tree() -> void:
	node = self
func _exit_tree() -> void:
	node = null
## 播放音效,音量随机浮动[0.8 - 1.2]
func play(_stream: AudioStream, random_pitch: bool = true) -> void:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = AudioServer.get_bus_name(2)
	player.name = "SePlayer[" + str(get_children().size()) + "]"
	player.stream = _stream
	if random_pitch:
		player.pitch_scale = randf_range(0.8, 1.2)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
	if debug_print:
		print("声音播放: [%s]" % _stream.resource_path)
