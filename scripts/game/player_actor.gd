class_name PlayerActor
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal interaction_prompt_changed(text: String)
signal camera_impact(strength: float)

const TEAM := 1

var controls_enabled: bool = true
var aim_direction: Vector3 = Vector3.FORWARD
var health := HealthComponent.new()
var _visual_root := Node3D.new()
var _body_visual: MeshInstance3D
var _weapon_visual: MeshInstance3D
var _knockback_velocity := Vector3.ZERO
var _dodge_direction := Vector3.ZERO
var _dodge_time := 0.0
var _dodge_available_at := 0
var _attack_available_at := 0
var _combo_index := 0
var _combo_expires_at := 0
var _charge_started_at := 0
var _charging := false
var _last_prompt: String = ""

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	add_child(PrimitiveFactory.capsule_shape(0.55, 1.8))
	_visual_root.position.y = 0.1
	add_child(_visual_root)
	_body_visual = PrimitiveFactory.capsule_visual(0.55, 1.8, Color(0.12, 0.76, 0.95))
	_visual_root.add_child(_body_visual)
	var visor := PrimitiveFactory.box_visual(Vector3(0.72, 0.24, 0.18), Color(0.08, 0.16, 0.25), 0.4)
	visor.position = Vector3(0, 0.35, -0.48)
	_visual_root.add_child(visor)
	_weapon_visual = PrimitiveFactory.box_visual(Vector3(0.12, 0.18, 1.45), Color(0.55, 0.72, 0.84), 0.35)
	_weapon_visual.position = Vector3(0.72, 0.12, -0.35)
	_weapon_visual.rotation.x = -0.25
	_visual_root.add_child(_weapon_visual)
	add_child(health)
	health.configure(GameState.stats.get_value(&"max_health"), GameState.stats.get_value(&"defense"))
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, health, TEAM, 0.72)
	add_child(hurtbox)
	GameState.stats.changed.connect(_on_stat_changed)
	GameState.equipment.changed.connect(_on_equipment_changed)
	_refresh_weapon_appearance()

func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or health.is_dead():
		return
	if event.is_action_pressed("attack"):
		_try_light_attack()
	elif event.is_action_pressed("charge_attack"):
		_charging = true
		_charge_started_at = Time.get_ticks_msec()
	elif event.is_action_released("charge_attack") and _charging:
		_charging = false
		_release_charged_attack()
	elif event.is_action_pressed("dodge"):
		_try_dodge()
	elif event.is_action_pressed("interact"):
		_try_interact()

func _physics_process(delta: float) -> void:
	_update_aim()
	_update_interaction_prompt()
	if health.is_dead():
		velocity = Vector3.ZERO
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if controls_enabled else Vector2.ZERO
	var desired := _camera_relative_direction(input_vector)
	if desired.length_squared() > 0.01:
		desired = desired.normalized()
	if _dodge_time > 0.0:
		_dodge_time -= delta
		velocity = _dodge_direction * 18.0
	else:
		velocity = desired * GameState.stats.get_value(&"move_speed") + _knockback_velocity
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 18.0 * delta)
	move_and_slide()
	global_position.y = 1.0
	if aim_direction.length_squared() > 0.01:
		look_at(global_position + aim_direction, Vector3.UP)

func restore_at(position: Vector3) -> void:
	global_position = position
	health.set_maximum(GameState.stats.get_value(&"max_health"))
	health.armor = GameState.stats.get_value(&"defense")
	health.revive(true)
	controls_enabled = true
	visible = true

func heal(amount: float) -> float:
	return health.heal(amount)

func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y)
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0.0
	forward.y = 0.0
	return right.normalized() * input_vector.x + forward.normalized() * -input_vector.y

func _update_aim() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var point: Variant = Plane(Vector3.UP, global_position.y).intersects_ray(origin, direction)
	if point is Vector3:
		var flat: Vector3 = point - global_position
		flat.y = 0.0
		if flat.length_squared() > 0.04:
			aim_direction = flat.normalized()

func _try_light_attack() -> void:
	var now := Time.get_ticks_msec()
	if now < _attack_available_at or _dodge_time > 0.0:
		return
	_combo_index = (_combo_index + 1) % 3 if now < _combo_expires_at else 0
	_combo_expires_at = now + 680
	_attack_available_at = now + (320 if _combo_index < 2 else 480)
	var multiplier: float = [1.0, 1.12, 1.45][_combo_index]
	var range := GameState.stats.get_value(&"attack_range")
	var context := DamageContext.create(
		GameState.stats.get_value(&"attack_damage") * multiplier,
		TEAM,
		"player",
		DamageContext.AttackCategory.COMBO_FINISHER if _combo_index == 2 else DamageContext.AttackCategory.LIGHT
	).with_source(self).with_knockback(aim_direction * (5.0 + _combo_index * 2.0))
	_spawn_melee_hitbox(context, range, Color(0.25, 0.9, 1.0))
	_animate_weapon_swing(0.17 + _combo_index * 0.03)

