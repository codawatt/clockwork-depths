class_name EnemyActor
extends CharacterBody3D

signal defeated(actor: EnemyActor, currency_reward: int, was_boss: bool)
signal boss_health_changed(current: float, maximum: float, display_name: String)
signal camera_impact(strength: float)

const TEAM := 2

var definition: EnemyDefinition
var target: PlayerActor
var health := HealthComponent.new()
var state: StringName = &"seek"
var phase: int = 1
var _state_remaining := 0.0
var _attack_available_at := 0
var _pattern_index := 0
var _visual_root := Node3D.new()
var _body_visual: MeshInstance3D
var _base_color := Color.WHITE
var _knockback_velocity := Vector3.ZERO
var _strafe_sign := 1.0
var _dead := false

func setup(enemy_definition: EnemyDefinition, player_target: PlayerActor) -> void:
	definition = enemy_definition
	target = player_target
	name = definition.display_name
	add_to_group("enemy")
	if definition.archetype == EnemyDefinition.Archetype.BOSS:
		add_to_group("boss")
	collision_layer = 2
	collision_mask = 1
	var radius := 1.05 if definition.archetype == EnemyDefinition.Archetype.BOSS else 0.58
	var height := 2.7 if definition.archetype == EnemyDefinition.Archetype.BOSS else 1.65
	add_child(PrimitiveFactory.capsule_shape(radius, height))
	add_child(_visual_root)
	_base_color = definition.color
	_body_visual = PrimitiveFactory.capsule_visual(radius, height, _base_color, 0.2 if definition.archetype == EnemyDefinition.Archetype.BOSS else 0.0)
	_visual_root.add_child(_body_visual)
	if definition.archetype == EnemyDefinition.Archetype.RANGED:
		var crown := PrimitiveFactory.cylinder_visual(0.72, 0.28, Color(0.3, 0.75, 1.0), 0.8)
		crown.position.y = 0.8
		_visual_root.add_child(crown)
	elif definition.archetype == EnemyDefinition.Archetype.MELEE:
		var fists := PrimitiveFactory.box_visual(Vector3(1.55, 0.45, 0.45), Color(0.7, 0.18, 0.08))
		fists.position = Vector3(0, 0, -0.15)
		_visual_root.add_child(fists)
	else:
		for offset: float in [-0.8, 0.8]:
			var shoulder := PrimitiveFactory.sphere_visual(0.48, Color(1.0, 0.52, 0.08), 1.0)
			shoulder.position = Vector3(offset, 0.48, 0)
			_visual_root.add_child(shoulder)
	add_child(health)
	health.invulnerability_seconds = 0.1
	health.configure(definition.max_health)
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	var hurtbox := Hurtbox.new()
	hurtbox.configure(self, health, TEAM, radius * 1.08)
	add_child(hurtbox)

func _physics_process(delta: float) -> void:
	if _dead or not is_instance_valid(target) or target.health.is_dead():
		velocity = Vector3.ZERO
		return
	if definition.archetype == EnemyDefinition.Archetype.BOSS:
		_update_boss_phase()
	if state == &"telegraph":
		_state_remaining -= delta
		velocity = _knockback_velocity
		if _state_remaining <= 0.0:
			_execute_attack()
	elif state == &"recover":
		_state_remaining -= delta
		velocity = _knockback_velocity
		if _state_remaining <= 0.0:
			state = &"seek"
			_set_color(_base_color)
	else:
		_update_seek()
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, 14.0 * delta)
	move_and_slide()
	global_position.y = 1.0 if definition.archetype != EnemyDefinition.Archetype.BOSS else 1.35
	var facing := target.global_position - global_position
	facing.y = 0.0
	if facing.length_squared() > 0.05:
		look_at(global_position + facing.normalized(), Vector3.UP)

func _update_seek() -> void:
	var difference := target.global_position - global_position
	difference.y = 0.0
	var distance := difference.length()
	var direction := difference.normalized() if distance > 0.01 else Vector3.ZERO
	if definition.archetype == EnemyDefinition.Archetype.MELEE:
		velocity = direction * definition.move_speed + _knockback_velocity
		if distance <= definition.attack_range:
			_begin_telegraph(0.52)
	elif definition.archetype == EnemyDefinition.Archetype.RANGED:
		if distance < 5.2:
			velocity = -direction * definition.move_speed + direction.rotated(Vector3.UP, PI * 0.5) * _strafe_sign
		elif distance > 9.0:
			velocity = direction * definition.move_speed
		else:
			velocity = direction.rotated(Vector3.UP, PI * 0.5) * _strafe_sign * definition.move_speed * 0.55
		if distance <= definition.attack_range:
			_begin_telegraph(0.72)
	else:
		velocity = direction * definition.move_speed * (1.18 if phase == 2 else 1.0) + _knockback_velocity
		if distance <= 10.5:
			_begin_telegraph(0.72 if phase == 1 else 0.48)

func _begin_telegraph(duration: float) -> void:
	if Time.get_ticks_msec() < _attack_available_at:
		return
	state = &"telegraph"
	_state_remaining = duration
	velocity = Vector3.ZERO
	_set_color(Color(1.0, 0.82, 0.12))
	_spawn_telegraph(duration)

