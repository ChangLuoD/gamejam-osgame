extends Node
class_name DisplaySetting

## 默认配置
const DEFAULT_CONFIG: Dictionary = {
	"window_size": "1280x720",
	"window_mode": "windowed",
	"max_fps": "120",
	"vsync_mode": "disabled",
}

## 窗口大小静态值
const WINDOW_SIZES: Dictionary = {
	#"3840x2160": Vector2i(3840, 2160),	# 3840x2160
	"2560x1440": Vector2i(2560, 1440),	# 2560x1440
	"1920x1080": Vector2i(1920, 1080),	# 1920x1080
	"1600x900": Vector2i(1600, 900),	# 1600x900
	"1280x720": Vector2i(1280, 720),	# 1280x720
	"640x360": Vector2i(640, 360),		# 640x480
}

## 窗口模式映射
const WINDOW_MODES: Dictionary = {
	"windowed": Window.Mode.MODE_WINDOWED,							# 窗口模式
	#"maximized": Window.Mode.MODE_MAXIMIZED,						# 最大化模式
	"fullscreen": Window.Mode.MODE_FULLSCREEN,						# 全屏模式
	#"exclusive_fullscreen": Window.Mode.MODE_EXCLUSIVE_FULLSCREEN,	# 独占全屏模式
}

## 最大刷新率
const MAX_FPS: Dictionary = {
	"30": 30,
	"60": 60,
	"120": 120,
	"144": 144,
	"unlimited": 0,
}

## 垂直同步模式映射
const VSYNC_MODES: Dictionary = {
	"disabled": DisplayServer.VSyncMode.VSYNC_DISABLED,	# 禁用垂直同步
	"enabled": DisplayServer.VSyncMode.VSYNC_ENABLED,	# 启用垂直同步
	"adaptive": DisplayServer.VSyncMode.VSYNC_ADAPTIVE,	# 自适应垂直同步
}

## 游戏窗口大小
@export_enum("2560x1440", "1920x1080", "1600x900", "1280x720", "640x360")
var window_size: String = DEFAULT_CONFIG["window_size"]:
	set(value):
		window_size = value
		set_window_size(window_size)

## 游戏窗口模式
@export_enum("windowed", "fullscreen") 
var window_mode: String = DEFAULT_CONFIG["window_mode"]:
	set(value):
		window_mode = value
		set_window_mode(window_mode)

## 最大刷新率
@export_enum("30", "60", "120", "144", "unlimited") 
var max_fps: String = DEFAULT_CONFIG["max_fps"]:
	set(value):
		max_fps = value
		set_max_fps(max_fps)

## 垂直同步模式
@export_enum("disabled", "enabled", "adaptive") 
var vsync_mode: String = DEFAULT_CONFIG["vsync_mode"]:
	set(value):
		vsync_mode = value
		set_vsync_mode(vsync_mode)

## 加载配置
func load_config(config_file: ConfigFile) -> void:
	window_size = config_file.get_value("graphics", "window_size", DEFAULT_CONFIG["window_size"])
	window_mode = config_file.get_value("graphics", "window_mode", DEFAULT_CONFIG["window_mode"])
	max_fps = config_file.get_value("graphics", "max_fps", DEFAULT_CONFIG["max_fps"])
	vsync_mode = config_file.get_value("graphics", "vsync_mode", DEFAULT_CONFIG["vsync_mode"])

## 保存配置
func save_config(config_file: ConfigFile) -> void:
	config_file.set_value("graphics", "window_size", window_size)
	config_file.set_value("graphics", "window_mode", window_mode)
	config_file.set_value("graphics", "max_fps", max_fps)
	config_file.set_value("graphics", "vsync_mode", vsync_mode)

## 应用默认配置
func apply_default_config() -> void:
	window_size = DEFAULT_CONFIG["window_size"]
	window_mode = DEFAULT_CONFIG["window_mode"]
	max_fps = DEFAULT_CONFIG["max_fps"]
	vsync_mode = DEFAULT_CONFIG["vsync_mode"]

## 设置窗口大小
func set_window_size(size: String) -> void:
	var window: Window = get_window()
	if window == null:
		return
	if WINDOW_SIZES.has(size):
		window.size = WINDOW_SIZES[size]
		window.move_to_center()
	else:
		push_warning("窗口大小中静态变量中没有对应键值: [%s]" % size)

## 获取窗口大小键列表
func get_window_size_keys() -> Array[String]:
	return WINDOW_SIZES.keys()

## 获取当前窗口大小索引
func get_window_size_index() -> int:
	var keys: Array = WINDOW_SIZES.keys()
	var index: int = keys.find(window_size)
	if index == -1:
		index = 0
	return index

## 按索引设置窗口大小
func set_window_size_by_index(index: int) -> void:
	var keys: Array = WINDOW_SIZES.keys()
	if index >= 0 and index < keys.size():
		window_size = keys[index]
	else:
		push_warning("窗口大小索引越界: [%d]" % index)

## 设置窗口模式
func set_window_mode(mode: String) -> void:
	var window: Window = get_window()
	if window == null:
		push_warning("未捕获到窗口")
		return
	if WINDOW_MODES.has(mode):
		window.mode = WINDOW_MODES[mode] as Window.Mode
		window.move_to_center()
	else:
		push_warning("窗口模式中静态变量中没有对应键值: [%s]" % mode)

## 设置最大刷新率
func set_max_fps(fps: String) -> void:
	if MAX_FPS.has(fps):
		Engine.max_fps = MAX_FPS[fps]
	else:
		push_warning("最大刷新率中静态变量中没有对应键值: [%s]" % fps)

## 设置垂直同步
func set_vsync_mode(vsync: String) -> void:
	if VSYNC_MODES.has(vsync):
		DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync] as DisplayServer.VSyncMode)
	else:
		push_warning("垂直同步模式中静态变量中没有对应键值: [%s]" % vsync)

## 打印配置
func print_config() -> void:
	print("窗口大小: %s" % window_size)
	print("窗口模式: %s" % window_mode)
	print("最大刷新率: %s" % max_fps)
	print("垂直同步模式: %s" % vsync_mode)