func _release_charged_attack() -> void:
	var held := (Time.get_ticks_msec() - _charge_started_at) / 1000.0
	if held < 0.28 or Time.get_ticks_msec() < _attack_available_at:
		return
	_attack_available_at = Time.get_ticks_msec() + 780
	var charge := clampf(held / 1.25, 0.35, 1.0)
	var power := GameState.stats.get_value(&"charge_power")
	var context := DamageContext.create(
		GameState.stats.get_value(&"attack_damage") * (1.35 + charge * power),
		TEAM,
		"player",
		DamageContext.AttackCategory.CHARGED,
		DamageContext.DamageType.ENERGY
	).with_source(self).with_knockback(aim_direction * 11.0)
	_spawn_projectile(context, aim_direction, 13.0, Color(0.12, 0.95, 1.0))
	var accessory := GameState.equipment.equipped(&"accessory")
	if accessory != null:
		var definition := GameState.item_definition(accessory.definition_id)
		if definition != null and definition.behavior_id == &"double_charge":
			var side := aim_direction.rotated(Vector3.UP, 0.18)
			_spawn_projectile(context, side, 13.0, Color(0.4, 1.0, 0.8))
	camera_impact.emit(0.7)

func _try_dodge() -> void:
	var now := Time.get_ticks_msec()
	if now < _dodge_available_at:
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var desired := _camera_relative_direction(input_vector)
	_dodge_direction = desired.normalized() if desired.length_squared() > 0.01 else aim_direction
	_dodge_time = 0.23
	_dodge_available_at = now + int(maxf(0.35, GameState.stats.get_value(&"dodge_cooldown")) * 1000.0)
	health.grant_invulnerability(0.34)
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3(0.72, 0.72, 1.2), 0.09)
	tween.tween_property(_visual_root, "scale", Vector3.ONE, 0.14)

func _spawn_melee_hitbox(context: DamageContext, attack_range: float, color: Color) -> void:
	var hitbox := Hitbox.new()
	hitbox.configure(context, attack_range * 0.52, 0.14)
	get_parent().add_child(hitbox)
	hitbox.global_position = global_position + aim_direction * attack_range * 0.65
	hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: camera_impact.emit(0.34))
	var flash := PrimitiveFactory.cylinder_visual(attack_range * 0.52, 0.05, color, 2.0)
	get_parent().add_child(flash)
	flash.global_position = hitbox.global_position + Vector3(0, -0.82, 0)
	var tween := get_tree().create_tween()
	tween.tween_property(flash, "scale", Vector3(1.45, 1.0, 1.45), 0.16)
	tween.parallel().tween_property(flash, "transparency", 1.0, 0.16)
	tween.tween_callback(flash.queue_free)

func _spawn_projectile(context: DamageContext, direction: Vector3, speed: float, color: Color) -> void:
	var projectile := CombatProjectile.new()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * 0.25 + direction * 1.0
	projectile.configure(context, direction, speed, 0.36, color)

func _animate_weapon_swing(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(_weapon_visual, "rotation:z", -1.5, duration * 0.5).from(0.85)
	tween.tween_property(_weapon_visual, "rotation:z", 0.0, duration * 0.5)

func _nearest_interactable() -> Node3D:
	var best: Node3D
	var best_distance := 3.1
	for node: Node in get_tree().get_nodes_in_group("interactable"):
		if node is Node3D and node.has_method("get_prompt"):
			var distance := global_position.distance_to(node.global_position)
			if distance < best_distance and not bool(node.call("is_disabled")):
				best = node
				best_distance = distance
	return best

func _try_interact() -> void:
	var target := _nearest_interactable()
	if target != null and target.has_method("interact"):
		target.call("interact", self)

func _update_interaction_prompt() -> void:
	var target := _nearest_interactable()
	var prompt := ""
	if target != null:
		prompt = "[E] %s" % str(target.call("get_prompt"))
	if prompt != _last_prompt:
		_last_prompt = prompt
		interaction_prompt_changed.emit(prompt)

func _on_health_changed(current: float, maximum: float) -> void:
	health_changed.emit(current, maximum)

func _on_damaged(context: DamageContext, _amount: float) -> void:
	_knockback_velocity += context.knockback
	camera_impact.emit(0.48)
	var material := _body_visual.material_override as StandardMaterial3D
	if material != null:
		var original := material.albedo_color
		material.albedo_color = Color.WHITE
		create_tween().tween_property(material, "albedo_color", original, 0.18)

func _on_died(_context: DamageContext) -> void:
	controls_enabled = false
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3(1.2, 0.08, 1.2), 0.35)
	tween.tween_callback(func() -> void: visible = false)
	died.emit()

func _on_stat_changed(stat_name: StringName, value: float) -> void:
	if stat_name == &"max_health":
		health.set_maximum(value, true)
	elif stat_name == &"defense":
		health.armor = value

func _on_equipment_changed(_slot: StringName) -> void:
	_refresh_weapon_appearance()

func _refresh_weapon_appearance() -> void:
	var weapon := GameState.equipment.equipped(&"weapon")
	if weapon == null:
		_weapon_visual.visible = false
		return
	_weapon_visual.visible = true
	var definition := GameState.item_definition(weapon.definition_id)
	if definition != null:
		_weapon_visual.material_override = PrimitiveFactory.material(definition.color, 0.5, 0.35)
