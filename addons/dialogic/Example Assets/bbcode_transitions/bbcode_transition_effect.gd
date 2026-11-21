@tool
class_name DialogicRichTextTransitionEffect
extends RichTextEffect

## 一个自定义富文本特效类，可以轻松地为逐字显示的字母添加动画。
## DialogicNode_DialogText 节点会正确更新 [member visible_characters]，并调用 [method reset] 和 [method skip]。
## 你可以直接为它创建一个资源，在检查器中编辑，并把它自身的路径/uid 加入
## Dialogic 的自定义 bbcode 特效设置。

## 由 DialogText 节点控制。
var visible_characters := -1

## bbcode 特效名称。
@export var bbcode := "animate_in"
var _cache := []

## 过渡时长。
@export_range(0.0, 5.0, 0.01) var time := 0.2
@export_group("颜色", "color")
## 在过渡期间调制文本颜色的渐变。
## 使用从透明到白色的渐变即可让文本淡入。
@export var color_modulate: Gradient = null
## 允许覆盖文本颜色，透明表示对文本颜色没有影响。
@export var color_replace: Gradient = null

@export_group("缩放", "scale")
## 启用缩放曲线动画。
@export var scale_enabled := false
## 为字符缩放添加动画的曲线。应以 1 结束。
@export var scale_curve := Curve.new()
## 应用缩放所围绕的轴心点。Vector2(0,0) 是字符的左下角，Vector2(1, 1) 是右上角。
@export var scale_pivot := Vector2()

@export_group("位置", "position")
## 启用位置曲线动画。
@export var position_enabled := false
## 为字符 x 位置添加动画的曲线。应以 0 结束。
@export var position_x_curve := Curve.new()
## 为字符 y 位置添加动画的曲线。应以 0 结束。
@export var position_y_curve := Curve.new()

@export_group("测试", "test")
## 可用于一次性预览整段文本的动画。小于 0 时被忽略。1 表示动画结束，与动画长度无关。
@export_range(-0.1, 1.0, 0.1) var test_value := -0.1

var _was_skipped := false
var _was_reset := false


## 当文本被清空/更改时由 DialogText 节点调用。
func reset() -> void:
	_was_reset = true
	_was_skipped = false
	_cache.clear()


## 当逐字显示被跳过时由 DialogText 节点调用，因此动画也会被跳过。
func skip() -> void:
	_was_skipped = true


## 实际处理字符的动画。
func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	var char_age :float = 0.0
	if test_value >= 0:
		char_age = remap(test_value, 0, 1, 0, time)

	else:
		if visible_characters == 0:
			_cache.clear()
			return false
		if _was_reset:
			if visible_characters != -1:
				_was_reset = false
			else:
				return false

		if len(_cache) < visible_characters or visible_characters == -1 or _was_skipped:
			if char_fx.range.x >= len(_cache):
				_cache.append(char_fx.elapsed_time)

		if _was_skipped:
			for i in range(len(_cache)):
				_cache[i] = char_fx.elapsed_time-time

		if len(_cache) > char_fx.range.x:
			char_age = char_fx.elapsed_time - _cache[char_fx.range.x]

	var text_server := TextServerManager.get_primary_interface()
	var trans: float = clamp(char_age, 0.0, time)/time

	if color_replace:
		var c := color_replace.sample(trans)
		c.a = 1
		char_fx.color = char_fx.color.lerp(c, color_replace.sample(trans).a)
	if color_modulate:
		char_fx.color *= color_modulate.sample(trans)
	if char_fx.font.is_valid():
		var glyph_size := text_server.font_get_glyph_size(char_fx.font, Vector2i(16,1), char_fx.glyph_index)
		if scale_enabled:
			char_fx.transform = char_fx.transform.translated_local(scale_pivot*glyph_size*Vector2(1, -1)*(1-scale_curve.sample(trans)))
			char_fx.transform = char_fx.transform.scaled_local(Vector2.ONE*scale_curve.sample(trans))

		if position_enabled:
			char_fx.transform = char_fx.transform.translated_local(Vector2(position_x_curve.sample(trans), position_y_curve.sample(trans))*glyph_size)

	return true
