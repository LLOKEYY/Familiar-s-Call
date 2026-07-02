extends PanelContainer

var _title: Label
var _body: Label
var _built: bool = false


func _ready() -> void:
	_ensure_built()


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(260, 0)
	UITheme.apply_panel_style(self)
	z_index = 100

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 14)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	vbox.add_child(_title)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 240
	_body.add_theme_font_size_override("font_size", 11)
	_body.add_theme_color_override("font_color", UITheme.TEXT)
	vbox.add_child(_body)


func show_for(data: FamiliarData, global_pos: Vector2) -> void:
	_ensure_built()
	if _title == null or _body == null:
		return
	_title.text = "%s (%s)" % [data.display_name, data.rarity.capitalize()]
	_body.text = "%s | %s\nSPD %d  HP %d  ATK %d\n\n%s" % [
		data.school.capitalize(),
		data.role.capitalize(),
		data.speed,
		data.hp,
		data.atk,
		data.passive_text,
	]
	position = global_pos + Vector2(12, 12)
	visible = true


func hide_tooltip() -> void:
	visible = false
