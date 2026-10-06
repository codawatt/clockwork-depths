# Clockwork Depths

Clockwork Depths is a **Godot 4.7.1 top-down 3D dungeon-crawler vertical slice** built entirely with primitive meshes, generated materials, lights, particles, and UI controls.

It demonstrates a complete staging-area-to-dungeon gameplay loop with responsive combat, data-driven encounters, persistent inventory and equipment, an environmental puzzle, a two-phase boss encounter, and guaranteed end-of-run rewards.

The project is an original implementation inspired by the pacing and structure of compact cooperative dungeon crawlers. It contains no proprietary names, characters, assets, audio, or level designs.

## Requirements

- **Godot 4.7.1-stable**
- Keyboard and mouse

No external art, audio, or third-party asset packs are required.

## Running the Project

Clone or download the repository, then open `project.godot` in **Godot 4.7.1-stable** and run the main scene.

From the command line, if the Godot executable is available on your `PATH`:

```bash
godot --path /path/to/ClockworkDepths
```

Depending on your platform and Godot installation, the executable may use a different name.

## Controls

| Action | Input |
| --- | --- |
| Move | WASD or arrow keys |
| Aim | Mouse |
| Three-hit sword combo | Left mouse or Space |
| Charge/release energy attack | Right mouse or Q |
| Invulnerable dodge | Shift |
| Interact | E |
| Inventory/equipment | Tab or I |
| Pause menu | Escape |
| Quick save / load | F5 / F9 |

Double-click a carried item to equip it. Double-click an equipped slot to unequip it.

Equipment can modify damage, attack range, defense, maximum health, movement speed, and charged-attack behavior.

## Gameplay Loop

A complete run consists of:

1. Starting in the staging bay and entering the dungeon through the gate.
2. Clearing an introductory melee/ranged encounter.
3. Surviving a mixed encounter with pulsing floor hazards.
4. Collecting and equipping dropped gear.
5. Solving the relay-order puzzle displayed in the puzzle room.
6. Defeating the **Vault Warden**.
7. Opening the reward cache for the guaranteed **Ember Blade** and **Forge Plate**.
8. Returning to the staging area.

The Vault Warden transitions into a more aggressive second phase at half health and rotates between slam, radial-volley, and dash attacks.

Profile progression is saved automatically and can be restored after restarting the project.

The intended duration of a complete run is approximately **10–15 minutes**, depending on player familiarity and play style.

## Project Structure

```text
resources/
    Data definitions for items, enemies, and encounters.

scripts/
    combat/
        Reusable damage, health, hitbox, hurtbox, and projectile components.

    domain/
        Scene-tree-independent inventory, equipment, item-instance,
        and stat models.

    game/
        Player and enemy actors, interactables, rooms, hazards,
        encounters, and run composition.

    services/
        Catalogs, profile/session management, and persistence.

    ui/
        Inventory, equipment, HUD, and other presentation logic.

tests/
    Deterministic domain-level verification.
```

The project uses custom `Resource` types for:

- `ItemDefinition`
- `EnemyDefinition`
- `EncounterDefinition`

`GameState` is the only autoload. It owns application-level profile/session state and persistence orchestration.

Moment-to-moment combat, room progression, encounters, and actors remain scene-owned.

For additional details, see:

- [Architecture](docs/ARCHITECTURE.md)
- [Save Format](docs/SAVE_FORMAT.md)
- [Verification](docs/VERIFICATION.md)

## Architecture

The project is divided into data, domain, combat, game, service, and presentation layers.

This keeps persistent state separate from scene presentation while avoiding unnecessary framework abstraction for a vertical slice.

Items and enemies are defined as Godot Resources. Persistent state references them through stable IDs rather than scene paths or runtime object references.

Stat modifiers have explicit sources, actors communicate through reusable damage contracts and signals, and ownership remains local:

- encounters own their spawned enemies;
- actors own their combat components;
- UI observes domain state rather than owning it;
- the root game scene owns the run lifecycle;
- `GameState` owns profile-level state and persistence.

The architecture is intended to support additional content primarily through new Resource definitions and focused behavior components.

Networking is intentionally outside the scope of the project, although combat data already keeps concepts such as team, source actor, attack category, payload, and runtime ownership explicit.

## Adding an Item

1. Create a `.tres` Resource under `resources/items/` using `ItemDefinition`.
2. Assign a unique and stable `item_id`.
3. Configure its display fields, item type, stack limit, equipment slot, behavior ID, and primitive display color.
4. Add any `StatModifier` subresources.
5. Add the Resource path to `ItemCatalog.ITEM_PATHS`.
6. Grant the item from a pickup, reward, or starting-profile rule using its stable ID.
7. Run the verification checks.

No inventory UI changes are required for standard items.

Catalog validation rejects missing IDs, invalid slots, and malformed modifiers.

