extends Control

const RIFT := "res://scenes/rift_trials/rift_trials.tscn"
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12
const SLOTS_PER_ROW := 3
const EVENT_PAUSE_SEC := 0.52
const SPEED_MULTIPLIERS := [1.0, 1.75, 2.5]
const SPEED_LABELS := ["1×", "1.75×", "2.5×"]

var _round_label: Label
var _speed_btn: Button
var _action_pill: PanelContainer
var _action_text: Label
var _synergy_label: Label
var _enemy_back_row: HBoxContainer
var _enemy_front_row: HBoxContainer
var _player_front_row: HBoxContainer
var _player_back_row: HBoxContainer
var _continue_btn: Button
var _pause_btn: Button
var _result_layer: CanvasLayer
var _result_backdrop: ColorRect
var _result_card: PanelContainer
var _result_title: Label
var _result_subtitle: Label
var _result_actions: VBoxContainer
var _field_card: PanelContainer
var _paused: bool = false
var _auto_running: bool = false
var _awaiting_start: bool = true
var _speed_index: int = 0

var _battle_data: Dictionary = {}
var _event_index: int = 0
var _playing: bool = false
var _result_shown: bool = false
var _unit_panels: Dictionary = {}
var _display_hp: Dictionary = {}
var _display_max_hp: Dictionary = {}
var _initial_hp: Dictionary = {}
var _initial_max_hp: Dictionary = {}
var _current_round: int = 1
var _player_synergy_text: String = ""
var _unit_status: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_build_result_overlay()
	_start_battle()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = UITheme.MOBILE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", MARGIN_Y)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)

	var scroll := MobileScrollContainer.create(false, true)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_field_card = _build_field_card()
	_field_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_field_card)

	body.add_child(_build_footer())

	get_viewport().size_changed.connect(func():
		call_deferred("_layout_field")
		call_deferred("_layout_result_card")
	)


func _build_result_overlay() -> void:
	_result_layer = CanvasLayer.new()
	_result_layer.layer = 80
	_result_layer.visible = false
	add_child(_result_layer)

	_result_backdrop = ColorRect.new()
	_result_backdrop.color = Color(0, 0, 0, 0.72)
	_result_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_layer.add_child(_result_backdrop)

	_result_card = PanelContainer.new()
	_result_card.custom_minimum_size = Vector2(300, 0)
	UITheme.apply_card_style(_result_card, 16)
	_result_layer.add_child(_result_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	_result_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_result_title = Label.new()
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_result_title)

	_result_subtitle = Label.new()
	_result_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_subtitle.add_theme_font_size_override("font_size", 14)
	_result_subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(_result_subtitle)

	_result_actions = VBoxContainer.new()
	_result_actions.add_theme_constant_override("separation", 8)
	vbox.add_child(_result_actions)

	call_deferred("_layout_result_card")


func _layout_result_card() -> void:
	if _result_card == null:
		return
	var vp := get_viewport_rect().size
	_result_card.position = Vector2(
		(vp.x - _result_card.size.x) * 0.5,
		(vp.y - _result_card.size.y) * 0.5
	)


func _build_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 16)
	UITheme.style_icon_button(close_btn)
	close_btn.pressed.connect(_confirm_leave)
	row.add_child(close_btn)

	_round_label = Label.new()
	_round_label.text = "Round 1"
	_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 18)
	_round_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(_round_label)

	_speed_btn = Button.new()
	_speed_btn.text = "1×"
	_speed_btn.custom_minimum_size = Vector2(40, 40)
	_speed_btn.add_theme_font_size_override("font_size", 14)
	UITheme.style_icon_button(_speed_btn)
	_speed_btn.pressed.connect(_cycle_speed)
	row.add_child(_speed_btn)

	_speed_index = clampi(GameState.default_battle_speed_index, 0, SPEED_MULTIPLIERS.size() - 1)
	_speed_btn.text = SPEED_LABELS[_speed_index]

	return row


func _cycle_speed() -> void:
	_speed_index = (_speed_index + 1) % SPEED_MULTIPLIERS.size()
	_speed_btn.text = SPEED_LABELS[_speed_index]


