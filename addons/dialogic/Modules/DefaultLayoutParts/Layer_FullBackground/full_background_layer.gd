@tool
extends DialogicLayoutLayer

# 这样做有点别扭，但我们需要一个 'none' 默认值来保持兼容性
# 这些枚举只是 Viewport.DefaultCanvasItemTextureFilter 的副本
enum DefaultCanvasItemTextureFilter {
	USE_PROJECT_SETTINGS=-1,
	NEAREST=0,
	LINEAR=1,
	LINEAR_WITH_MIPMAPS=2,
	NEAREST_WITH_MIPMAPS=3
}

# 这些枚举只是 Viewport.DefaultCanvasItemTextureRepeat 的副本
enum DefaultCanvasItemTextureRepeat {
	USE_PROJECT_SETTINGS=-1,
	DISABLED=0,
	ENABLED=1,
	REPEAT_MIRROR=2
}


@export var bg_texture_filter : DefaultCanvasItemTextureFilter = DefaultCanvasItemTextureFilter.USE_PROJECT_SETTINGS
@export var bg_texture_repeat : DefaultCanvasItemTextureRepeat = DefaultCanvasItemTextureRepeat.USE_PROJECT_SETTINGS
