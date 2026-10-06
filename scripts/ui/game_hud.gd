class_name GameHud
extends CanvasLayer

signal overlay_changed(is_open: bool)
signal quit_requested
signal reset_run_requested

var _health_bar := ProgressBar.new()
var _health_label := Label.new()
var _currency_label := Label.new()
var _objective_label := Label.new()
var _prompt_label := Label.new()
var _toast_label := Label.new()
var _boss_panel := VBoxContainer.new()
var _boss_label := Label.new()
var _boss_bar := ProgressBar.new()
var _inventory_panel := PanelContainer.new()
var _inventory_list := ItemList.new()
var _equipment_list := ItemList.new()
var _details := RichTextLabel.new()
var _pause_panel := PanelContainer.new()
var _completion_panel := PanelContainer.new()
var _inventory_ids: Array[String] = []
var _equipment_slots: Array[StringName] = []
var _toast_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_hud()
	_build_inventory()
	_build_pause()
	_build_completion()
	GameState.profile_changed.connect(refresh_profile)
	GameState.save_status.connect(_on_save_status)
	refresh_profile()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _pause_panel.visible:
			return
		_inventory_panel.visible = not _inventory_panel.visible
		if _inventory_panel.visible:
			refresh_inventory()
		overlay_changed.emit(_inventory_panel.visible)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if _inventory_panel.visible:
			_inventory_panel.visible = false
			_pause_panel.visible = false
			overlay_changed.emit(false)
		else:
			_pause_panel.visible = not _pause_panel.visible
			overlay_changed.emit(_pause_panel.visible)
		get_viewport().set_input_as_handled()

func bind_player(player: PlayerActor) -> void:
	player.health_changed.connect(set_health)
	player.interaction_prompt_changed.connect(set_prompt)
	set_health(player.health.current, player.health.maximum)

func set_health(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

func set_objective(text: String) -> void:
	_objective_label.text = text

func set_prompt(text: String) -> void:
	_prompt_label.text = text

func set_boss_health(current: float, maximum: float, display_name: String) -> void:
	_boss_panel.visible = current > 0.0
	_boss_label.text = display_name
	_boss_bar.max_value = maximum
	_boss_bar.value = current

func hide_boss_health() -> void:
	_boss_panel.visible = false

func show_toast(message: String, duration: float = 2.3) -> void:
	_toast_label.text = message
	_toast_label.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(duration)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.4)

func show_completion() -> void:
	_completion_panel.visible = true
	var tween := create_tween()
	tween.tween_interval(4.0)
	tween.tween_property(_completion_panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void:
		_completion_panel.visible = false
		_completion_panel.modulate.a = 1.0
	)

func refresh_profile() -> void:
	_currency_label.text = "COGS  %04d" % GameState.currency
	if _inventory_panel.visible:
		refresh_inventory()

func refresh_inventory() -> void:
	_inventory_list.clear()
	_inventory_ids.clear()
	for item: ItemInstance in GameState.inventory.items():
		var definition := GameState.item_definition(item.definition_id)
		var display := definition.display_name if definition != null else "Obsolete Item"
		_inventory_list.add_item("%s%s" % [display, "  ×%d" % item.quantity if item.quantity > 1 else ""])
		_inventory_ids.append(item.instance_id)
	_equipment_list.clear()
	_equipment_slots.clear()
	for slot_name: StringName in EquipmentModel.SLOT_NAMES:
		var equipped := GameState.equipment.equipped(slot_name)
		var item_name := "—"
		if equipped != null:
			var definition := GameState.item_definition(equipped.definition_id)
			item_name = definition.display_name if definition != null else "Obsolete"
		_equipment_list.add_item("%-10s  %s" % [String(slot_name).capitalize(), item_name])
		_equipment_slots.append(slot_name)
	_details.text = "Select an item. Double-click to equip; double-click equipped gear to unequip."

func is_overlay_open() -> bool:
	return _inventory_panel.visible or _pause_panel.visible

func _build_hud() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var stats_margin := MarginContainer.new()
	stats_margin.offset_left = 24
	stats_margin.offset_top = 20
	stats_margin.offset_right = 390
	stats_margin.offset_bottom = 170
	root.add_child(stats_margin)
	var stats_box := VBoxContainer.new()
	stats_box.add_theme_constant_override("separation", 5)
	stats_margin.add_child(stats_box)
	var title := Label.new()
	title.text = "CLOCKWORK DEPTHS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.35, 0.9, 1.0))
	stats_box.add_child(title)
	var health_row := HBoxContainer.new()
	_health_bar.custom_minimum_size = Vector2(250, 22)
	_health_bar.show_percentage = false
	health_row.add_child(_health_bar)
	health_row.add_child(_health_label)
	stats_box.add_child(health_row)
	_currency_label.add_theme_color_override("font_color", Color(1.0, 0.76, 0.18))
	stats_box.add_child(_currency_label)
	_objective_label.text = "Find the dungeon gate"
	_objective_label.add_theme_font_size_override("font_size", 17)
	stats_box.add_child(_objective_label)
	var controls := Label.new()
	controls.text = "WASD move  •  Mouse aim  •  LMB combo  •  RMB charge  •  Shift dodge\nE interact  •  Tab inventory  •  F5 save  •  F9 load"
	controls.modulate = Color(0.72, 0.78, 0.86)
	controls.position = Vector2(24, 622)
	root.add_child(controls)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 22)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.34))
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-260, -86)
	_prompt_label.size = Vector2(520, 36)
	root.add_child(_prompt_label)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 20)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.position = Vector2(-330, 32)
	_toast_label.size = Vector2(660, 36)
	root.add_child(_toast_label)
	_boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_panel.position = Vector2(-250, 76)
	_boss_panel.size = Vector2(500, 64)
	_boss_panel.visible = false
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_label.add_theme_font_size_override("font_size", 20)
	_boss_bar.custom_minimum_size = Vector2(500, 24)
	_boss_bar.show_percentage = false
	_boss_panel.add_child(_boss_label)
	_boss_panel.add_child(_boss_bar)
	root.add_child(_boss_panel)