func _event_pause_sec() -> float:
	return EVENT_PAUSE_SEC / SPEED_MULTIPLIERS[_speed_index]


func _build_field_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	vbox.add_child(_make_row_label("Rival back row"))
	_enemy_back_row = _make_unit_row()
	vbox.add_child(_enemy_back_row)

	vbox.add_child(_make_row_label("Rival front row"))
	_enemy_front_row = _make_unit_row()
	vbox.add_child(_enemy_front_row)

	vbox.add_child(_build_status_section())

	vbox.add_child(_make_row_label("Your front row"))
	_player_front_row = _make_unit_row()
	vbox.add_child(_player_front_row)

	vbox.add_child(_make_row_label("Your back row"))
	_player_back_row = _make_unit_row()
	vbox.add_child(_player_back_row)

	return card


func _make_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	return lbl


func _make_unit_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in SLOTS_PER_ROW:
		var host := Control.new()
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.size_flags_stretch_ratio = 1.0
		host.custom_minimum_size = Vector2(0, 72)
		row.add_child(host)
	return row


func _build_status_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	_action_pill = PanelContainer.new()
	_action_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	var pill_sb := StyleBoxFlat.new()
	pill_sb.bg_color = Color(0.12, 0.22, 0.42)
	pill_sb.border_color = UITheme.BLUE
	pill_sb.set_border_width_all(1)
	pill_sb.set_corner_radius_all(16)
	pill_sb.content_margin_left = 12
	pill_sb.content_margin_right = 12
	pill_sb.content_margin_top = 8
	pill_sb.content_margin_bottom = 8
	_action_pill.add_theme_stylebox_override("panel", pill_sb)

	_action_text = Label.new()
	_action_text.text = "Tap to begin battle"
	_action_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_text.add_theme_font_size_override("font_size", 12)
	_action_text.add_theme_color_override("font_color", Color.WHITE)
	_action_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_pill.add_child(_action_text)
	_action_pill.gui_input.connect(_on_action_pill_input)
	_action_pill.custom_minimum_size.y = 44
	section.add_child(_action_pill)

	_synergy_label = Label.new()
	_synergy_label.text = ""
	_synergy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_synergy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_synergy_label.add_theme_font_size_override("font_size", 11)
	_synergy_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	section.add_child(_synergy_label)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.28, 0.28, 0.32)
	section.add_child(line)

	return section


func _build_footer() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_pause_btn = Button.new()
	_pause_btn.text = "⏸  Pause"
	_pause_btn.custom_minimum_size = Vector2(0, 48)
	_pause_btn.disabled = true
	_pause_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_btn.size_flags_stretch_ratio = 1.0
	_pause_btn.add_theme_font_size_override("font_size", 15)
	_style_secondary_button(_pause_btn)
	_pause_btn.pressed.connect(_toggle_pause)
	row.add_child(_pause_btn)

	_continue_btn = Button.new()
	_continue_btn.text = "Begin"
	_continue_btn.custom_minimum_size = Vector2(0, 48)
	_continue_btn.disabled = false
	_continue_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_continue_btn.size_flags_stretch_ratio = 1.0
	_continue_btn.add_theme_font_size_override("font_size", 16)
	UITheme.style_accent_button(_continue_btn)
	_continue_btn.pressed.connect(_on_continue)
	row.add_child(_continue_btn)

	return row


func _style_secondary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.19)
	sb.border_color = Color(0.28, 0.28, 0.32)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _layout_field() -> void:
	var inner_w := get_viewport_rect().size.x - float(MARGIN_X * 2) - 32.0
	var gap := 8.0
	var slot_w := floorf((inner_w - gap * float(SLOTS_PER_ROW - 1)) / float(SLOTS_PER_ROW))
	var slot_h := slot_w * 1.15
	for row in [_enemy_back_row, _enemy_front_row, _player_front_row, _player_back_row]:
		if row == null:
			continue
		for host in row.get_children():
			if host is Control:
				(host as Control).custom_minimum_size = Vector2(slot_w, slot_h)


