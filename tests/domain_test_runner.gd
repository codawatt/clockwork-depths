extends SceneTree

var _failures: PackedStringArray = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("Clockwork Depths domain verification")
	_test_project_contract()
	_test_inventory()
	_test_equipment_and_stats()
	_test_persistence()
	if _failures.is_empty():
		print("PASS: %d checks" % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("FAIL: %d of %d checks failed" % [_failures.size(), _checks])
		quit(1)

func _test_project_contract() -> void:
	_check(FileAccess.file_exists("res://scenes/main.tscn"), "configured main scene exists")
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"attack", &"charge_attack", &"dodge", &"interact", &"inventory", &"pause", &"quick_save", &"quick_load"]:
		_check(InputMap.has_action(action), "input action exists: %s" % action)
	var catalog := ItemCatalog.new()
	catalog.load_all()
	_check(catalog.validation_warnings.is_empty(), "catalog resources validate")
	_check(catalog.items.size() >= 7, "item resources resolve")
	_check(catalog.enemies.size() >= 3, "enemy resources resolve")
	for path: String in ["res://resources/encounters/intro.tres", "res://resources/encounters/mixed.tres", "res://resources/encounters/boss.tres"]:
		var encounter := load(path) as EncounterDefinition
		_check(encounter != null and encounter.validation_errors().is_empty(), "encounter resolves and validates: %s" % path)

func _test_inventory() -> void:
	var stack_definition := ItemDefinition.new()
	stack_definition.item_id = &"test_stack"
	stack_definition.display_name = "Test Stack"
	stack_definition.item_type = ItemDefinition.ItemType.CONSUMABLE
	stack_definition.max_stack_size = 5
	var definitions := {&"test_stack": stack_definition}
	var inventory := InventoryModel.new()
	inventory.configure(definitions, 2)
	_check(inventory.add(&"test_stack", 7) == 0, "inventory adds across stacks")
	_check(inventory.item_count() == 2 and inventory.quantity_of(&"test_stack") == 7, "stack distribution and lookup")
	_check(inventory.add(&"test_stack", 4) == 1, "capacity reports exact remainder")
	_check(inventory.quantity_of(&"test_stack") == 10, "full stacks stop at capacity")
	_check(inventory.remove(&"test_stack", 3) == 0 and inventory.quantity_of(&"test_stack") == 7, "inventory removes requested quantity")
	_check(inventory.remove(&"test_stack", 9) == 2 and inventory.quantity_of(&"test_stack") == 0, "remove reports unavailable remainder")
	inventory.add(&"test_stack", 6)
	var serialized := inventory.serialize()
	var restored := InventoryModel.new()
	restored.configure(definitions, 2)
	_check(restored.restore(serialized) == 0 and restored.quantity_of(&"test_stack") == 6, "inventory serialization restores")
	var corrupt: Array = serialized.duplicate(true)
	corrupt.append({"instance_id": "bad", "definition_id": "missing", "quantity": -2})
	_check(restored.restore(corrupt) == 1, "corrupted or obsolete items are discarded")

func _test_equipment_and_stats() -> void:
	var catalog := ItemCatalog.new()
	catalog.load_all()
	var stats := StatBlock.new()
	stats.configure({&"attack_damage": 10.0, &"attack_range": 2.0, &"max_health": 100.0, &"defense": 0.0, &"move_speed": 8.0, &"dodge_cooldown": 1.0, &"charge_power": 1.0})
	var inventory := InventoryModel.new()
	inventory.configure(catalog.items, 5)
	var equipment := EquipmentModel.new()
	equipment.configure(inventory, stats, catalog.items)
	inventory.add(&"training_blade")
	var first_id := inventory.items()[0].instance_id
	_check(equipment.equip(first_id), "compatible weapon equips")
	_check(is_equal_approx(stats.get_value(&"attack_damage"), 12.0), "equipment modifier applies")
	inventory.add(&"ember_blade")
	var ember_id := ""
	for item: ItemInstance in inventory.items():
		if item.definition_id == &"ember_blade": ember_id = item.instance_id
	_check(not ember_id.is_empty() and equipment.equip(ember_id), "occupied slot replacement succeeds")
	_check(inventory.quantity_of(&"training_blade") == 1, "replaced equipment returns to inventory")
	_check(is_equal_approx(stats.get_value(&"attack_damage"), 19.0) and is_equal_approx(stats.get_value(&"attack_range"), 2.35), "old modifiers removed and new modifiers recalculated")
	var serialized_inventory := inventory.serialize()
	var serialized_equipment := equipment.serialize()
	var restored_inventory := InventoryModel.new()
	restored_inventory.configure(catalog.items, 5)
	restored_inventory.restore(serialized_inventory)
	var restored_stats := StatBlock.new()
	restored_stats.configure({&"attack_damage": 10.0, &"attack_range": 2.0, &"max_health": 100.0, &"defense": 0.0, &"move_speed": 8.0, &"dodge_cooldown": 1.0, &"charge_power": 1.0})
	var restored_equipment := EquipmentModel.new()
	restored_equipment.configure(restored_inventory, restored_stats, catalog.items)
	_check(restored_equipment.restore(serialized_equipment) == 0, "equipment restores without invalid entries")
	_check(restored_equipment.equipped(&"weapon") != null and is_equal_approx(restored_stats.get_value(&"attack_damage"), 19.0), "restored equipment reapplies modifiers")

func _test_persistence() -> void:
	var test_path := "user://clockwork_depths_domain_test.json"
	var repository := SaveRepository.new(test_path)
	repository.reset()
	var missing := repository.load_data()
	_check(not bool(missing.ok) and missing.reason == "missing", "missing save handled gracefully")
	var dto := {
		"profile": {"currency": 123, "dungeon_completed": true},
		"inventory": [],
		"equipment": {},
		"upgrades": ["test_upgrade"],
		"statistics": {"enemies_defeated": 9, "runs_completed": 1},
		"settings": {"camera_shake": false},
	}
	_check(bool(repository.save(dto).ok), "atomic save creation succeeds")
	var loaded := repository.load_data()
	_check(bool(loaded.ok) and int(loaded.data.profile.currency) == 123 and bool(loaded.data.profile.dungeon_completed), "saved profile restores")
	var malformed_path := "user://clockwork_depths_malformed_test.json"
	var malformed_repository := SaveRepository.new(malformed_path)
	malformed_repository.reset()
	_write_text(malformed_path, "{not-json")
	var malformed := malformed_repository.load_data()
	_check(not bool(malformed.ok) and malformed.reason == "malformed", "malformed save falls back safely")
	var v1_path := "user://clockwork_depths_v1_test.json"
	var v1_repository := SaveRepository.new(v1_path)
	v1_repository.reset()
	_write_text(v1_path, JSON.stringify({"version": 1, "profile": {"currency": 4, "dungeon_completed": false}, "inventory": [], "equipment": {}}))
	var migrated := v1_repository.load_data()
	_check(bool(migrated.ok) and int(migrated.data.version) == SaveRepository.CURRENT_VERSION and migrated.data.has("settings"), "version 1 save migrates with defaults")
	repository.reset()
	malformed_repository.reset()
	v1_repository.reset()

func _write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok  ", description)
	else:
		_failures.append(description)
		print("  ERR ", description)
