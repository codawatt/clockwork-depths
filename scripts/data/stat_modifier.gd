class_name StatModifier
extends Resource

@export var stat_name: StringName = &""
@export var additive: float = 0.0
@export var multiplier: float = 1.0

func is_valid() -> bool:
	return not stat_name.is_empty() and multiplier >= 0.0
