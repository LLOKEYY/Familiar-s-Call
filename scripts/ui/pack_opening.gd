extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SHOP_SCENE := "res://scenes/shop/shop.tscn"
const GRIMOIRE_SCENE := "res://scenes/grimoire/grimoire.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12

var _dust_label: Label
var _lumen_label: Label
var _tear_btn: Button
var _pity_label: Label
var _pity_bar: ProgressBar
var _recent_row: HBoxContainer
var _reveal_layer: CanvasLayer
var _reveal_panel: PanelContainer
var _reveal_label: Label
var _card_holder: CenterContainer
var _continue_btn: Button
var _reveal_dim: ColorRect
var _interactive: Array = []
var _opening: bool = false


func _ready() -> void:
	_build_ui()
	_build_reveal_overlay()
	GameState.currencies_changed.connect(_refresh_currencies)
	_refresh_all()
	if GameState.consume_daily_page_open_request() and not GameState.daily_free_page_claimed:
		call_deferred("_tear_open_daily")


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
	root.add_theme_constant_override("separation", 12)
	scroll.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_daily_card())
	root.add_child(_build_pack_row())
	root.add_child(_build_pity_card())
	root.add_child(_build_recent_card())
	root.add_child(_build_shop_row())


func _build_reveal_overlay() -> void:
	_reveal_layer = CanvasLayer.new()
	_reveal_layer.layer = 60
	_reveal_layer.visible = false
	add_child(_reveal_layer)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_reveal_dim_input)
	_reveal_dim = dim
	_reveal_layer.add_child(dim)

	_reveal_panel = PanelContainer.new()
	_reveal_panel.custom_minimum_size = Vector2(300, 320)
	UITheme.apply_card_style(_reveal_panel, 16)
	_reveal_layer.add_child(_reveal_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_reveal_panel.add_child(vbox)

	_reveal_label = Label.new()
	_reveal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reveal_label.add_theme_font_size_override("font_size", 16)
	_reveal_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_reveal_label)

	_card_holder = CenterContainer.new()
	_card_holder.custom_minimum_size = Vector2(0, 220)
	vbox.add_child(_card_holder)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.custom_minimum_size.y = 40
	_continue_btn.visible = false
	UITheme.style_accent_button(_continue_btn)
	_continue_btn.pressed.connect(_close_reveal)
	vbox.add_child(_continue_btn)

	call_deferred("_center_reveal_panel")


func _on_reveal_dim_input(event: InputEvent) -> void:
	if not _opening or not _continue_btn.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_reveal()
	elif event is InputEventScreenTouch and event.pressed:
		_close_reveal()


func _close_reveal() -> void:
	if not _opening:
		return
	_reveal_layer.visible = false
	_continue_btn.visible = false
	_opening = false
	_set_interactive_enabled(true)


func _center_reveal_panel() -> void:
	if _reveal_panel == null:
		return
	var vp := get_viewport_rect().size
	_reveal_panel.position = Vector2(
		(vp.x - _reveal_panel.size.x) * 0.5,
		(vp.y - _reveal_panel.size.y) * 0.5
	)


func _build_top_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	bar.add_child(_make_currency_pill("★", true))
	bar.add_child(_make_currency_pill("◆", false))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(36, 36)
	UITheme.style_icon_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	bar.add_child(back)
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


func _build_daily_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var sub := Label.new()
	sub.text = "Free once per day"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(sub)

	var title := Label.new()
	title.text = "Today's page"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	_tear_btn = Button.new()
	_tear_btn.text = "Tear open"
	_tear_btn.custom_minimum_size.y = 44
	UITheme.style_accent_button(_tear_btn)
	_tear_btn.pressed.connect(_tear_open_daily)
	vbox.add_child(_tear_btn)
	_interactive.append(_tear_btn)
	return card


func _build_pack_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	row.add_child(_make_pack_card(
		"▤",
		"Common page",
		"90/9/1%",
		"★",
		300,
		"common_page",
		false
	))
	row.add_child(_make_pack_card(
		"📘",
		"Sealed tome",
		"60/28/10/2%",
		"◆",
		150,
		"sealed_tome",
		true
	))
	return row


