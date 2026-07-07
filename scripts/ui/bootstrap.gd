extends Control

const NAME_PICKER := "res://scenes/name_picker/name_picker.tscn"
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SETTINGS := "res://scenes/settings/settings.tscn"
const AUTO_RETRY_COUNT := 2
const AUTO_RETRY_DELAY_SEC := 0.6

var _status_label: Label
var _retry_btn: Button
var _settings_btn: Button
var _auto_retries_left := 0


func _ready() -> void:
	_build_ui()
	_auto_retries_left = AUTO_RETRY_COUNT
	call_deferred("_start_connect")


func _start_connect() -> void:
	await get_tree().process_frame
	_try_connect()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = UITheme.MOBILE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 48)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Familiar's Call"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	_status_label = Label.new()
	_status_label.text = "Connecting…"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(_status_label)

	_retry_btn = Button.new()
	_retry_btn.text = "Retry"
	_retry_btn.visible = false
	_retry_btn.custom_minimum_size.y = 48
	_style_retry_button(_retry_btn)
	_retry_btn.pressed.connect(func() -> void:
		_auto_retries_left = 0
		_try_connect()
	)
	vbox.add_child(_retry_btn)

	_settings_btn = Button.new()
	_settings_btn.text = "Settings"
	_settings_btn.visible = false
	_settings_btn.custom_minimum_size.y = 48
	_style_retry_button(_settings_btn)
	_settings_btn.pressed.connect(_open_settings)
	vbox.add_child(_settings_btn)


func _try_connect() -> void:
	if not OnlineGate.requires_online():
		_proceed()
		return
	_status_label.text = "Connecting…"
	_retry_btn.visible = false
	_settings_btn.visible = false
	OnlineGate.refresh(_on_connection_ready)


func _open_settings() -> void:
	get_tree().change_scene_to_file(SETTINGS)


func _proceed() -> void:
	if GameState.needs_profile_setup():
		get_tree().change_scene_to_file(NAME_PICKER)
	else:
		get_tree().change_scene_to_file(MAIN_MENU)


func _on_connection_ready(ok: bool) -> void:
	if not ok:
		if _auto_retries_left > 0:
			_auto_retries_left -= 1
			_status_label.text = "Connecting…"
			await get_tree().create_timer(AUTO_RETRY_DELAY_SEC).timeout
			OnlineGate.refresh(_on_connection_ready)
			return
		_status_label.text = OnlineGate.status_message if not OnlineGate.status_message.is_empty() else "Connection failed."
		_retry_btn.visible = true
		_settings_btn.visible = true
		return
	_proceed()


func _style_retry_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.BLUE
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
