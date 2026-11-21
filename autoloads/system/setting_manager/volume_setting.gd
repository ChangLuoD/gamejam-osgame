extends Node
class_name VolumeSetting

## 默认配置
const DEFAULT_CONFIG: Dictionary = {
	"mute" : false,
	"master_volume" : 0.7,
	"music_volume" : 0.7,
	"se_volume" : 0.7,
	"video_volume" : 0.7,
}

## 静音
@export var mute: bool = DEFAULT_CONFIG["mute"]:
	set(value):
		mute = value
		set_mute(mute)

## 主音量
@export_range(0.0, 1.0, 0.01) 
var master_volume: float = DEFAULT_CONFIG["master_volume"]:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		set_volume(0, master_volume)

## 音乐音量
@export_range(0.0, 1.0, 0.01) 
var music_volume: float = DEFAULT_CONFIG["music_volume"]:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		set_volume(1, music_volume)
		
## 音效音量
@export_range(0.0, 1.0, 0.01) 
var se_volume: float = DEFAULT_CONFIG["se_volume"]:
	set(value):
		se_volume = clampf(value, 0.0, 1.0)
		set_volume(2, se_volume)

## 音效音量
@export_range(0.0, 1.0, 0.01) 
var video_volume: float = DEFAULT_CONFIG["video_volume"]:
	set(value):
		video_volume = clampf(value, 0.0, 1.0)
		set_volume(3, video_volume)
## 加载配置
func load_config(config_file: ConfigFile) -> void:
	mute = config_file.get_value("volume", "mute", DEFAULT_CONFIG["mute"])
	master_volume = config_file.get_value("volume", "master_volume", DEFAULT_CONFIG["master_volume"])
	music_volume = config_file.get_value("volume", "music_volume", DEFAULT_CONFIG["music_volume"])
	se_volume = config_file.get_value("volume", "se_volume", DEFAULT_CONFIG["se_volume"])
	video_volume = config_file.get_value("volume", "video_volume", DEFAULT_CONFIG["video_volume"])

## 保存配置
func save_config(config_file: ConfigFile) -> void:
	config_file.set_value("volume", "mute", mute)
	config_file.set_value("volume", "master_volume", master_volume)
	config_file.set_value("volume", "music_volume", music_volume)
	config_file.set_value("volume", "se_volume", se_volume)
	config_file.set_value("volume", "video_volume", video_volume)
	
## 应用默认配置
func apply_default_config() -> void:
	mute = DEFAULT_CONFIG["mute"]
	master_volume = DEFAULT_CONFIG["master_volume"]
	music_volume = DEFAULT_CONFIG["music_volume"]
	se_volume = DEFAULT_CONFIG["se_volume"]
	video_volume = DEFAULT_CONFIG["video_volume"]

## 设置音量
func set_volume(bus_index: int, value: float) -> void:
	AudioServer.set_bus_volume_linear(bus_index, value)

## 设置静音
func set_mute(is_mute: bool) -> void:
	for bus_index in range(AudioServer.bus_count):
		AudioServer.set_bus_mute(bus_index ,is_mute)

## 打印配置
func print_config() -> void:
	print("静音: %s" % mute)
	print("主音量: %.2f" % master_volume)
	print("音乐音量: %.2f" % music_volume)
	print("音效音量: %.2f" % se_volume)
	print("视频音量: %.2f" % video_volume)
