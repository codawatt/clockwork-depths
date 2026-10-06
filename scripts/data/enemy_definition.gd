class_name EnemyDefinition
extends Resource

enum Archetype { MELEE, RANGED, BOSS }

@export var enemy_id: StringName = &""
@export var display_name: String = "Enemy"
@export var archetype: Archetype = Archetype.MELEE
@export_range(1.0, 1000.0) var max_health: float = 40.0
@export_range(0.1, 20.0) var move_speed: float = 3.0
@export_range(0.0, 100.0) var damage: float = 10.0
@export_range(0.2, 20.0) var attack_range: float = 2.0
@export_range(0.1, 20.0) var attack_cooldown: float = 1.5
@export_range(0, 1000, 1) var currency_reward: int = 5
@export var color: Color = Color(0.9, 0.2, 0.2)

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if enemy_id.is_empty(): errors.append("enemy_id is required")
	if max_health <= 0.0: errors.append("max_health must be positive")
	if move_speed <= 0.0: errors.append("move_speed must be positive")
	if attack_cooldown <= 0.0: errors.append("attack_cooldown must be positive")
	return errors