func _start_battle() -> void:
	var player: Array = GameState.active_coven
	var enemy: Array = GameState.pending_battle.get("enemy_squad", [])
	_battle_data = BattleSimulator.simulate_battle(player, enemy)
	GameState.last_battle_result = _battle_data
	_initial_hp = _battle_data.get("initial_hp", {})
	_initial_max_hp = _battle_data.get("initial_max_hp", {})
	_player_synergy_text = _build_synergy_text(player)
	_synergy_label.text = _player_synergy_text
	_current_round = 1
	_round_label.text = "Round %d" % _current_round
	_build_unit_display()
	call_deferred("_layout_field")


func _build_synergy_text(squad: Array) -> String:
	var syn: Dictionary = SynergyResolver.get_active_synergies(squad)
	var lines: PackedStringArray = []
	for m in syn.get("mono", []):
		var school: String = str(m.get("school", ""))
		var effect_id: String = str(m.get("effect_id", ""))
		lines.append("%s synergy active — %s" % [
			UITheme.school_label(school),
			_mono_effect_text(effect_id),
		])
	for d in syn.get("dual", []):
		lines.append("%s — %s" % [
			str(d.get("name", "Combo")),
			_dual_effect_text(str(d.get("effect_id", ""))),
		])
	if lines.is_empty():
		return "No active synergies"
	return "\n".join(lines)


func _mono_effect_text(effect_id: String) -> String:
	match effect_id:
		"pyro_dmg_10pct": return "+10% damage"
		"nature_heal_10pct": return "+10% healing"
		"necro_lifesteal_5pct": return "+5% lifesteal"
		"illusion_dodge_5pct": return "+5% dodge"
		"military_armor_10pct": return "+10% armor"
	return "bonus active"


func _dual_effect_text(effect_id: String) -> String:
	match effect_id:
		"wildfire_shield": return "heals burn foes"
		"death_magic": return "bonus vs low HP"
		"phantom_flame": return "burned foes dodge less"
		"scorched_earth": return "front row burn bonus"
		"decay": return "lifesteal on hit"
		"feywild": return "healing grants dodge"
		"fortify": return "stronger taunt"
		"grave_whispers": return "longer debuffs"
		"undying_ranks": return "front Necro +HP"
		"phantom_drill": return "back row armor"
	return "combo bonus active"


func _build_unit_display() -> void:
	_unit_panels.clear()
	_display_hp.clear()
	_clear_row(_enemy_back_row)
	_clear_row(_enemy_front_row)
	_clear_row(_player_front_row)
	_clear_row(_player_back_row)

	_place_team(1, _enemy_back_row, "back")
	_place_team(1, _enemy_front_row, "front")
	_place_team(0, _player_front_row, "front")
	_place_team(0, _player_back_row, "back")


func _clear_row(row: HBoxContainer) -> void:
	if row == null:
		return
	for host in row.get_children():
		for c in host.get_children():
			c.queue_free()


func _place_team(team: int, row_ui: HBoxContainer, row_name: String) -> void:
	var units: Array = _units_in_row(team, row_name)
	var hosts := row_ui.get_children()
	for i in SLOTS_PER_ROW:
		if i >= hosts.size():
			break
		var host: Control = hosts[i]
		var inst = units[i] if i < units.size() else null
		var panel: BattleUnitPanel
		if inst != null:
			var start_hp: int = int(_initial_hp.get(inst.uid, inst.current_hp))
			var start_max: int = int(_initial_max_hp.get(inst.uid, inst.max_hp))
			_display_hp[inst.uid] = start_hp
			_display_max_hp[inst.uid] = start_max
			panel = BattleUnitPanel.create(inst, start_hp, start_max)
			_unit_panels[inst.uid] = panel
			_init_unit_status(inst)
			panel.set_status_icons(_unit_status.get(inst.uid, {}))
		else:
			panel = BattleUnitPanel.create_empty()
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		host.add_child(panel)


func _units_in_row(team: int, row_name: String) -> Array:
	var all: Array = _battle_data.player_units if team == 0 else _battle_data.enemy_units
	var result: Array = []
	for u in all:
		var inst: FamiliarInstance = u
		if inst.row == row_name:
			result.append(inst)
	return result


func _init_unit_status(inst: FamiliarInstance) -> void:
	_unit_status[inst.uid] = {
		"burn": inst.burn_turns > 0,
		"taunt": inst.is_taunting(),
		"dodge": inst.dodge_bonus > 0.05,
		"blind": inst.blinded,
	}