func _build_inventory() -> void:
	_inventory_panel.set_anchors_preset(Control.PRESET_CENTER)
	_inventory_panel.position = Vector2(-450, -285)
	_inventory_panel.size = Vector2(900, 570)
	_inventory_panel.visible = false
	add_child(_inventory_panel)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_inventory_panel.add_child(outer)
	var title := Label.new()
	title.text = "INVENTORY & EQUIPMENT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	outer.add_child(title)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)
	var inventory_column := VBoxContainer.new()
	inventory_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inventory_title := Label.new()
	inventory_title.text = "Carried items"
	inventory_column.add_child(inventory_title)
	_inventory_list.custom_minimum_size = Vector2(360, 330)
	_inventory_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_list.item_selected.connect(_on_inventory_selected)
	_inventory_list.item_activated.connect(_on_inventory_activated)
	inventory_column.add_child(_inventory_list)
	columns.add_child(inventory_column)
	var equipment_column := VBoxContainer.new()
	equipment_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var equipment_title := Label.new()
	equipment_title.text = "Equipped slots"
	equipment_column.add_child(equipment_title)
	_equipment_list.custom_minimum_size = Vector2(360, 210)
	_equipment_list.item_selected.connect(_on_equipment_selected)
	_equipment_list.item_activated.connect(_on_equipment_activated)
	equipment_column.add_child(_equipment_list)
	columns.add_child(equipment_column)
	_details.bbcode_enabled = true
	_details.custom_minimum_size = Vector2(0, 105)
	_details.fit_content = true
	outer.add_child(_details)
	var hint := Label.new()
	hint.text = "Double-click to equip / unequip   •   Tab or Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(hint)

func _build_pause() -> void:
	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.position = Vector2(-190, -230)
	_pause_panel.size = Vector2(380, 460)
	_pause_panel.visible = false
	add_child(_pause_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(box)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	box.add_child(title)
	_add_pause_button(box, "Resume", func() -> void:
		_pause_panel.visible = false
		overlay_changed.emit(false)
	)
	_add_pause_button(box, "Save profile", func() -> void: GameState.save_profile())
	_add_pause_button(box, "Load profile", func() -> void:
		GameState.load_profile()
		reset_run_requested.emit()
	)
	_add_pause_button(box, "Reset save & profile", func() -> void:
		GameState.reset_save_and_profile()
		reset_run_requested.emit()
	)
	_add_pause_button(box, "Quit", func() -> void: quit_requested.emit())

func _build_completion() -> void:
	_completion_panel.set_anchors_preset(Control.PRESET_CENTER)
	_completion_panel.position = Vector2(-320, -90)
	_completion_panel.size = Vector2(640, 180)
	_completion_panel.visible = false
	add_child(_completion_panel)
	var label := Label.new()
	label.text = "DUNGEON COMPLETE\nThe Warden's vault is open"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.16))
	_completion_panel.add_child(label)

func _add_pause_button(parent: VBoxContainer, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	parent.add_child(button)

func _on_inventory_selected(index: int) -> void:
	if index < 0 or index >= _inventory_ids.size():
		return
	var item := GameState.inventory.find_instance(_inventory_ids[index])
	if item == null:
		return
	var definition := GameState.item_definition(item.definition_id)
	if definition == null:
		return
	_details.text = "[font_size=22][color=#65e8ff]%s[/color][/font_size]\n%s\nSlot: %s  •  Stack: %d" % [definition.display_name, definition.description, String(definition.slot_name()).capitalize(), item.quantity]

func _on_inventory_activated(index: int) -> void:
	if index >= 0 and index < _inventory_ids.size():
		if GameState.equipment.equip(_inventory_ids[index]):
			show_toast("Equipment changed — stats recalculated")
		else:
			show_toast("That item cannot be equipped")
		refresh_inventory()

func _on_equipment_selected(index: int) -> void:
	if index < 0 or index >= _equipment_slots.size():
		return
	var item := GameState.equipment.equipped(_equipment_slots[index])
	if item == null:
		_details.text = "Empty %s slot" % String(_equipment_slots[index]).capitalize()
		return
	var definition := GameState.item_definition(item.definition_id)
	if definition != null:
		_details.text = "[font_size=22][color=#ffcc55]%s[/color][/font_size]\n%s\nDouble-click to unequip." % [definition.display_name, definition.description]

func _on_equipment_activated(index: int) -> void:
	if index >= 0 and index < _equipment_slots.size():
		if GameState.equipment.unequip(_equipment_slots[index]):
			show_toast("Item returned to inventory")
		else:
			show_toast("Cannot unequip: inventory may be full")
		refresh_inventory()

func _on_save_status(message: String, succeeded: bool) -> void:
	show_toast(message)
	_toast_label.add_theme_color_override("font_color", Color(0.35, 1.0, 0.55) if succeeded else Color(1.0, 0.35, 0.25))
