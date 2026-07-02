extends Control

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const MARGIN_X := 16
const MARGIN_Y := 12
const BTN_SIZE := 48
const TAB_EMOJI_SIZE := 22
const GRID_COLUMNS := 4
const CARD_ASPECT := 1.28

const SCHOOL_TABS := [
	"pyromancy", "nature", "necromancy", "illusion", "military",
]
const CHAPTER_NAMES := {
	"pyromancy": "Pyromancy chapter",
	"nature": "Nature chapter",
	"necromancy": "Necromancy chapter",
	"illusion": "Illusion chapter",
	"military": "Military chapter",
}
const DUAL_KEYS := [
	"pyromancy+nature", "pyromancy+necromancy", "pyromancy+illusion", "pyromancy+military",
	"nature+necromancy", "nature+illusion", "nature+military",
	"necromancy+illusion", "necromancy+military", "illusion+military",
]
const REWARD_MILESTONES := [0.75, 0.5, 0.25]

var _active_tab: String = "pyromancy"
var _tab_buttons: Dictionary = {}
var _content_root: VBoxContainer
var _grid: GridContainer
var _info_layer: CanvasLayer
var _info_backdrop: ColorRect
var _info_panel: PanelContainer


func _ready() -> void:
	_build_ui()
	_build_info_overlay()
	GameState.collection_changed.connect(_refresh_content)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_refresh_content()


func _on_viewport_resized() -> void:
	call_deferred("_layout_grid")
	call_deferred("_layout_info_panel")


func _exit_tree() -> void:
	if GameState.collection_changed.is_connected(_refresh_content):
		GameState.collection_changed.disconnect(_refresh_content)


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

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	outer.add_child(_build_header())
	outer.add_child(_build_tab_row())

	var scroll := MobileScrollContainer.create(false, true)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)

	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", 12)
	scroll.add_child(_content_root)


func _build_info_overlay() -> void:
	_info_layer = CanvasLayer.new()
	_info_layer.layer = 50
	add_child(_info_layer)

	_info_backdrop = ColorRect.new()
	_info_backdrop.visible = false
	_info_backdrop.color = Color(0, 0, 0, 0.55)
	_info_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_info_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_backdrop.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_hide_info()
		elif event is InputEventScreenTouch and event.pressed:
			_hide_info()
	)
	_info_layer.add_child(_info_backdrop)

	_info_panel = PanelContainer.new()
	_info_panel.visible = false
	_info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_info_panel.z_index = 200
	UITheme.apply_card_style(_info_panel, 14)
	_info_layer.add_child(_info_panel)


func _build_header() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	back.add_theme_font_size_override("font_size", 20)
	UITheme.style_icon_button(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file(MAIN_MENU))
	row.add_child(back)

	var title := Label.new()
	title.text = "Grimoire"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(title)

	return row


func _build_tab_row() -> MobileScrollContainer:
	var scroll := MobileScrollContainer.create(true, false)
	scroll.custom_minimum_size.y = BTN_SIZE + 4

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)

	for school in SCHOOL_TABS:
		var btn := _make_tab_button(school)
		row.add_child(btn)
		_tab_buttons[school] = btn

	var bound_btn := _make_tab_button("bound")
	row.add_child(bound_btn)
	_tab_buttons["bound"] = bound_btn

	_style_tab_buttons()
	return scroll


func _make_tab_button(tab_id: String) -> Button:
	var btn := Button.new()
	btn.text = _tab_emoji(tab_id)
	btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
	btn.add_theme_font_size_override("font_size", TAB_EMOJI_SIZE)
	btn.pressed.connect(func(): _set_tab(tab_id))
	return btn


func _tab_emoji(tab_id: String) -> String:
	if tab_id == "bound":
		return "📖"
	return UITheme.school_emoji(tab_id)


func _style_tab_buttons() -> void:
	for key in _tab_buttons:
		var btn: Button = _tab_buttons[key]
		UITheme.style_filter_pill(btn, key == _active_tab)
		btn.custom_minimum_size = Vector2(BTN_SIZE, BTN_SIZE)
		btn.add_theme_font_size_override("font_size", TAB_EMOJI_SIZE)