func _make_pack_card(
	icon_text: String,
	title_text: String,
	odds_text: String,
	cost_icon: String,
	cost: int,
	pack_type: String,
	highlighted: bool
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.0
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = UITheme.BLUE if highlighted else UITheme.CARD_BORDER
	sb.set_border_width_all(2 if highlighted else 1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var icon := Label.new()
	icon.text = icon_text
	icon.add_theme_font_size_override("font_size", 22)
	icon.add_theme_color_override("font_color", UITheme.BLUE if highlighted else UITheme.TEXT_MUTED)
	vbox.add_child(icon)

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var odds := Label.new()
	odds.text = odds_text
	odds.add_theme_font_size_override("font_size", 12)
	odds.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(odds)

	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 4)
	vbox.add_child(cost_row)

	var cost_icon_lbl := Label.new()
	cost_icon_lbl.text = cost_icon
	cost_icon_lbl.add_theme_font_size_override("font_size", 13)
	cost_icon_lbl.add_theme_color_override(
		"font_color",
		Color(0.95, 0.78, 0.28) if cost_icon == "★" else UITheme.BLUE
	)
	cost_row.add_child(cost_icon_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = str(cost)
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color", Color.WHITE)
	cost_row.add_child(cost_lbl)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_open(pack_type)
	)
	_interactive.append(card)
	return card


func _build_pity_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Pity progress"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	_pity_label = Label.new()
	_pity_label.add_theme_font_size_override("font_size", 13)
	_pity_label.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	header.add_child(_pity_label)
	vbox.add_child(header)

	_pity_bar = ProgressBar.new()
	_pity_bar.custom_minimum_size.y = 8
	_pity_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.12, 0.12, 0.15)
	bar_bg.set_corner_radius_all(4)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = UITheme.BLUE
	bar_fill.set_corner_radius_all(4)
	_pity_bar.add_theme_stylebox_override("background", bar_bg)
	_pity_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_pity_bar)

	var hint := Label.new()
	hint.text = "Guaranteed epic within 20 tomes, legendary within 60."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	vbox.add_child(hint)
	return card


func _build_recent_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 14)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "Recent pulls"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var view_all := Button.new()
	view_all.text = "View all"
	view_all.add_theme_font_size_override("font_size", 12)
	view_all.add_theme_color_override("font_color", UITheme.BLUE)
	view_all.pressed.connect(func(): get_tree().change_scene_to_file(GRIMOIRE_SCENE))
	header.add_child(view_all)
	vbox.add_child(header)

	_recent_row = HBoxContainer.new()
	_recent_row.add_theme_constant_override("separation", 8)
	vbox.add_child(_recent_row)
	return card


func _build_shop_row() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 12)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			get_tree().change_scene_to_file(SHOP_SCENE)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var icon := Label.new()
	icon.text = "🛍"
	icon.add_theme_font_size_override("font_size", 18)
	icon.add_theme_color_override("font_color", UITheme.BLUE)
	row.add_child(icon)

	var lbl := Label.new()
	lbl.text = "Need more Lumen?"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(lbl)

	var chev := Label.new()
	chev.text = "›"
	chev.add_theme_font_size_override("font_size", 20)
	chev.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	row.add_child(chev)
	return card


func _refresh_all() -> void:
	_refresh_currencies()
	_refresh_daily()
	_refresh_pity()
	_refresh_recent()


func _refresh_currencies() -> void:
	if _dust_label:
		_dust_label.text = str(GameState.dust)
	if _lumen_label:
		_lumen_label.text = str(GameState.lumen)


func _refresh_daily() -> void:
	if _tear_btn == null:
		return
	if DailyBackend.uses_server_dailies() and not GameState.daily_rewards_available():
		_tear_btn.text = "Offline"
		_tear_btn.disabled = true
	elif GameState.daily_free_page_claimed:
		_tear_btn.text = "Claimed"
		_tear_btn.disabled = true
	else:
		_tear_btn.text = "Tear open"
		_tear_btn.disabled = false
	UITheme.style_accent_button(_tear_btn)


func _refresh_pity() -> void:
	if _pity_label == null or _pity_bar == null:
		return
	var pity_cfg: Dictionary = DataLoader.economy_config.get("pity", {})
	var epic_within: int = int(pity_cfg.get("epic_within", 20))
	var counter: int = GameState.tome_pity_counter
	var current: int = counter % epic_within
	if current == 0 and counter > 0:
		current = epic_within
	_pity_label.text = "%d / %d" % [current, epic_within]
	_pity_bar.max_value = epic_within
	_pity_bar.value = current


func _refresh_recent() -> void:
	if _recent_row == null:
		return
	for c in _recent_row.get_children():
		c.queue_free()

	var shown: int = 0
	for familiar_id in GameState.recent_pulls:
		if shown >= 5:
			break
		var data: FamiliarData = DataLoader.get_familiar(str(familiar_id))
		if data == null:
			continue
		_recent_row.add_child(_make_pull_tile(data))
		shown += 1

	if shown == 0:
		var empty := Label.new()
		empty.text = "No pulls yet"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		_recent_row.add_child(empty)


