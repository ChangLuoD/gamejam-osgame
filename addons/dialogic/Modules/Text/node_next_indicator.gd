@icon("node_next_indicator_icon.svg")
class_name DialogicNode_NextIndicator
extends Control

## 在文本完全显示后显示的节点。
## 默认实现允许设置图标和动画。


@export var enabled := true

## 若为 true，当文本是问题时也会显示下一句指示器。
@export var show_on_questions := false
## 若为 true，即使 Dialogic 会自动继续，也会显示下一句指示器。
@export var show_on_autoadvance := false

enum Animations {BOUNCE, BLINK, NONE}

## 指示器应播放哪种动画。
@export var animation := Animations.BOUNCE

var texture_rect: TextureRect

## 设置用作指示器的图像。
@export var texture: Texture2D = preload("res://addons/dialogic/Example Assets/next-indicator/next-indicator.png") as Texture2D:
	set(_texture):
		texture = _texture
		if texture_rect:
			texture_rect.texture = texture

@export var texture_size := Vector2(32,32):
	set(_texture_size):
		texture_size = _texture_size
		if has_node('Texture'):
			get_node('Texture').size = _texture_size
			get_node('Texture').position = -_texture_size

@export var indicator_offset := Vector2(0, 0):
	set(_indicator_offset):
		indicator_offset = _indicator_offset
		if has_node('Texture'):
			texture_rect.position = indicator_offset

var tween: Tween

func _ready() -> void:
	add_to_group('dialogic_next_indicator')
	gui_input.connect(_on_gui_input)
	# 缺少 TextureRect 时创建一个
	if not texture_rect:
		var icon := TextureRect.new()
		icon.name = 'Texture'
		icon.ignore_texture_size = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = texture_size
		icon.position = -icon.size
		add_child(icon)
		texture_rect = icon

	texture_rect.texture = texture

	hide()
	visibility_changed.connect(_on_visibility_changed)


func _on_gui_input(event: InputEvent) -> void:
	DialogicUtil.autoload().Inputs.handle_node_gui_input(event)


func _on_visibility_changed() -> void:
	if visible:
		play_animation(animation, 1.0)

		if indicator_offset != Vector2.ZERO:
			texture_rect.position = indicator_offset



func play_animation(current_animation: int, time:float) -> void:
	# 清理之前的补间，避免位置漂移
	if tween:
		tween.stop()

	match current_animation:
		Animations.BOUNCE:
			tween = (create_tween() as Tween)
			var distance := 4
			tween.set_parallel(false)
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_loops()

			tween.tween_property(self, 'position', Vector2(0,distance), time*0.3).as_relative()
			tween.tween_property(self, 'position', - Vector2(0,distance), time*0.3).as_relative()
		Animations.BLINK:
			tween = (create_tween() as Tween)
			tween.set_parallel(false)
			tween.set_trans(Tween.TRANS_SINE)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.set_loops()

			tween.tween_property(self, 'modulate:a', 0, time*0.3)
			tween.tween_property(self, 'modulate:a', 1, time*0.3)