func _set_tab(tab_id: String) -> void:
	_hide_info()
	_active_tab = tab_id
	_style_tab_buttons()
	_refresh_content()


func _refresh_content() -> void:
	if _content_root == null:
		return
	_hide_info()
	for c in _content_root.get_children():
		c.queue_free()

	if _active_tab == "bound":
		_content_root.add_child(_build_bound_section())
	else:
		_content_root.add_child(_build_school_progress(_active_tab))
		_grid = _build_familiar_grid(_active_tab)
		_content_root.add_child(_grid)
		_content_root.add_child(_build_sigil_card(_active_tab))

	call_deferred("_layout_grid")


func _layout_grid() -> void:
	if _grid == null:
		return
	var inner_w := get_viewport_rect().size.x - float(MARGIN_X * 2)
	_grid.custom_minimum_size.x = inner_w
	var gap := 8.0
	var col_w := floorf((inner_w - gap * float(GRID_COLUMNS - 1)) / float(GRID_COLUMNS))
	var card_h := col_w * CARD_ASPECT
	for child in _grid.get_children():
		if child is Control:
			(child as Control).custom_minimum_size = Vector2(col_w, card_h)


func _build_familiar_grid(school: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	for familiar in DataLoader.get_familiars_by_school(school):
		var owned := GameState.grimoire_pages.has(familiar.id)
		if owned:
			grid.add_child(_make_owned_card(familiar, school))
		else:
			grid.add_child(_make_locked_card(familiar))

	return grid


func _make_owned_card(familiar: FamiliarData, school: String) -> PanelContainer:
	var level := GameState.get_familiar_level(familiar.id)
	var card := FamiliarPortraitCard.create_owned(familiar, school, level)
	card.add_tap_handler(func(): _on_familiar_tapped(familiar.id))
	return card


func _make_locked_card(familiar: FamiliarData) -> PanelContainer:
	var card := FamiliarPortraitCard.create_locked(familiar)
	card.add_tap_handler(func(): _show_locked_info(familiar))
	return card


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


func _on_familiar_tapped(familiar_id: String) -> void:
	var data: FamiliarData = DataLoader.get_familiar(familiar_id)
	if data == null:
		return
	_show_info(data)


func _show_info(data: FamiliarData) -> void:
	_rebuild_info_panel(data, false)
	_info_panel.visible = true
	_info_backdrop.visible = true
	call_deferred("_layout_info_panel")


func _show_locked_info(familiar: FamiliarData) -> void:
	_rebuild_info_panel(familiar, true)
	_info_panel.visible = true
	_info_backdrop.visible = true
	call_deferred("_layout_info_panel")


func _hide_info() -> void:
	_info_panel.visible = false
	_info_backdrop.visible = false


func _rebuild_info_panel(data: FamiliarData, locked: bool) -> void:
	for c in _info_panel.get_children():
		c.queue_free()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_info_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	vbox.add_child(header)

	var emoji_box := PanelContainer.new()
	emoji_box.custom_minimum_size = Vector2(48, 48)
	var sb := StyleBoxFlat.new()
	if locked:
		sb.bg_color = Color(0.12, 0.12, 0.14)
		sb.border_color = Color(0.32, 0.32, 0.36)
		sb.set_border_width_all(1)
	else:
		sb.bg_color = UITheme.school_slot_bg(data.school)
	sb.set_corner_radius_all(12)
	emoji_box.add_theme_stylebox_override("panel", sb)
	header.add_child(emoji_box)

	var emoji := Label.new()
	emoji.text = "🔒" if locked else UITheme.school_emoji(data.school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	emoji.add_theme_font_size_override("font_size", 24)
	if locked:
		emoji.modulate = Color(0.55, 0.55, 0.58)
	emoji_box.add_child(emoji)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_col)

	var name_lbl := Label.new()
	name_lbl.text = "???" if locked else data.display_name
	name_lbl.add_theme_font_size_override("font_size", 17)
	name_lbl.add_theme_color_override("font_color", Color.WHITE if not locked else UITheme.TEXT_DIM)
	title_col.add_child(name_lbl)

	var sub := Label.new()
	if locked:
		sub.text = "%s · Not collected" % UITheme.school_label(data.school)
	else:
		sub.text = "%s · %s · %s" % [
			data.rarity.capitalize(),
			UITheme.school_label(data.school),
			data.role.capitalize(),
		]
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	title_col.add_child(sub)

	if locked:
		var hint := Label.new()
		hint.text = "Tear pages or open packs to discover this familiar."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.custom_minimum_size.x = 300
		hint.add_theme_font_size_override("font_size", 12)
		hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		vbox.add_child(hint)
	else:
		var level := GameState.get_familiar_level(data.id)
		var pages := int(GameState.grimoire_pages.get(data.id, 1))
		var lvl_lbl := Label.new()
		lvl_lbl.text = "Level %d / %d" % [level, FamiliarLeveling.max_level()]
		lvl_lbl.add_theme_font_size_override("font_size", 13)
		lvl_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
		vbox.add_child(lvl_lbl)

		var prog: Dictionary = FamiliarLeveling.progress_to_next_level(pages, level)
		if prog.get("maxed", false):
			var maxed := Label.new()
			maxed.text = "Max level — duplicates grant Dust"
			maxed.add_theme_font_size_override("font_size", 12)
			maxed.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			vbox.add_child(maxed)
		else:
			var progress := Label.new()
			progress.text = "Next level: %d / %d duplicates" % [
				int(prog.get("current", 0)),
				int(prog.get("needed", 0)),
			]
			progress.add_theme_font_size_override("font_size", 12)
			progress.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
			vbox.add_child(progress)

		var pages_lbl := Label.new()
		pages_lbl.text = "Pages collected: ×%d" % pages
		pages_lbl.add_theme_font_size_override("font_size", 12)
		pages_lbl.add_theme_color_override("font_color", UITheme.TEXT_DIM)
		vbox.add_child(pages_lbl)

		var leveled_stats := FamiliarLeveling.stat_multiplier(level)
		var stats := Label.new()
		stats.text = "SPD %d   HP %d   ATK %d" % [
			data.speed,
			maxi(1, int(round(float(data.hp) * leveled_stats))),
			maxi(1, int(round(float(data.atk) * leveled_stats))),
		]
		stats.add_theme_font_size_override("font_size", 13)
		stats.add_theme_color_override("font_color", UITheme.TEXT)
		vbox.add_child(stats)

		var passive := Label.new()
		passive.text = data.passive_text
		passive.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		passive.custom_minimum_size.x = 300
		passive.add_theme_font_size_override("font_size", 12)
		passive.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
		vbox.add_child(passive)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, BTN_SIZE)
	close_btn.add_theme_font_size_override("font_size", 16)
	UITheme.style_accent_button(close_btn)
	close_btn.pressed.connect(_hide_info)
	vbox.add_child(close_btn)

	call_deferred("_fit_info_panel")