func _execute_attack() -> void:
	if not is_instance_valid(target):
		return
	var cooldown_scale := 0.68 if phase == 2 else 1.0
	_attack_available_at = Time.get_ticks_msec() + int(definition.attack_cooldown * cooldown_scale * 1000.0)
	if definition.archetype == EnemyDefinition.Archetype.MELEE:
		_melee_attack(definition.attack_range * 0.62, definition.damage, 7.0)
	elif definition.archetype == EnemyDefinition.Archetype.RANGED:
		_fire_at_target(definition.damage, 8.5, Color(0.62, 0.18, 1.0))
		_strafe_sign *= -1.0
	else:
		match _pattern_index % 3:
			0: _boss_slam()
			1: _boss_volley()
			2: _boss_dash()
		_pattern_index += 1
	state = &"recover"
	_state_remaining = 0.4 if phase == 1 else 0.24

func _melee_attack(radius: float, damage: float, knockback_force: float) -> void:
	var direction := (target.global_position - global_position).normalized()
	direction.y = 0.0
	var context := DamageContext.create(damage, TEAM, String(definition.enemy_id)).with_source(self).with_knockback(direction * knockback_force)
	var hitbox := Hitbox.new()
	hitbox.configure(context, radius, 0.18)
	get_parent().add_child(hitbox)
	hitbox.global_position = global_position + direction * radius * 0.6
	hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: camera_impact.emit(0.55))

func _fire_at_target(damage: float, speed: float, color: Color) -> void:
	var direction := target.global_position - global_position
	direction.y = 0.0
	var context := DamageContext.create(damage, TEAM, String(definition.enemy_id), DamageContext.AttackCategory.PROJECTILE, DamageContext.DamageType.ENERGY).with_source(self).with_knockback(direction.normalized() * 3.0)
	_spawn_projectile(context, direction.normalized(), speed, color)

func _boss_slam() -> void:
	var context := DamageContext.create(definition.damage * 1.15, TEAM, String(definition.enemy_id), DamageContext.AttackCategory.COMBO_FINISHER).with_source(self)
	context.knockback = (target.global_position - global_position).normalized() * 12.0
	var hitbox := Hitbox.new()
	hitbox.configure(context, 3.8 if phase == 1 else 4.8, 0.22)
	get_parent().add_child(hitbox)
	hitbox.global_position = global_position
	camera_impact.emit(1.0)

func _boss_volley() -> void:
	var count := 8 if phase == 1 else 12
	for index: int in range(count):
		var direction := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(index) / float(count))
		var context := DamageContext.create(definition.damage * 0.65, TEAM, String(definition.enemy_id), DamageContext.AttackCategory.PROJECTILE, DamageContext.DamageType.ENERGY).with_source(self).with_knockback(direction * 4.0)
		_spawn_projectile(context, direction, 7.0 if phase == 1 else 9.0, Color(1.0, 0.22, 0.08))

func _boss_dash() -> void:
	var direction := target.global_position - global_position
	direction.y = 0.0
	_knockback_velocity = direction.normalized() * (16.0 if phase == 1 else 21.0)
	_melee_attack(2.3, definition.damage * 1.3, 14.0)

func _spawn_projectile(context: DamageContext, direction: Vector3, speed: float, color: Color) -> void:
	var projectile := CombatProjectile.new()
	get_parent().add_child(projectile)
	projectile.global_position = global_position + Vector3.UP * 0.25 + direction * 1.2
	projectile.configure(context, direction, speed, 0.34, color)

func _spawn_telegraph(duration: float) -> void:
	var radius := definition.attack_range * 0.7
	if definition.archetype == EnemyDefinition.Archetype.BOSS:
		radius = [3.8, 5.2, 2.5][_pattern_index % 3]
	var marker := PrimitiveFactory.cylinder_visual(radius, 0.035, Color(1.0, 0.22, 0.08), 2.5)
	get_parent().add_child(marker)
	marker.global_position = global_position + Vector3(0, -0.92 if definition.archetype != EnemyDefinition.Archetype.BOSS else -1.27, 0)
	marker.scale = Vector3(0.15, 1.0, 0.15)
	var tween := get_tree().create_tween()
	tween.tween_property(marker, "scale", Vector3.ONE, duration)
	tween.tween_callback(marker.queue_free)

func _update_boss_phase() -> void:
	if phase == 1 and health.current <= health.maximum * 0.5:
		phase = 2
		_base_color = Color(1.0, 0.06, 0.48)
		_set_color(_base_color)
		_visual_root.scale = Vector3(1.14, 1.14, 1.14)
		camera_impact.emit(1.2)

func _on_health_changed(current: float, maximum: float) -> void:
	if definition != null and definition.archetype == EnemyDefinition.Archetype.BOSS:
		boss_health_changed.emit(current, maximum, definition.display_name)

func _on_damaged(context: DamageContext, _amount: float) -> void:
	_knockback_velocity += context.knockback * (0.25 if definition.archetype == EnemyDefinition.Archetype.BOSS else 1.0)
	var original := _body_visual.material_override as StandardMaterial3D
	if original != null:
		original.albedo_color = Color.WHITE
		create_tween().tween_property(original, "albedo_color", _base_color, 0.16)

func _on_died(_context: DamageContext) -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 0
	defeated.emit(self, definition.currency_reward, definition.archetype == EnemyDefinition.Archetype.BOSS)
	var tween := create_tween()
	tween.tween_property(_visual_root, "scale", Vector3(1.45, 0.05, 1.45), 0.34)
	tween.parallel().tween_property(_visual_root, "rotation:y", PI, 0.34)
	tween.tween_callback(queue_free)

func _set_color(color: Color) -> void:
	var material := _body_visual.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = color
