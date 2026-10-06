class_name InventoryModel
extends RefCounted

signal changed
signal invalid_item_discarded(reason: String)

var capacity: int = 20
var _definitions: Dictionary = {}
var _items: Array[ItemInstance] = []

func configure(definitions: Dictionary, slot_capacity: int = 20) -> void:
	_definitions = definitions
	capacity = maxi(1, slot_capacity)
	_items.clear()
	changed.emit()

func items() -> Array[ItemInstance]:
	return _items.duplicate()

func item_count() -> int:
	return _items.size()

func find_instance(instance_id: String) -> ItemInstance:
	for item: ItemInstance in _items:
		if item.instance_id == instance_id:
			return item
	return null

func add(definition_id: StringName, quantity: int = 1, metadata: Dictionary = {}) -> int:
	if quantity <= 0 or not _definitions.has(definition_id):
		return quantity
	var definition: ItemDefinition = _definitions[definition_id]
	var remaining := quantity
	if definition.max_stack_size > 1:
		for item: ItemInstance in _items:
			if item.definition_id == definition_id and item.metadata == metadata and item.quantity < definition.max_stack_size:
				var moved: int = mini(remaining, definition.max_stack_size - item.quantity)
				item.quantity += moved
				remaining -= moved
				if remaining == 0:
					changed.emit()
					return 0
	while remaining > 0 and _items.size() < capacity:
		var stack_amount: int = mini(remaining, definition.max_stack_size)
		_items.append(ItemInstance.create(definition_id, stack_amount, metadata))
		remaining -= stack_amount
	if remaining != quantity:
		changed.emit()
	return remaining

func add_instance(item: ItemInstance) -> bool:
	if item == null or not item.is_structurally_valid() or not _definitions.has(item.definition_id):
		return false
	if _items.size() >= capacity:
		return false
	_items.append(item)
	changed.emit()
	return true

func take_instance(instance_id: String) -> ItemInstance:
	for index: int in range(_items.size()):
		if _items[index].instance_id == instance_id:
			var item: ItemInstance = _items[index]
			_items.remove_at(index)
			changed.emit()
			return item
	return null

func remove(definition_id: StringName, quantity: int) -> int:
	var remaining := maxi(0, quantity)
	for index: int in range(_items.size() - 1, -1, -1):
		var item: ItemInstance = _items[index]
		if item.definition_id != definition_id:
			continue
		var removed: int = mini(remaining, item.quantity)
		item.quantity -= removed
		remaining -= removed
		if item.quantity <= 0:
			_items.remove_at(index)
		if remaining == 0:
			break
	if remaining != quantity:
		changed.emit()
	return remaining

func quantity_of(definition_id: StringName) -> int:
	var total := 0
	for item: ItemInstance in _items:
		if item.definition_id == definition_id:
			total += item.quantity
	return total

func serialize() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: ItemInstance in _items:
		result.append(item.to_dict())
	return result

func restore(serialized_items: Array) -> int:
	_items.clear()
	var discarded := 0
	for value: Variant in serialized_items:
		if not value is Dictionary:
			discarded += 1
			continue
		var item := ItemInstance.from_dict(value)
		if not item.is_structurally_valid() or not _definitions.has(item.definition_id):
			discarded += 1
			continue
		var definition: ItemDefinition = _definitions[item.definition_id]
		if item.quantity > definition.max_stack_size or _items.size() >= capacity:
			discarded += 1
			continue
		_items.append(item)
	if discarded > 0:
		invalid_item_discarded.emit("Discarded %d invalid or obsolete inventory entries" % discarded)
	changed.emit()
	return discarded
