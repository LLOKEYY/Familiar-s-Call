class_name MobileScrollContainer
extends ScrollContainer

## Touch/mouse drag scrolling with hidden scroll bars (mobile-first).

var swipe_horizontal: bool = false
var swipe_vertical: bool = true
var swipe_enabled: bool = true

const DRAG_THRESHOLD := 12.0

var _tracking: bool = false
var _panning: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _start_scroll_h: int = 0
var _start_scroll_v: int = 0
var _pan_horizontal: bool = false


static func create(horizontal: bool = false, vertical: bool = true) -> MobileScrollContainer:
	var scroll := MobileScrollContainer.new()
	scroll.swipe_horizontal = horizontal
	scroll.swipe_vertical = vertical
	return scroll


func _ready() -> void:
	clip_contents = true
	_apply_scroll_modes()
	set_process_input(true)


func configure(horizontal: bool, vertical: bool) -> MobileScrollContainer:
	swipe_horizontal = horizontal
	swipe_vertical = vertical
	_apply_scroll_modes()
	return self


func set_swipe_enabled(enabled: bool) -> void:
	swipe_enabled = enabled
	_apply_scroll_modes()
	if not enabled:
		_reset_pan()


func is_swipe_active() -> bool:
	return swipe_enabled and (swipe_horizontal or swipe_vertical)


func _apply_scroll_modes() -> void:
	var h_on := swipe_horizontal and swipe_enabled
	var v_on := swipe_vertical and swipe_enabled
	horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if h_on
		else ScrollContainer.SCROLL_MODE_DISABLED
	)
	vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_SHOW_NEVER
		if v_on
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		scroll_horizontal = _clamp_h(scroll_horizontal)
		scroll_vertical = _clamp_v(scroll_vertical)


func _input(event: InputEvent) -> void:
	if not is_swipe_active():
		return
	if not _tracking and not _panning:
		if event is InputEventScreenTouch and event.pressed:
			if not _contains_global_point(event.position):
				return
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _contains_global_point(event.position):
				return
		else:
			return
	_handle_pan_event(event)


func _contains_global_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _handle_pan_event(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_track(event.position)
		else:
			_end_track()
	elif event is InputEventScreenDrag:
		_update_track(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_track(event.position)
		else:
			_end_track()
	elif event is InputEventMouseMotion and _tracking and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_track(event.position)


func _begin_track(pos: Vector2) -> void:
	_tracking = true
	_panning = false
	_start_pos = pos
	_start_scroll_h = scroll_horizontal
	_start_scroll_v = scroll_vertical


func _update_track(pos: Vector2) -> void:
	if not _tracking:
		return
	var delta := _start_pos - pos
	if not _panning:
		if delta.length() < DRAG_THRESHOLD:
			return
		_panning = true
		if swipe_horizontal and swipe_vertical:
			_pan_horizontal = absf(delta.x) > absf(delta.y)
		elif swipe_horizontal:
			_pan_horizontal = true
		else:
			_pan_horizontal = false
	if _panning:
		if _pan_horizontal and swipe_horizontal:
			scroll_horizontal = _clamp_h(int(_start_scroll_h + delta.x))
		elif not _pan_horizontal and swipe_vertical:
			scroll_vertical = _clamp_v(int(_start_scroll_v + delta.y))
		get_viewport().set_input_as_handled()


func _end_track() -> void:
	if not _tracking and not _panning:
		return
	_tracking = false
	_panning = false


func _reset_pan() -> void:
	_tracking = false
	_panning = false


func clamp_horizontal(value: int) -> int:
	return _clamp_h(value)


func clamp_vertical(value: int) -> int:
	return _clamp_v(value)


func _clamp_h(value: int) -> int:
	return clampi(value, 0, _max_scroll_h())


func _clamp_v(value: int) -> int:
	return clampi(value, 0, _max_scroll_v())


func _max_scroll_h() -> int:
	if get_child_count() == 0:
		return 0
	var content: Control = get_child(0)
	var content_w := maxi(int(content.size.x), int(content.get_combined_minimum_size().x))
	return maxi(0, content_w - int(size.x))


func _max_scroll_v() -> int:
	if get_child_count() == 0:
		return 0
	var content: Control = get_child(0)
	var content_h := maxi(int(content.size.y), int(content.get_combined_minimum_size().y))
	return maxi(0, content_h - int(size.y))
