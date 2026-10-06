class_name ItemInstance
extends RefCounted

var instance_id: String = ""
var definition_id: StringName = &""
var quantity: int = 1
var durability: float = 1.0
var upgrade_level: int = 0
var rolled_modifiers: Dictionary = {}
var metadata: Dictionary = {}

static func create(definition: StringName, amount: int = 1, custom_metadata: Dictionary = {}) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = "%s-%d-%d" % [definition, Time.get_ticks_usec(), randi()]
	item.definition_id = definition
	item.quantity = maxi(1, amount)
	item.metadata = custom_metadata.duplicate(true)
	return item

func to_dict() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": String(definition_id),
		"quantity": quantity,
		"durability": durability,
		"upgrade_level": upgrade_level,
		"rolled_modifiers": rolled_modifiers.duplicate(true),
		"metadata": metadata.duplicate(true),
	}

static func from_dict(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = str(data.get("instance_id", ""))
	item.definition_id = StringName(str(data.get("definition_id", "")))
	item.quantity = int(data.get("quantity", 0))
	item.durability = clampf(float(data.get("durability", 1.0)), 0.0, 1.0)
	item.upgrade_level = maxi(0, int(data.get("upgrade_level", 0)))
	var rolled: Variant = data.get("rolled_modifiers", {})
	item.rolled_modifiers = rolled.duplicate(true) if rolled is Dictionary else {}
	var custom: Variant = data.get("metadata", {})
	item.metadata = custom.duplicate(true) if custom is Dictionary else {}
	return item

func is_structurally_valid() -> bool:
	return not instance_id.is_empty() and not definition_id.is_empty() and quantity > 0
