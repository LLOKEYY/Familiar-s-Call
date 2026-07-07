extends Control

const SCENES := {
	"squad": "res://scenes/squad_builder/squad_builder.tscn",
	"rift": "res://scenes/rift_trials/rift_trials.tscn",
	"pack": "res://scenes/pack_opening/pack_opening.tscn",
	"grimoire": "res://scenes/grimoire/grimoire.tscn",
	"shop": "res://scenes/shop/shop.tscn",
	"battle_pass": "res://scenes/battle_pass/battle_pass.tscn",
	"settings": "res://scenes/settings/settings.tscn",
	"account": "res://scenes/account/account.tscn",
}

const PLAY_SCENES := ["squad", "rift", "pack", "grimoire", "shop", "battle_pass"]

var _offline_banner: Label

var _dust_label: Label
var _lumen_label: Label
var _ritual_progress_label: Label
var _ritual_list: VBoxContainer
var _page_subtitle: Label
var _open_btn: Button
var _content_root: VBoxContainer
var _scroll: MobileScrollContainer
var _player_name_label: Label


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh_currencies)
	GameState.rituals_changed.connect(func() -> void:
		call_deferred("_refresh_rituals")
	)
	GameState.profile_changed.connect(_refresh_player_name)
	DailyBackend.sync_completed.connect(func(_success: bool) -> void:
		call_deferred("_refresh_all")
		call_deferred("_refresh_offline_banner")
	)
	OnlineGate.connection_changed.connect(func(_online: bool) -> void:
		call_deferred("_refresh_offline_banner")
	)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_refresh_all()
	_refresh_offline_banner()
	call_deferred("_on_viewport_resized")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = UITheme.MOBILE_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	_scroll = MobileScrollContainer.create(false, true)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_scroll)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 12)
	_scroll.add_child(_content_root)

	_content_root.add_child(_build_top_bar())
	_offline_banner = _build_offline_banner()
	_content_root.add_child(_offline_banner)
	_content_root.add_child(_build_header_card())
	_content_root.add_child(_build_todays_page_card())
	_content_root.add_child(_build_rituals_card())
	_content_root.add_child(_build_battle_button())
	_content_root.add_child(_build_nav_grid())

	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 8)
	_content_root.add_child(bottom_pad)


func _on_viewport_resized() -> void:
	var w := get_viewport_rect().size.x - 40
	if _content_root:
		_content_root.custom_minimum_size.x = w


func _full_width(node: Control) -> Control:
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return node


func _build_top_bar() -> HBoxContainer:
	var bar := _full_width(HBoxContainer.new()) as HBoxContainer
	bar.add_theme_constant_override("separation", 10)

	bar.add_child(_make_currency_pill("★", true))
	bar.add_child(_make_currency_pill("◆", false))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var account := Button.new()
	account.text = "👤"
	account.custom_minimum_size = Vector2(40, 40)
	UITheme.style_icon_button(account)
	account.pressed.connect(_on_account)
	bar.add_child(account)

	var settings := Button.new()
	settings.text = "⚙"
	settings.custom_minimum_size = Vector2(40, 40)
	UITheme.style_icon_button(settings)
	settings.pressed.connect(_on_settings)
	bar.add_child(settings)
	return bar


func _make_currency_pill(icon_text: String, is_dust: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UITheme.make_pill())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	pill.add_child(row)

	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 13)
	icon.add_theme_color_override(
		"font_color",
		Color(0.95, 0.78, 0.28) if is_dust else UITheme.BLUE
	)
	row.add_child(icon)

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	if is_dust:
		_dust_label = lbl
	else:
		_lumen_label = lbl
	return pill


func _build_header_card() -> PanelContainer:
	var card := _full_width(PanelContainer.new()) as PanelContainer
	UITheme.apply_card_style(card, 16)
	card.custom_minimum_size.y = 80

	var center := CenterContainer.new()
	card.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	center.add_child(vbox)

	var subtitle := Label.new()
	subtitle.text = "Apprentice mage"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(subtitle)
	_player_name_label = subtitle

	var title := Label.new()
	title.text = "Familiar's Call"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)
	return card


func _build_todays_page_card() -> PanelContainer:
	var card := _full_width(PanelContainer.new()) as PanelContainer
	UITheme.apply_card_style(card, 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var heading := Label.new()
	heading.text = "Today's page"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", UITheme.BLUE)
	text_col.add_child(heading)

	_page_subtitle = Label.new()
	_page_subtitle.text = "A new familiar awaits"
	_page_subtitle.add_theme_font_size_override("font_size", 13)
	_page_subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(_page_subtitle)

	_open_btn = Button.new()
	_open_btn.text = "Open"
	_open_btn.custom_minimum_size = Vector2(84, 40)
	UITheme.style_accent_button(_open_btn)
	_open_btn.pressed.connect(_claim_free_page)
	row.add_child(_open_btn)
	return card


func _build_rituals_card() -> PanelContainer:
	var card := _full_width(PanelContainer.new()) as PanelContainer
	UITheme.apply_card_style(card, 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Daily rituals"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_ritual_progress_label = Label.new()
	_ritual_progress_label.add_theme_font_size_override("font_size", 14)
	_ritual_progress_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	header.add_child(_ritual_progress_label)
	vbox.add_child(header)

	_ritual_list = VBoxContainer.new()
	_ritual_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_ritual_list)
	return card


func _build_battle_button() -> PanelContainer:
	var card := _full_width(PanelContainer.new()) as PanelContainer
	UITheme.apply_primary_card(card)
	card.custom_minimum_size.y = 54
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_go("rift")
	)

	var center := CenterContainer.new()
	card.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)

	var icon := Label.new()
	icon.text = "⚔"
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Battle"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.14))
	row.add_child(lbl)
	return card