func _set_unit_status_flag(uid: int, flag: String, value: bool) -> void:
	if uid < 0:
		return
	if not _unit_status.has(uid):
		_unit_status[uid] = {"burn": false, "taunt": false, "dodge": false, "blind": false}
	_unit_status[uid][flag] = value
	_sync_status_icons(uid)


func _sync_status_icons(uid: int) -> void:
	if uid < 0 or not _unit_panels.has(uid):
		return
	var panel: BattleUnitPanel = _unit_panels[uid]
	if _unit_status.has(uid):
		panel.set_status_icons(_unit_status[uid])


func _apply_status_from_event(e: Dictionary) -> void:
	var action: String = e.get("action", "")
	var actor_uid: int = int(e.get("actor_uid", -1))
	var target_uid: int = int(e.get("target_uid", -1))
	match action:
		"attack":
			if _has_burn_passive(actor_uid):
				_set_unit_status_flag(target_uid, "burn", true)
		"burn_tick":
			_set_unit_status_flag(actor_uid, "burn", true)
		"dodge":
			pass
		"death":
			_unit_status.erase(actor_uid)
			_sync_status_icons(actor_uid)
		"blinded_skip":
			_set_unit_status_flag(actor_uid, "blind", true)


func _on_action_pill_input(event: InputEvent) -> void:
	if not _is_tap(event) or _result_shown:
		return
	if _awaiting_start:
		_begin_auto_battle()
	elif _paused:
		_resume_auto_battle()


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _on_continue() -> void:
	if _result_shown:
		return
	if _awaiting_start:
		_begin_auto_battle()
	elif _paused:
		_resume_auto_battle()


func _begin_auto_battle() -> void:
	if _playing or _result_shown:
		return
	_awaiting_start = false
	_playing = true
	_paused = false
	_reset_display_hp()
	_event_index = 0
	_pause_btn.disabled = false
	_continue_btn.text = "Continue"
	_continue_btn.disabled = true
	_action_text.text = "Battle underway..."
	_run_auto_battle()


func _resume_auto_battle() -> void:
	if _result_shown or not _playing:
		return
	_paused = false
	_pause_btn.text = "⏸  Pause"
	_continue_btn.disabled = true
	_action_text.text = "Battle underway..."
	_run_auto_battle()


func _run_auto_battle() -> void:
	if _auto_running or _result_shown:
		return
	_auto_running = true
	var events: Array = _battle_data.get("events", [])
	if events.is_empty():
		_action_text.text = "No battle events — check your coven."
		_show_result()
		_auto_running = false
		return

	while _playing and not _paused and not _result_shown and _event_index < events.size():
		await _advance_one_event()

	if not _result_shown and _event_index >= events.size():
		_sync_all_panels(true)
		_show_result()
	_auto_running = false


func _advance_one_event() -> void:
	if _result_shown:
		return
	var events: Array = _battle_data.get("events", [])
	if _event_index >= events.size():
		return

	var e: Dictionary = events[_event_index]
	await _apply_event(e)
	_event_index += 1


func _toggle_pause() -> void:
	if _result_shown or not _playing or _awaiting_start:
		return
	if _paused:
		_resume_auto_battle()
		return
	_paused = true
	_pause_btn.text = "▶  Resume"
	_continue_btn.disabled = false
	_action_text.text = "Paused — tap Resume or Continue"


func _confirm_leave() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Leave battle?"
	dlg.dialog_text = "Progress on this fight will be lost."
	dlg.ok_button_text = "Leave"
	dlg.cancel_button_text = "Stay"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): get_tree().change_scene_to_file(RIFT))
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)


func _reset_display_hp() -> void:
	for uid in _unit_panels:
		var start: int = int(_initial_hp.get(uid, 0))
		var start_max: int = int(_initial_max_hp.get(uid, 1))
		_display_hp[uid] = start
		_display_max_hp[uid] = start_max
		var panel: BattleUnitPanel = _unit_panels[uid]
		if panel.unit == null:
			continue
		panel.unit.is_dead = false
		panel.set_hp(start, start_max, false)
		panel.modulate = Color.WHITE
		_init_unit_status(panel.unit)
		panel.set_status_icons(_unit_status.get(uid, {}))


