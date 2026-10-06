class_name EncounterRoom
extends Node3D

signal encounter_started(room: EncounterRoom, objective: String)
signal encounter_completed(room: EncounterRoom)
signal boss_spawned(boss: EnemyActor)
signal pickup_spawned(pickup: WorldPickup)

var definition: EncounterDefinition
var player: PlayerActor
var entry_door: WorldDoor
var exit_door: WorldDoor
var completed: bool = false
var active: bool = false
var _trigger := Area3D.new()
var _living: Dictionary = {}
var _spawned: Array[Node] = []

func setup(encounter: EncounterDefinition, target: PlayerActor, trigger_size: Vector3, entrance: WorldDoor, exit: WorldDoor) -> void:
	definition = encounter
	player = target
	entry_door = entrance
	exit_door = exit
	name = "Encounter_%s" % definition.encounter_id
	_trigger.collision_layer = 0
	_trigger.collision_mask = 1
	_trigger.monitoring = true
	_trigger.add_child(PrimitiveFactory.box_shape(trigger_size))
	_trigger.body_entered.connect(_on_body_entered)
	add_child(_trigger)
	if exit_door != null:
		exit_door.set_locked(true)

func reset_for_run() -> void:
	for node: Node in _spawned:
		if is_instance_valid(node):
			node.queue_free()
	_spawned.clear()
	_living.clear()
	completed = false
	active = false
	_trigger.monitoring = true
	if exit_door != null:
		exit_door.set_locked(true)
	if entry_door != null:
		entry_door.set_locked(false)

func _on_body_entered(body: Node3D) -> void:
	if body != player or active or completed:
		return
	start()

func start() -> void:
	if active or completed:
		return
	active = true
	_trigger.set_deferred("monitoring", false)
	if entry_door != null:
		entry_door.set_locked(true)
	if exit_door != null:
		exit_door.set_locked(true)
	encounter_started.emit(self, definition.objective_text)
	var spawns := definition.spawn_entries()
	for index: int in range(spawns.size()):
		var spawn: Dictionary = spawns[index]
		var enemy_id: StringName = spawn.get("enemy_id", &"")
		var enemy_definition := GameState.enemy_definition(enemy_id)
		if enemy_definition == null:
			push_warning("Encounter %s skipped missing enemy %s" % [definition.encounter_id, enemy_id])
			continue
		var enemy := EnemyActor.new()
		get_parent().add_child(enemy)
		var offset: Vector3 = spawn.get("offset", Vector3(index * 2.0, 0, 0))
		enemy.global_position = global_position + offset + Vector3.UP
		enemy.setup(enemy_definition, player)
		enemy.defeated.connect(_on_enemy_defeated)
		_living[enemy.get_instance_id()] = enemy
		_spawned.append(enemy)
		if enemy_definition.archetype == EnemyDefinition.Archetype.BOSS:
			boss_spawned.emit(enemy)
	if _living.is_empty():
		complete()

func complete() -> void:
	if completed:
		return
	active = false
	completed = true
	if entry_door != null:
		entry_door.set_locked(false)
	if exit_door != null:
		exit_door.set_locked(false)
	encounter_completed.emit(self)

func _on_enemy_defeated(enemy: EnemyActor, currency_reward: int, was_boss: bool) -> void:
	_living.erase(enemy.get_instance_id())
	GameState.record_enemy_defeat()
	_spawn_reward(enemy.global_position, currency_reward, was_boss)
	if _living.is_empty():
		complete()

func _spawn_reward(position: Vector3, reward: int, was_boss: bool) -> void:
	var pickup := WorldPickup.new()
	get_parent().add_child(pickup)
	pickup.global_position = position
	if was_boss:
		pickup.setup(WorldPickup.Kind.CURRENCY, reward)
	else:
		pickup.setup(WorldPickup.Kind.HEALTH, 18) if randi() % 4 == 0 else pickup.setup(WorldPickup.Kind.CURRENCY, reward)
	_spawned.append(pickup)
	pickup_spawned.emit(pickup)
