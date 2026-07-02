extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12
const TIER_COL_W := 92
const TIER_HEADER_H := 20
const ROW_GAP := 8
const SHOWCASE_MIN_H := 128

var _dust_label: Label
var _lumen_label: Label
var _tier_label: Label
var _xp_bar: ProgressBar
var _xp_detail: Label
var _track_scroll: MobileScrollContainer
var _track_row: HBoxContainer
var _track_card: PanelContainer
var _track_labels_col: VBoxContainer
var _free_row_lbl: Label
var _paid_row_lbl: Label
var _season_showcase: PanelContainer
var _showcase_name: Label
var _showcase_detail: Label
var _showcase_tier: Label
var _showcase_art: PanelContainer
var _showcase_emoji: Label
var _premium_banner: PanelContainer
var _toast_label: Label
var _reward_cell_h: int = 72


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh_currencies)
	GameState.battle_pass_changed.connect(_refresh_all)
	get_viewport().size_changed.connect(func(): call_deferred("_layout_track_heights"))
	_refresh_all()
	call_deferred("_layout_track_heights")


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
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_season_header())
	root.add_child(_build_progress_card())
	_premium_banner = _build_premium_banner()
	root.add_child(_premium_banner)
	_track_card = _build_track_area()
	root.add_child(_track_card)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_label.add_theme_color_override("font_color", UITheme.SUCCESS)
	_toast_label.visible = false
	root.add_child(_toast_label)


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


func _build_season_header() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_season_style(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var cfg: Dictionary = DataLoader.battle_pass_config
	var subtitle := Label.new()
	subtitle.text = cfg.get("season_subtitle", "Season")
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))
	text_col.add_child(subtitle)

	var title := Label.new()
	title.text = cfg.get("season_name", "Battle Pass")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(title)

	var hint := Label.new()
	hint.text = "Win battles to earn pass XP"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(hint)

	var emblem := Label.new()
	emblem.text = "◎"
	emblem.add_theme_font_size_override("font_size", 28)
	emblem.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	row.add_child(emblem)
	return card


func _build_progress_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var row := HBoxContainer.new()
	_tier_label = Label.new()
	_tier_label.add_theme_font_size_override("font_size", 15)
	_tier_label.add_theme_color_override("font_color", Color.WHITE)
	_tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_tier_label)

	_xp_detail = Label.new()
	_xp_detail.add_theme_font_size_override("font_size", 12)
	_xp_detail.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	row.add_child(_xp_detail)
	vbox.add_child(row)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size.y = 10
	_xp_bar.show_percentage = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.12, 0.15)
	sb.set_corner_radius_all(5)
	_xp_bar.add_theme_stylebox_override("background", sb)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.95, 0.72, 0.22)
	fill.set_corner_radius_all(5)
	_xp_bar.add_theme_stylebox_override("fill", fill)
	vbox.add_child(_xp_bar)
	return card


func _build_premium_banner() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_premium_banner_style(card)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var title := Label.new()
	title.text = "Premium track"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(title)

	var sub := Label.new()
	sub.text = "Unlock bonus rewards + season card"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(sub)

	var btn := Button.new()
	btn.text = DataLoader.battle_pass_config.get("premium_price", "$4.99")
	btn.custom_minimum_size = Vector2(88, 40)
	_style_premium_button(btn)
	btn.pressed.connect(_on_unlock_premium)
	row.add_child(btn)
	return card


func _build_track_area() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 12)

	var outer := VBoxContainer.new()
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 10)
	card.add_child(outer)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 1.35
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	outer.add_child(margin)

	var area := HBoxContainer.new()
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.add_theme_constant_override("separation", 8)
	margin.add_child(area)

	_track_labels_col = VBoxContainer.new()
	_track_labels_col.custom_minimum_size.x = 36
	_track_labels_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_labels_col.add_theme_constant_override("separation", ROW_GAP)
	area.add_child(_track_labels_col)

	var tier_spacer := Control.new()
	tier_spacer.custom_minimum_size.y = TIER_HEADER_H
	_track_labels_col.add_child(tier_spacer)

	_free_row_lbl = Label.new()
	_free_row_lbl.text = "Free"
	_free_row_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_free_row_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_free_row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_row_lbl.add_theme_font_size_override("font_size", 11)
	_free_row_lbl.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	_track_labels_col.add_child(_free_row_lbl)

	_paid_row_lbl = Label.new()
	_paid_row_lbl.text = "Paid"
	_paid_row_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_paid_row_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_paid_row_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paid_row_lbl.add_theme_font_size_override("font_size", 11)
	_paid_row_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	_track_labels_col.add_child(_paid_row_lbl)

	area.add_child(_build_track_scroll())

	var bottom_pad := MarginContainer.new()
	bottom_pad.add_theme_constant_override("margin_left", 8)
	bottom_pad.add_theme_constant_override("margin_right", 8)
	bottom_pad.add_theme_constant_override("margin_bottom", 4)
	bottom_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_pad.size_flags_stretch_ratio = 1.0
	outer.add_child(bottom_pad)

	var bottom_col := VBoxContainer.new()
	bottom_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bottom_col.add_theme_constant_override("separation", 6)
	bottom_pad.add_child(bottom_col)

	bottom_col.add_child(_build_season_showcase())

	var hint := Label.new()
	hint.text = "Swipe tiers left or right"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	bottom_col.add_child(hint)

	return card