func _build_nav_grid() -> VBoxContainer:
	var outer := _full_width(VBoxContainer.new()) as VBoxContainer
	outer.add_theme_constant_override("separation", 10)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_nav_tile(row1, "◉", "Coven", "squad")
	_add_nav_tile(row1, "▤", "Pages", "pack")
	outer.add_child(row1)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_nav_tile(row2, "☰", "Grimoire", "grimoire")
	_add_nav_tile(row2, "▣", "Shop", "shop")
	outer.add_child(row2)

	outer.add_child(_build_battle_pass_button())
	return outer


func _build_battle_pass_button() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 80)
	_apply_battle_pass_style(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_go("battle_pass")
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := Label.new()
	icon.text = "◎"
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	row.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var title := Label.new()
	title.text = "Battle Pass"
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(title)

	var sub := Label.new()
	sub.text = "Season rewards — free & premium tracks"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(sub)

	var chevron := Label.new()
	chevron.text = "›"
	chevron.add_theme_font_size_override("font_size", 22)
	chevron.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	row.add_child(chevron)

	return panel


func _apply_battle_pass_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.14, 0.11, 0.08)
	sb.border_color = Color(0.55, 0.40, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)


func _add_nav_tile(parent: HBoxContainer, icon: String, label_text: String, scene_key: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	panel.custom_minimum_size = Vector2(0, 80)
	UITheme.style_nav_tile(panel)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)

	var icon_lbl := Label.new()
	icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 20)
	icon_lbl.add_theme_color_override("font_color", UITheme.BLUE)
	col.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = label_text
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(name_lbl)

	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_go(scene_key)
	)
	parent.add_child(panel)


func _refresh_all() -> void:
	_refresh_currencies()
	_refresh_page_card()
	_refresh_rituals()
	_refresh_player_name()


func _refresh_player_name() -> void:
	if _player_name_label == null:
		return
	var name_text := GameState.display_name.strip_edges()
	_player_name_label.text = name_text if not name_text.is_empty() else "Apprentice mage"


func _refresh_currencies() -> void:
	if _dust_label:
		_dust_label.text = str(GameState.dust)
	if _lumen_label:
		_lumen_label.text = str(GameState.lumen)


func _refresh_page_card() -> void:
	if _open_btn == null:
		return
	if DailyBackend.uses_server_dailies() and not GameState.daily_rewards_available():
		_page_subtitle.text = "Offline — sync for today's page"
		_open_btn.text = "Unavailable"
		_open_btn.disabled = true
	elif GameState.daily_free_page_claimed:
		_page_subtitle.text = "Come back tomorrow"
		_open_btn.text = "Done"
		_open_btn.disabled = true
	else:
		_page_subtitle.text = "A new familiar awaits"
		_open_btn.text = "Open"
		_open_btn.disabled = false
	UITheme.style_accent_button(_open_btn)


func _refresh_rituals() -> void:
	if _ritual_list == null:
		return
	for c in _ritual_list.get_children():
		_ritual_list.remove_child(c)
		c.free()

	var rituals: Dictionary = GameState.get_daily_rituals()
	var ritual_entries: Array = rituals.get("rituals", [])
	_ritual_progress_label.text = "%d / %d" % [rituals.get("completed", 0), mini(3, ritual_entries.size())]

	var dust_reward: int = int(rituals.get("dust_reward", 150))
	for entry in ritual_entries:
		if entry is Dictionary:
			_add_ritual_row(
				str(entry.get("label", "")),
				entry.get("completed", false),
				int(entry.get("reward", dust_reward)),
			)


func _add_ritual_row(text: String, done: bool, reward: int = 150) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var mark := Label.new()
	mark.custom_minimum_size = Vector2(18, 0)
	mark.add_theme_font_size_override("font_size", 13)
	if done:
		mark.text = "✓"
		mark.add_theme_color_override("font_color", UITheme.SUCCESS)
	else:
		mark.text = "○"
		mark.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	row.add_child(mark)

	var lbl := Label.new()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if done:
		lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	else:
		lbl.add_theme_color_override("font_color", UITheme.TEXT)
	row.add_child(lbl)

	var reward_lbl := Label.new()
	reward_lbl.custom_minimum_size.x = 52
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	reward_lbl.add_theme_font_size_override("font_size", 12)
	if done:
		reward_lbl.text = "Claimed"
		reward_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	else:
		reward_lbl.text = "+%d ★" % reward
		reward_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))
	row.add_child(reward_lbl)

	_ritual_list.add_child(row)


func _build_offline_banner() -> Label:
	var lbl := Label.new()
	lbl.visible = false
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.45, 0.32))
	return lbl


func _refresh_offline_banner() -> void:
	if _offline_banner == null:
		return
	if OnlineGate.can_play():
		_offline_banner.visible = false
		return
	_offline_banner.visible = true
	var msg := OnlineGate.status_message.strip_edges()
	if msg.is_empty():
		msg = "Offline — reconnect to play."
	_offline_banner.text = msg


func _go(key: String) -> void:
	if key in PLAY_SCENES and not OnlineGate.can_play():
		_refresh_offline_banner()
		return
	if SCENES.has(key):
		get_tree().change_scene_to_file(SCENES[key])


func _claim_free_page() -> void:
	if not OnlineGate.can_play():
		_refresh_offline_banner()
		return
	if DailyBackend.uses_server_dailies() and not GameState.daily_rewards_available():
		return
	if GameState.daily_free_page_claimed:
		return
	GameState.request_daily_page_open()
	_go("pack")


func _on_settings() -> void:
	_go("settings")


func _on_account() -> void:
	_go("account")
