extends Control

const SLOTS := 6
const FRONT_SLOTS := 3
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12
const GAP := 8
const GRID_COLUMNS := 4
const CARD_ASPECT := 1.28

const FILTER_SCHOOLS := ["all", "pyromancy", "nature", "necromancy", "illusion", "military"]
const FILTER_LABELS := {
	"all": "All",
	"pyromancy": "Pyro",
	"nature": "Nature",
	"necromancy": "Necro",
	"illusion": "Illus.",
	"military": "Mil.",
}

var _selected: Array = []
var _front_count: int = FRONT_SLOTS
var _school_filter: String = "all"
var _filter_buttons: Dictionary = {}
var _synergy_list: VBoxContainer
var _synergy_scroll: MobileScrollContainer
var _synergy_card: PanelContainer
var _collection_grid: GridContainer
var _front_slots: Array = []
var _back_slots: Array = []
var _save_btn: Button
var _list_scroll: MobileScrollContainer
var _filter_scroll: MobileScrollContainer
var _root: VBoxContainer
var _slot_h: float = 64.0

var _drag_active: bool = false
var _drag_id: String = ""
var _drag_from_slot: int = -1
var _drag_ghost: PanelContainer
var _drag_layer: CanvasLayer
var _info_backdrop: ColorRect
var _info_panel: PanelContainer
var _highlight_slot_idx: int = -2
var _pool_drop_highlight: bool = false
var _list_scroll_was_enabled: bool = true
var _touch_dragging: bool = false
var _drag_started_ms: int = 0


func _ready() -> void:
	_sync_selected_from_game()
	_build_ui()
	_build_drag_overlay()
	_refresh_all()
	GameState.collection_changed.connect(_on_collection_changed)
	get_viewport().size_changed.connect(_layout_viewport)
	call_deferred("_layout_viewport")


func _exit_tree() -> void:
	if GameState.collection_changed.is_connected(_on_collection_changed):
		GameState.collection_changed.disconnect(_on_collection_changed)


func _on_collection_changed() -> void:
	if is_inside_tree():
		_refresh_collection()


func _sync_selected_from_game() -> void:
	_selected.clear()
	for i in SLOTS:
		_selected.append(null)
	var coven: Array = GameState.active_coven
	for i in mini(coven.size(), SLOTS):
		var entry = coven[i]
		if entry is Dictionary and str(entry.get("id", "")) != "":
			_selected[i] = entry.duplicate()
	_front_count = _infer_front_count()


func _build_drag_overlay() -> void:
	_drag_layer = CanvasLayer.new()
	_drag_layer.layer = 50
	add_child(_drag_layer)

	_drag_ghost = PanelContainer.new()
	_drag_ghost.visible = false
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 10
	_drag_layer.add_child(_drag_ghost)

	_info_backdrop = ColorRect.new()
	_info_backdrop.visible = false
	_info_backdrop.color = Color(0, 0, 0, 0.55)
	_info_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_info()
		elif event is InputEventScreenTouch and event.pressed:
			_hide_info()
	)
	_drag_layer.add_child(_info_backdrop)

	_info_panel = PanelContainer.new()
	_info_panel.visible = false
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.z_index = 200
	UITheme.apply_card_style(_info_panel, 14)
	_drag_layer.add_child(_info_panel)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = UITheme.MOBILE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.clip_contents = true
	margin.add_theme_constant_override("margin_left", MARGIN_X)
	margin.add_theme_constant_override("margin_right", MARGIN_X)
	margin.add_theme_constant_override("margin_top", MARGIN_Y)
	margin.add_theme_constant_override("margin_bottom", MARGIN_Y)
	add_child(margin)

	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_theme_constant_override("separation", GAP)
	margin.add_child(_root)

	_root.add_child(_build_header())
	_root.add_child(_build_formation_card())
	_root.add_child(_build_synergy_card())

	_filter_scroll = MobileScrollContainer.create(true, false)
	_filter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_filter_scroll.clip_contents = true
	_root.add_child(_filter_scroll)
	_filter_scroll.add_child(_build_filter_row())

	_list_scroll = MobileScrollContainer.create(false, true)
	_list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_scroll.size_flags_stretch_ratio = 1.0
	_list_scroll.clip_contents = true
	_root.add_child(_list_scroll)

	_collection_grid = GridContainer.new()
	_collection_grid.columns = GRID_COLUMNS
	_collection_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_collection_grid.add_theme_constant_override("h_separation", 8)
	_collection_grid.add_theme_constant_override("v_separation", 8)
	_list_scroll.add_child(_collection_grid)