func _apply_event(e: Dictionary) -> void:
	var action: String = e.get("action", "")
	var actor_uid: int = e.get("actor_uid", -1)
	var target_uid: int = e.get("target_uid", -1)
	var value: int = e.get("value", 0)

	if action == "round_start":
		_current_round = int(e.get("round", _current_round))
		_round_label.text = "Round %d" % _current_round

	_update_action_pill(e)
	_apply_status_from_event(e)

	match action:
		"attack":
			_flash_panel(actor_uid, "attack")
			if value > 0 and not _is_unit_fallen(target_uid):
				_damage_display(target_uid, value)
				_flash_panel(target_uid, "damage", value)
		"heal", "lifesteal":
			_heal_display(target_uid, value)
			_flash_panel(target_uid, "heal", value)
		"reflect", "burn_tick":
			_damage_display(target_uid if target_uid >= 0 else actor_uid, value)
			_flash_panel(target_uid if target_uid >= 0 else actor_uid, "damage", value)
		"death_burst", "death_weaken", "wildfire_burn":
			if target_uid >= 0:
				_damage_display(target_uid, value)
				_flash_panel(target_uid, "damage", value)
		"miss":
			_flash_panel(target_uid, "dodge")
		"dodge":
			_flash_panel(target_uid, "dodge")
		"death":
			_set_display_hp(actor_uid, 0, true)
			var panel: BattleUnitPanel = _unit_panels.get(actor_uid)
			if panel and panel.unit:
				panel.unit.is_dead = true
				panel.set_hp(0, panel.unit.max_hp, true)
				panel.set_status_icons({})
		"battle_end":
			_sync_all_panels(true)

	await get_tree().create_timer(_event_pause_sec()).timeout


func _update_action_pill(e: Dictionary) -> void:
	var action: String = e.get("action", "")
	var actor_uid: int = e.get("actor_uid", -1)
	var target_uid: int = e.get("target_uid", -1)
	var value: int = e.get("value", 0)
	var text := ""
	match action:
		"round_start":
			text = "— Round %d —" % e.get("round", 0)
		"attack":
			var actor_name := _brief_name(actor_uid)
			var target_name := _brief_name(target_uid)
			if _has_burn_passive(actor_uid):
				text = "🔥 %s burns %s" % [actor_name, target_name]
			else:
				text = "%s attacks %s for %d" % [actor_name, target_name, value]
		"lifesteal":
			text = "💚 %s drains %d HP" % [_brief_name(target_uid), value]
		"heal":
			text = "💚 %s heals for %d" % [_brief_name(target_uid), value]
		"dodge":
			text = "%s dodged!" % _brief_name(target_uid)
		"burn_tick":
			text = "🔥 %s takes %d burn damage" % [_brief_name(actor_uid), value]
		"reflect":
			text = "%s reflects %d damage" % [_brief_name(actor_uid), value]
		"death_burst":
			text = "💥 %s's death burst hits %s for %d" % [
				_brief_name(actor_uid), _brief_name(target_uid), value,
			]
		"death_weaken":
			text = "☠ %s weakens %s" % [_brief_name(actor_uid), _brief_name(target_uid)]
		"wildfire_burn":
			text = "🔥 Wildfire scorches %s" % _brief_name(target_uid)
		"miss":
			text = "%s's attack missed!" % _brief_name(actor_uid)
		"debuff_accuracy":
			text = "🌑 %s blinds %s" % [_brief_name(actor_uid), _brief_name(target_uid)]
		"confuse":
			text = "✨ %s confuses %s" % [_brief_name(actor_uid), _brief_name(target_uid)]
		"death":
			text = "%s was defeated" % _brief_name(actor_uid)
		"battle_end":
			text = "Battle over!"
		"skip_turn", "blinded_skip":
			text = "%s skips a turn" % _brief_name(actor_uid)
		_:
			if not action.is_empty():
				text = action.capitalize()
	if not text.is_empty():
		_action_text.text = text


func _has_burn_passive(uid: int) -> bool:
	var inst := _instance_for(uid)
	if inst == null:
		return false
	return "burn" in inst.data.passive_id


