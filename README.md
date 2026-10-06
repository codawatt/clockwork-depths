# Clockwork Depths

Clockwork Depths is a Godot 4.7.1 top-down 3D dungeon-crawler vertical slice built entirely from primitive meshes, generated materials, lights, and UI controls. It demonstrates a complete staging-area-to-dungeon-to-staging-area loop with responsive combat, data-driven encounters, persistent inventory/equipment, a puzzle, a two-phase boss, and a guaranteed reward.

This is an original implementation inspired by the rhythm of compact cooperative dungeon crawlers. It contains no proprietary names, assets, characters, audio, or level designs.

## Play

### Packaged Linux build

1. Extract `ClockworkDepths_Linux_x86_64.zip`.
2. Run `PlayClockworkDepths.sh` (or run `ClockworkDepths.x86_64 --main-pack ClockworkDepths.pck`).

The package includes the supplied official Godot 4.7.1 Linux editor/runtime and an exported project pack. A conventional release-template binary could not be produced because Godot 4.7.1 export templates were not installed. The delivered runtime-plus-pack build was launched and its automated full-loop check passed.

### Source project

Open `project.godot` in Godot **4.7.1-stable**, then run the main scene.

From a shell:

```bash
Godot_v4.7.1-stable_linux.x86_64 --path /path/to/ClockworkDepths_Source
```

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

Double-click a carried item to equip it. Double-click an equipped slot to unequip it. Equipment visibly affects damage, range, defense, health, movement speed, or charged-attack behavior.

## Playable loop

1. Begin in the staging bay and enter the luminous gate.
2. Clear the introductory melee/ranged encounter.
3. Survive a mixed encounter with pulsing floor hazards.
4. Equip dropped gear and observe the stat/gameplay change.
5. Solve the relay order shown on the puzzle-room wall.
6. Defeat the Vault Warden. At half health it accelerates and changes presentation; its rotating patterns include a slam, radial volley, and dash.
7. Open the cache for the guaranteed Ember Blade and Forge Plate.
8. Return to staging. The profile is saved automatically and can be restored after restarting.

The 10–15 minute duration is a human-playtest target, not an automated claim.

## Architecture at a glance

- `resources/` contains custom `ItemDefinition`, `EnemyDefinition`, and `EncounterDefinition` data.
- `scripts/domain/` contains scene-tree-independent inventory, equipment, item-instance, and statistic models.
- `scripts/combat/` contains reusable damage context, health, hitbox, hurtbox, and projectile components.
- `scripts/game/` composes actors, interactables, encounter rooms, hazards, and the vertical-slice world.
- `scripts/services/` contains the item/enemy catalog, profile session, and replaceable persistence repository.
- `scripts/ui/` observes domain signals; it never owns inventory or equipment truth.
- `tests/` contains the deterministic domain runner. The main scene also exposes an opt-in packaged lifecycle check through `--verify-loop`.

`GameState` is the only autoload. It owns application-level profile/session state and repository orchestration; moment-to-moment combat and room logic remain in scene-owned nodes. See [Architecture](docs/ARCHITECTURE.md) and [Save format](docs/SAVE_FORMAT.md).

## Why this structure fits the slice

The data/domain/combat/presentation split gives the requested extension points without inventing a generic engine. Items and enemies are Resources, persistent state uses stable IDs and DTOs, stat modifiers have explicit sources, and actors communicate through damage contracts and signals. Scene ownership stays explicit: encounters own spawned enemies, actors own components, and the root owns the run lifecycle.

The architecture can grow by adding Resource definitions and composed behavior while preserving the domain and persistence interfaces. Future network authority could replace the local damage/application boundary because team, source actor ID, attack category, payload, and runtime source ownership are already explicit; networking itself is intentionally absent.

## Add a new item

