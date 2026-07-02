extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const NAME_PICKER := "res://scenes/name_picker/name_picker.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12

var _profile_name_label: Label
var _profile_link_label: Label
var _sync_status_label: Label
var _sync_detail_label: Label
var _sync_dot: PanelContainer
var _retry_sync_btn: Button


func _ready() -> void:
	_build_ui()
	GameState.profile_changed.connect(_sync_profile_card)
	DailyBackend.sync_completed.connect(func(_success: bool) -> void:
		_sync_sync_card()
	)
	GameState.rituals_changed.connect(_sync_sync_card)
	DataLoader.backend_dev_config_changed.connect(_sync_sync_card)
	_sync_profile_card()
	_sync_sync_card()
	if DailyBackend.uses_server_dailies() and not GameState.daily_server_online:
		DailyBackend.ensure_auth(func(_ok: bool) -> void:
			DailyBackend.request_sync()
			_sync_sync_card()
		)


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

	var scroll := MobileScrollContainer.create(false, true)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	scroll.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_profile_card())
	root.add_child(_build_sync_card())
	root.add_child(_build_connect_card())


func _build_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(36, 36)
	UITheme.style_icon_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	row.add_child(back)

	var title := Label.new()
	title.text = "Account"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	return row


func _build_profile_card() -> PanelContainer:
	var card := _make_card()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	vbox.add_child(row)

	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(56, 56)
	var avatar_sb := StyleBoxFlat.new()
	avatar_sb.bg_color = UITheme.BLUE
	avatar_sb.set_corner_radius_all(28)
	avatar.add_theme_stylebox_override("panel", avatar_sb)
	row.add_child(avatar)

	var avatar_icon := Label.new()
	avatar_icon.text = "👤"
	avatar_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_icon.add_theme_font_size_override("font_size", 26)
	avatar.add_child(avatar_icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = "Apprentice mage"
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(name_lbl)
	_profile_name_label = name_lbl

	var link_lbl := Label.new()
	link_lbl.text = "Local profile"
	link_lbl.add_theme_font_size_override("font_size", 12)
	link_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(link_lbl)
	_profile_link_label = link_lbl

	_add_divider(vbox)
	_add_menu_row(vbox, "Edit name", _show_edit_name_dialog)
	_add_divider(vbox)

	var reset_btn := Button.new()
	reset_btn.text = "Reset progress"
	reset_btn.custom_minimum_size.y = 40
	_style_secondary_button(reset_btn)
	reset_btn.pressed.connect(_on_reset_progress)
	vbox.add_child(reset_btn)

	return card


func _build_sync_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	var heading := Label.new()
	heading.text = "Daily sync"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	var dot_wrap := CenterContainer.new()
	dot_wrap.custom_minimum_size = Vector2(12, 12)
	row.add_child(dot_wrap)

	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(8, 8)
	var dot_sb := StyleBoxFlat.new()
	dot_sb.bg_color = UITheme.TEXT_DIM
	dot_sb.set_corner_radius_all(4)
	dot.add_theme_stylebox_override("panel", dot_sb)
	dot_wrap.add_child(dot)
	_sync_dot = dot

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var status_lbl := Label.new()
	status_lbl.text = "Checking…"
	status_lbl.add_theme_font_size_override("font_size", 15)
	status_lbl.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(status_lbl)
	_sync_status_label = status_lbl

	var detail_lbl := Label.new()
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_lbl.add_theme_font_size_override("font_size", 12)
	detail_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(detail_lbl)
	_sync_detail_label = detail_lbl

	var retry_btn := Button.new()
	retry_btn.text = "Retry sync"
	retry_btn.custom_minimum_size.y = 40
	_style_secondary_button(retry_btn)
	retry_btn.visible = false
	retry_btn.pressed.connect(_on_retry_sync)
	vbox.add_child(retry_btn)
	_retry_sync_btn = retry_btn

	return card


func _build_connect_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	var heading := Label.new()
	heading.text = "Cloud backup"
	heading.add_theme_font_size_override("font_size", 12)
	heading.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(heading)

	_add_connect_account_row(vbox)

	return card


func _sync_profile_card() -> void:
	if _profile_name_label:
		var name_text := GameState.display_name.strip_edges()
		_profile_name_label.text = name_text if not name_text.is_empty() else "Apprentice mage"
	if _profile_link_label:
		_profile_link_label.text = "Local profile"


func _sync_sync_card() -> void:
	if _sync_status_label == null:
		return

	if not DailyBackend.is_enabled():
		_set_sync_dot(UITheme.TEXT_DIM)
		_sync_status_label.text = "Local play"
		_sync_detail_label.text = "Cloud dailies (Supabase) are off."
		_retry_sync_btn.visible = false
		return

	if not DailyBackend.is_configured():
		_set_sync_dot(UITheme.TEXT_DIM)
		_sync_status_label.text = "Not configured"
		_sync_detail_label.text = "Set Supabase URL and anon key in Settings → Developer."
		_retry_sync_btn.visible = false
		return

	if not DailyBackend.uses_server_dailies():
		_set_sync_dot(UITheme.TEXT_DIM)
		_sync_status_label.text = "Profile required"
		_sync_detail_label.text = "Finish name setup to enable daily sync."
		_retry_sync_btn.visible = false
		return

	if DailyBackend.is_syncing():
		_set_sync_dot(UITheme.ACCENT)
		_sync_status_label.text = "Syncing…"
		_sync_detail_label.text = "Fetching today's rituals and rewards."
		_retry_sync_btn.visible = false
		return

	if GameState.daily_server_online:
		_set_sync_dot(UITheme.SUCCESS)
		_sync_status_label.text = "Synced"
		var detail_parts: PackedStringArray = []
		if not GameState.daily_ritual_date.is_empty():
			detail_parts.append("Today: %s UTC" % GameState.daily_ritual_date)
		var synced_at := _format_server_time(GameState.daily_server_time_utc)
		if not synced_at.is_empty():
			detail_parts.append("Last sync: %s" % synced_at)
		_sync_detail_label.text = " · ".join(detail_parts) if not detail_parts.is_empty() else "Connected to Supabase."
		_retry_sync_btn.visible = false
		return

	_set_sync_dot(Color(0.92, 0.45, 0.32))
	_sync_status_label.text = "Offline"
	var error_text := DailyBackend.last_sync_error.strip_edges()
	if error_text.is_empty():
		_sync_detail_label.text = "Daily page and ritual rewards need a Supabase connection."
	else:
		_sync_detail_label.text = error_text
	_retry_sync_btn.visible = true
	_retry_sync_btn.disabled = false


func _on_retry_sync() -> void:
	if not DailyBackend.uses_server_dailies() or DailyBackend.is_syncing():
		return
	_retry_sync_btn.disabled = true
	_sync_sync_card()
	DailyBackend.ensure_auth(func(ok: bool) -> void:
		if not ok:
			_sync_sync_card()
			return
		DailyBackend.request_sync()
		_sync_sync_card()
	)


func _set_sync_dot(color: Color) -> void:
	if _sync_dot == null:
		return
	var dot_sb := _sync_dot.get_theme_stylebox("panel") as StyleBoxFlat
	if dot_sb == null:
		dot_sb = StyleBoxFlat.new()
		dot_sb.set_corner_radius_all(4)
	_sync_dot.add_theme_stylebox_override("panel", dot_sb)
	dot_sb.bg_color = color


func _format_server_time(iso: String) -> String:
	var trimmed := iso.strip_edges()
	if trimmed.is_empty():
		return ""
	var readable := trimmed.replace("T", " ").trim_suffix("Z")
	if readable.length() >= 16:
		return "%s UTC" % readable.substr(0, 16)
	return "%s UTC" % readable


func _add_connect_account_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			_show_connect_account_placeholder()
	)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = "Connect account"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var hint := Label.new()
	hint.text = "Coming soon"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hint)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)