func _process(_delta: float) -> void:
	if not _drag_active:
		return

	var pos: Vector2 = get_viewport().get_mouse_position()
	_move_drag_ghost(pos)
	_update_drop_highlight(pos)

	if Time.get_ticks_msec() - _drag_started_ms < 80:
		return

	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag(pos)


func _unhandled_input(event: InputEvent) -> void:
	if not _drag_active:
		return
	if event is InputEventScreenDrag:
		_touch_dragging = true
		var drag_pos: Vector2 = event.position
		_move_drag_ghost(drag_pos)
		_update_drop_highlight(drag_pos)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_drag(event.position)
		get_viewport().set_input_as_handled()


func _layout_viewport() -> void:
	if _root == null or _list_scroll == null:
		return

	var vp := get_viewport_rect().size
	var inner_w := vp.x - float(MARGIN_X * 2)
	var inner_h := vp.y - float(MARGIN_Y * 2)

	_slot_h = clampf(floorf((inner_h - 360.0) * 0.12 + 58.0), 56.0, 68.0)

	var header_h := 34.0
	var filter_h := 28.0
	var synergy_h := 72.0
	var form_h := 16.0 + 22.0 + _slot_h * 2.0 + GAP
	var top_h := header_h + GAP + form_h + GAP + synergy_h + GAP + filter_h + GAP
	var list_h := maxf(100.0, inner_h - top_h)

	_list_scroll.custom_minimum_size = Vector2(0, list_h)

	if _synergy_card:
		_synergy_card.custom_minimum_size = Vector2(0, synergy_h)
		_synergy_card.clip_contents = true

	for host in _front_slots + _back_slots:
		if host is Control:
			host.custom_minimum_size = Vector2(0, _slot_h)

	_collection_grid.custom_minimum_size.x = inner_w
	var gap := 8.0
	var col_w := floorf((inner_w - gap * float(GRID_COLUMNS - 1)) / float(GRID_COLUMNS))
	var card_h := col_w * CARD_ASPECT
	for child in _collection_grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(col_w, card_h)

	_filter_scroll.custom_minimum_size = Vector2(inner_w, filter_h)

	if _info_panel:
		var panel_w: float = maxf(_info_panel.size.x, _info_panel.custom_minimum_size.x)
		var panel_h: float = maxf(_info_panel.size.y, _info_panel.custom_minimum_size.y)
		_info_panel.position = Vector2(
			floorf((vp.x - panel_w) * 0.5),
			floorf(vp.y - panel_h - 24.0)
		)


func _build_header() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	bar.custom_minimum_size.y = 34

	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(32, 32)
	UITheme.style_icon_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	bar.add_child(back)

	var title := Label.new()
	title.text = "Coven"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.clip_text = true
	bar.add_child(title)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.custom_minimum_size = Vector2(64, 32)
	UITheme.style_accent_button(_save_btn)
	_save_btn.pressed.connect(_save_active)
	bar.add_child(_save_btn)
	return bar


func _build_formation_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.clip_contents = true
	UITheme.apply_compact_card(card, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	vbox.add_child(_make_row_label("Front row"))
	_front_slots = _make_slot_row(vbox)

	vbox.add_child(_make_row_label("Back row"))
	_back_slots = _make_slot_row(vbox)
	return card


func _make_row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size.y = 14
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	return lbl


func _make_slot_row(parent: VBoxContainer) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)

	var slots: Array = []
	for i in 3:
		var host := Control.new()
		host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.size_flags_stretch_ratio = 1.0
		host.custom_minimum_size = Vector2(0, _slot_h)
		host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.clip_contents = true
		row.add_child(host)
		slots.append(host)
	return slots