func _fit_info_panel() -> void:
	if _info_panel:
		_info_panel.custom_minimum_size = _info_panel.get_combined_minimum_size()
		_layout_info_panel()


func _layout_info_panel() -> void:
	if _info_panel == null or not _info_panel.visible:
		return
	var vp := get_viewport_rect().size
	var panel_w: float = maxf(_info_panel.size.x, _info_panel.custom_minimum_size.x)
	var panel_h: float = maxf(_info_panel.size.y, _info_panel.custom_minimum_size.y)
	_info_panel.position = Vector2(
		(vp.x - panel_w) * 0.5,
		(vp.y - panel_h) * 0.5
	)


func _build_school_progress(school: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	var owned := _count_owned(school)
	var total := DataLoader.get_familiars_by_school(school).size()
	var pct := GameState.get_school_completion(school)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var chapter := Label.new()
	chapter.text = CHAPTER_NAMES.get(school, "%s chapter" % school.capitalize())
	chapter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter.add_theme_font_size_override("font_size", 14)
	chapter.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(chapter)

	var count_lbl := Label.new()
	count_lbl.text = "%d / %d" % [owned, total]
	count_lbl.add_theme_font_size_override("font_size", 14)
	count_lbl.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(count_lbl)

	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 8
	bar.max_value = 1.0
	bar.value = pct
	bar.show_percentage = false
	_style_progress_bar(bar, school)
	vbox.add_child(bar)

	var hint := Label.new()
	hint.text = _next_reward_text(school, pct)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	vbox.add_child(hint)

	return card


func _style_progress_bar(bar: ProgressBar, school: String) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.14, 0.14, 0.16)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.school_color(school)
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)


