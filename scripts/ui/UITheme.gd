class_name UITheme
extends RefCounted

const SCHOOL_COLORS := {
	"pyromancy": Color(0.91, 0.36, 0.30),
	"nature": Color(0.35, 0.72, 0.45),
	"necromancy": Color(0.55, 0.35, 0.75),
	"illusion": Color(0.35, 0.55, 0.92),
	"military": Color(0.55, 0.58, 0.62),
}

const RARITY_COLORS := {
	"common": Color(0.65, 0.65, 0.68),
	"rare": Color(0.30, 0.55, 0.95),
	"epic": Color(0.65, 0.35, 0.90),
	"legendary": Color(0.95, 0.75, 0.25),
}

const BG := Color(0.10, 0.08, 0.16)
const MOBILE_BG := Color(0.05, 0.05, 0.065)
const PANEL := Color(0.16, 0.12, 0.24)
const CARD := Color(0.14, 0.14, 0.165)
const CARD_BORDER := Color(0.22, 0.22, 0.26)
const ACCENT := Color(0.79, 0.64, 0.15)
const BLUE := Color(0.28, 0.52, 0.96)
const TEXT := Color(0.92, 0.88, 0.82)
const TEXT_MUTED := Color(0.55, 0.56, 0.60)
const TEXT_DIM := Color(0.38, 0.39, 0.42)
const PRIMARY_BTN := Color(0.96, 0.96, 0.97)
const SUCCESS := Color(0.35, 0.78, 0.48)
const SCHOOL_SLOT_BG := {
	"pyromancy": Color(0.94, 0.82, 0.78),
	"nature": Color(0.78, 0.92, 0.84),
	"necromancy": Color(0.86, 0.80, 0.94),
	"illusion": Color(0.78, 0.86, 0.96),
	"military": Color(0.90, 0.88, 0.82),
}
const SCHOOL_ICON_COLOR := {
	"pyromancy": Color(0.72, 0.32, 0.22),
	"nature": Color(0.22, 0.52, 0.32),
	"necromancy": Color(0.45, 0.28, 0.62),
	"illusion": Color(0.22, 0.42, 0.72),
	"military": Color(0.42, 0.44, 0.48),
}
const HP_FILL := Color(0.35, 0.78, 0.42)
const HP_LOW := Color(0.9, 0.35, 0.3)
const HP_MID := Color(0.9, 0.7, 0.25)


static func school_color(school: String) -> Color:
	return SCHOOL_COLORS.get(school, Color.GRAY)


static func rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.GRAY)


static func hp_color(ratio: float) -> Color:
	if ratio <= 0.25:
		return HP_LOW
	if ratio <= 0.5:
		return HP_MID
	return HP_FILL


static func apply_panel_style(panel: PanelContainer) -> void:
	apply_card_style(panel, 6, PANEL, ACCENT)


static func apply_card_style(panel: PanelContainer, radius: int = 14, bg: Color = CARD, border: Color = CARD_BORDER) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)


static func apply_compact_card(panel: PanelContainer, radius: int = 12) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)


static func style_button(btn: Button, accent: bool = false) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT if accent else Color(0.22, 0.18, 0.32)
	sb.border_color = ACCENT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.BLACK if accent else TEXT)


static func style_primary_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PRIMARY_BTN
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	btn.add_theme_font_size_override("font_size", 18)


static func style_accent_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BLUE
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = BLUE.lightened(0.08)
	var disabled := sb.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.22, 0.23, 0.27)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", TEXT_DIM)


static func apply_primary_card(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PRIMARY_BTN
	sb.set_corner_radius_all(14)
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", sb)


static func style_icon_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.18, 0.22)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", BLUE)


static func style_nav_tile(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)


static func style_nav_tile_button(btn: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = CARD_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 14
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	btn.add_theme_stylebox_override("normal", sb)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.18, 0.22)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color.WHITE)


static func school_slot_bg(school: String) -> Color:
	return SCHOOL_SLOT_BG.get(school, Color(0.3, 0.3, 0.34))


static func school_icon_color(school: String) -> Color:
	return SCHOOL_ICON_COLOR.get(school, Color.WHITE)


static func school_emoji(school: String) -> String:
	match school:
		"pyromancy": return "🔥"
		"nature": return "🌿"
		"necromancy": return "💀"
		"illusion": return "✨"
		"military": return "🛡️"
	return "◆"


static func school_label(school: String) -> String:
	match school:
		"necromancy": return "Necromancy"
		"pyromancy": return "Pyromancy"
		"illusion": return "Illusion"
		"military": return "Military"
		"nature": return "Nature"
	return school.capitalize()


static func school_icon(school: String) -> String:
	return school_emoji(school)


static func familiar_brief_name(display_name: String) -> String:
	var parts: PackedStringArray = display_name.split(" ")
	if parts.is_empty():
		return display_name
	return parts[0]


static func role_icon(role: String) -> String:
	match role:
		"tank": return "⛨"
		"support": return "✚"
		"disruptor": return "⚡"
	return "♨"


static func style_filter_pill(btn: Button, selected: bool) -> void:
	var sb := StyleBoxFlat.new()
	if selected:
		sb.bg_color = PRIMARY_BTN
		sb.set_border_width_all(0)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.12))
	else:
		sb.bg_color = Color(0.14, 0.14, 0.17)
		sb.border_color = Color(0.28, 0.28, 0.32)
		sb.set_border_width_all(1)
		btn.add_theme_color_override("font_color", TEXT_MUTED)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)


static func apply_synergy_panel(panel: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.border_color = BLUE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)


static func make_empty_slot_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.11, 0.13)
	sb.border_color = Color(0.35, 0.35, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


static func make_pill() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.18, 0.21)
	sb.set_corner_radius_all(20)
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func configure_mobile_scroll(
	scroll: ScrollContainer,
	horizontal: bool = false,
	vertical: bool = true
) -> void:
	set_mobile_scroll_horizontal(scroll, horizontal)
	set_mobile_scroll_vertical(scroll, vertical)


static func set_mobile_scroll_horizontal(scroll: ScrollContainer, enabled: bool) -> void:
	scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if enabled
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


static func set_mobile_scroll_vertical(scroll: ScrollContainer, enabled: bool) -> void:
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if enabled
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


static func is_mobile_scroll_enabled(axis_mode: int) -> bool:
	return axis_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
