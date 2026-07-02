class_name BattleUnitPanel
extends PanelContainer

var unit: FamiliarInstance
var display_hp: int = 0

var _art: PanelContainer
var _emoji: Label
var _hp_bar: HPBar
var _status_row: HBoxContainer
var _fallen_overlay: Label
var _flash: ColorRect


static func create(inst: FamiliarInstance, start_hp: int, start_max_hp: int = -1) -> BattleUnitPanel:
	var panel := BattleUnitPanel.new()
	panel.unit = inst
	panel.display_hp = start_hp
	panel._build()
	var max_hp := start_max_hp if start_max_hp > 0 else inst.max_hp
	panel.set_hp(start_hp, max_hp, false)
	return panel


static func create_empty() -> BattleUnitPanel:
	var panel := BattleUnitPanel.new()
	panel.unit = null
	panel._build_empty()
	return panel


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = UITheme.rarity_color(unit.data.rarity)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_art = PanelContainer.new()
	_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_art.size_flags_stretch_ratio = 1.0
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = UITheme.school_slot_bg(unit.data.school)
	art_sb.set_corner_radius_all(8)
	_art.add_theme_stylebox_override("panel", art_sb)
	vbox.add_child(_art)

	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 2)
	_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_status_row)

	_emoji = Label.new()
	_emoji.text = UITheme.school_emoji(unit.data.school)
	_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	_emoji.add_theme_font_size_override("font_size", 22)
	_emoji.add_theme_color_override("font_color", UITheme.school_icon_color(unit.data.school))
	_emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_emoji)
	_emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_status_row.offset_top = 2
	_status_row.offset_left = 2
	_status_row.offset_right = -2
	_status_row.offset_bottom = 14

	_hp_bar = HPBar.new()
	_hp_bar.custom_minimum_size = Vector2(0, 5)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_hp_bar)

	_fallen_overlay = Label.new()
	_fallen_overlay.text = "💀"
	_fallen_overlay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fallen_overlay.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fallen_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fallen_overlay.add_theme_font_size_override("font_size", 18)
	_fallen_overlay.modulate = Color(0.45, 0.45, 0.48, 0.9)
	_fallen_overlay.visible = false
	_fallen_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fallen_overlay)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)


func _build_empty() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.12)
	sb.border_color = Color(0.22, 0.22, 0.26)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	var art := PanelContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.0
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = Color(0.08, 0.08, 0.10)
	art_sb.set_corner_radius_all(8)
	art.add_theme_stylebox_override("panel", art_sb)
	vbox.add_child(art)

	var spacer := Label.new()
	spacer.text = ""
	spacer.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(spacer)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(0, 5)
	bar_bg.color = Color(0.14, 0.14, 0.16)
	vbox.add_child(bar_bg)

	modulate = Color(0.55, 0.55, 0.58, 0.7)


func set_hp(current: int, maximum: int, animate: bool) -> void:
	if unit == null:
		return
	display_hp = current
	if _hp_bar != null:
		_hp_bar.set_values(current, maximum, animate)
	var fallen := current <= 0
	if _fallen_overlay:
		_fallen_overlay.visible = fallen
	if _art:
		_art.modulate = Color(0.45, 0.45, 0.48, 0.85) if fallen else Color.WHITE
	if _emoji:
		_emoji.visible = not fallen
	modulate = Color(0.55, 0.55, 0.58, 0.85) if fallen else Color.WHITE


func set_status_icons(flags: Dictionary) -> void:
	_update_status_icons(flags)


func _update_status_icons(flags: Dictionary = {}) -> void:
	if _status_row == null or unit == null:
		return
	for c in _status_row.get_children():
		c.queue_free()
	if display_hp <= 0:
		return
	var use_flags := flags
	if use_flags.is_empty():
		use_flags = {
			"burn": unit.burn_turns > 0,
			"taunt": unit.is_taunting(),
			"dodge": unit.dodge_bonus > 0.05,
			"blind": unit.blinded,
		}
	if use_flags.get("burn", false):
		_add_status_icon("🔥")
	if use_flags.get("taunt", false):
		_add_status_icon("🛡️")
	if use_flags.get("dodge", false):
		_add_status_icon("💨")
	if use_flags.get("blind", false):
		_add_status_icon("🌑")


func _add_status_icon(emoji: String) -> void:
	var lbl := Label.new()
	lbl.text = emoji
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_row.add_child(lbl)


func sync_from_instance(animate: bool = false) -> void:
	if unit == null:
		return
	var hp := 0 if unit.is_dead else unit.current_hp
	set_hp(hp, unit.max_hp, animate)
	_update_status_icons()


func flash_attack() -> void:
	if _art == null:
		return
	var tween := create_tween()
	tween.tween_property(_art, "modulate", Color(1.35, 1.35, 1.35), 0.08)
	tween.tween_property(_art, "modulate", Color.WHITE, 0.12)


func flash_damage(_amount: int) -> void:
	var tween := create_tween()
	tween.tween_property(_flash, "color", Color(0.9, 0.2, 0.2, 0.45), 0.05)
	tween.tween_property(_flash, "color:a", 0.0, 0.2)


func flash_heal(_amount: int) -> void:
	var tween := create_tween()
	tween.tween_property(_flash, "color", Color(0.2, 0.85, 0.45, 0.45), 0.05)
	tween.tween_property(_flash, "color:a", 0.0, 0.2)


func flash_dodge() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.7, 0.95, 1.2), 0.1)
	tween.tween_property(self, "modulate", Color.WHITE if display_hp > 0 else modulate, 0.15)
