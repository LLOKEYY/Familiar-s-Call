extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12

const LUMEN_BUNDLES := [
	{"lumen": 100, "subtitle": "Spark pouch", "price": "$1.99"},
	{"lumen": 280, "subtitle": "+12% bonus", "price": "$4.99"},
	{"lumen": 600, "subtitle": "+20% bonus", "price": "$9.99"},
	{"lumen": 1300, "subtitle": "+30% bonus", "price": "$19.99"},
]

var _dust_label: Label
var _lumen_label: Label


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh_currencies)
	_refresh_currencies()


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

	root.add_child(_build_top_bar())
	root.add_child(_build_featured_card())
	root.add_child(_build_bundles_section())
	root.add_child(_build_new_player_bundle())


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


func _refresh_currencies() -> void:
	if _dust_label:
		_dust_label.text = str(GameState.dust)
	if _lumen_label:
		_lumen_label.text = str(GameState.lumen)


func _build_featured_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_featured_style(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	vbox.add_child(_make_badge("Best value"))

	var title := Label.new()
	title.text = "Apprentice's path"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Season 3 · 8 tomes worth of rewards"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(subtitle)

	var btn := Button.new()
	btn.text = "$7.99 · Unlock premium"
	btn.custom_minimum_size.y = 44
	UITheme.style_accent_button(btn)
	btn.pressed.connect(_on_battle_pass_pressed)
	vbox.add_child(btn)

	return card


func _build_bundles_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Lumen bundles"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color.WHITE)
	section.add_child(heading)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	section.add_child(grid)

	for bundle in LUMEN_BUNDLES:
		grid.add_child(_make_bundle_card(bundle))

	return section


func _make_bundle_card(bundle: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 108)
	UITheme.apply_compact_card(card, 12)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		_on_bundle_input(event, int(bundle.get("lumen", 0)))
	)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(vbox)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(top)

	var icon := Label.new()
	icon.text = "◆"
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", UITheme.BLUE)
	top.add_child(icon)

	var amount := Label.new()
	amount.text = "%d Lumen" % int(bundle.get("lumen", 0))
	amount.add_theme_font_size_override("font_size", 15)
	amount.add_theme_color_override("font_color", Color.WHITE)
	top.add_child(amount)

	var sub := Label.new()
	sub.text = str(bundle.get("subtitle", ""))
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	var price := Label.new()
	price.text = str(bundle.get("price", ""))
	price.add_theme_font_size_override("font_size", 14)
	price.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(price)

	return card


func _build_new_player_bundle() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 12)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		_on_new_player_input(event)
	)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var gift := Label.new()
	gift.text = "🎁"
	gift.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gift.add_theme_font_size_override("font_size", 28)
	row.add_child(gift)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_col)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(title_row)

	var title := Label.new()
	title.text = "New player bundle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(title)

	var price := Label.new()
	price.text = "$4.99"
	price.add_theme_font_size_override("font_size", 15)
	price.add_theme_color_override("font_color", Color.WHITE)
	title_row.add_child(price)

	var desc := Label.new()
	desc.text = "500 Lumen, 3 sealed tomes, and a guaranteed rare."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(desc)

	return card


func _apply_featured_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = UITheme.BLUE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)


func _make_badge(text: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.BLUE
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	badge.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(lbl)
	return badge


func _on_bundle_input(event: InputEvent, lumen: int) -> void:
	if not _is_tap(event):
		return
	_grant_lumen(lumen)


func _on_new_player_input(event: InputEvent) -> void:
	if not _is_tap(event):
		return
	_grant_lumen(500, "New player bundle unlocked! (MVP: 500 Lumen granted)")


func _on_battle_pass_pressed() -> void:
	_show_notice(
		"Apprentice's Path",
		"Battle pass rewards are coming in a future update. Real purchases are not enabled in this MVP build."
	)


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _grant_lumen(amount: int, message: String = "") -> void:
	EconomyManager.grant_debug_lumen(amount)
	var msg := message if not message.is_empty() else "+%d Lumen added (debug grant for testing)" % amount
	_show_notice("Purchase", msg)


func _show_notice(title: String, text: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = title
	dlg.dialog_text = text
	dlg.ok_button_text = "OK"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(dlg.queue_free)