func _build_season_showcase() -> PanelContainer:
	_season_showcase = PanelContainer.new()
	_season_showcase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_season_showcase.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_season_showcase.custom_minimum_size.y = SHOWCASE_MIN_H
	_apply_showcase_style(_season_showcase)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_season_showcase.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	_showcase_art = PanelContainer.new()
	_showcase_art.custom_minimum_size = Vector2(88, 0)
	_showcase_art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = UITheme.school_slot_bg("pyromancy")
	art_sb.set_corner_radius_all(10)
	_showcase_art.add_theme_stylebox_override("panel", art_sb)
	row.add_child(_showcase_art)

	_showcase_emoji = Label.new()
	_showcase_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_showcase_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_showcase_emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	_showcase_emoji.add_theme_font_size_override("font_size", 36)
	_showcase_art.add_child(_showcase_emoji)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var badge := Label.new()
	badge.text = "★ Season grand prize"
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	text_col.add_child(badge)

	_showcase_name = Label.new()
	_showcase_name.add_theme_font_size_override("font_size", 17)
	_showcase_name.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(_showcase_name)

	_showcase_detail = Label.new()
	_showcase_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_showcase_detail.add_theme_font_size_override("font_size", 12)
	_showcase_detail.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(_showcase_detail)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_col.add_child(spacer)

	_showcase_tier = Label.new()
	_showcase_tier.add_theme_font_size_override("font_size", 12)
	text_col.add_child(_showcase_tier)

	return _season_showcase


func _build_track_scroll() -> MobileScrollContainer:
	_track_scroll = MobileScrollContainer.create(true, false)
	_track_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_track_row = HBoxContainer.new()
	_track_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_track_row.add_theme_constant_override("separation", ROW_GAP)
	_track_scroll.add_child(_track_row)
	return _track_scroll


func _clamp_scroll(value: int) -> int:
	if _track_scroll == null:
		return value
	return _track_scroll.clamp_horizontal(value)


func _refresh_all() -> void:
	_refresh_currencies()
	_refresh_progress()
	_refresh_premium_banner()
	_refresh_season_showcase()
	_rebuild_track()
	call_deferred("_layout_track_heights")


func _refresh_currencies() -> void:
	if _dust_label:
		_dust_label.text = str(GameState.dust)
	if _lumen_label:
		_lumen_label.text = str(GameState.lumen)


func _refresh_progress() -> void:
	var prog: Dictionary = GameState.get_battle_pass_tier_progress()
	var max_tier := GameState.get_battle_pass_max_tier()
	_tier_label.text = "Tier %d / %d" % [prog.get("tier", 1), max_tier]
	if prog.get("needed", 1) <= 1 and prog.get("tier", 1) >= max_tier:
		_xp_detail.text = "%d XP · Max tier" % GameState.battle_pass_xp
		_xp_bar.value = 100.0
	else:
		_xp_detail.text = "%d / %d XP" % [prog.get("current", 0), prog.get("needed", 1)]
		_xp_bar.value = float(prog.get("ratio", 0.0)) * 100.0


func _refresh_premium_banner() -> void:
	if _premium_banner == null:
		return
	_premium_banner.visible = not GameState.battle_pass_premium


func _get_season_promo() -> Dictionary:
	for entry in DataLoader.battle_pass_config.get("tiers", []):
		var prem: Dictionary = entry.get("premium", {})
		if prem.get("type", "") == "promo_card":
			return {"tier": int(entry.get("tier", 15)), "reward": prem}
	return {}


