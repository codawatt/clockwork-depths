class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(context: DamageContext, applied_damage: float)
signal died(context: DamageContext)

var maximum: float = 1.0
var current: float = 1.0
var armor: float = 0.0
var invulnerability_seconds: float = 0.16
var _invulnerability_remaining: float = 0.0
var _dead: bool = false

func _process(delta: float) -> void:
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)

func configure(maximum_health: float, defense: float = 0.0) -> void:
	maximum = maxf(1.0, maximum_health)
	current = maximum
	armor = maxf(0.0, defense)
	_dead = false
	health_changed.emit(current, maximum)

func set_maximum(value: float, preserve_ratio: bool = false) -> void:
	var ratio := current / maximum if maximum > 0.0 else 1.0
	maximum = maxf(1.0, value)
	current = clampf(maximum * ratio if preserve_ratio else current, 0.0, maximum)
	health_changed.emit(current, maximum)

func heal(amount: float) -> float:
	if _dead or amount <= 0.0:
		return 0.0
	var before := current
	current = minf(maximum, current + amount)
	health_changed.emit(current, maximum)
	return current - before

func apply_damage(context: DamageContext) -> bool:
	if _dead or context == null or context.amount <= 0.0:
		return false
	if _invulnerability_remaining > 0.0:
		return false
	var applied := maxf(1.0, context.amount - armor)
	current = maxf(0.0, current - applied)
	_invulnerability_remaining = invulnerability_seconds
	damaged.emit(context, applied)
	health_changed.emit(current, maximum)
	if current <= 0.0:
		_dead = true
		died.emit(context)
	return true

func grant_invulnerability(seconds: float) -> void:
	_invulnerability_remaining = maxf(_invulnerability_remaining, maxf(0.0, seconds))

func revive(full_health: bool = true) -> void:
	_dead = false
	current = maximum if full_health else maxf(1.0, current)
	_invulnerability_remaining = 0.5
	health_changed.emit(current, maximum)

func is_dead() -> bool:
	return _dead
