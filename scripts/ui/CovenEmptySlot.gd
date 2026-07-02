class_name CovenEmptySlot
extends PanelContainer

var drop_highlight: bool = false:
	set(value):
		drop_highlight = value
		_apply_style()


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build()
	_apply_style()


func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var art := PanelContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.name = "Art"
	vbox.add_child(art)

	var plus := Label.new()
	plus.text = "+"
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plus.set_anchors_preset(Control.PRESET_FULL_RECT)
	plus.add_theme_font_size_override("font_size", 20)
	plus.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(plus)

	var hint := Label.new()
	hint.text = "Empty"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hint)


func _apply_style() -> void:
	var sb := StyleBoxFlat.new()
	if drop_highlight:
		sb.bg_color = Color(0.14, 0.16, 0.22)
		sb.border_color = UITheme.BLUE
		sb.set_border_width_all(2)
	else:
		sb.bg_color = Color(0.12, 0.12, 0.14)
		sb.border_color = Color(0.32, 0.32, 0.36)
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var art := find_child("Art", true, false) as PanelContainer
	if art == null:
		return
	var art_sb := StyleBoxFlat.new()
	if drop_highlight:
		art_sb.bg_color = Color(0.12, 0.14, 0.20)
		art_sb.border_color = UITheme.BLUE
		art_sb.set_border_width_all(1)
	else:
		art_sb.bg_color = Color(0.10, 0.10, 0.12)
		art_sb.border_color = Color(0.28, 0.28, 0.32)
		art_sb.set_border_width_all(1)
	art_sb.set_corner_radius_all(6)
	art.add_theme_stylebox_override("panel", art_sb)