func _refresh_season_showcase() -> void:
	if _season_showcase == null:
		return
	var promo := _get_season_promo()
	if promo.is_empty():
		_season_showcase.visible = false
		return
	_season_showcase.visible = true

	var reward: Dictionary = promo.get("reward", {})
	var tier := int(promo.get("tier", 15))
	var fid: String = reward.get("familiar_id", "")
	var data: FamiliarData = DataLoader.get_familiar(fid)
	if data == null:
		return

	var art_sb := _showcase_art.get_theme_stylebox("panel") as StyleBoxFlat
	if art_sb != null:
		art_sb.bg_color = UITheme.school_slot_bg(data.school)
		_showcase_art.add_theme_stylebox_override("panel", art_sb)
	_showcase_emoji.text = UITheme.school_emoji(data.school)
	_showcase_emoji.add_theme_color_override("font_color", UITheme.school_icon_color(data.school))
	_showcase_name.text = data.display_name
	_showcase_detail.text = "%s · %s familiar" % [data.rarity.capitalize(), data.school.capitalize()]

	var current_tier := GameState.get_battle_pass_tier()
	var claimed := GameState.is_battle_pass_reward_claimed(tier, true)
	if claimed:
		_showcase_tier.text = "Claimed on premium track"
		_showcase_tier.add_theme_color_override("font_color", UITheme.SUCCESS)
	elif current_tier >= tier and GameState.battle_pass_premium:
		_showcase_tier.text = "Tier %d unlocked — claim in track above" % tier
		_showcase_tier.add_theme_color_override("font_color", UITheme.BLUE)
	elif GameState.battle_pass_premium:
		_showcase_tier.text = "Reach tier %d to claim" % tier
		_showcase_tier.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	else:
		_showcase_tier.text = "Premium track · Tier %d" % tier
		_showcase_tier.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))


func _layout_track_heights() -> void:
	if _track_scroll == null:
		return
	var scroll_h := int(_track_scroll.size.y)
	if scroll_h < 80:
		return
	_reward_cell_h = maxi(72, int((scroll_h - TIER_HEADER_H - ROW_GAP * 2) * 0.5))
	_apply_reward_cell_heights()
	_update_track_row_min_height()


func _apply_reward_cell_heights() -> void:
	if _track_row == null:
		return
	for col in _track_row.get_children():
		if col is VBoxContainer:
			for child in col.get_children():
				if child is PanelContainer:
					child.custom_minimum_size.y = _reward_cell_h


func _update_track_row_min_height() -> void:
	if _track_row == null:
		return
	_track_row.custom_minimum_size.y = TIER_HEADER_H + ROW_GAP + _reward_cell_h + ROW_GAP + _reward_cell_h


func _rebuild_track() -> void:
	if _track_row == null:
		return
	for c in _track_row.get_children():
		c.queue_free()

	var current_tier := GameState.get_battle_pass_tier()
	for entry in DataLoader.battle_pass_config.get("tiers", []):
		var tier := int(entry.get("tier", 0))
		if tier <= 0:
			continue
		_track_row.add_child(_make_tier_column(tier, entry, current_tier))

	call_deferred("_scroll_to_current_tier", current_tier)
	call_deferred("_update_scroll_limits")
	call_deferred("_layout_track_heights")


func _update_scroll_limits() -> void:
	if _track_scroll == null or _track_row == null:
		return
	_track_scroll.scroll_horizontal = _clamp_scroll(_track_scroll.scroll_horizontal)


func _scroll_to_current_tier(tier: int) -> void:
	if _track_scroll == null or _track_row == null:
		return
	var idx := tier - 1
	if idx < 0 or idx >= _track_row.get_child_count():
		return
	var col: Control = _track_row.get_child(idx)
	var target_x := col.position.x - 24.0
	_track_scroll.scroll_horizontal = _clamp_scroll(int(maxi(0.0, target_x)))


func _make_tier_column(tier: int, entry: Dictionary, current_tier: int) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = TIER_COL_W
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", ROW_GAP)

	var tier_lbl := Label.new()
	tier_lbl.text = str(tier)
	tier_lbl.custom_minimum_size.y = TIER_HEADER_H
	tier_lbl.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tier_lbl.add_theme_font_size_override("font_size", 12)
	if tier <= current_tier:
		tier_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	else:
		tier_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	col.add_child(tier_lbl)

	var unlocked := tier <= current_tier
	var free_cell := _make_reward_cell(tier, entry.get("free", {}), false, unlocked)
	free_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(free_cell)
	var prem_cell := _make_reward_cell(tier, entry.get("premium", {}), true, unlocked)
	prem_cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(prem_cell)
	return col