func _show_edit_name_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Edit name"
	dlg.ok_button_text = "Save"
	dlg.min_size = Vector2i(300, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	dlg.add_child(margin)

	var field := LineEdit.new()
	field.text = GameState.display_name
	field.max_length = GameState.DISPLAY_NAME_MAX
	field.placeholder_text = "Your name"
	field.custom_minimum_size.y = 44
	_style_name_field(field)
	margin.add_child(field)

	add_child(dlg)
	dlg.popup_centered()
	field.call_deferred("grab_focus")

	dlg.confirmed.connect(func() -> void:
		var result: Dictionary = GameState.update_display_name(field.text)
		if not result.get("ok", false):
			_show_info_dialog("Invalid name", str(result.get("message", "Could not save name.")))
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)


func _show_connect_account_placeholder() -> void:
	_show_info_dialog(
		"Connect account",
		"Google Play and Apple sign-in are coming soon.\n\nYour Grimoire stays on this device until you connect an account."
	)


func _on_reset_progress() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Reset progress?"
	dlg.dialog_text = "This clears your Grimoire and returns you to name setup on this device."
	dlg.ok_button_text = "Reset"
	dlg.cancel_button_text = "Cancel"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func():
		SaveManager.reset_game()
		dlg.queue_free()
		get_tree().change_scene_to_file(NAME_PICKER)
	)
	dlg.canceled.connect(dlg.queue_free)


func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 14)
	return card


func _make_card_body(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	return vbox


func _add_menu_row(parent: VBoxContainer, label_text: String, callback: Callable) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			callback.call()
	)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(chevron)


func _add_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.22, 0.22, 0.26)
	parent.add_child(line)


func _show_info_dialog(title: String, body: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = body
	dlg.ok_button_text = "OK"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _style_secondary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.20)
	sb.border_color = Color(0.28, 0.28, 0.32)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)


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
