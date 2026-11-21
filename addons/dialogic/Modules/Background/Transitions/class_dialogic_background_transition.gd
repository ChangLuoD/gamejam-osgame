class_name DialogicBackgroundTransition
extends Node

## 辅助
var this_folder: String = get_script().resource_path.get_base_dir()


## 在调用 _fade() 之前设置，为上一个背景场景的根节点。
var prev_scene: Node
## 在调用 _fade() 之前设置，为上一个背景场景的视口纹理。
var prev_texture: ViewportTexture

## 在调用 _fade() 之前设置，为即将播放的背景场景的根节点。
var next_scene: Node
## 在调用 _fade() 之前设置，为即将播放的背景场景的视口纹理。
var next_texture: ViewportTexture

## 在调用 _fade() 之前设置，为此次淡入淡出请求的时长
var time: float

## 在调用 _fade() 之前设置，为背景容器（TextureRect）
var bg_holder: DialogicNode_BackgroundHolder


@warning_ignore("unused_signal") # 由继承此类的脚本使用
signal transition_finished


## 由各过渡脚本重写
func _fade() -> void:
	pass


func set_shader(path_to_shader:String=DialogicUtil.get_module_path('Background').path_join("Transitions/default_transition_shader.gdshader")) -> ShaderMaterial:
	if bg_holder:
		if path_to_shader.is_empty():
			bg_holder.material = null
			bg_holder.color = Color.TRANSPARENT
			return null
		bg_holder.material = ShaderMaterial.new()
		bg_holder.material.shader = load(path_to_shader)
		return bg_holder.material
	return null


func tween_shader_progress(_progress_parameter:="progress") -> PropertyTweener:
	if !bg_holder:
		return

	if !bg_holder.material is ShaderMaterial:
		return

	bg_holder.material.set_shader_parameter("progress", 0.0)
	var tween := create_tween()
	var tweener := tween.tween_property(bg_holder, "material:shader_parameter/progress", 1.0, time).from(0.0)
	tween.tween_callback(emit_signal.bind('transition_finished'))
	return tweener
