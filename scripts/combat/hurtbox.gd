class_name Hurtbox
extends Area3D

var team: int = 0
var health: HealthComponent
var actor: Node3D

func configure(owner_actor: Node3D, health_component: HealthComponent, actor_team: int, radius: float = 0.7) -> void:
	actor = owner_actor
	health = health_component
	team = actor_team
	collision_layer = 8
	collision_mask = 0
	monitorable = true
	add_child(PrimitiveFactory.sphere_shape(radius))

func receive_hit(context: DamageContext) -> bool:
	if context == null or health == null or context.source_team == team:
		return false
	context.hit_position = global_position
	return health.apply_damage(context)
