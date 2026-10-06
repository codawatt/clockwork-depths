class_name CombatProjectile
extends Node3D

var velocity: Vector3 = Vector3.ZERO
var lifetime: float = 4.0
var _hitbox: Hitbox

func configure(context: DamageContext, direction: Vector3, speed: float, radius: float = 0.32, color: Color = Color.CYAN) -> void:
	velocity = direction.normalized() * speed
	_hitbox = Hitbox.new()
	_hitbox.configure(context, radius, lifetime)
	_hitbox.hit_landed.connect(_on_hit)
	add_child(_hitbox)
	add_child(PrimitiveFactory.sphere_visual(radius, color, 2.3))
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	lifetime -= delta
	if lifetime <= 0.0 or global_position.y < -2.0:
		queue_free()

func _on_hit(_hurtbox: Hurtbox) -> void:
	queue_free()