1. Create a `.tres` Resource under `resources/items/` using `ItemDefinition`.
2. Assign a unique, stable `item_id`, display fields, type, stack limit, slot, behavior ID, and primitive display color.
3. Add `StatModifier` subresources for additive or multiplicative effects.
4. Add the Resource path to `ItemCatalog.ITEM_PATHS`.
5. Grant it from a pickup, reward, or starting-profile rule using the stable ID. No UI changes are needed.
6. Run the domain checks; catalog validation rejects missing IDs, invalid slots, and malformed modifiers.

New weapon behavior can branch on the definition's `behavior_id` at the player weapon boundary. The Prism Charm's second charged pulse is the included example.

## Add a new enemy

1. Create a `.tres` Resource under `resources/enemies/` using `EnemyDefinition`.
2. Set a stable `enemy_id`, archetype, health, movement, attack range/cooldown, reward, and color.
3. Add the Resource path to `ItemCatalog.ENEMY_PATHS`.
4. Add an entry to an encounter's export-safe `spawn_manifest`, for example `arc_sentry@4,0,-3`.
5. For behavior beyond melee/ranged/boss modes, add a focused behavior/state component or extend the state boundary in `EnemyActor`; do not couple it to a room.
6. Run both verification commands below.

Encounter Resources also retain typed `enemy_ids` and `spawn_offsets` fields for editor authoring. The scalar manifest is preferred in this deliverable because it survived the supplied editor-runtime pack conversion reliably; parsing and validation are centralized in `EncounterDefinition`.

## Add a new equipment slot

1. Add the enum member and stable string mapping in `ItemDefinition`.
2. Add the slot name to `EquipmentModel.SLOT_NAMES`.
3. Assign compatible items to the new enum value.
4. If the slot introduces a new stat or behavior, add its base value to `GameState` and consume the final value at the appropriate actor/component boundary.
5. Extend save migration only if the slot needs non-null defaults. Existing equipment serialization iterates the stable slot list, and the UI renders that list automatically.

## Verification

With the supplied binary adjacent to the project:

```bash
Godot_v4.7.1-stable_linux.x86_64 --headless --import --path ClockworkDepths_Source
Godot_v4.7.1-stable_linux.x86_64 --headless --path ClockworkDepths_Source --script res://tests/domain_test_runner.gd
Godot_v4.7.1-stable_linux.x86_64 --headless --path ClockworkDepths_Source -- --verify-loop
```

The completed verification results are recorded in [Verification](docs/VERIFICATION.md).

## Deliberate trade-offs

- The world is assembled by a focused runtime builder to keep primitive-art production cheap. In a larger project, repeated room shells would become authored PackedScenes while retaining `EncounterRoom` and definition APIs.
- Standard enemies share one actor and small state boundary because the slice has two archetypes. A larger roster should extract movement/attack policies before adding more branches.
- Encounters use a validated scalar spawn manifest in addition to typed Resource arrays due a reproducible array-default issue in the supplied editor-runtime pack. The compatibility logic is isolated to the definition class.
- The save repository is local JSON with atomic replacement and a backup, behind a replaceable class boundary. Cloud sync, user accounts, and encryption are outside scope.
- Direct steering is sufficient for the compact open rooms. Navigation meshes and crowd avoidance are intentionally omitted.
- Effects prioritize telegraphs, silhouettes, material flashes, particles/lighting-like pulses, and camera response. There is no model, texture, animation, or audio pipeline.

## Known limitations

- Keyboard/mouse only; no controller remapping UI or accessibility options screen.
- One fixed linear dungeon; no procedural generation or mid-run room persistence.
- Saving stores profile progression, not a suspended live encounter. Loading returns the player to staging and starts a fresh run.
- Room completion is session-scoped and resets on a new gate entry, as required; only overall dungeon completion persists.
- Enemy steering does not path around arbitrary future obstacles.
- No networking, audio, detailed animation, crafting, or content beyond the vertical slice.
- The standard Godot release-template export was unavailable in the environment; the verified Linux deliverable uses the supplied official 4.7.1 runtime with an exported `.pck`.
