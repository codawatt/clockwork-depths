# Verification record

Environment: supplied `Godot v4.7.1.stable.official.a13da4feb`, Linux x86_64, headless compatibility renderer.

## Completed checks

| Check | Result |
| --- | --- |
| Project import and script parse | Pass |
| Configured main scene and input actions | Pass |
| 120-frame source scene smoke launch | Pass |
| Resource/catalog validation and encounter resolution | Pass |
| Inventory add, stacking, capacity, removal, lookup, serialization, restoration | Pass |
| Corrupt/obsolete inventory validation | Pass |
| Equipment compatibility, replacement, return, stat-source recalculation, restoration | Pass |
| Missing save, atomic creation, malformed fallback, v1 migration, profile restoration | Pass |
| Automated staging → combat → puzzle → boss phase → reward → save/load lifecycle | Pass |
| Exported `.pck` generated | Pass |
| Supplied 4.7.1 runtime launched exported pack and passed lifecycle check | Pass |
| Conventional release-template binary | Not available: matching debug/release export templates were absent |

The domain runner completed **39 checks**. The packaged lifecycle runner completed **13 checks**. Automated checks verify state transitions and contracts, not subjective combat feel or the 10–15 minute human-play duration target.

## Commands used

```bash
godot --headless --import --path project
godot --headless --path project --script res://tests/domain_test_runner.gd
godot --headless --path project -- --verify-loop
godot --headless --path project --export-pack Linux build/ClockworkDepths.pck
ClockworkDepths.x86_64 --headless --main-pack ClockworkDepths.pck -- --verify-loop
```
