class_name ItemDefinition
extends Resource

enum ItemType { CONSUMABLE, CURRENCY, EQUIPMENT }
enum EquipmentSlot { NONE, WEAPON, SHIELD, HELMET, ARMOR, ACCESSORY }

@export var item_id: StringName = &""
@export var display_name: String = "Unnamed Item"
@export_multiline var description: String = ""
@export var item_type: ItemType = ItemType.EQUIPMENT
@export_range(1, 99, 1) var max_stack_size: int = 1
@export var equipment_slot: EquipmentSlot = EquipmentSlot.NONE
@export var modifiers: Array[StatModifier] = []
@export var base_damage: float = 0.0
@export var behavior_id: StringName = &"standard"
@export var color: Color = Color.WHITE

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if item_id.is_empty():
		errors.append("item_id must be stable and non-empty")
	if display_name.strip_edges().is_empty():
		errors.append("display_name is required")
	if max_stack_size < 1:
		errors.append("max_stack_size must be positive")
	if item_type == ItemType.EQUIPMENT and equipment_slot == EquipmentSlot.NONE:
		errors.append("equipment requires a compatible slot")
	for modifier: StatModifier in modifiers:
		if modifier == null or not modifier.is_valid():
			errors.append("contains an invalid stat modifier")
	return errors

func slot_name() -> StringName:
	return ItemDefinition.slot_to_name(equipment_slot)

static func slot_to_name(slot: EquipmentSlot) -> StringName:
	match slot:
		EquipmentSlot.WEAPON: return &"weapon"
		EquipmentSlot.SHIELD: return &"shield"
		EquipmentSlot.HELMET: return &"helmet"
		EquipmentSlot.ARMOR: return &"armor"
		EquipmentSlot.ACCESSORY: return &"accessory"
		_: return &"none"
