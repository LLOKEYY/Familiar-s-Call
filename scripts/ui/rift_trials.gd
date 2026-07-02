extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const BATTLE := "res://scenes/battle/battle.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12


func _trial_theme(trial_id: String) -> Dictionary:
	match trial_id:
		"trial_1":
			return {"emoji": "🔥", "school": "pyromancy", "accent": UITheme.school_color("pyromancy")}
		"trial_2":
			return {"emoji": "🌿", "school": "nature", "accent": UITheme.school_color("nature")}
		"trial_3":
			return {"emoji": "💀", "school": "necromancy", "accent": UITheme.school_color("necromancy")}
		"trial_4":
			return {"emoji": "✨", "school": "illusion", "accent": UITheme.school_color("illusion")}
		"trial_5":
			return {"emoji": "🛡️", "school": "military", "accent": UITheme.school_color("military")}
	return {"emoji": "◎", "school": "military", "accent": UITheme.BLUE}

var _dust_label: Label
var _lumen_label: Label
var _list: VBoxContainer


func _ready() -> void:
	_build_ui()
	GameState.currencies_changed.connect(_refresh_currencies)
	_refresh_currencies()
	_populate()


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
	root.add_child(_build_header_card())
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	root.add_child(_list)


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


func _build_header_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_card_style(card, 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 4)
	row.add_child(text_col)

	var subtitle := Label.new()
	subtitle.text = "Campaign"
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", UITheme.BLUE)
	text_col.add_child(subtitle)

	var title := Label.new()
	title.text = "Rift Trials"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	text_col.add_child(title)

	var hint := Label.new()
	hint.text = "Clear trials in order to earn Dust"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(hint)

	var emblem := Label.new()
	emblem.text = "⚔"
	emblem.add_theme_font_size_override("font_size", 26)
	emblem.add_theme_color_override("font_color", UITheme.BLUE)
	row.add_child(emblem)
	return card


func _populate() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()

	var index := 0
	for trial_variant in DataLoader.rift_trials:
		index += 1
		var trial: Dictionary = trial_variant
		_list.add_child(_make_trial_card(trial, index))


func _make_trial_card(trial: Dictionary, index: int) -> PanelContainer:
	var trial_id: String = trial.get("id", "")
	var cleared := GameState.is_trial_cleared(trial_id)
	var locked := not _requirements_met(trial.get("required_cleared", []))
	var theme: Dictionary = _trial_theme(trial_id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_trial_card_style(card, cleared, locked, theme.get("accent", UITheme.BLUE))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(48, 48)
	var icon_sb := StyleBoxFlat.new()
	icon_sb.bg_color = UITheme.school_slot_bg(theme.get("school", "military"))
	icon_sb.set_corner_radius_all(10)
	icon_box.add_theme_stylebox_override("panel", icon_sb)
	row.add_child(icon_box)

	var icon_lbl := Label.new()
	icon_lbl.text = theme.get("emoji", "◎")
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_lbl.add_theme_font_size_override("font_size", 22)
	icon_box.add_child(icon_lbl)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 6)
	row.add_child(body)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	body.add_child(title_row)

	var name_lbl := Label.new()
	name_lbl.text = "%d. %s" % [index, trial.get("name", "Trial")]
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.clip_text = true
	title_row.add_child(name_lbl)

	var badge := Label.new()
	badge.text = _status_badge(cleared, locked)
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", _status_color(cleared, locked))
	title_row.add_child(badge)

	var desc := Label.new()
	desc.text = trial.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	body.add_child(desc)

	var meta_row := HBoxContainer.new()
	meta_row.add_theme_constant_override("separation", 8)
	body.add_child(meta_row)

	var reward := Label.new()
	reward.text = "★ %d Dust" % int(trial.get("dust_reward", 0))
	reward.add_theme_font_size_override("font_size", 12)
	reward.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	meta_row.add_child(reward)

	var squad_lbl := Label.new()
	squad_lbl.text = "%d rivals" % _squad_size(trial)
	squad_lbl.add_theme_font_size_override("font_size", 12)
	squad_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	meta_row.add_child(squad_lbl)

	if not cleared and not locked:
		var fight := Button.new()
		fight.text = "Fight"
		fight.custom_minimum_size = Vector2(0, 40)
		UITheme.style_accent_button(fight)
		var t: Dictionary = trial
		fight.pressed.connect(func(): _start_trial(t))
		body.add_child(fight)
	elif locked:
		var locked_hint := Label.new()
		locked_hint.text = "Clear the previous trial to unlock"
		locked_hint.add_theme_font_size_override("font_size", 11)
		locked_hint.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		body.add_child(locked_hint)
	elif cleared:
		var cleared_hint := Label.new()
		cleared_hint.text = "✓ Cleared"
		cleared_hint.add_theme_font_size_override("font_size", 12)
		cleared_hint.add_theme_color_override("font_color", UITheme.SUCCESS)
		body.add_child(cleared_hint)

	return card


func _apply_trial_card_style(card: PanelContainer, cleared: bool, locked: bool, accent: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	if cleared:
		sb.border_color = Color(0.28, 0.48, 0.32)
	elif locked:
		sb.border_color = Color(0.24, 0.24, 0.28)
	else:
		sb.border_color = accent
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	card.add_theme_stylebox_override("panel", sb)
	if locked:
		card.modulate = Color(0.72, 0.72, 0.76, 1.0)
	else:
		card.modulate = Color.WHITE


func _status_badge(cleared: bool, locked: bool) -> String:
	if cleared:
		return "CLEARED"
	if locked:
		return "LOCKED"
	return "OPEN"


func _status_color(cleared: bool, locked: bool) -> Color:
	if cleared:
		return UITheme.SUCCESS
	if locked:
		return UITheme.TEXT_DIM
	return UITheme.BLUE


func _squad_size(trial: Dictionary) -> int:
	return trial.get("enemy_squad", []).size()


func _requirements_met(required: Array) -> bool:
	for id in required:
		if not GameState.is_trial_cleared(id):
			return false
	return true


func _start_trial(trial: Dictionary) -> void:
	if GameState.active_coven.size() < 6:
		return
	var squad: Array = trial.get("enemy_squad", []).duplicate(true)
	if squad.size() < 6:
		push_warning("Trial %s has fewer than 6 enemies" % trial.get("id", ""))
	GameState.pending_battle = {
		"mode": "rift",
		"trial_id": trial.get("id", ""),
		"trial_name": trial.get("name", ""),
		"enemy_squad": squad,
		"dust_reward": int(trial.get("dust_reward", 0)),
	}
	get_tree().change_scene_to_file(BATTLE)
