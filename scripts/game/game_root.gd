class_name GameRoot
extends Node

const INTRO_ENCOUNTER: EncounterDefinition = preload("res://resources/encounters/intro.tres")
const MIXED_ENCOUNTER: EncounterDefinition = preload("res://resources/encounters/mixed.tres")
const BOSS_ENCOUNTER: EncounterDefinition = preload("res://resources/encounters/boss.tres")

var _world := Node3D.new()
var _player: PlayerActor
var _camera: Camera3D
var _hud: GameHud
var _intro_room: EncounterRoom
var _mixed_room: EncounterRoom
var _boss_room: EncounterRoom
var _rooms: Array[EncounterRoom] = []
var _intro_exit: WorldDoor
var _mixed_exit: WorldDoor
var _puzzle_exit: WorldDoor
var _boss_exit: WorldDoor
var _hub_gate: WorldInteractable
var _reward_chest: WorldInteractable
var _return_gate: WorldInteractable
var _puzzle_trigger := Area3D.new()
var _puzzle_consoles: Array[WorldInteractable] = []
var _puzzle_progress: Array[int] = []
var _puzzle_active := false
var _puzzle_completed := false
var _shake_strength := 0.0
var _rng := RandomNumberGenerator.new()
var _verification_failures: PackedStringArray = []
var _verification_checks := 0

