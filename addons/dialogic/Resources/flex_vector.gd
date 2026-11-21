@tool
class_name DialogicFlexVector
extends Resource
## 表示一个位置或尺寸，可以是绝对像素值，也可以是相对于给定父级尺寸的相对值。[br][br]
## 允许混用，例如 x 可以是绝对值而 y 是相对值。
## 请注意：编辑此值，或通过 [method as_pixels]
## 或 [method as_percent] 获取它时，都要保证 [member container_size] 是最新的。
## 百分比是 0.0 到 1.0 之间的浮点数，1.0 表示 container_size 对应维度的 100%。
## 主要由 PortraitContainer 使用。

## FlexVector 的 x_value。
@export var x_value := 0.0:
	set(x):
		x_value = x
		emit_changed()

## FlexVector 的 y_value。
@export var y_value := 0.0:
	set(y):
		y_value = y
		emit_changed()

## 若为 true，[param x_value] 以百分比表示（范围 0 到 1，作为父级 x 维度的乘数）。
@export var x_percent := true
## 若为 true，[param y_value] 以百分比表示（范围 0 到 1，作为父级 y 维度的乘数）。
@export var y_percent := true

var container_size := Vector2()


## 以像素为单位返回值。请确保 container_size 是最新的。
func as_pixels() -> Vector2:
	return Vector2(
		x_value if not x_percent else x_value * container_size.x,
		y_value if not y_percent else y_value * container_size.y
		)


## 以百分比为单位返回值。请确保 container_size 是最新的。
func as_percent() -> Vector2:
	return Vector2(
		0 if container_size.x == 0 else x_value / container_size.x if not x_percent else x_value,
		0 if container_size.y == 0 else y_value / container_size.y if not y_percent else y_value
		)


## 加上给定的向量，同时保持当前的 x_percent 和 y_percent 状态，必要时转换传入的值。
func add(flex_vector:DialogicFlexVector) -> void:
	if x_percent == flex_vector.x_percent:
		x_value += flex_vector.x_value
	else:
		if x_percent:
			x_value += flex_vector.as_percent().x
		else:
			x_value += flex_vector.as_pixels().x

	if y_percent == flex_vector.y_percent:
		y_value += flex_vector.y_value
	else:
		if y_percent:
			y_value += flex_vector.as_percent().y
		else:
			y_value += flex_vector.as_pixels().y


## 从给定字符串创建新的 FlexVector。参见 [method overwrite_from_string]
static func from_string(input: String) -> DialogicFlexVector:
	var vec := DialogicFlexVector.new()
	vec.overwrite_from_string(input)
	return vec


## 从输入字符串中提取信息并应用到该 FlexVector。
## 字符串格式可以是 "x10 y20" 或 "x10px y0.2%"。
## 也可以只提供一个维度，另一个维度保持原值。
## 如果未指定类型，则按百分比处理。
func overwrite_from_string(input:String) -> void:
	var vector_regex := RegEx.create_from_string(r"(?<part>x|y)\s*(?<number>(-|\+)?(\d|\.|)*)(\s*(?<type>%|px))?")
	for i in vector_regex.search_all(input):
		var value := float(i.get_string(&'number'))
		match i.get_string(&'part').to_lower().strip_edges():
			"x":
				x_value = value
				match i.get_string(&'type'):
					"px":
						x_percent = false
					"%", _:
						x_percent = true
			"y":
				y_value = value
				match i.get_string(&'type'):
					"px":
						y_percent = false
					"%", _:
						y_percent = true



## 使用给定的 parent_size，以及 [param vector] 中假定为像素的值，创建新的 FlexVector。
static func from_vector(vector:Vector2, parent_size:=Vector2()) -> DialogicFlexVector:
	var vec := DialogicFlexVector.new()
	vec.container_size = parent_size
	vec.x_value = vector.x
	vec.x_percent = false
	vec.y_value = vector.y
	vec.y_percent = false
	return vec


## 用 [param vector] 中假定为像素的值替换当前值，但保持 x_percent 和 y_percent 状态，并在必要时进行转换。
func overwrite_from_vector(vector:Vector2) -> void:
	zero()
	add(from_vector(vector, container_size))



func copy() -> DialogicFlexVector:
	var vec := DialogicFlexVector.new()
	vec.x_value = x_value
	vec.y_value = y_value
	vec.x_percent = x_percent
	vec.y_percent = y_percent
	vec.container_size = container_size
	return vec


## 将两个值都设为 0。
func zero() -> void:
	x_value = 0
	y_value = 0


## 转换为 FlexVector 的字符串表示形式。
func _to_string() -> String:
	return "x" + str(self.x_value) + ["px", "%"][int(self.x_percent)] + " y" + str(self.y_value) + ["px", "%"][int(self.y_percent)] + " "+str(get_instance_id())


## 将给定 [param flex_vec] 的 x_percent 和 y_percent 应用到该对象，并转换数值。
## 请事先确保 container_size 是最新的。
func make_similar(flex_vec: DialogicFlexVector) -> void:
	if flex_vec.x_percent != x_percent:
		if flex_vec.x_percent:
			x_value = as_percent().x
			x_percent = true
		else:
			x_value = as_pixels().x
			x_percent = false
	if flex_vec.y_percent != y_percent:
		if flex_vec.y_percent:
			y_value = as_percent().y
			y_percent = true
		else:
			y_value = as_pixels().y
			y_percent = false
