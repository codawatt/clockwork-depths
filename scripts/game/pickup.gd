class_name WorldPickup
extends Area3D

signal collected(message: String)

enum Kind { CURRENCY, HEALTH, EQUIPMENT }

var kind: Kind = Kind.CURRENCY
var amount: int = 0
var item_id: StringName = &""
var _visual_root := Node3D.new()

func setup(pickup_kind: Kind, value: int = 0, definition_id: StringName = &"") -> void:
	kind = pickup_kind
	amount = value
	item_id = definition_id
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	add_child(PrimitiveFactory.sphere_shape(0.8))
	add_child(_visual_root)
	var tint := Color(1.0, 0.72, 0.08)
	if kind == Kind.HEALTH:
		tint = Color(0.15, 1.0, 0.38)
	elif kind == Kind.EQUIPMENT:
		var definition := GameState.item_definition(item_id)
		tint = definition.color if definition != null else Color.CYAN
	var core := PrimitiveFactory.sphere_visual(0.46, tint, 2.0)
	_visual_root.add_child(core)
	var ring := PrimitiveFactory.cylinder_visual(0.68, 0.08, tint, 2.0)
	ring.position.y = -0.58
	_visual_root.add_child(ring)

func _process(delta: float) -> void:
	_visual_root.rotation.y += delta * 2.2
	_visual_root.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.18

func _on_body_entered(body: Node3D) -> void:
	if not body is PlayerActor:
		return
	var player: PlayerActor = body
	match kind:
		Kind.CURRENCY:
			GameState.add_currency(amount)
			collected.emit("+%d cogs" % amount)
		Kind.HEALTH:
			var healed := player.heal(float(amount))
			if healed <= 0.0:
				return
			collected.emit("Recovered %d health" % int(healed))
		Kind.EQUIPMENT:
			var remainder := GameState.inventory.add(item_id, 1)
			if remainder > 0:
				collected.emit("Inventory full")
				return
			var definition := GameState.item_definition(item_id)
			collected.emit("Found %s — open inventory to equip" % (definition.display_name if definition != null else String(item_id)))
	queue_free()
