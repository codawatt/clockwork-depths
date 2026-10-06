# Save-data format

The current format version is **2**. The default path is `user://clockwork_depths_save.json`; Godot resolves that location per OS/user. A sibling `.bak` retains the previous valid primary after replacement.

```json
{
  "version": 2,
  "profile": {
	"currency": 142,
	"dungeon_completed": true
  },
  "inventory": [
	{
	  "instance_id": "ember_blade-123456-42",
	  "definition_id": "ember_blade",
	  "quantity": 1,
	  "durability": 1.0,
	  "upgrade_level": 0,
	  "rolled_modifiers": {},
	  "metadata": {}
	}
  ],
  "equipment": {
	"weapon": null,
	"shield": null,
	"helmet": null,
	"armor": null,
	"accessory": null
  },
  "upgrades": [],
  "statistics": {
	"enemies_defeated": 8,
	"runs_completed": 1
  },
  "settings": {
	"camera_shake": true
  }
}
```

## Validation and restore rules

- The root must be a dictionary and its version must be in the supported range.
- Profile, equipment, statistics, and settings must be dictionaries; inventory and upgrades must be arrays.
- Currency and quantities are clamped/validated before application.
- Item and equipment state uses stable definition/instance IDs, never scene-tree paths or Node references.
- Unknown definitions, malformed item entries, invalid quantities, over-limit stacks, incompatible equipment slots, and entries beyond capacity are discarded.
- Equipment modifiers are recomputed from definitions after restoration; calculated stat values are not trusted from disk.
- Missing or malformed primary data returns a safe failure. A valid backup is used when available.

## Write workflow

1. Normalize the runtime DTO to version 2 and required defaults.
2. Write and flush `<save>.tmp`.
3. Rotate the current primary to `<save>.bak`.
4. Rename the temporary file to the primary path.
5. Restore the backup if final replacement fails.

## Migration

Version 1 data is accepted. Migration supplies default `upgrades`, `settings`, and `statistics`, then normalizes to version 2. Future migrations should be additive, sequential, and tested with a representative older DTO before increasing `CURRENT_VERSION`.

Live encounter state is deliberately absent. Loading a profile restores persistent progression and returns play to staging; beginning a dungeon starts fresh session-scoped room state.
