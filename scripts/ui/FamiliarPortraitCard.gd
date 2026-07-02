class_name FamiliarPortraitCard
extends PanelContainer

var familiar_data: FamiliarData
var is_locked: bool = false


static func create_owned(
	data: FamiliarData,
	school_key: String = "",
	level: int = 1,
) -> FamiliarPortraitCard:
	var card := FamiliarPortraitCard.new()
	card.familiar_data = data
	card.is_locked = false
	card._build_owned(school_key if not school_key.is_empty() else data.school, level)
	return card


static func create_locked(data: FamiliarData) -> FamiliarPortraitCard:
	var card := FamiliarPortraitCard.new()
	card.familiar_data = data
	card.is_locked = true
	card._build_locked()
	return card


func _build_owned(school: String, level: int = 1) -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = UITheme.rarity_color(familiar_data.rarity)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var art := _make_art_panel(school, false)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.0
	vbox.add_child(art)

	if level > 1:
		var badge := Label.new()
		badge.text = "Lv %d" % level
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		var badge_wrap := PanelContainer.new()
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Color(0.08, 0.08, 0.1, 0.82)
		bsb.set_corner_radius_all(6)
		bsb.content_margin_left = 5
		bsb.content_margin_right = 5
		bsb.content_margin_top = 2
		bsb.content_margin_bottom = 2
		badge_wrap.add_theme_stylebox_override("panel", bsb)
		badge_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge_wrap.add_child(badge)
		badge_wrap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge_wrap.position = Vector2(-4, 4)
		art.add_child(badge_wrap)

	var emoji := Label.new()
	emoji.text = UITheme.school_emoji(school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji.add_theme_font_size_override("font_size", 26)
	emoji.add_theme_color_override("font_color", UITheme.school_icon_color(school))
	art.add_child(emoji)

	var name_lbl := Label.new()
	name_lbl.text = UITheme.familiar_brief_name(familiar_data.display_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_lbl)


func _build_locked() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.14)
	sb.border_color = Color(0.32, 0.32, 0.36)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var art := _make_art_panel(familiar_data.school, true)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.0
	vbox.add_child(art)

	var lock := Label.new()
	lock.text = "🔒"
	lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock.add_theme_font_size_override("font_size", 20)
	lock.modulate = Color(0.55, 0.55, 0.58)
	art.add_child(lock)

	var name_lbl := Label.new()
	name_lbl.text = "???"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(name_lbl)


func _make_art_panel(school: String, locked: bool) -> PanelContainer:
	var art := PanelContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_sb := StyleBoxFlat.new()
	if locked:
		art_sb.bg_color = Color(0.10, 0.10, 0.12)
		art_sb.border_color = Color(0.28, 0.28, 0.32)
		art_sb.set_border_width_all(1)
	else:
		art_sb.bg_color = UITheme.school_slot_bg(school)
	art_sb.set_corner_radius_all(8)
	art.add_theme_stylebox_override("panel", art_sb)
	return art


func add_tap_handler(on_tap: Callable) -> void:
	var hit := ColorRect.new()
	hit.color = Color(0, 0, 0, 0)
	hit.mouse_filter = Control.MOUSE_FILTER_STOP
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			on_tap.call()
	)
	add_child(hit)


static func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false