func _build_synergy_card() -> PanelContainer:
	_synergy_card = PanelContainer.new()
	_synergy_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_synergy_card.clip_contents = true
	UITheme.apply_synergy_panel(_synergy_card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_synergy_card.add_child(vbox)

	var heading := Label.new()
	heading.text = "Active synergies"
	heading.custom_minimum_size.y = 16
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", UITheme.BLUE)
	vbox.add_child(heading)

	_synergy_scroll = MobileScrollContainer.create(false, true)
	_synergy_scroll.custom_minimum_size = Vector2(0, 56)
	vbox.add_child(_synergy_scroll)

	_synergy_list = VBoxContainer.new()
	_synergy_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_synergy_list.add_theme_constant_override("separation", 2)
	_synergy_scroll.add_child(_synergy_list)
	return _synergy_card


func _build_filter_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for school in FILTER_SCHOOLS:
		var btn := Button.new()
		if school == "all":
			btn.text = FILTER_LABELS[school]
		else:
			btn.text = "%s %s" % [UITheme.school_emoji(school), FILTER_LABELS[school]]
		btn.custom_minimum_size.y = 28
		btn.add_theme_font_size_override("font_size", 11)
		UITheme.style_filter_pill(btn, school == _school_filter)
		var s: String = school
		btn.pressed.connect(func(): _set_filter(s))
		row.add_child(btn)
		_filter_buttons[school] = btn
	return row


func _slot_index_for_ui(front_row: bool, ui_index: int) -> int:
	if front_row:
		return ui_index if ui_index < FRONT_SLOTS else -1
	return FRONT_SLOTS + ui_index if ui_index < SLOTS - FRONT_SLOTS else -1


func _ui_visible_for_slot(slot_idx: int) -> Dictionary:
	if slot_idx < FRONT_SLOTS:
		return {"front": true, "ui": slot_idx}
	if slot_idx < SLOTS:
		return {"front": false, "ui": slot_idx - FRONT_SLOTS}
	return {}


func _set_filter(school: String) -> void:
	_school_filter = school
	for key in _filter_buttons:
		UITheme.style_filter_pill(_filter_buttons[key], key == school)
	_refresh_collection()


func _refresh_all() -> void:
	_refresh_slots()
	_refresh_synergies()
	_refresh_collection()
	call_deferred("_layout_viewport")


func _refresh_slots() -> void:
	_clear_slot_row(_front_slots)
	_clear_slot_row(_back_slots)

	for i in SLOTS:
		var mapping: Dictionary = _ui_visible_for_slot(i)
		if mapping.is_empty():
			continue
		var hosts: Array = _front_slots if mapping.get("front", false) else _back_slots
		var ui_idx: int = int(mapping.get("ui", 0))
		if ui_idx >= hosts.size():
			continue
		var host: Control = hosts[ui_idx]
		var entry = _selected[i]
		if entry != null and entry.get("id", "") != "":
			var data: FamiliarData = DataLoader.get_familiar(entry.get("id", ""))
			if data:
				entry["row"] = "front" if i < _front_count else "back"
				_mount_slot(host, CovenFilledSlot.create(data, i), i)
		else:
			_mount_slot(host, CovenEmptySlot.new(), i)


func _mount_slot(host: Control, slot_node: Control, slot_idx: int) -> void:
	for c in host.get_children():
		c.queue_free()
	slot_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	slot_node.offset_right = 0.0
	slot_node.offset_bottom = 0.0
	if slot_node is CovenFilledSlot:
		var filled := slot_node as CovenFilledSlot
		filled.familiar_tapped.connect(_on_familiar_tapped)
		filled.familiar_drag_started.connect(_on_slot_drag_started)
	elif slot_node is CovenEmptySlot:
		pass
	host.add_child(slot_node)


func _clear_slot_row(hosts: Array) -> void:
	for host in hosts:
		for c in host.get_children():
			c.queue_free()


func _refresh_synergies() -> void:
	for c in _synergy_list.get_children():
		c.queue_free()

	var squad: Array = _valid_squad()
	for line in SynergyResolver.get_synergy_display_lines(squad):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.custom_minimum_size.y = 16

		var bullet := Label.new()
		bullet.text = "•"
		bullet.custom_minimum_size.x = 10
		bullet.add_theme_font_size_override("font_size", 12)
		bullet.add_theme_color_override("font_color", line.get("color", UITheme.TEXT_MUTED))
		row.add_child(bullet)

		var lbl := Label.new()
		lbl.text = line.get("text", "")
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.clip_text = true
		lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if line.get("active", false):
			lbl.add_theme_color_override("font_color", Color.WHITE)
		else:
			lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		row.add_child(lbl)

		_synergy_list.add_child(row)


func _refresh_collection() -> void:
	for c in _collection_grid.get_children():
		c.queue_free()

	for entry in GameState.get_owned_list():
		var data: FamiliarData = entry.data
		if _is_familiar_in_squad(data.id):
			continue
		if _school_filter != "all" and data.school != _school_filter:
			continue
		var row := CovenFamiliarRow.create(data)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.familiar_tapped.connect(_on_familiar_tapped)
		row.familiar_drag_started.connect(_on_collection_drag_started)
		row.press_began.connect(_on_list_press_began)
		row.press_ended.connect(_on_list_press_ended)
		_collection_grid.add_child(row)

	call_deferred("_layout_viewport")


func _on_list_press_began() -> void:
	if not _drag_active:
		_list_scroll.set_swipe_enabled(false)


func _on_list_press_ended() -> void:
	if not _drag_active:
		_list_scroll.set_swipe_enabled(true)


func _on_familiar_tapped(familiar_id: String) -> void:
	var data: FamiliarData = DataLoader.get_familiar(familiar_id)
	if data == null:
		return
	_show_info(data)


func _show_info(data: FamiliarData) -> void:
	_rebuild_info_panel(data)
	_info_panel.visible = true
	_info_backdrop.visible = true
	call_deferred("_layout_viewport")


func _hide_info() -> void:
	_info_panel.visible = false
	_info_backdrop.visible = false


func _rebuild_info_panel(data: FamiliarData) -> void:
	for c in _info_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_info_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var emoji_box := PanelContainer.new()
	emoji_box.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.school_slot_bg(data.school)
	sb.set_corner_radius_all(12)
	emoji_box.add_theme_stylebox_override("panel", sb)
	header.add_child(emoji_box)

	var emoji := Label.new()
	emoji.text = UITheme.school_emoji(data.school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	emoji.add_theme_font_size_override("font_size", 24)
	emoji_box.add_child(emoji)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)

	var name_lbl := Label.new()
	name_lbl.text = data.display_name
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_col.add_child(name_lbl)

	var sub := Label.new()
	sub.text = "%s · %s · %s" % [
		data.rarity.capitalize(),
		UITheme.school_label(data.school),
		data.role.capitalize(),
	]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	title_col.add_child(sub)

	var stats := Label.new()
	stats.text = "SPD %d   HP %d   ATK %d" % [data.speed, data.hp, data.atk]
	stats.add_theme_font_size_override("font_size", 13)
	stats.add_theme_color_override("font_color", UITheme.TEXT)
	vbox.add_child(stats)

	var passive := Label.new()
	passive.text = data.passive_text
	passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	passive.custom_minimum_size.x = 320
	passive.add_theme_font_size_override("font_size", 12)
	passive.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(passive)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.y = 36
	UITheme.style_accent_button(close_btn)
	close_btn.pressed.connect(_hide_info)
	vbox.add_child(close_btn)

	call_deferred("_fit_info_panel")


func _fit_info_panel() -> void:
	if _info_panel:
		_info_panel.custom_minimum_size = _info_panel.get_combined_minimum_size()


func _on_collection_drag_started(familiar_id: String) -> void:
	_begin_drag(familiar_id, -1)


func _on_slot_drag_started(familiar_id: String, slot_index: int) -> void:
	_begin_drag(familiar_id, slot_index)


func _begin_drag(familiar_id: String, from_slot: int) -> void:
	var data: FamiliarData = DataLoader.get_familiar(familiar_id)
	if data == null:
		return
	_cancel_all_gestures()
	_hide_info()
	_drag_active = true
	_drag_id = familiar_id
	_drag_from_slot = from_slot
	_build_drag_ghost(data)
	_drag_ghost.visible = true
	_move_drag_ghost(get_viewport().get_mouse_position())
	_list_scroll_was_enabled = _list_scroll.is_swipe_active()
	_list_scroll.set_swipe_enabled(false)
	_touch_dragging = false
	_drag_started_ms = Time.get_ticks_msec()
	set_process(true)


func _build_drag_ghost(data: FamiliarData) -> void:
	for c in _drag_ghost.get_children():
		c.queue_free()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.school_slot_bg(data.school)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_drag_ghost.add_theme_stylebox_override("panel", sb)
	_drag_ghost.custom_minimum_size = Vector2(88, 88)

	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_drag_ghost.add_child(col)

	var emoji := Label.new()
	emoji.text = UITheme.school_emoji(data.school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.add_theme_font_size_override("font_size", 28)
	col.add_child(emoji)

	var name_lbl := Label.new()
	name_lbl.text = UITheme.familiar_brief_name(data.display_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 10)
	col.add_child(name_lbl)


func _move_drag_ghost(global_pos: Vector2) -> void:
	_drag_ghost.global_position = global_pos - Vector2(44, 44)


func _update_drop_highlight(global_pos: Vector2) -> void:
	var target := _slot_at_global_pos(global_pos)
	var slot_idx: int = int(target.get("slot", -1)) if not target.is_empty() else -1
	var over_pool: bool = _is_over_pool(global_pos)

	if slot_idx == _highlight_slot_idx and over_pool == _pool_drop_highlight:
		return

	_clear_drop_highlights()
	_highlight_slot_idx = slot_idx
	_pool_drop_highlight = over_pool

	if slot_idx >= 0:
		var hosts: Array = _front_slots if target.get("front", false) else _back_slots
		var ui_idx: int = int(target.get("ui", 0))
		if ui_idx >= 0 and ui_idx < hosts.size():
			var host: Control = hosts[ui_idx]
			for c in host.get_children():
				if c is CovenEmptySlot:
					(c as CovenEmptySlot).drop_highlight = true
				elif c is CovenFilledSlot:
					(c as CovenFilledSlot).modulate = Color(0.85, 0.92, 1.0)

	if over_pool and _drag_from_slot >= 0:
		_list_scroll.modulate = Color(0.85, 0.92, 1.0)


func _clear_drop_highlights() -> void:
	_highlight_slot_idx = -2
	_pool_drop_highlight = false
	_list_scroll.modulate = Color.WHITE
	for host in _front_slots + _back_slots:
		for c in host.get_children():
			if c is CovenEmptySlot:
				(c as CovenEmptySlot).drop_highlight = false
			elif c is CovenFilledSlot:
				(c as CovenFilledSlot).modulate = Color.WHITE


func _is_over_pool(global_pos: Vector2) -> bool:
	if _list_scroll.get_global_rect().has_point(global_pos):
		return true
	if _collection_grid.get_global_rect().has_point(global_pos):
		return true
	return false


func _is_familiar_in_squad(familiar_id: String) -> bool:
	for i in SLOTS:
		if i >= _selected.size():
			break
		var entry = _selected[i]
		if entry != null and str(entry.get("id", "")) == familiar_id:
			return true
	return false


func _return_to_bench(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= SLOTS:
		return
	_selected[slot_idx] = null
	_refresh_all()


func _slot_at_global_pos(global_pos: Vector2) -> Dictionary:
	# Ignore formation hits while returning a familiar to the bench.
	if _drag_from_slot >= 0 and _is_over_pool(global_pos):
		return {}
	for slot_idx in SLOTS:
		var mapping: Dictionary = _ui_visible_for_slot(slot_idx)
		if mapping.is_empty():
			continue
		var hosts: Array = _front_slots if mapping.get("front", false) else _back_slots
		var ui_idx: int = int(mapping.get("ui", 0))
		if ui_idx < 0 or ui_idx >= hosts.size():
			continue
		var host: Control = hosts[ui_idx]
		for child in host.get_children():
			if child is Control and (child as Control).get_global_rect().has_point(global_pos):
				return {"front": mapping.get("front", false), "ui": ui_idx, "slot": slot_idx}
		if host.get_global_rect().has_point(global_pos):
			return {"front": mapping.get("front", false), "ui": ui_idx, "slot": slot_idx}
	return {}


func _finish_drag(global_pos: Vector2) -> void:
	if not _drag_active:
		return

	# Pool drop takes priority when dragging out of formation.
	if _drag_from_slot >= 0 and _is_over_pool(global_pos):
		_return_to_bench(_drag_from_slot)
	else:
		var target: Dictionary = _slot_at_global_pos(global_pos)
		if not target.is_empty():
			_apply_drop(int(target.get("slot", -1)))

	_cancel_drag()


func _cancel_drag() -> void:
	_drag_active = false
	_drag_id = ""
	_drag_from_slot = -1
	_touch_dragging = false
	_drag_ghost.visible = false
	_clear_drop_highlights()
	set_process(false)
	if _list_scroll_was_enabled:
		_list_scroll.set_swipe_enabled(true)


func _apply_drop(target_slot: int) -> void:
	if target_slot < 0 or _drag_id.is_empty():
		return

	var target_row := "front" if target_slot < _front_count else "back"
	var target_entry = _selected[target_slot]

	if _drag_from_slot >= 0:
		if _drag_from_slot == target_slot:
			return
		var source_entry = _selected[_drag_from_slot]
		_selected[target_slot] = source_entry.duplicate() if source_entry else null
		_selected[_drag_from_slot] = target_entry.duplicate() if target_entry else null
		if _selected[target_slot] != null:
			_selected[target_slot]["row"] = target_row
		if _selected[_drag_from_slot] != null:
			var from_row := "front" if _drag_from_slot < _front_count else "back"
			_selected[_drag_from_slot]["row"] = from_row
	else:
		_remove_id_from_squad(_drag_id)
		if target_entry != null and target_entry.get("id", "") != "":
			var displaced_id: String = target_entry.get("id", "")
			_selected[target_slot] = {"id": _drag_id, "row": target_row}
			_place_in_first_empty(displaced_id)
		else:
			_selected[target_slot] = {"id": _drag_id, "row": target_row}

	_refresh_all()


func _remove_id_from_squad(familiar_id: String) -> void:
	for i in SLOTS:
		if _selected[i] != null and _selected[i].get("id", "") == familiar_id:
			_selected[i] = null


func _place_in_first_empty(familiar_id: String) -> void:
	for i in SLOTS:
		if _selected[i] == null or _selected[i].get("id", "") == "":
			var row := "front" if i < _front_count else "back"
			_selected[i] = {"id": familiar_id, "row": row}
			return


func _cancel_all_gestures() -> void:
	for child in _collection_grid.get_children():
		if child is CovenFamiliarRow:
			(child as CovenFamiliarRow).cancel_gesture()
	for host in _front_slots + _back_slots:
		for c in host.get_children():
			if c is CovenFilledSlot:
				(c as CovenFilledSlot).cancel_gesture()


func _save_active() -> void:
	var squad: Array = _valid_squad()
	if squad.size() < SLOTS:
		_save_btn.text = "Need 6"
		await get_tree().create_timer(1.0).timeout
		_save_btn.text = "Save"
		return
	GameState.set_active_coven(squad)
	GameState.set_defense_coven(squad)
	SaveManager.save_game()
	_save_btn.text = "Saved!"
	await get_tree().create_timer(0.8).timeout
	_save_btn.text = "Save"


func _valid_squad() -> Array:
	var squad: Array = []
	for i in SLOTS:
		if i < _selected.size():
			var entry = _selected[i]
			if entry != null and str(entry.get("id", "")) != "":
				squad.append(entry.duplicate())
	return squad


func _infer_front_count() -> int:
	return FRONT_SLOTS
