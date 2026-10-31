extends Area3D
class_name TrainInteractable

var interaction_id: String = ""
var title: String = ""
var hint: String = ""
var active: bool = true:
	set(value):
		active = value
		collision_layer = 2 if value else 0

func configure(id: String, caption: String, description: String, size: Vector3) -> void:
	interaction_id = id
	title = caption
	hint = description
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
