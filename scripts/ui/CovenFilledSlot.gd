class_name CovenFilledSlot
extends PanelContainer

signal familiar_tapped(familiar_id: String)
signal familiar_drag_started(familiar_id: String, slot_index: int)

const HOLD_SEC := 0.38

var familiar_data: FamiliarData
var slot_index: int = -1
var _pointer_down: bool = false
var _hold_timer: float = 0.0
var _drag_started: bool = false


static func create(data: FamiliarData, slot_idx: int) -> CovenFilledSlot:
	var slot := CovenFilledSlot.new()
	slot.familiar_data = data
	slot.slot_index = slot_idx
	slot._build()
	return slot


func _ready() -> void:
	set_process(false)


func _build() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.CARD
	sb.border_color = UITheme.rarity_color(familiar_data.rarity)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var art := PanelContainer.new()
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	art.size_flags_stretch_ratio = 1.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_sb := StyleBoxFlat.new()
	art_sb.bg_color = UITheme.school_slot_bg(familiar_data.school)
	art_sb.set_corner_radius_all(6)
	art.add_theme_stylebox_override("panel", art_sb)
	vbox.add_child(art)

	var emoji := Label.new()
	emoji.text = UITheme.school_emoji(familiar_data.school)
	emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji.set_anchors_preset(Control.PRESET_FULL_RECT)
	emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji.add_theme_font_size_override("font_size", 20)
	emoji.add_theme_color_override("font_color", UITheme.school_icon_color(familiar_data.school))
	art.add_child(emoji)

	var name_lbl := Label.new()
	name_lbl.text = UITheme.familiar_brief_name(familiar_data.display_name)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.clip_text = true
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(name_lbl)

	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down = true
			_hold_timer = 0.0
			_drag_started = false
			set_process(true)
		else:
			_finish_pointer()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down = true
			_hold_timer = 0.0
			_drag_started = false
			set_process(true)
		else:
			_finish_pointer()


func _process(delta: float) -> void:
	if not _pointer_down or _drag_started:
		return
	_hold_timer += delta
	if _hold_timer >= HOLD_SEC:
		_drag_started = true
		set_process(false)
		familiar_drag_started.emit(familiar_data.id, slot_index)


func _finish_pointer() -> void:
	set_process(false)
	if _pointer_down and not _drag_started:
		familiar_tapped.emit(familiar_data.id)
	_pointer_down = false
	_drag_started = false
	_hold_timer = 0.0


func cancel_gesture() -> void:
	_pointer_down = false
	_drag_started = false
	_hold_timer = 0.0
	set_process(false)
