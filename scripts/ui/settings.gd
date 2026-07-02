extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12
const APP_VERSION := "v0.1.0"
const BATTLE_SPEEDS := ["1×", "1.75×", "2.5×"]

var _music_slider: HSlider
var _sfx_slider: HSlider
var _vibration_toggle: CheckButton
var _speed_value_lbl: Label
var _reduced_motion_toggle: CheckButton
var _daily_page_toggle: CheckButton
var _clash_digest_toggle: CheckButton
var _dev_enabled_toggle: CheckButton
var _dev_supabase_url_label: Label
var _dev_anon_key_label: Label
var _dev_status_label: Label


func _ready() -> void:
	_build_ui()
	_sync_from_state()
	if OS.is_debug_build():
		DailyBackend.sync_completed.connect(func(_success: bool) -> void:
			_refresh_dev_status()
		)
		DataLoader.backend_dev_config_changed.connect(_on_dev_backend_config_changed)


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
	root.add_child(_section_label("Audio"))
	root.add_child(_build_audio_card())
	root.add_child(_section_label("Gameplay"))
	root.add_child(_build_gameplay_card())
	root.add_child(_section_label("Notifications"))
	root.add_child(_build_notifications_card())
	root.add_child(_section_label("Legal and support"))
	root.add_child(_build_legal_card())

	if OS.is_debug_build():
		root.add_child(_section_label("Developer"))
		root.add_child(_build_dev_card())

	var footer := Label.new()
	footer.text = "Familiar's Call · %s" % APP_VERSION
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	root.add_child(footer)


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
	title.text = "Settings"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	return row


func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	return lbl


func _build_audio_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	_music_slider = _add_slider_row(vbox, "Music")
	_music_slider.value_changed.connect(func(v: float) -> void:
		GameState.music_volume = int(v)
		GameState.save_settings()
	)

	_add_divider(vbox)

	_sfx_slider = _add_slider_row(vbox, "Sound effects")
	_sfx_slider.value_changed.connect(func(v: float) -> void:
		GameState.sfx_volume = int(v)
		GameState.save_settings()
	)

	_add_divider(vbox)

	_vibration_toggle = _add_toggle_row(vbox, "Vibration")
	_vibration_toggle.toggled.connect(func(on: bool) -> void:
		GameState.vibration_enabled = on
		GameState.save_settings()
	)

	return card


func _build_gameplay_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	var speed_row := _add_link_row(vbox, "Default battle speed")
	_speed_value_lbl = speed_row.get_node("Value") as Label
	speed_row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			_cycle_battle_speed()
	)

	_add_divider(vbox)

	_reduced_motion_toggle = _add_toggle_row(vbox, "Reduced motion")
	_reduced_motion_toggle.toggled.connect(func(on: bool) -> void:
		GameState.reduced_motion = on
		GameState.save_settings()
	)

	return card


func _build_notifications_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	_daily_page_toggle = _add_toggle_row(vbox, "Daily page reminder")
	_daily_page_toggle.toggled.connect(func(on: bool) -> void:
		GameState.notify_daily_page = on
		GameState.save_settings()
	)

	_add_divider(vbox)

	_clash_digest_toggle = _add_toggle_row(vbox, "Clash attack digest")
	_clash_digest_toggle.toggled.connect(func(on: bool) -> void:
		GameState.notify_clash_digest = on
		GameState.save_settings()
	)

	return card