func _ready() -> void:
	_rng.randomize()
	_build_environment()
	add_child(_world)
	_build_rooms()
	_spawn_player()
	_build_camera()
	_build_progression()
	_build_hud()
	_begin_run(false)
	if "--verify-loop" in OS.get_cmdline_user_args():
		call_deferred("_run_gameplay_verification")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		GameState.save_profile()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		var result := GameState.load_profile()
		if bool(result.get("ok", false)):
			_reset_to_hub()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if _camera == null or _player == null:
		return
	var target_position := _player.global_position + Vector3(0.0, 17.0, 14.0)
	_camera.global_position = _camera.global_position.lerp(target_position, 1.0 - exp(-6.5 * delta))
	var shake := Vector3.ZERO
	if _shake_strength > 0.01 and bool(GameState.settings.get("camera_shake", true)):
		shake = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 0.4), _rng.randf_range(-1.0, 1.0)) * _shake_strength
		_shake_strength = move_toward(_shake_strength, 0.0, delta * 3.5)
	_camera.look_at(_player.global_position + shake, Vector3.UP)

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.012, 0.018, 0.035)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.36, 0.58)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color(0.63, 0.78, 1.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _build_rooms() -> void:
	_create_room(0.0, 18.0, "STAGING BAY", Color(0.06, 0.13, 0.2))
	_create_room(20.0, 22.0, "FOUNDRY GUARD", Color(0.13, 0.09, 0.08))
	_create_room(43.0, 22.0, "LIVE CONDUITS", Color(0.11, 0.07, 0.15))
	_create_room(66.0, 22.0, "SEQUENCE VAULT", Color(0.05, 0.13, 0.13))
	_create_room(90.0, 24.0, "WARDEN ARENA", Color(0.16, 0.045, 0.06))
	_create_room(112.0, 20.0, "REWARD VAULT", Color(0.15, 0.12, 0.035))
	_add_static_box(Vector3(-9.25, 1.25, 0), Vector3(0.5, 2.5, 20.5), Color(0.08, 0.18, 0.28))
	_add_static_box(Vector3(122.25, 1.25, 0), Vector3(0.5, 2.5, 20.5), Color(0.24, 0.16, 0.05))
	for room_x: float in [0.0, 20.0, 43.0, 66.0, 90.0, 112.0]:
		var light := OmniLight3D.new()
		light.position = Vector3(room_x, 6.5, 0)
		light.light_color = Color(0.3, 0.7, 1.0) if room_x < 80.0 else Color(1.0, 0.32, 0.12)
		light.light_energy = 4.0
		light.omni_range = 16.0
		_world.add_child(light)

func _create_room(center_x: float, length: float, title: String, floor_color: Color) -> void:
	_add_static_box(Vector3(center_x, -0.25, 0), Vector3(length, 0.5, 20.0), floor_color)
	_add_static_box(Vector3(center_x, 1.25, -10.25), Vector3(length, 2.5, 0.5), floor_color.lightened(0.18))
	_add_static_box(Vector3(center_x, 1.25, 10.25), Vector3(length, 2.5, 0.5), floor_color.lightened(0.18))
	var label := Label3D.new()
	label.text = title
	label.font_size = 64
	label.modulate = Color(0.45, 0.88, 1.0)
	label.position = Vector3(center_x, 2.65, -9.82)
	label.rotation_degrees = Vector3(0, 0, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_world.add_child(label)
	for z: float in [-7.4, 7.4]:
		var column := PrimitiveFactory.cylinder_visual(0.42, 2.8, floor_color.lightened(0.3), 0.25)
		column.position = Vector3(center_x, 1.4, z)
		_world.add_child(column)

func _add_static_box(position: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	body.add_child(PrimitiveFactory.box_shape(size))
	body.add_child(PrimitiveFactory.box_visual(size, color))
	_world.add_child(body)
	return body

func _spawn_player() -> void:
	_player = PlayerActor.new()
	_world.add_child(_player)
	_player.global_position = Vector3(0, 1, 0)
	_player.died.connect(_on_player_died)
	_player.camera_impact.connect(_on_camera_impact)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 55.0
	_camera.position = _player.global_position + Vector3(0, 17, 14)
	add_child(_camera)
	_camera.look_at(_player.global_position, Vector3.UP)

func _build_progression() -> void:
	_intro_exit = _create_door(31.3)
	_mixed_exit = _create_door(54.3)
	_puzzle_exit = _create_door(77.3)
	_boss_exit = _create_door(102.3)
	_hub_gate = _create_interactable(WorldInteractable.Kind.DUNGEON_GATE, Vector3(6.0, 1.0, 0), "Enter dungeon", Color(0.1, 0.85, 1.0))
	_hub_gate.used.connect(_on_hub_gate_used)
	_intro_room = _create_encounter(Vector3(20, 1.5, 0), INTRO_ENCOUNTER, null, _intro_exit, Vector3(19, 3, 18))
	_mixed_room = _create_encounter(Vector3(43, 1.5, 0), MIXED_ENCOUNTER, _intro_exit, _mixed_exit, Vector3(19, 3, 18))
	_boss_room = _create_encounter(Vector3(90, 1.5, 0), BOSS_ENCOUNTER, _puzzle_exit, _boss_exit, Vector3(21, 3, 18))
	_rooms = [_intro_room, _mixed_room, _boss_room]
	_intro_room.encounter_completed.connect(_on_intro_completed)
	_mixed_room.encounter_completed.connect(_on_mixed_completed)
	_boss_room.encounter_completed.connect(_on_boss_completed)
	for room: EncounterRoom in _rooms:
		room.encounter_started.connect(_on_encounter_started)
		room.boss_spawned.connect(_on_boss_spawned)
		room.pickup_spawned.connect(_on_pickup_spawned)
	_build_hazards()
	_build_puzzle()
	_reward_chest = _create_interactable(WorldInteractable.Kind.REWARD_CHEST, Vector3(112, 1, 0), "Open Warden cache", Color(1.0, 0.55, 0.05))
	_reward_chest.used.connect(_on_reward_chest_used)
	_return_gate = _create_interactable(WorldInteractable.Kind.RETURN_GATE, Vector3(119, 1, 0), "Return to staging bay", Color(0.18, 1.0, 0.58))
	_return_gate.used.connect(_on_return_gate_used)
	_return_gate.set_disabled(true)

func _create_door(x_position: float) -> WorldDoor:
	var door := WorldDoor.new()
	_world.add_child(door)
	door.position = Vector3(x_position, 0, 0)
	door.setup(19.5)
	return door

func _create_interactable(kind: WorldInteractable.Kind, position: Vector3, prompt: String, tint: Color, index: int = -1) -> WorldInteractable:
	var result := WorldInteractable.new()
	_world.add_child(result)
	result.global_position = position
	result.setup(kind, prompt, tint, index)
	return result

func _create_encounter(position: Vector3, definition: EncounterDefinition, entry: WorldDoor, exit: WorldDoor, trigger_size: Vector3) -> EncounterRoom:
	var room := EncounterRoom.new()
	_world.add_child(room)
	room.global_position = position
	room.setup(definition, _player, trigger_size, entry, exit)
	return room

func _build_hazards() -> void:
	for position: Vector3 in [Vector3(39, 1, -4), Vector3(47, 1, 4)]:
		var hazard := HazardPulse.new()
		_world.add_child(hazard)
		hazard.global_position = position
		hazard.setup()

func _build_puzzle() -> void:
	_puzzle_trigger.collision_layer = 0
	_puzzle_trigger.collision_mask = 1
	_puzzle_trigger.monitoring = true
	_puzzle_trigger.add_child(PrimitiveFactory.box_shape(Vector3(19, 3, 18)))
	_puzzle_trigger.body_entered.connect(_on_puzzle_entered)
	_puzzle_trigger.position = Vector3(66, 1.5, 0)
	_world.add_child(_puzzle_trigger)
	var positions: Array[Vector3] = [Vector3(64, 1, -4), Vector3(69, 1, 0), Vector3(64, 1, 4)]
	var colors: Array[Color] = [Color(0.1, 0.9, 1.0), Color(1.0, 0.55, 0.05), Color(0.72, 0.18, 1.0)]
	var names: Array[String] = ["Cyan relay", "Amber relay", "Violet relay"]
	for index: int in range(3):
		var console := _create_interactable(WorldInteractable.Kind.CONSOLE, positions[index], "Activate %s" % names[index], colors[index], index)
		console.used.connect(_on_console_used)
		_puzzle_consoles.append(console)
	var sign := Label3D.new()
	sign.text = "SEQUENCE: AMBER  →  CYAN  →  VIOLET"
	sign.font_size = 44
	sign.modulate = Color(1.0, 0.82, 0.38)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(70, 2.6, -8.8)
	_world.add_child(sign)

func _build_hud() -> void:
	_hud = GameHud.new()
	add_child(_hud)
	_hud.bind_player(_player)
	_hud.overlay_changed.connect(_on_overlay_changed)
	_hud.quit_requested.connect(func() -> void: get_tree().quit())
	_hud.reset_run_requested.connect(_reset_to_hub)
	_hud.set_objective("Find the luminous dungeon gate")

func _begin_run(teleport_player: bool = true) -> void:
	for room: EncounterRoom in _rooms:
		room.reset_for_run()
	_puzzle_progress.clear()
	_puzzle_active = false
	_puzzle_completed = false
	_puzzle_trigger.monitoring = true
	for console: WorldInteractable in _puzzle_consoles:
		console.set_disabled(false)
	_mixed_exit.set_locked(true)
	_puzzle_exit.set_locked(true)
	_boss_exit.set_locked(true)
	_reward_chest.set_disabled(false)
	_return_gate.set_disabled(true)
	_hud.hide_boss_health() if _hud != null else null
	if teleport_player:
		_player.global_position = Vector3(11.5, 1, 0)
		_player.controls_enabled = true
		_hud.set_objective("Clear the Foundry Guard")

func _reset_to_hub() -> void:
	_begin_run(false)
	_player.restore_at(Vector3(0, 1, 0))
	_hud.hide_boss_health()
	_hud.set_objective("Find the luminous dungeon gate")
	_hud.show_toast("Returned to staging bay")

func _on_hub_gate_used(_gate: WorldInteractable, _player_actor: PlayerActor) -> void:
	_begin_run(true)
	_hud.show_toast("Dungeon run started — room progress resets each run")

func _on_encounter_started(_room: EncounterRoom, objective: String) -> void:
	_hud.set_objective(objective)
	_hud.show_toast("Exits locked — encounter active")

func _on_intro_completed(_room: EncounterRoom) -> void:
	_hud.set_objective("Advance through the live conduits")
	_hud.show_toast("Foundry clear — exit unlocked")
	_spawn_equipment_pickup(Vector3(26, 1, 0), &"guardian_disc")

func _on_mixed_completed(_room: EncounterRoom) -> void:
	_hud.set_objective("Solve the relay sequence: Amber → Cyan → Violet")
	_hud.show_toast("Conduits stabilized — puzzle room unlocked")
	_spawn_equipment_pickup(Vector3(49, 1, 0), &"velocity_coil")

func _on_puzzle_entered(body: Node3D) -> void:
	if body != _player or _puzzle_active or _puzzle_completed:
		return
	_puzzle_active = true
	_mixed_exit.set_locked(true)
	_puzzle_exit.set_locked(true)
	_hud.set_objective("Activate: Amber → Cyan → Violet")
	_hud.show_toast("Relay chamber sealed")

func _on_console_used(console: WorldInteractable, _player_actor: PlayerActor) -> void:
	if not _puzzle_active or _puzzle_completed:
		return
	var expected: Array[int] = [1, 0, 2]
	var next_index := expected[_puzzle_progress.size()]
	if console.index != next_index:
		_puzzle_progress.clear()
		for candidate: WorldInteractable in _puzzle_consoles:
			candidate.set_disabled(false)
		_hud.show_toast("Sequence reset — read the wall signal")
		return
	_puzzle_progress.append(console.index)
	console.set_disabled(true)
	_hud.show_toast("Relay %d / 3 synchronized" % _puzzle_progress.size())
	if _puzzle_progress.size() == expected.size():
		_puzzle_completed = true
		_puzzle_active = false
		_mixed_exit.set_locked(false)
		_puzzle_exit.set_locked(false)
		_hud.set_objective("Enter the Warden arena")
		_hud.show_toast("Sequence complete — vault path unlocked")
		_spawn_equipment_pickup(Vector3(72, 1, 0), &"scout_helm")

func _on_boss_spawned(boss: EnemyActor) -> void:
	boss.boss_health_changed.connect(_hud.set_boss_health)
	boss.camera_impact.connect(_on_camera_impact)
	_hud.set_boss_health(boss.health.current, boss.health.maximum, boss.definition.display_name)

func _on_boss_completed(_room: EncounterRoom) -> void:
	_hud.hide_boss_health()
	_hud.set_objective("Claim the Warden cache")
	_hud.show_toast("Vault Warden defeated — reward room unlocked")

func _on_reward_chest_used(chest: WorldInteractable, _player_actor: PlayerActor) -> void:
	var reward_id: StringName = &"ember_blade"
	if GameState.inventory.add(reward_id, 1) > 0:
		_hud.show_toast("Inventory full — make space for the guaranteed reward")
		return
	GameState.inventory.add(&"forge_plate", 1)
	GameState.add_currency(75)
	GameState.mark_dungeon_completed()
	chest.set_disabled(true)
	_return_gate.set_disabled(false)
	_hud.set_objective("Return to staging and save progress")
	_hud.show_completion()
	_hud.show_toast("Ember Blade + Forge Plate acquired")

func _on_return_gate_used(_gate: WorldInteractable, _player_actor: PlayerActor) -> void:
	var result := GameState.save_profile()
	_reset_to_hub()
	if bool(result.get("ok", false)):
		_hud.show_toast("Run complete — profile saved in staging bay")

func _spawn_equipment_pickup(position: Vector3, item_id: StringName) -> void:
	var pickup := WorldPickup.new()
	_world.add_child(pickup)
	pickup.global_position = position
	pickup.setup(WorldPickup.Kind.EQUIPMENT, 0, item_id)
	_on_pickup_spawned(pickup)

func _on_pickup_spawned(pickup: WorldPickup) -> void:
	pickup.collected.connect(_hud.show_toast)

func _on_player_died() -> void:
	_hud.show_toast("System failure — reconstructing in staging bay")
	await get_tree().create_timer(1.2).timeout
	_reset_to_hub()

func _on_camera_impact(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

func _on_overlay_changed(is_open: bool) -> void:
	_player.controls_enabled = not is_open

func _run_gameplay_verification() -> void:
	print("Clockwork Depths gameplay-loop verification")
	GameState.repository = SaveRepository.new("user://clockwork_depths_integration_test.json")
	GameState.repository.reset()
	GameState.new_profile()
	_begin_run(false)
	_verify(_player != null and _hud != null, "runtime world composes player and UI")
	_on_hub_gate_used(_hub_gate, _player)
	_verify(_player.global_position.x > 9.0, "hub gate starts dungeon run")
	_intro_room.start()
	_verification_defeat_room(_intro_room)
	_verify(_intro_room.completed and not _intro_exit.locked, "intro encounter unlocks exit")
	_mixed_room.start()
	_verification_defeat_room(_mixed_room)
	_verify(_mixed_room.completed and not _mixed_exit.locked, "mixed encounter unlocks puzzle path")
	_on_puzzle_entered(_player)
	_on_console_used(_puzzle_consoles[1], _player)
	_on_console_used(_puzzle_consoles[0], _player)
	_on_console_used(_puzzle_consoles[2], _player)
	_verify(_puzzle_completed and not _puzzle_exit.locked, "ordered relay puzzle unlocks boss arena")
	_boss_room.start()
	var bosses: Array = _boss_room._living.values()
	_verify(bosses.size() == 1 and bosses[0] is EnemyActor, "boss encounter spawns configured boss")
	if not bosses.is_empty() and bosses[0] is EnemyActor:
		var boss: EnemyActor = bosses[0]
		boss.health.apply_damage(DamageContext.create(230.0, PlayerActor.TEAM, "test"))
		await get_tree().physics_frame
		await get_tree().physics_frame
		_verify(boss.phase == 2, "boss increases pressure below half health")
		await get_tree().create_timer(0.13).timeout
		boss.health.apply_damage(DamageContext.create(999.0, PlayerActor.TEAM, "test"))
	_verify(_boss_room.completed and not _boss_exit.locked, "boss defeat unlocks reward room")
	_on_reward_chest_used(_reward_chest, _player)
	_verify(GameState.dungeon_completed and GameState.inventory.quantity_of(&"ember_blade") == 1, "cache grants guaranteed equipment and progression")
	var currency_before_save := GameState.currency
	var save_result := GameState.save_profile()
	_verify(bool(save_result.get("ok", false)), "completed profile saves")
	GameState.new_profile()
	_verify(not GameState.dungeon_completed, "runtime profile can reset independently")
	var load_result := GameState.load_profile(false)
	_verify(bool(load_result.get("ok", false)) and GameState.dungeon_completed and GameState.currency == currency_before_save, "process-style reload restores progression and currency")
	_verify(GameState.inventory.quantity_of(&"ember_blade") == 1, "process-style reload restores inventory")
	GameState.repository.reset()
	if _verification_failures.is_empty():
		print("PASS: %d checks" % _verification_checks)
		get_tree().quit(0)
	else:
		for failure: String in _verification_failures:
			push_error(failure)
		print("FAIL: %d of %d checks failed" % [_verification_failures.size(), _verification_checks])
		get_tree().quit(1)

func _verification_defeat_room(room: EncounterRoom) -> void:
	var enemies: Array = room._living.values().duplicate()
	for value: Variant in enemies:
		if value is EnemyActor:
			var enemy: EnemyActor = value
			enemy.health.apply_damage(DamageContext.create(9999.0, PlayerActor.TEAM, "test"))

func _verify(condition: bool, description: String) -> void:
	_verification_checks += 1
	if condition:
		print("  ok  ", description)
	else:
		_verification_failures.append(description)
		print("  ERR ", description)