func _make_pull_tile(data: FamiliarData) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(44, 44)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.school_slot_bg(data.school)
	sb.set_corner_radius_all(10)
	tile.add_theme_stylebox_override("panel", sb)

	var emoji := Label.new()
	emoji.text = UITheme.school_emoji(data.school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	emoji.add_theme_font_size_override("font_size", 20)
	tile.add_child(emoji)
	return tile


func _set_interactive_enabled(enabled: bool) -> void:
	for node in _interactive:
		if node is Button:
			(node as Button).disabled = not enabled
		elif node is Control:
			(node as Control).mouse_filter = (
				Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
			)


func _tear_open_daily() -> void:
	if _opening:
		return
	if DailyBackend.uses_server_dailies():
		if not GameState.daily_rewards_available():
			return
		if GameState.daily_free_page_claimed:
			return
		_opening = true
		_set_interactive_enabled(false)
		DailyBackend.claim_pack(func(result: Dictionary) -> void:
			_on_daily_pack_claimed(result)
		)
		return
	_opening = true
	var result: Dictionary = EconomyManager.open_free_page()
	if not result.get("ok", false):
		_opening = false
		return
	await _finish_free_page_result(result)


func _on_daily_pack_claimed(result: Dictionary) -> void:
	if not result.get("ok", false):
		_opening = false
		_set_interactive_enabled(true)
		_refresh_daily()
		return
	var roll: Dictionary = EconomyManager.roll_claimed_free_page()
	if not roll.get("ok", false):
		_opening = false
		_set_interactive_enabled(true)
		_refresh_daily()
		return
	await _finish_free_page_result(roll)


func _finish_free_page_result(result: Dictionary) -> void:
	var familiar: FamiliarData = result.get("familiar")
	var rarity: String = result.get("rarity", "common")
	await _animate_pull(familiar, rarity, result.get("add_result", {}))
	_opening = false
	_set_interactive_enabled(true)
	_refresh_all()


func _open(pack_type: String) -> void:
	if _opening:
		return
	var result: Dictionary = EconomyManager.open_pack(pack_type)
	if not result.get("ok", false):
		return
	var familiar: FamiliarData = result.get("familiar")
	var rarity: String = result.get("rarity", "")
	await _animate_pull(familiar, rarity, result.get("add_result", {}))
	_refresh_all()


func _animate_pull(familiar: FamiliarData, rarity: String, add_result: Dictionary = {}) -> void:
	_opening = true
	_set_interactive_enabled(false)
	_continue_btn.visible = false
	_reveal_layer.visible = true
	_reveal_label.text = "Tearing the page..."
	for c in _card_holder.get_children():
		c.queue_free()
	call_deferred("_center_reveal_panel")

	var mystery := PanelContainer.new()
	mystery.custom_minimum_size = Vector2(140, 200)
	UITheme.apply_card_style(mystery, 12)
	var mystery_lbl := Label.new()
	mystery_lbl.text = "?"
	mystery_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mystery_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mystery_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	mystery_lbl.add_theme_font_size_override("font_size", 48)
	mystery.add_child(mystery_lbl)
	_card_holder.add_child(mystery)

	var shake := create_tween()
	shake.tween_property(mystery, "rotation", 0.06, 0.06)
	shake.tween_property(mystery, "rotation", -0.06, 0.06)
	shake.tween_property(mystery, "rotation", 0.04, 0.05)
	shake.tween_property(mystery, "rotation", 0.0, 0.05)
	await shake.finished

	var flip := create_tween()
	flip.tween_property(mystery, "scale:x", 0.0, 0.18)
	await flip.finished
	mystery.queue_free()

	_reveal_label.text = _pull_result_text(familiar, rarity, add_result)
	var card := FamiliarCard.create(familiar)
	_card_holder.add_child(card)
	FamiliarCard.animate_reveal(card)
	_continue_btn.visible = true
	call_deferred("_center_reveal_panel")

	while _opening:
		await get_tree().process_frame


func _pull_result_text(familiar: FamiliarData, rarity: String, add_result: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("%s — %s" % [familiar.display_name, rarity.capitalize()])
	if add_result.get("new_unlock", false):
		lines.append("New familiar unlocked!")
	elif add_result.get("level_up", false):
		lines.append("Level up! Now level %d" % int(add_result.get("new_level", 1)))
	elif add_result.get("max_level_dupe", false):
		lines.append("Max level — +%d Dust" % int(add_result.get("dust_granted", 0)))
	else:
		var level := GameState.get_familiar_level(familiar.id)
		var pages := int(GameState.grimoire_pages.get(familiar.id, 0))
		var prog: Dictionary = FamiliarLeveling.progress_to_next_level(pages, level)
		if not prog.get("maxed", false) and int(prog.get("needed", 0)) > 0:
			lines.append(
				"Duplicate — %d / %d to level %d"
				% [int(prog.get("current", 0)), int(prog.get("needed", 0)), level + 1]
			)
	return "\n".join(lines)