func _brief_name(uid: int) -> String:
	var inst := _instance_for(uid)
	if inst == null:
		return "?"
	return UITheme.familiar_brief_name(inst.data.display_name)


func _instance_for(uid: int) -> FamiliarInstance:
	for u in _battle_data.player_units + _battle_data.enemy_units:
		var inst: FamiliarInstance = u
		if inst.uid == uid:
			return inst
	return null


func _is_unit_fallen(uid: int) -> bool:
	if uid < 0 or not _display_hp.has(uid):
		return true
	return int(_display_hp[uid]) <= 0


func _flash_panel(uid: int, kind: String, amount: int = 0) -> void:
	if not _unit_panels.has(uid):
		return
	var panel: BattleUnitPanel = _unit_panels[uid]
	match kind:
		"attack":
			panel.flash_attack()
		"damage":
			panel.flash_damage(amount)
		"heal":
			panel.flash_heal(amount)
		"dodge":
			panel.flash_dodge()


func _damage_display(uid: int, amount: int) -> void:
	if uid < 0 or not _display_hp.has(uid):
		return
	var new_hp: int = maxi(0, int(_display_hp[uid]) - amount)
	_set_display_hp(uid, new_hp, true)


func _heal_display(uid: int, amount: int) -> void:
	if uid < 0 or not _display_hp.has(uid):
		return
	var max_hp := int(_display_max_hp.get(uid, 1))
	var new_hp: int = mini(max_hp, int(_display_hp[uid]) + amount)
	_set_display_hp(uid, new_hp, true)


func _set_display_hp(uid: int, hp: int, animate: bool) -> void:
	_display_hp[uid] = hp
	if _unit_panels.has(uid):
		var panel: BattleUnitPanel = _unit_panels[uid]
		var max_hp := int(_display_max_hp.get(uid, 1))
		panel.set_hp(hp, max_hp, animate)


func _sync_all_panels(animate: bool) -> void:
	for u in _battle_data.player_units + _battle_data.enemy_units:
		var inst: FamiliarInstance = u
		if _unit_panels.has(inst.uid):
			var panel: BattleUnitPanel = _unit_panels[inst.uid]
			panel.sync_from_instance(animate)
			_display_hp[inst.uid] = 0 if inst.is_dead else inst.current_hp


func _show_result() -> void:
	if _result_shown:
		return
	_result_shown = true
	_playing = false
	_continue_btn.disabled = true
	_pause_btn.disabled = true

	var winner: int = _battle_data.get("winner", -1)
	var won := winner == 0

	if won:
		var reward := int(GameState.pending_battle.get("dust_reward", 40))
		GameState.grant_dust(reward)
		GameState.record_battle_win()
		var mode: String = GameState.pending_battle.get("mode", "")
		if mode == "rift":
			GameState.record_trial_clear(GameState.pending_battle.get("trial_id", ""))
		var duals: Array = _battle_data.get("active_duals", {}).get(0, [])
		for d in duals:
			GameState.record_bound_page_win(d.get("key", ""))
		_result_title.text = "Victory!"
		_result_title.add_theme_color_override("font_color", UITheme.SUCCESS)
		_result_subtitle.text = "+%d Dust earned" % reward
		_action_text.text = "Victory!"
	else:
		_result_title.text = "Defeat"
		_result_title.add_theme_color_override("font_color", Color(0.92, 0.42, 0.38))
		_result_subtitle.text = "Adjust your coven and try again."
		_action_text.text = "Defeat"

	SaveManager.save_game()
	_populate_result_actions()
	_result_layer.visible = true
	call_deferred("_layout_result_card")


func _populate_result_actions() -> void:
	for c in _result_actions.get_children():
		c.queue_free()

	var trials_btn := Button.new()
	trials_btn.text = "Back to Trials"
	trials_btn.custom_minimum_size.y = 48
	UITheme.style_accent_button(trials_btn)
	trials_btn.pressed.connect(func(): get_tree().change_scene_to_file(RIFT))
	_result_actions.add_child(trials_btn)

	var menu_btn := Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size.y = 44
	_style_secondary_button(menu_btn)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	_result_actions.add_child(menu_btn)