Weapon-specific behavior can branch from the definition's `behavior_id` at the player weapon boundary. The **Prism Charm** charged-attack behavior is included as an example.

## Adding an Enemy

1. Create a `.tres` Resource under `resources/enemies/` using `EnemyDefinition`.
2. Assign a stable `enemy_id`.
3. Configure its archetype, health, movement, attack range, cooldown, reward, and presentation color.
4. Add the Resource path to `ItemCatalog.ENEMY_PATHS`.
5. Add the enemy to an encounter's `spawn_manifest`.

Example:

```text
arc_sentry@4,0,-3
```

6. Run the verification checks.

For behavior beyond the existing melee, ranged, and boss modes, add a focused behavior/state component or extend the behavior boundary in `EnemyActor`.

Enemy behavior should remain independent from individual room implementations.

### Encounter Spawn Data

`EncounterDefinition` retains typed `enemy_ids` and `spawn_offsets` fields for editor-side authoring.

The project also supports a validated scalar `spawn_manifest`, with parsing and validation centralized in `EncounterDefinition`. This keeps encounter composition deterministic and avoids spreading serialization-specific logic into gameplay code.

## Adding an Equipment Slot

1. Add the new enum member and stable string mapping in `ItemDefinition`.
2. Add the slot name to `EquipmentModel.SLOT_NAMES`.
3. Assign compatible items to the new slot.
4. Add any new base stat to `GameState` if the slot introduces a new statistic.
5. Consume the final calculated value at the appropriate actor or component boundary.
6. Update save migration only if the new slot requires a non-null default.

Equipment serialization iterates the stable slot list, and the inventory UI renders that list automatically.

## Persistence

Profile data is stored using stable IDs and serializable data-transfer structures rather than scene references.

The local save repository uses JSON with atomic replacement and backup behavior behind a replaceable repository boundary.

The save system stores persistent profile progression rather than a suspended live dungeon state.

Loading a profile returns the player to staging. Entering the dungeon begins a fresh run.

Room completion is session-scoped and resets on each new dungeon entry, while overall dungeon completion and persistent equipment remain part of the saved profile.

Cloud synchronization, accounts, and encryption are outside the scope of the project.

## Verification

The project includes deterministic domain checks and an automated full-loop lifecycle check.

With Godot available from the command line:

```bash
godot --headless --import --path /path/to/ClockworkDepths
godot --headless --path /path/to/ClockworkDepths --script res://tests/domain_test_runner.gd
godot --headless --path /path/to/ClockworkDepths -- --verify-loop
```

Replace `godot` with the appropriate Godot executable for your platform if necessary.

Verification results and coverage are documented in [docs/VERIFICATION.md](docs/VERIFICATION.md).

## Design Decisions

### Runtime-built environment

The dungeon environment is assembled using focused runtime builders and primitive geometry.

This keeps art production lightweight and makes the complete slice reproducible without an external asset pipeline.

For a larger project, repeated room shells would likely become authored `PackedScene` assets while retaining the existing `EncounterRoom` and data-definition APIs.

### Shared standard enemy actor

The current enemy roster uses one standard actor with a small behavior/state boundary because the slice only requires a limited set of archetypes.

A larger roster should extract additional movement and attack policies instead of continually adding branches to the same actor.

### Data-driven encounters

Enemy and encounter configuration lives in Resources rather than room-specific scripts.

Encounter parsing and validation are centralized so gameplay code consumes validated encounter data instead of handling serialization details directly.

### Local persistence

Persistence is intentionally simple and local.

The repository abstraction allows the storage implementation to be replaced without changing inventory, equipment, or gameplay-domain code.

### Direct enemy steering

The existing rooms are compact and open enough that direct steering is sufficient.

Navigation meshes, obstacle-aware pathfinding, and crowd avoidance are intentionally omitted.

### Procedural presentation

The project has no external model, texture, animation, or audio pipeline.

Combat feedback instead relies on:

- silhouettes;
- primitive geometry;
- material flashes;
- particles;
- lighting effects;
- floor telegraphs;
- camera response;
- UI feedback.

## Known Limitations

- Keyboard and mouse only.
- No controller-remapping interface.
- No dedicated accessibility settings screen.
- One fixed linear dungeon.
- No procedural generation.
- No suspended mid-run save state.
- Loading begins from staging rather than restoring a live encounter.
- Enemy steering does not navigate around arbitrary obstacles.
- No networking.
- No audio.
- No detailed skeletal animation pipeline.
- No crafting system.
- Content is intentionally limited to the vertical slice.

## Scope

Clockwork Depths is intended as a compact example of a complete gameplay architecture rather than a full game.

Its focus is on demonstrating:

- a complete playable loop;
- reusable combat components;
- data-driven content;
- explicit scene ownership;
- inventory and equipment domain models;
- persistent profile state;
- encounter composition;
- puzzle progression;
- boss phase transitions;
- automated verification;
- clear extension points for additional content.