func _make_reward_cell(tier: int, reward: Dictionary, premium: bool, tier_unlocked: bool) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(TIER_COL_W, _reward_cell_h)
	cell.clip_contents = true
	_style_reward_cell(cell, premium, tier_unlocked, tier, premium)

	var body := MarginContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.add_theme_constant_override("margin_left", 6)
	body.add_theme_constant_override("margin_right", 6)
	body.add_theme_constant_override("margin_top", 8)
	body.add_theme_constant_override("margin_bottom", 8)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(body)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(vbox)

	var icon := Label.new()
	icon.text = _reward_icon(reward)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 26)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon)

	var caption := Label.new()
	caption.text = _reward_caption(reward)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.clip_text = true
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.custom_minimum_size = Vector2(TIER_COL_W - 16, 22)
	caption.add_theme_font_size_override("font_size", 11)
	caption.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(caption)

	var claimed := GameState.is_battle_pass_reward_claimed(tier, premium)
	var can_claim := tier_unlocked and not claimed
	if premium and not GameState.battle_pass_premium:
		can_claim = false

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 11)
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	status.offset_bottom = -4
	status.offset_top = -18
	if claimed:
		status.text = "✓"
		status.add_theme_color_override("font_color", UITheme.SUCCESS)
	elif can_claim:
		status.text = "Tap"
		status.add_theme_color_override("font_color", UITheme.BLUE)
		_add_claim_button(cell, tier, premium)
	elif premium and not GameState.battle_pass_premium:
		status.text = "🔒"
	else:
		status.text = ""
	cell.add_child(status)

	if reward.get("type", "") == "promo_card":
		var badge := Label.new()
		badge.text = "Season"
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 8)
		badge.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
		badge.set_anchors_preset(Control.PRESET_TOP_WIDE)
		badge.offset_top = 2
		badge.offset_bottom = 12
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(badge)

	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return cell


func _add_claim_button(cell: Control, tier: int, premium: bool) -> void:
	var btn := Button.new()
	btn.flat = true
	btn.text = ""
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	btn.offset_top = -26
	btn.offset_bottom = 0
	var sb := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	btn.pressed.connect(func(): _on_claim(tier, premium))
	cell.add_child(btn)


func _reward_icon(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"dust":
			return "★"
		"lumen":
			return "◆"
		"page":
			return "▤"
		"promo_card":
			var data: FamiliarData = DataLoader.get_familiar(reward.get("familiar_id", ""))
			if data != null:
				return UITheme.school_emoji(data.school)
			return "✦"
	return "?"


func _reward_caption(reward: Dictionary) -> String:
	match reward.get("type", ""):
		"dust":
			return "%d Dust" % int(reward.get("amount", 0))
		"lumen":
			return "%d Lumen" % int(reward.get("amount", 0))
		"page", "promo_card":
			var data: FamiliarData = DataLoader.get_familiar(reward.get("familiar_id", ""))
			if data != null:
				return UITheme.familiar_brief_name(data.display_name)
			return "Page"
	return ""


func _on_claim(tier: int, premium: bool) -> void:
	var result: Dictionary = GameState.claim_battle_pass_reward(tier, premium)
	if result.get("ok", false):
		_show_toast(result.get("message", "Claimed!"))
		_refresh_all()
	else:
		_show_toast(result.get("error", "Cannot claim"), false)


func _on_unlock_premium() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Unlock premium track?"
	dlg.dialog_text = "Premium unlock is a debug grant for now — real purchases come later."
	dlg.ok_button_text = "Unlock"
	dlg.cancel_button_text = "Cancel"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func():
		GameState.unlock_battle_pass_premium()
		SaveManager.save_game()
		_refresh_all()
		dlg.queue_free()
	)
	dlg.canceled.connect(dlg.queue_free)


func _show_toast(text: String, success: bool = true) -> void:
	if _toast_label == null:
		return
	_toast_label.text = text
	_toast_label.add_theme_color_override(
		"font_color",
		UITheme.SUCCESS if success else Color(0.92, 0.42, 0.38)
	)
	_toast_label.visible = true
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func(): _toast_label.visible = false)


func _apply_season_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = Color(0.55, 0.38, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)


func _apply_showcase_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.10)
	sb.border_color = Color(0.75, 0.58, 0.20)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)


func _apply_premium_banner_style(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = Color(0.55, 0.42, 0.18)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)


func _style_premium_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.72, 0.22)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color(0.12, 0.10, 0.06))


func _style_reward_cell(
	cell: PanelContainer,
	premium: bool,
	tier_unlocked: bool,
	tier: int,
	is_premium_track: bool
) -> void:
	var sb := StyleBoxFlat.new()
	var claimed := GameState.is_battle_pass_reward_claimed(tier, is_premium_track)
	if claimed:
		sb.bg_color = Color(0.10, 0.14, 0.11)
		sb.border_color = Color(0.28, 0.48, 0.32)
	elif tier_unlocked and (not is_premium_track or GameState.battle_pass_premium):
		sb.bg_color = Color(0.16, 0.16, 0.20) if not premium else Color(0.18, 0.15, 0.10)
		sb.border_color = UITheme.BLUE if not premium else Color(0.75, 0.58, 0.20)
	else:
		sb.bg_color = Color(0.11, 0.11, 0.13)
		sb.border_color = Color(0.20, 0.20, 0.24)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 0
	sb.content_margin_right = 0
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	cell.add_theme_stylebox_override("panel", sb)
