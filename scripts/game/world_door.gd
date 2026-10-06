class_name WorldDoor
extends StaticBody3D

var locked: bool = true
var _collision: CollisionShape3D
var _visual: MeshInstance3D

func setup(width: float = 16.0, color: Color = Color(0.95, 0.18, 0.08)) -> void:
	name = "EncounterDoor"
	collision_layer = 1
	collision_mask = 0
	_collision = PrimitiveFactory.box_shape(Vector3(0.65, 3.2, width))
	_collision.position.y = 0.6
	add_child(_collision)
	_visual = PrimitiveFactory.box_visual(Vector3(0.65, 3.2, width), color, 1.2)
	_visual.position.y = 0.6
	add_child(_visual)
	set_locked(true)

func set_locked(value: bool) -> void:
	locked = value
	if _collision == null or _visual == null:
		return
	_collision.set_deferred("disabled", not locked)
	_visual.visible = locked
