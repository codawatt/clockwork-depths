class_name StatBlock
extends RefCounted

signal changed(stat_name: StringName, value: float)

var _base: Dictionary = {}
var _modifiers_by_source: Dictionary = {}

func configure(base_values: Dictionary) -> void:
	_base.clear()
	for key: Variant in base_values:
		_base[StringName(str(key))] = float(base_values[key])
	_emit_all()

func set_base(stat_name: StringName, value: float) -> void:
	_base[stat_name] = value
	changed.emit(stat_name, get_value(stat_name))

func get_base(stat_name: StringName, fallback: float = 0.0) -> float:
	return float(_base.get(stat_name, fallback))

func add_modifier(source_id: StringName, stat_name: StringName, additive: float, multiplier: float = 1.0) -> void:
	var source: Dictionary = _modifiers_by_source.get(source_id, {})
	source[stat_name] = {"additive": additive, "multiplier": maxf(0.0, multiplier)}
	_modifiers_by_source[source_id] = source
	changed.emit(stat_name, get_value(stat_name))

func remove_source(source_id: StringName) -> void:
	var source: Variant = _modifiers_by_source.get(source_id)
	if not source is Dictionary:
		return
	_modifiers_by_source.erase(source_id)
	for stat_name: Variant in source:
		changed.emit(StringName(str(stat_name)), get_value(StringName(str(stat_name))))

func get_value(stat_name: StringName, fallback: float = 0.0) -> float:
	var value := get_base(stat_name, fallback)
	var multiplier := 1.0
	for source_value: Variant in _modifiers_by_source.values():
		if source_value is Dictionary and source_value.has(stat_name):
			var modifier: Dictionary = source_value[stat_name]
			value += float(modifier.get("additive", 0.0))
			multiplier *= float(modifier.get("multiplier", 1.0))
	return value * multiplier

func serialize_base() -> Dictionary:
	var result := {}
	for key: Variant in _base:
		result[String(key)] = _base[key]
	return result

func _emit_all() -> void:
	for key: Variant in _base:
		changed.emit(StringName(str(key)), get_value(StringName(str(key))))
