class_name ProfileGameState
extends Node

signal profile_changed
signal save_status(message: String, succeeded: bool)

var catalog := ItemCatalog.new()
var inventory := InventoryModel.new()
var equipment := EquipmentModel.new()
var stats := StatBlock.new()
var repository := SaveRepository.new()

var currency: int = 0
var dungeon_completed: bool = false
var upgrades: PackedStringArray = []
var statistics: Dictionary = {"enemies_defeated": 0, "runs_completed": 0}
var settings: Dictionary = {"camera_shake": true}

func _ready() -> void:
	catalog.load_all()
	if not catalog.validation_warnings.is_empty():
		for warning: String in catalog.validation_warnings:
			push_warning(warning)
	_initialize_models()
	var result := load_profile(false)
	if not bool(result.get("ok", false)):
		new_profile()

func _initialize_models() -> void:
	stats.configure({
		&"max_health": 100.0,
		&"attack_damage": 14.0,
		&"defense": 0.0,
		&"move_speed": 8.0,
		&"attack_range": 2.15,
		&"dodge_cooldown": 1.1,
		&"charge_power": 1.0,
	})
	inventory.configure(catalog.items, 20)
	equipment.configure(inventory, stats, catalog.items)
	inventory.changed.connect(_on_domain_changed)
	equipment.changed.connect(_on_equipment_changed)

func new_profile() -> void:
	currency = 0
	dungeon_completed = false
	upgrades = PackedStringArray()
	statistics = {"enemies_defeated": 0, "runs_completed": 0}
	settings = {"camera_shake": true}
	_initialize_models_safely()
	inventory.add(&"training_blade")
	var starter_items := inventory.items()
	if not starter_items.is_empty():
		equipment.equip(starter_items[0].instance_id)
	profile_changed.emit()

func _initialize_models_safely() -> void:
	for connection: Dictionary in inventory.changed.get_connections():
		inventory.changed.disconnect(connection.callable)
	for connection: Dictionary in equipment.changed.get_connections():
		equipment.changed.disconnect(connection.callable)
	_initialize_models()

func add_currency(amount: int) -> void:
	currency = maxi(0, currency + amount)
	profile_changed.emit()

func record_enemy_defeat() -> void:
	statistics["enemies_defeated"] = int(statistics.get("enemies_defeated", 0)) + 1
	profile_changed.emit()

func mark_dungeon_completed() -> void:
	if not dungeon_completed:
		statistics["runs_completed"] = int(statistics.get("runs_completed", 0)) + 1
	dungeon_completed = true
	profile_changed.emit()

func save_profile() -> Dictionary:
	var result := repository.save(to_dto())
	if bool(result.get("ok", false)):
		save_status.emit("Progress saved", true)
	else:
		save_status.emit("Save failed: %s" % result.get("reason", "unknown"), false)
	return result

func load_profile(announce: bool = true) -> Dictionary:
	var result := repository.load_data()
	if not bool(result.get("ok", false)):
		if announce:
			save_status.emit("No valid save (%s)" % result.get("reason", "unknown"), false)
		return result
	apply_dto(result.data)
	if announce:
		save_status.emit("Progress loaded", true)
	return result

func reset_save_and_profile() -> void:
	repository.reset()
	new_profile()
	save_status.emit("Save reset", true)

func to_dto() -> Dictionary:
	return {
		"version": SaveRepository.CURRENT_VERSION,
		"profile": {"currency": currency, "dungeon_completed": dungeon_completed},
		"inventory": inventory.serialize(),
		"equipment": equipment.serialize(),
		"upgrades": Array(upgrades),
		"statistics": statistics.duplicate(true),
		"settings": settings.duplicate(true),
	}

func apply_dto(data: Dictionary) -> void:
	_initialize_models_safely()
	var profile: Dictionary = data.get("profile", {})
	currency = maxi(0, int(profile.get("currency", 0)))
	dungeon_completed = bool(profile.get("dungeon_completed", false))
	var loaded_upgrades: Variant = data.get("upgrades", [])
	upgrades = PackedStringArray(loaded_upgrades) if loaded_upgrades is Array else PackedStringArray()
	var loaded_stats: Variant = data.get("statistics", {})
	statistics = loaded_stats.duplicate(true) if loaded_stats is Dictionary else {"enemies_defeated": 0, "runs_completed": 0}
	var loaded_settings: Variant = data.get("settings", {})
	settings = loaded_settings.duplicate(true) if loaded_settings is Dictionary else {"camera_shake": true}
	var serialized_inventory: Variant = data.get("inventory", [])
	if serialized_inventory is Array:
		inventory.restore(serialized_inventory)
	var serialized_equipment: Variant = data.get("equipment", {})
	if serialized_equipment is Dictionary:
		equipment.restore(serialized_equipment)
	profile_changed.emit()

func item_definition(item_id: StringName) -> ItemDefinition:
	return catalog.item(item_id)

func enemy_definition(enemy_id: StringName) -> EnemyDefinition:
	return catalog.enemy(enemy_id)

func _on_domain_changed() -> void:
	profile_changed.emit()

func _on_equipment_changed(_slot_name: StringName) -> void:
	profile_changed.emit()
