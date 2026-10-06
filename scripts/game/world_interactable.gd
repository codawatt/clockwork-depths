class_name WorldInteractable
extends Node3D

signal used(interactable: WorldInteractable, player: PlayerActor)

enum Kind { DUNGEON_GATE, CONSOLE, REWARD_CHEST, RETURN_GATE }

var kind: Kind = Kind.CONSOLE
var prompt: String = "Interact"
var disabled: bool = false
var index: int = -1
var color: Color = Color.CYAN
var _visual: MeshInstance3D
var _ring: MeshInstance3D

func setup(interactable_kind: Kind, interaction_prompt: String, tint: Color, data_index: int = -1) -> void:
	kind = interactable_kind
	prompt = interaction_prompt
	index = data_index
	color = tint
	add_to_group("interactable")
	match kind:
		Kind.DUNGEON_GATE, Kind.RETURN_GATE:
			_visual = PrimitiveFactory.box_visual(Vector3(0.5, 3.2, 4.6), tint, 1.5)
			_visual.position.y = 0.7
			add_child(_visual)
			_ring = PrimitiveFactory.cylinder_visual(2.2, 0.08, tint, 2.0)
			_ring.position.y = -0.9
			add_child(_ring)
		Kind.REWARD_CHEST:
			_visual = PrimitiveFactory.box_visual(Vector3(2.1, 1.2, 1.35), tint, 1.0)
			_visual.position.y = -0.25
			add_child(_visual)
			var lid := PrimitiveFactory.box_visual(Vector3(2.25, 0.35, 1.5), tint.lightened(0.2), 1.4)
			lid.position.y = 0.48
			add_child(lid)
		Kind.CONSOLE:
			_visual = PrimitiveFactory.cylinder_visual(0.68, 1.5, tint, 0.6)
			_visual.position.y = -0.25
			add_child(_visual)
			_ring = PrimitiveFactory.cylinder_visual(0.86, 0.12, tint, 2.0)
			_ring.position.y = 0.56
			add_child(_ring)

func interact(player: PlayerActor) -> void:
	if disabled:
		return
	used.emit(self, player)

func get_prompt() -> String:
	return prompt

func is_disabled() -> bool:
	return disabled

func set_disabled(value: bool) -> void:
	disabled = value
	if _visual != null:
		_visual.scale = Vector3(1.0, 0.42, 1.0) if disabled else Vector3.ONE
		var material := _visual.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = Color(0.18, 0.2, 0.24) if disabled else color
	if _ring != null:
		_ring.visible = not disabled
