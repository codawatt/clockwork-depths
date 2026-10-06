class_name EquipmentModel
extends RefCounted

signal changed(slot_name: StringName)

const SLOT_NAMES: Array[StringName] = [&"weapon", &"shield", &"helmet", &"armor", &"accessory"]

var _inventory: InventoryModel
var _stats: StatBlock
var _definitions: Dictionary = {}
var _equipped: Dictionary = {}

func configure(inventory: InventoryModel, stats: StatBlock, definitions: Dictionary) -> void:
	_inventory = inventory
	_stats = stats
	_definitions = definitions
	_equipped.clear()
	for slot_name: StringName in SLOT_NAMES:
		_equipped[slot_name] = null

func equipped(slot_name: StringName) -> ItemInstance:
	var item: Variant = _equipped.get(slot_name)
	return item if item is ItemInstance else null

func equip(instance_id: String) -> bool:
	var candidate := _inventory.find_instance(instance_id)
	if candidate == null or not _definitions.has(candidate.definition_id):
		return false
	var definition: ItemDefinition = _definitions[candidate.definition_id]
	if definition.item_type != ItemDefinition.ItemType.EQUIPMENT:
		return false
	var slot_name := definition.slot_name()
	if not _equipped.has(slot_name):
		return false
	var taken := _inventory.take_instance(instance_id)
	if taken == null:
		return false
	var previous: ItemInstance = equipped(slot_name)
	if previous != null and not _inventory.add_instance(previous):
		_inventory.add_instance(taken)
		return false
	_remove_item_modifiers(previous)
	_equipped[slot_name] = taken
	_apply_item_modifiers(taken)
	changed.emit(slot_name)
	return true

func unequip(slot_name: StringName) -> bool:
	var previous := equipped(slot_name)
	if previous == null or not _inventory.add_instance(previous):
		return false
	_remove_item_modifiers(previous)
	_equipped[slot_name] = null
	changed.emit(slot_name)
	return true

func serialize() -> Dictionary:
	var result := {}
	for slot_name: StringName in SLOT_NAMES:
		var item := equipped(slot_name)
		result[String(slot_name)] = item.to_dict() if item != null else null
	return result

func restore(data: Dictionary) -> int:
	var discarded := 0
	for slot_name: StringName in SLOT_NAMES:
		_remove_item_modifiers(equipped(slot_name))
		_equipped[slot_name] = null
		var value: Variant = data.get(String(slot_name))
		if value == null:
			continue
		if not value is Dictionary:
			discarded += 1
			continue
		var item := ItemInstance.from_dict(value)
		if not item.is_structurally_valid() or not _definitions.has(item.definition_id):
			discarded += 1
			continue
		var definition: ItemDefinition = _definitions[item.definition_id]
		if definition.slot_name() != slot_name:
			discarded += 1
			continue
		_equipped[slot_name] = item
		_apply_item_modifiers(item)
		changed.emit(slot_name)
	return discarded

func _apply_item_modifiers(item: ItemInstance) -> void:
	if item == null or not _definitions.has(item.definition_id):
		return
	var definition: ItemDefinition = _definitions[item.definition_id]
	var source := StringName("equipment:%s" % item.instance_id)
	for modifier: StatModifier in definition.modifiers:
		_stats.add_modifier(source, modifier.stat_name, modifier.additive, modifier.multiplier)

func _remove_item_modifiers(item: ItemInstance) -> void:
	if item != null:
		_stats.remove_source(StringName("equipment:%s" % item.instance_id))
