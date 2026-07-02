extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 24
const MARGIN_Y := 32

var _name_field: LineEdit
var _error_label: Label
var _continue_btn: Button


func _ready() -> void:
	if not GameState.needs_profile_setup():
		get_tree().change_scene_to_file(MAIN_MENU)
		return
	_build_ui()


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
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_top.size_flags_stretch_ratio = 1.0
	root.add_child(spacer_top)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 16)
	root.add_child(card)

	var card_body := MarginContainer.new()
	card_body.add_theme_constant_override("margin_left", 20)
	card_body.add_theme_constant_override("margin_right", 20)
	card_body.add_theme_constant_override("margin_top", 24)
	card_body.add_theme_constant_override("margin_bottom", 24)
	card.add_child(card_body)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card_body.add_child(vbox)

	var title := Label.new()
	title.text = "Choose your name"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "This stays on your device. Connect Google Play or Apple later to back up progress."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(subtitle)

	_name_field = LineEdit.new()
	_name_field.placeholder_text = "Apprentice name"
	_name_field.max_length = GameState.DISPLAY_NAME_MAX
	_name_field.custom_minimum_size.y = 48
	_name_field.clear_button_enabled = true
	_name_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style_name_field(_name_field)
	_name_field.text_submitted.connect(func(_text: String) -> void: _on_continue())
	vbox.add_child(_name_field)

	_error_label = Label.new()
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error_label.add_theme_font_size_override("font_size", 12)
	_error_label.add_theme_color_override("font_color", UITheme.SCHOOL_COLORS.pyromancy)
	_error_label.visible = false
	vbox.add_child(_error_label)

	_continue_btn = Button.new()
	_continue_btn.text = "Begin"
	_continue_btn.custom_minimum_size.y = 48
	UITheme.style_accent_button(_continue_btn)
	_continue_btn.pressed.connect(_on_continue)
	vbox.add_child(_continue_btn)

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer_bottom.size_flags_stretch_ratio = 1.2
	root.add_child(spacer_bottom)

	call_deferred("_focus_name_field")


func _style_name_field(field: LineEdit) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.10)
	sb.border_color = UITheme.CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	field.add_theme_stylebox_override("normal", sb)
	field.add_theme_stylebox_override("focus", sb)
	field.add_theme_color_override("font_color", Color.WHITE)
	field.add_theme_color_override("font_placeholder_color", UITheme.TEXT_DIM)


func _focus_name_field() -> void:
	_name_field.grab_focus()


func _on_continue() -> void:
	_clear_error()
	var result: Dictionary = GameState.setup_profile(_name_field.text)
	if not result.get("ok", false):
		_show_error(str(result.get("message", "Invalid name.")))
		return
	get_tree().change_scene_to_file(MAIN_MENU)


func _show_error(message: String) -> void:
	_error_label.text = message
	_error_label.visible = true


func _clear_error() -> void:
	_error_label.text = ""
	_error_label.visible = false
