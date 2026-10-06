class_name SaveRepository
extends RefCounted

const CURRENT_VERSION := 2

var save_path: String = "user://clockwork_depths_save.json"

func _init(custom_path: String = "") -> void:
	if not custom_path.is_empty():
		save_path = custom_path

func save(data: Dictionary) -> Dictionary:
	var normalized := _normalize(data)
	var temp_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "open_failed", "error": FileAccess.get_open_error()}
	file.store_string(JSON.stringify(normalized, "  "))
	file.flush()
	file.close()
	var absolute_save := ProjectSettings.globalize_path(save_path)
	var absolute_temp := ProjectSettings.globalize_path(temp_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(absolute_backup)
		var backup_error := DirAccess.rename_absolute(absolute_save, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temp)
			return {"ok": false, "reason": "backup_failed", "error": backup_error}
	var replace_error := DirAccess.rename_absolute(absolute_temp, absolute_save)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_save)
		return {"ok": false, "reason": "replace_failed", "error": replace_error}
	return {"ok": true, "reason": "saved", "version": CURRENT_VERSION}

func load_data() -> Dictionary:
	var primary := _read_and_validate(save_path)
	if bool(primary.get("ok", false)):
		return primary
	var backup := _read_and_validate(save_path + ".bak")
	if bool(backup.get("ok", false)):
		backup["reason"] = "recovered_from_backup"
		return backup
	return primary

func reset() -> bool:
	var all_removed := true
	for suffix: String in ["", ".tmp", ".bak"]:
		var path := save_path + suffix
		if FileAccess.file_exists(path):
			all_removed = DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK and all_removed
	return all_removed

func _read_and_validate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing", "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "reason": "open_failed", "data": {}}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "reason": "malformed", "data": {}}
	var parsed: Variant = parser.data
	if not parsed is Dictionary:
		return {"ok": false, "reason": "malformed", "data": {}}
	var version := int(parsed.get("version", 0))
	if version < 1 or version > CURRENT_VERSION:
		return {"ok": false, "reason": "unsupported_version", "data": {}}
	var migrated := _migrate(parsed, version)
	if not _has_valid_shape(migrated):
		return {"ok": false, "reason": "invalid_shape", "data": {}}
	return {"ok": true, "reason": "loaded", "data": _normalize(migrated), "source_version": version}

func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	var result := data.duplicate(true)
	if from_version == 1:
		result["upgrades"] = result.get("upgrades", [])
		result["settings"] = result.get("settings", {"camera_shake": true})
		result["statistics"] = result.get("statistics", {"enemies_defeated": 0, "runs_completed": 0})
	result["version"] = CURRENT_VERSION
	return result

func _normalize(data: Dictionary) -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"profile": data.get("profile", {"currency": 0, "dungeon_completed": false}),
		"inventory": data.get("inventory", []),
		"equipment": data.get("equipment", {}),
		"upgrades": data.get("upgrades", []),
		"statistics": data.get("statistics", {"enemies_defeated": 0, "runs_completed": 0}),
		"settings": data.get("settings", {"camera_shake": true}),
	}

func _has_valid_shape(data: Dictionary) -> bool:
	return data.get("profile") is Dictionary \
		and data.get("inventory") is Array \
		and data.get("equipment") is Dictionary \
		and data.get("upgrades") is Array \
		and data.get("statistics") is Dictionary \
		and data.get("settings") is Dictionary
