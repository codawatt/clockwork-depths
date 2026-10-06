class_name Hitbox
extends Area3D

signal hit_landed(hurtbox: Hurtbox)

var context: DamageContext
var lifetime: float = 0.16
var _already_hit: Dictionary = {}

func configure(damage_context: DamageContext, radius: float, duration: float = 0.16) -> void:
	context = damage_context
	lifetime = duration
	collision_layer = 4
	collision_mask = 8
	monitoring = true
	monitorable = false
	add_child(PrimitiveFactory.sphere_shape(radius))

func _physics_process(delta: float) -> void:
	lifetime -= delta
	for area: Area3D in get_overlapping_areas():
		if area is Hurtbox:
			var hurtbox: Hurtbox = area
			var actor_id := hurtbox.actor.get_instance_id() if is_instance_valid(hurtbox.actor) else hurtbox.get_instance_id()
			if not _already_hit.has(actor_id) and hurtbox.receive_hit(context):
				_already_hit[actor_id] = true
				hit_landed.emit(hurtbox)
	if lifetime <= 0.0:
		queue_free()
