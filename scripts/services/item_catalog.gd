class_name ItemCatalog
extends RefCounted

const ITEM_PATHS: PackedStringArray = [
	"res://resources/items/training_blade.tres",
	"res://resources/items/ember_blade.tres",
	"res://resources/items/guardian_disc.tres",
	"res://resources/items/scout_helm.tres",
	"res://resources/items/forge_plate.tres",
	"res://resources/items/velocity_coil.tres",
	"res://resources/items/prism_charm.tres",
]

const ENEMY_PATHS: PackedStringArray = [
	"res://resources/enemies/brass_mauler.tres",
	"res://resources/enemies/arc_sentry.tres",
	"res://resources/enemies/vault_warden.tres",
]

var items: Dictionary = {}
var enemies: Dictionary = {}
var validation_warnings: PackedStringArray = []

func load_all() -> void:
	items.clear()
	enemies.clear()
	validation_warnings.clear()
	for path: String in ITEM_PATHS:
		var resource := ResourceLoader.load(path)
		if resource is ItemDefinition:
			var definition: ItemDefinition = resource
			var errors := definition.validation_errors()
			if errors.is_empty() and not items.has(definition.item_id):
				items[definition.item_id] = definition
			else:
				validation_warnings.append("Invalid or duplicate item at %s: %s" % [path, ", ".join(errors)])
		else:
			validation_warnings.append("Missing item resource: %s" % path)
	for path: String in ENEMY_PATHS:
		var resource := ResourceLoader.load(path)
		if resource is EnemyDefinition:
			var definition: EnemyDefinition = resource
			var errors := definition.validation_errors()
			if errors.is_empty() and not enemies.has(definition.enemy_id):
				enemies[definition.enemy_id] = definition
			else:
				validation_warnings.append("Invalid or duplicate enemy at %s: %s" % [path, ", ".join(errors)])
		else:
			validation_warnings.append("Missing enemy resource: %s" % path)

func item(item_id: StringName) -> ItemDefinition:
	var value: Variant = items.get(item_id)
	return value if value is ItemDefinition else null

func enemy(enemy_id: StringName) -> EnemyDefinition:
	var value: Variant = enemies.get(enemy_id)
	return value if value is EnemyDefinition else null