func _build_dev_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)
	vbox.add_theme_constant_override("separation", 10)

	_dev_enabled_toggle = _add_toggle_row(vbox, "Cloud dailies (Supabase)")
	_dev_enabled_toggle.toggled.connect(_on_dev_enabled_toggled)

	_add_divider(vbox)

	var url_row := _add_link_row(vbox, "Supabase URL")
	_dev_supabase_url_label = url_row.get_node("Value") as Label
	url_row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			_show_edit_supabase_url_dialog()
	)

	_add_divider(vbox)

	var key_row := _add_link_row(vbox, "Anon key")
	_dev_anon_key_label = key_row.get_node("Value") as Label
	key_row.gui_input.connect(func(event: InputEvent) -> void:
		if _is_tap(event):
			_show_edit_anon_key_dialog()
	)

	_add_divider(vbox)
	_add_menu_row(vbox, "Open Supabase dashboard ↗", _dev_open_supabase_dashboard)

	_add_divider(vbox)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	vbox.add_child(btn_row)

	for spec in [
		["Sync", _dev_sync_now],
		["Ping", _dev_ping_server],
		["Offline", _dev_force_offline],
	]:
		var btn := Button.new()
		btn.text = spec[0]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = 40
		_style_dev_button(btn)
		btn.pressed.connect(spec[1])
		btn_row.add_child(btn)

	_add_divider(vbox)
	_add_menu_row(vbox, "Copy profile ID", _dev_copy_profile_id)
	_add_divider(vbox)
	_add_menu_row(vbox, "Reset dev backend overrides", _dev_reset_backend_overrides)
	_add_divider(vbox)
	_add_menu_row(vbox, "Open Account sync screen", _dev_open_account)

	var status := Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(status)
	_dev_status_label = status

	var hint := Label.new()
	hint.text = "One-time setup: supabase/README.md — enable Anonymous sign-ins, run migration, deploy daily function."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(hint)

	_refresh_dev_status()
	return card


func _build_legal_card() -> PanelContainer:
	var card := _make_card()
	var vbox := _make_card_body(card)

	_add_menu_row(vbox, "Pack odds", _show_pack_odds)
	_add_divider(vbox)
	_add_menu_row(vbox, "Restore purchases", _restore_purchases)
	_add_divider(vbox)
	_add_menu_row(vbox, "Privacy policy", _show_privacy)
	_add_divider(vbox)
	_add_menu_row(vbox, "Contact support", _contact_support)

	return card


func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 14)
	return card


func _make_card_body(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	margin.add_child(vbox)
	return vbox


func _add_slider_row(parent: VBoxContainer, label_text: String) -> HSlider:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 8)
	wrap.custom_minimum_size.y = 52
	parent.add_child(wrap)

	var row := HBoxContainer.new()
	wrap.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(120, 20)
	_style_slider(slider)
	wrap.add_child(slider)
	return slider


func _add_toggle_row(parent: VBoxContainer, label_text: String) -> CheckButton:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	var toggle := CheckButton.new()
	_style_toggle(toggle)
	row.add_child(toggle)
	return toggle


func _add_link_row(parent: VBoxContainer, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 48
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	var value := Label.new()
	value.name = "Value"
	value.text = "2×"
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	row.add_child(value)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 18)
	chevron.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	row.add_child(chevron)

	return row


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


func _sync_from_state() -> void:
	if _music_slider:
		_music_slider.value = GameState.music_volume
	if _sfx_slider:
		_sfx_slider.value = GameState.sfx_volume
	if _vibration_toggle:
		_vibration_toggle.button_pressed = GameState.vibration_enabled
	if _reduced_motion_toggle:
		_reduced_motion_toggle.button_pressed = GameState.reduced_motion
	if _daily_page_toggle:
		_daily_page_toggle.button_pressed = GameState.notify_daily_page
	if _clash_digest_toggle:
		_clash_digest_toggle.button_pressed = GameState.notify_clash_digest
	_update_speed_label()
	_sync_dev_from_state()


func _sync_dev_from_state() -> void:
	if not OS.is_debug_build() or _dev_enabled_toggle == null:
		return
	_dev_enabled_toggle.set_block_signals(true)
	_dev_enabled_toggle.button_pressed = DailyBackend.is_enabled()
	_dev_enabled_toggle.set_block_signals(false)
	if _dev_supabase_url_label:
		var url := str(DataLoader.backend_config.get("supabase_url", ""))
		_dev_supabase_url_label.text = _truncate_middle(url, 28) if not url.is_empty() else "Not set"
	if _dev_anon_key_label:
		var key := str(DataLoader.backend_config.get("supabase_anon_key", ""))
		_dev_anon_key_label.text = "Set" if key.length() > 8 else "Not set"
	_refresh_dev_status()