func _next_reward_text(school: String, pct: float) -> String:
	if pct >= 1.0:
		return "Chapter complete — grimoire sigil unlocked."
	for milestone in REWARD_MILESTONES:
		if pct < milestone:
			return "Next reward at %d%% — a free common familiar." % int(milestone * 100.0)
	return "Reach 100%% to unlock the %s grimoire sigil." % UITheme.school_label(school)


func _build_sigil_card(school: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 12)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "Grimoire sigil"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var complete := GameState.get_school_completion(school) >= 1.0
	var lock := Label.new()
	lock.text = "✓" if complete else "🔒"
	lock.add_theme_font_size_override("font_size", 14)
	lock.modulate = UITheme.SUCCESS if complete else Color(0.55, 0.55, 0.58)
	header.add_child(lock)

	var body := Label.new()
	body.text = _sigil_text(school, complete)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 11)
	body.add_theme_color_override("font_color", UITheme.TEXT_MUTED if not complete else UITheme.TEXT)
	vbox.add_child(body)

	return card


func _sigil_text(school: String, complete: bool) -> String:
	var mono_cfg: Dictionary = DataLoader.synergy_config.get("mono_school", {}).get(school, {})
	var threshold: int = int(mono_cfg.get("threshold", 2))
	var school_name := UITheme.school_label(school)
	if complete:
		var bonus_name: String = str(mono_cfg.get("name", "School bonus"))
		return "Sigil active — %s applies when %d or more %s familiars are in your coven." % [
			bonus_name, threshold, school_name,
		]
	return "Reach 100%% to unlock a passive perk for any squad fielding %d or more %s familiars." % [
		threshold, school_name,
	]


func _build_bound_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Bound pages"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color.WHITE)
	section.add_child(heading)

	var sub := Label.new()
	sub.text = "Win battles with dual-school squads to bind combo pages."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	section.add_child(sub)

	var dual_cfg: Dictionary = DataLoader.synergy_config.get("dual_school", {})
	for key in DUAL_KEYS:
		section.add_child(_make_bound_card(key, dual_cfg.get(key, {})))

	return section


func _make_bound_card(key: String, info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.apply_compact_card(card, 12)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)

	var schools := key.split("+")
	var emoji := Label.new()
	if schools.size() >= 2:
		emoji.text = "%s%s" % [UITheme.school_emoji(schools[0]), UITheme.school_emoji(schools[1])]
	else:
		emoji.text = "📖"
	emoji.add_theme_font_size_override("font_size", 18)
	row.add_child(emoji)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var wins: int = int(GameState.bound_pages.get(key, 0))
	var bound := wins > 0

	var title := Label.new()
	title.text = str(info.get("name", key))
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UITheme.BLUE if bound else Color.WHITE)
	text_col.add_child(title)

	var combo := Label.new()
	combo.text = key.replace("+", " + ").capitalize()
	combo.add_theme_font_size_override("font_size", 11)
	combo.add_theme_color_override("font_color", UITheme.TEXT_MUTED)
	text_col.add_child(combo)

	var wins_lbl := Label.new()
	wins_lbl.text = "Wins: %d" % wins
	wins_lbl.add_theme_font_size_override("font_size", 11)
	wins_lbl.add_theme_color_override("font_color", UITheme.SUCCESS if bound else UITheme.TEXT_DIM)
	text_col.add_child(wins_lbl)

	return card


func _count_owned(school: String) -> int:
	var count := 0
	for f in DataLoader.get_familiars_by_school(school):
		if GameState.grimoire_pages.has(f.id):
			count += 1
	return count
