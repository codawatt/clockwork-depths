class_name DamageContext
extends RefCounted

enum DamageType { PHYSICAL, ENERGY, HAZARD }
enum AttackCategory { LIGHT, COMBO_FINISHER, CHARGED, PROJECTILE, HAZARD }

var amount: float = 0.0
var damage_type: DamageType = DamageType.PHYSICAL
var category: AttackCategory = AttackCategory.LIGHT
var source_actor_id: String = ""
var source_team: int = 0
var source: WeakRef
var knockback: Vector3 = Vector3.ZERO
var hit_position: Vector3 = Vector3.ZERO

static func create(
	damage_amount: float,
	team: int,
	actor_id: String,
	attack_category: AttackCategory = AttackCategory.LIGHT,
	attack_type: DamageType = DamageType.PHYSICAL
) -> DamageContext:
	var context := DamageContext.new()
	context.amount = maxf(0.0, damage_amount)
	context.source_team = team
	context.source_actor_id = actor_id
	context.category = attack_category
	context.damage_type = attack_type
	return context

func with_source(node: Node) -> DamageContext:
	source = weakref(node)
	return self

func with_knockback(force: Vector3) -> DamageContext:
	knockback = force
	return self
