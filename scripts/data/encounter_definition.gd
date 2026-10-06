class_name EncounterDefinition
extends Resource

@export var encounter_id: StringName = &""
@export var room_id: StringName = &""
@export var enemy_ids: PackedStringArray = []
@export var spawn_offsets: Array[Vector3] = []
@export_multiline var spawn_manifest: String = ""
@export var objective_text: String = "Defeat all enemies"

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if encounter_id.is_empty(): errors.append("encounter_id is required")
	if room_id.is_empty(): errors.append("room_id is required")
	if spawn_entries().is_empty(): errors.append("at least one enemy is required")
	if spawn_manifest.strip_edges().is_empty() and not spawn_offsets.is_empty() and spawn_offsets.size() != enemy_ids.size():
		errors.append("spawn_offsets must be empty or match enemy_ids")
	return errors

func spawn_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not spawn_manifest.strip_edges().is_empty():
		for raw_entry: String in spawn_manifest.split(";", false):
			var parts := raw_entry.strip_edges().split("@", false, 1)
			if parts.size() != 2 or parts[0].strip_edges().is_empty():
				continue
			var coordinates := parts[1].split(",", false)
			if coordinates.size() != 3:
				continue
			result.append({
				"enemy_id": StringName(parts[0].strip_edges()),
				"offset": Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2])),
			})
		return result
	for index: int in range(enemy_ids.size()):
		result.append({
			"enemy_id": StringName(enemy_ids[index]),
			"offset": spawn_offsets[index] if index < spawn_offsets.size() else Vector3(index * 2.0, 0, 0),
		})
	return result