func _truncate_middle(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	var half := int(max_len / 2) - 1
	return "%s…%s" % [text.substr(0, half), text.substr(text.length() - half)]


func _refresh_dev_status() -> void:
	if _dev_status_label == null:
		return
	if not DailyBackend.is_enabled():
		_dev_status_label.text = "Cloud dailies off — using local daily rituals."
		return
	if not DailyBackend.is_configured():
		_dev_status_label.text = "Set Supabase URL and anon key (see supabase/README.md)."
		return
	if not DailyBackend.uses_server_dailies():
		_dev_status_label.text = "Configured — finish name setup, then Sync."
		return
	if DailyBackend.is_syncing():
		_dev_status_label.text = "Syncing with Supabase…"
		return
	if GameState.daily_server_online:
		var parts: PackedStringArray = []
		if not GameState.daily_ritual_date.is_empty():
			parts.append("day %s UTC" % GameState.daily_ritual_date)
		if not GameState.daily_server_time_utc.is_empty():
			parts.append("synced %s" % GameState.daily_server_time_utc)
		if DailyBackend.has_session():
			parts.append("signed in")
		_dev_status_label.text = "Online — %s" % (" · ".join(parts) if not parts.is_empty() else "connected")
		return
	var err := DailyBackend.last_sync_error.strip_edges()
	if err.is_empty():
		err = "cannot reach Supabase"
	_dev_status_label.text = "Offline — %s" % err


func _dev_open_supabase_dashboard() -> void:
	OS.shell_open("https://supabase.com/dashboard")


func _on_dev_backend_config_changed() -> void:
	_sync_dev_from_state()


func _on_dev_enabled_toggled(on: bool) -> void:
	DataLoader.set_dev_backend_enabled(on)
	if on:
		DailyRituals.ensure_today()
	else:
		DailyBackend.force_offline()
		DailyRituals.ensure_today()
	_refresh_dev_status()


func _dev_sync_now() -> void:
	if not DailyBackend.is_configured():
		_show_info_dialog("Sync", "Set Supabase URL and anon key first.")
		return
	if not DailyBackend.uses_server_dailies():
		_show_info_dialog("Sync", "Turn on cloud dailies and finish name setup first.")
		return
	_refresh_dev_status()
	DailyBackend.ensure_auth(func(auth_ok: bool) -> void:
		if not auth_ok:
			_refresh_dev_status()
			_show_info_dialog("Sign-in failed", DailyBackend.last_sync_error)
			return
		DailyBackend.request_sync(func(result: Dictionary) -> void:
			_refresh_dev_status()
			if result.get("ok", false):
				_show_info_dialog(
					"Sync OK",
					"Day: %s\nUser: %s" % [
						GameState.daily_ritual_date,
						GameState.profile_id.substr(0, 8) + "…",
					]
				)
			else:
				_show_info_dialog("Sync failed", str(result.get("error", DailyBackend.last_sync_error)))
		)
	)


func _dev_ping_server() -> void:
	if not DailyBackend.is_configured():
		_show_info_dialog("Ping", "Set Supabase URL and anon key first.")
		return
	DailyBackend.ping_health(func(result: Dictionary) -> void:
		if result.get("ok", false):
			_show_info_dialog("Ping OK", "Supabase auth service is reachable.")
		else:
			_show_info_dialog(
				"Ping failed",
				str(result.get("error", "Unknown error"))
			)
		_refresh_dev_status()
	)
	_refresh_dev_status()


func _dev_force_offline() -> void:
	DailyBackend.force_offline()
	_refresh_dev_status()


func _dev_copy_profile_id() -> void:
	var profile_id := GameState.profile_id.strip_edges()
	if profile_id.is_empty():
		_show_info_dialog("User ID", "No profile yet — complete name setup and Sync first.")
		return
	DisplayServer.clipboard_set(profile_id)
	_show_info_dialog("User ID copied", profile_id)


func _dev_reset_backend_overrides() -> void:
	DataLoader.reset_dev_backend_overrides()
	GameState.clear_supabase_session()
	DailyBackend.force_offline()
	DailyRituals.ensure_today()
	_sync_dev_from_state()


func _dev_open_account() -> void:
	get_tree().change_scene_to_file("res://scenes/account/account.tscn")


func _show_edit_supabase_url_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Supabase URL"
	dlg.ok_button_text = "Save"
	dlg.min_size = Vector2i(320, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	dlg.add_child(margin)

	var field := LineEdit.new()
	field.text = str(DataLoader.backend_config.get("supabase_url", ""))
	field.placeholder_text = "https://YOUR_PROJECT.supabase.co"
	field.custom_minimum_size.y = 44
	_style_dev_field(field)
	margin.add_child(field)

	add_child(dlg)
	dlg.popup_centered()
	field.call_deferred("grab_focus")

	dlg.confirmed.connect(func() -> void:
		DataLoader.set_dev_supabase_url(field.text)
		if DailyBackend.is_enabled():
			DailyRituals.ensure_today()
		_sync_dev_from_state()
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)


func _show_edit_anon_key_dialog() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Supabase anon key"
	dlg.ok_button_text = "Save"
	dlg.min_size = Vector2i(320, 0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	dlg.add_child(margin)

	var field := LineEdit.new()
	field.text = str(DataLoader.backend_config.get("supabase_anon_key", ""))
	field.placeholder_text = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9…"
	field.custom_minimum_size.y = 44
	_style_dev_field(field)
	margin.add_child(field)

	add_child(dlg)
	dlg.popup_centered()
	field.call_deferred("grab_focus")

	dlg.confirmed.connect(func() -> void:
		DataLoader.set_dev_supabase_anon_key(field.text)
		if DailyBackend.is_enabled():
			DailyRituals.ensure_today()
		_sync_dev_from_state()
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)


func _update_speed_label() -> void:
	if _speed_value_lbl == null:
		return
	var idx := clampi(GameState.default_battle_speed_index, 0, BATTLE_SPEEDS.size() - 1)
	_speed_value_lbl.text = BATTLE_SPEEDS[idx]


func _cycle_battle_speed() -> void:
	GameState.default_battle_speed_index = (
		(GameState.default_battle_speed_index + 1) % BATTLE_SPEEDS.size()
	)
	GameState.save_settings()
	_update_speed_label()


func _show_pack_odds() -> void:
	var packs: Dictionary = DataLoader.economy_config.get("packs", {})
	var lines: PackedStringArray = []
	for pack_id in packs:
		var pack: Dictionary = packs[pack_id]
		var odds: Dictionary = pack.get("odds", {})
		lines.append("%s:" % pack_id.capitalize().replace("_", " "))
		for rarity in ["common", "rare", "epic", "legendary"]:
			if odds.has(rarity):
				lines.append("  %s: %s%%" % [rarity.capitalize(), odds[rarity]])
		lines.append("")
	var pity: Dictionary = DataLoader.economy_config.get("pity", {})
	if not pity.is_empty():
		lines.append("Pity: epic within %d, legendary within %d tomes" % [
			int(pity.get("epic_within", 0)),
			int(pity.get("legendary_within", 0)),
		])
	_show_info_dialog("Pack odds", "\n".join(lines))


func _restore_purchases() -> void:
	_show_info_dialog(
		"Restore purchases",
		"Purchase restore is not connected yet. Premium unlocks granted in debug mode stay on this device."
	)


func _show_privacy() -> void:
	_show_info_dialog(
		"Privacy policy",
		"Familiar's Call stores game progress locally on your device. A full privacy policy will be published before launch."
	)


func _contact_support() -> void:
	_show_info_dialog(
		"Contact support",
		"Email support@familiarscall.example for help.\n(MVP placeholder — replace before release.)"
	)


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


func _style_slider(slider: HSlider) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.14, 0.17)
	bg.set_corner_radius_all(4)
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	slider.add_theme_stylebox_override("slider", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.BLUE
	fill.set_corner_radius_all(4)
	slider.add_theme_stylebox_override("grabber_area", fill)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color.WHITE
	grabber.set_corner_radius_all(6)
	grabber.content_margin_left = 6
	grabber.content_margin_right = 6
	grabber.content_margin_top = 6
	grabber.content_margin_bottom = 6
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)


func _style_toggle(toggle: CheckButton) -> void:
	var off := StyleBoxFlat.new()
	off.bg_color = Color(0.22, 0.22, 0.26)
	off.set_corner_radius_all(12)
	off.content_margin_left = 4
	off.content_margin_right = 4
	toggle.add_theme_stylebox_override("normal", off)
	var on := StyleBoxFlat.new()
	on.bg_color = UITheme.BLUE
	on.set_corner_radius_all(12)
	toggle.add_theme_stylebox_override("pressed", on)
	toggle.add_theme_stylebox_override("hover_pressed", on)


func _style_dev_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.16, 0.20)
	sb.border_color = Color(0.28, 0.28, 0.32)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)


func _style_dev_field(field: LineEdit) -> void:
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
