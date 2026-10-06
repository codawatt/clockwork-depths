class_name HazardPulse
extends Node3D

var period: float = 2.4
var telegraph_time: float = 0.75
var radius: float = 2.1
var damage: float = 11.0
var _remaining: float = 0.6
var _telegraphing := false
var _marker: MeshInstance3D

func setup(tint: Color = Color(1.0, 0.1, 0.05)) -> void:
	_marker = PrimitiveFactory.cylinder_visual(radius, 0.055, tint, 2.0)
	_marker.position.y = -0.92
	_marker.scale = Vector3(0.18, 1.0, 0.18)
	add_child(_marker)

func _physics_process(delta: float) -> void:
	_remaining -= delta
	if not _telegraphing and _remaining <= telegraph_time:
		_telegraphing = true
		var tween := create_tween()
		tween.tween_property(_marker, "scale", Vector3.ONE, telegraph_time)
	if _remaining <= 0.0:
		_pulse()
		_remaining = period
		_telegraphing = false
		_marker.scale = Vector3(0.18, 1.0, 0.18)

func _pulse() -> void:
	var context := DamageContext.create(damage, EnemyActor.TEAM, "conduit", DamageContext.AttackCategory.HAZARD, DamageContext.DamageType.HAZARD)
	context.knockback = Vector3(4.0, 0.0, 0.0)
	var hitbox := Hitbox.new()
	hitbox.configure(context, radius, 0.18)
	get_parent().add_child(hitbox)
	hitbox.global_position = global_position
	var flash := PrimitiveFactory.cylinder_visual(radius, 0.12, Color(1.0, 0.65, 0.05), 3.0)
	get_parent().add_child(flash)
	flash.global_position = global_position + Vector3(0, -0.87, 0)
	var tween := get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector3(1.25, 1.0, 1.25), 0.22)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.22)
	tween.tween_callback(flash.queue_free)
