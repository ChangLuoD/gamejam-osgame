extends Node
class_name SettingManager
## 游戏设置

## 保存路径
const SAVE_PATH: String = "user://config.cfg"

@onready var display_setting: DisplaySetting = %DisplaySetting

@onready var volume_setting: VolumeSetting = %VolumeSetting

@export_category("调试")
## 调试打印
@export var debug_print: bool = false

func _ready() -> void:
	load_config()
	if debug_print:
		print_config()

## 保存配置
func save_config() -> void:
	var config_file: ConfigFile = ConfigFile.new()

	display_setting.save_config(config_file)
	volume_setting.save_config(config_file)

	config_file.save(SAVE_PATH)
	if debug_print:
		print_config()
		print("游戏设置已保存")

## 加载设置
func load_config() -> void:
	var config_file: ConfigFile = ConfigFile.new()
	if config_file.load(SAVE_PATH) != OK:
		push_warning("未找到设置文件,重置为默认设置")
		apply_default_config()
		save_config()
	else:
		display_setting.load_config(config_file)
		volume_setting.load_config(config_file)
		if debug_print:
			print("游戏设置已读取")

## 应用默认设置
func apply_default_config() -> void:
	display_setting.apply_default_config()
	volume_setting.apply_default_config()

## 打印配置
func print_config() -> void:
	print("========== 游戏设置 ==========")
	print("保存路径: %s" % SAVE_PATH)
	print("---- 显示设置 ----")
	display_setting.print_config()
	print("---- 音量设置 ----")
	volume_setting.print_config()
	print("==============================")
